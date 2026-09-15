#!/usr/bin/env python3
"""Compile SDK-derived expressions in typed native contexts; report exact successes/failures."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from .platforms.ios_api import SDKCatalog, Reference, _identifier, TargetAvailabilityError
from .ios_sdk_environment import locate, target as sdk_target, validate_report
from .symbolgraph import graph_paths
from .platforms.swift_imports import public_imports
from .frontends import unique_object


def compiler_sources():
    root=Path(__file__).parent
    return {str(path.relative_to(root)):hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(root.rglob('*.py'))}


def deployment_version(value):
    if not isinstance(value,str) or not re.fullmatch(r'[1-9][0-9]{0,2}\.[0-9]{1,2}',value):
        raise ValueError('iOS deployment version requires major.minor, for example 18.0')
    return tuple(map(int,value.split('.')))


def dependency_graphs(modules):
    if not isinstance(modules, dict) or len(modules)>32:
        raise ValueError('Type modules require at most 32 named graph inputs')
    paths={};inputs={}
    for module,path in sorted(modules.items()):
        _identifier(module)
        paths[module]=graph_paths(path)
        inputs[module]=[{'name':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths[module]]
    return paths,inputs


def parse_type_modules(entries):
    result={}
    for entry in entries:
        if '=' not in entry: raise ValueError('Type module requires MODULE=SYMBOLGRAPH_DIR')
        module,path=entry.split('=',1)
        if module in result: raise ValueError('Duplicate type module: '+module)
        _identifier(module)
        if not path: raise ValueError('Type module requires a graph path')
        result[module]=path
    return result


def entry_key(entry):
    from .ios_native_variants import validate_identity
    if 'variant' in entry: validate_identity(entry['variant'])
    return (entry['module'],entry['id'],entry.get('variant'))

def member_identity(entry):
    return {key:entry[key] for key in ('module','id','variant') if key in entry}

def candidate_for(catalog, api, module, version, explicit_imports, variant=None):
    if variant is not None:
        catalog=catalog.select(api.id,variant)

    params=[];receiver=None
    if api.owner_parameters:
        try:
            receiver=catalog.probe_receiver(api.id,version)
            api=catalog.specialize(api.id,receiver)
        except ValueError:raise
    if api.owner_kind == 'protocol' and api.kind in ('static_method', 'static_property'):
        receiver=Reference('receiver','any '+api.owner+'.Type');params.append('receiver: '+receiver.type)
    if api.kind in ('method','property'):
        receiver=Reference('receiver',api.owner,mutable=api.mutating);params.append(('inputReceiver' if api.mutating else 'receiver')+': '+api.owner)
    values=[]
    for index,param in enumerate(api.parameters):
        name='p'+str(index);params.append(name+': '+('inout ' if param.inout else '@escaping ' if param.escaping else '')+param.type);values.append(Reference(name,param.type,mutable=param.inout))
    try:
        emission=catalog.emit_call(api.id,values,receiver=receiver,ios_version=version,allow_async=True,allow_throws=True,actor_context='main')
        expression=emission.expression
    except ValueError:raise
    function='dcflight_verify_'+hashlib.sha256((api.id+('\0'+variant if variant else '')).encode()).hexdigest()[:16]
    effects=(' async' if api.async_ or api.actor_isolation=='instance' else '')+(' throws' if api.throws else '')
    source='@MainActor func '+function+'('+', '.join(params)+')'+effects+' { '+('var receiver = inputReceiver; ' if api.mutating else '')+'let _: '+emission.result_type+' = '+expression+' }'
    candidate={'id':api.id,'module':module,'source':source,**({'variant':variant} if variant else {})}
    if api.owner_parameters: candidate['specialization']={'receiverType':receiver.type}
    candidate['imports']=list(public_imports(set(emission.imports)|set(explicit_imports)))
    for name in candidate['imports']:_identifier(name)
    return candidate

def main(argv=None, *, progress=True):
    p=argparse.ArgumentParser()
    p.add_argument('--module',action='append',required=True,metavar='MODULE=SYMBOLGRAPH_DIR')
    p.add_argument('--type-module',action='append',default=[],metavar='MODULE=SYMBOLGRAPH_DIR')
    p.add_argument('--limit',type=int,default=1000,help='Maximum sampled signatures per module; 0 means all')
    p.add_argument('--batch-size',type=int,default=100)
    p.add_argument('--ios-version',default='18.0')
    p.add_argument('--sdk-environment',choices=('iphonesimulator','iphoneos'),default='iphonesimulator')
    p.add_argument('--swift-version',choices=('5','6'),default='5')
    p.add_argument('--import',dest='additional_imports',action='append',default=[])
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args(argv)
    if len(args.additional_imports)>32: raise ValueError('Too many additional imports')
    for module in args.additional_imports: _identifier(module)
    version=deployment_version(args.ios_version)
    target=sdk_target(args.sdk_environment,version)
    if args.limit < 0 or args.batch_size < 1:
        p.error('limit must be nonnegative and batch-size must be positive')
    if args.output.exists():
        p.error('output already exists; choose a fresh evidence path')
    sdk_identity=locate(args.sdk_environment);sdk=sdk_identity['sdk'];sdk_version=sdk_identity['sdkVersion']
    compiler_identity=compiler_sources()
    swift=subprocess.check_output(['xcrun','swiftc','--version'],text=True).strip()
    type_paths,type_inputs=dependency_graphs(parse_type_modules(args.type_module))
    candidates=[];skipped=[];coverage={};inputs={}
    for entry in args.module:
        module,path=entry.split('=',1)
        paths=graph_paths(path)
        inputs[module]=[{'name':graph.name,'sha256':hashlib.sha256(graph.read_bytes()).hexdigest()} for graph in paths]
        catalog=SDKCatalog.from_symbolgraphs(paths,module,type_graphs=type_paths)
        coverage[module]=catalog.coverage()
        apis=sorted(((variant if len(group)>1 else None,a) for group in catalog.variants.values() for variant,a in group.items()
                     if not a.unsupported or (a.unsupported == ('generic owner requires explicit specialization',) and a.owner_parameters)),key=lambda item:(item[1].id,item[0] or ''))
        if args.limit and len(apis)>args.limit:
            apis=[apis[i*len(apis)//args.limit] for i in range(args.limit)]
        for variant,api in apis:
            try:candidates.append(candidate_for(catalog,api,module,version,args.additional_imports,variant))
            except TargetAvailabilityError as error:skipped.append({'id':api.id,'module':module,**({'variant':variant} if variant else {}),'reason':str(error),'classification':error.classification})
            except ValueError as error:skipped.append({'id':api.id,'module':module,**({'variant':variant} if variant else {}),'reason':str(error)})
    passed=[];failed=[];invocations=[]
    groups={}
    for candidate in candidates:groups.setdefault(tuple(candidate['imports']),[]).append(candidate)
    work=[(imports,group[start:start+args.batch_size]) for imports,group in sorted(groups.items()) for start in range(0,len(group),args.batch_size)]
    if not work:work=[((),[])]
    with tempfile.TemporaryDirectory() as temp:
        sourcepath=Path(temp)/'Verify.swift'
        for import_set,remaining in work:
            imports=''.join('import '+module+'\n' for module in import_set);import_lines=len(import_set)
            # Remove only entries with compiler errors, then recompile survivors. A successful
            # complete compiler invocation is required before recording any surviving API.
            for attempt in range(6):
                if not remaining: break
                sourcepath.write_text(imports+'\n'.join(x['source'] for x in remaining)+'\n')
                command=['xcrun','swiftc','-typecheck','-swift-version',args.swift_version,'-target',target,'-sdk',sdk,str(sourcepath)]
                proc=subprocess.run(command,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
                invocation={'imports':list(import_set),'members':[member_identity(c) for c in remaining],'sourceSHA256':hashlib.sha256(sourcepath.read_bytes()).hexdigest(),'command':command,'commandSHA256':hashlib.sha256(json.dumps(command,separators=(',',':')).encode()).hexdigest(),'exitCode':proc.returncode}
                invocations.append(invocation)
                if proc.returncode==0:
                    passed.extend(remaining);remaining=[];break
                errors={}
                for match in re.finditer(r'Verify.swift:(\d+):\d+: error: ([^\n]+)',proc.stdout):
                    index=int(match.group(1))-import_lines-1
                    if 0<=index<len(remaining): errors.setdefault(index,[]).append(match.group(2))
                if not errors:
                    failed.extend({**case,'errors':['Batch failed without attributable diagnostics',proc.stdout[:2000]]} for case in remaining)
                    remaining=[];break
                failed.extend({**remaining[index],'errors':messages} for index,messages in errors.items())
                remaining=[case for index,case in enumerate(remaining) if index not in errors]
            failed.extend({**case,'errors':['Batch retries exhausted; not certified']} for case in remaining)
            report={**sdk_identity,'kind':'dcflight.ios.import-contract.v2','invocations':invocations,'target':target,'iosVersion':list(version),'sdk':sdk,'coverage':coverage,
                    'swiftLanguageVersion':args.swift_version,
                    'additionalImports':args.additional_imports,
                    'sdkVersion':sdk_version,'compilerSources':compiler_identity,
                    'swift':swift,'inputs':inputs,'typeInputs':type_inputs,'automaticTypeImports':'referenced','actorContext':'main',
                    'verification':'Native Swift typechecking only; no runtime execution claim',
                    'candidateCount':len(candidates),'nativeTested':len(passed),'failedCount':len(failed),'skippedCount':len(skipped),
                    'passed':passed,'failed':failed,'skipped':skipped}
            args.output.parent.mkdir(parents=True,exist_ok=True)
            args.output.write_text(json.dumps(report,indent=2)+'\n')
            if progress: print(json.dumps({'processed':len(passed)+len(failed),'candidates':len(candidates),'passed':len(passed),'failed':len(failed)}),flush=True)
    # A process exit status must not certify a failed or vacuous native sweep.
    # Skipped target APIs remain explicit in the report; this is no coverage claim.
    return 0 if passed and not failed else 1



def export_records(module_paths, report_path, output, *, type_modules=None):
    """Write current descriptors with target-scoped native certification and failures closed."""
    report=json.loads(Path(report_path).read_text(),object_pairs_hook=unique_object)
    additional=report.get('additionalImports',[])
    if not isinstance(additional,list) or len(additional)>32: raise ValueError('Invalid additional imports')
    for module in additional: _identifier(module)
    output=Path(output)
    if output.exists():
        raise ValueError('Descriptor output already exists; choose a fresh path')
    if report.get('compilerSources') != compiler_sources():
        raise ValueError('Compiler changed since native verification')
    for count,items in (('nativeTested','passed'),('failedCount','failed'),('skippedCount','skipped')):
        if type(report.get(count)) is not int or report[count] != len(report[items]):
            raise ValueError('Inconsistent native report count: '+count)
    if type(report.get('candidateCount')) is not int or report['candidateCount'] != len(report['passed'])+len(report['failed']):
        raise ValueError('Native batch report is incomplete')
    if any(not isinstance(report.get(key),str) or not report[key] for key in ('target','sdk')):
        raise ValueError('Native report must identify target and SDK')
    for item in report['failed']:
        errors=item.get('errors')
        if not isinstance(errors,list) or not errors or any(not isinstance(e,str) or not e for e in errors):
            raise ValueError('Rejected API needs native diagnostics')
    for item in report['skipped']:
        if not isinstance(item.get('reason'),str) or not item['reason']:
            raise ValueError('Skipped API needs a reason')
    identities=[entry_key(x) for category in ('passed','failed','skipped') for x in report[category]]
    if len(set(identities)) != len(identities):
        raise ValueError('Duplicate or conflicting native evidence identity')
    if set(module_paths) != set(report.get('inputs',{})):
        raise ValueError('Export modules differ from verified inputs')
    type_paths,type_inputs=dependency_graphs(type_modules or {})
    if type_inputs != report.get('typeInputs',{}):
        raise ValueError('Type dependency graphs differ from verified inputs')
    catalogs={}
    for module,path in module_paths.items():
        paths=graph_paths(path)
        current=[{'name':graph.name,'sha256':hashlib.sha256(graph.read_bytes()).hexdigest()} for graph in paths]
        if current != report['inputs'][module]:
            raise ValueError('SDK graphs changed since native verification: '+module)
        catalogs[module]=SDKCatalog.from_symbolgraphs(paths,module,type_graphs=type_paths)
    for module,identity,variant in identities:
        if module not in catalogs or identity not in catalogs[module].apis:
            raise ValueError('Native evidence references unknown SDK identity')
        catalogs[module].get(identity,variant)  # Skips also require an exact known call form.
    for entry in report['passed']:
        api=catalogs[entry['module']].get(entry['id'],entry.get('variant'))
        specialization=entry.get('specialization')
        if api.owner_parameters:
            if not isinstance(specialization,dict) or set(specialization)!={'receiverType'} or not isinstance(specialization['receiverType'],str):
                raise ValueError('Generic native proof requires an exact receiver specialization')
            catalogs[entry['module']].select(api.id,entry.get('variant')).specialize(api.id,Reference('receiver',specialization['receiverType'],mutable=api.mutating))
        elif specialization is not None:
            raise ValueError('Unexpected receiver specialization on nongeneric native proof')
    if report.get('kind')!='dcflight.ios.import-contract.v2':
        raise ValueError('Native export requires import-contract v2 report; regenerate legacy evidence')
    if report.get('automaticTypeImports') != 'referenced':
        raise ValueError('Native export requires referenced automatic type import contract')
    version=deployment_version('.'.join(map(str,report.get('iosVersion',[]))))
    environment_name=validate_report(report)
    if report.get('actorContext')!='main' or report.get('target')!=sdk_target(environment_name,version):raise ValueError('Native report context differs')
    expected={}
    for entry in report['passed']+report['failed']:
        key=entry_key(entry)
        candidate=candidate_for(catalogs[key[0]],catalogs[key[0]].get(key[1],key[2]),key[0],version,additional,key[2])
        if any(entry.get(field)!=candidate.get(field) for field in ('source','imports','specialization','variant')):raise ValueError('Native candidate import/source contract differs')
        expected[key]=candidate
    successful=set();invocations=report.get('invocations')
    if not isinstance(invocations,list) or len(invocations)>max(1,len(expected)*6):raise ValueError('Invalid native invocation list')
    for invocation in invocations:
        if not isinstance(invocation,dict):raise ValueError('Invalid native invocation')
        members=invocation.get('members');imports=invocation.get('imports');command=invocation.get('command')
        if not isinstance(members,list) or not members or len(members)>len(expected):raise ValueError('Invalid invocation members')
        keys=[]
        for member in members:
            if not isinstance(member,dict) or set(member) not in ({'module','id'},{'module','id','variant'}):raise ValueError('Invalid invocation identity')
            key=entry_key(member)
            if key not in expected or key in keys:raise ValueError('Unknown or duplicate invocation candidate')
            keys.append(key)
            if expected[key]['imports']!=imports:raise ValueError('Cross-candidate import leakage')
        source=''.join('import '+name+'\n' for name in imports)+'\n'.join(expected[key]['source'] for key in keys)+'\n'
        if hashlib.sha256(source.encode()).hexdigest()!=invocation.get('sourceSHA256'):raise ValueError('Invocation source hash differs')
        prefix=['xcrun','swiftc','-typecheck','-swift-version',report.get('swiftLanguageVersion'),'-target',report['target'],'-sdk',report['sdk']]
        if not isinstance(command,list) or len(command)!=len(prefix)+1 or command[:-1]!=prefix or not isinstance(command[-1],str) or Path(command[-1]).name!='Verify.swift':raise ValueError('Invocation native command differs')
        if hashlib.sha256(json.dumps(command,separators=(',',':')).encode()).hexdigest()!=invocation.get('commandSHA256'):raise ValueError('Invocation command hash differs')
        if type(invocation.get('exitCode')) is not int:raise ValueError('Invalid invocation exit status')
        if invocation['exitCode']==0:successful.update(keys)
    if successful!={entry_key(entry) for entry in report['passed']}:raise ValueError('Native successes lack exact successful invocation')
    target_unavailable={}
    for entry in report['skipped']:
        if 'classification' not in entry:continue
        key=entry_key(entry)
        try:candidate_for(catalogs[key[0]],catalogs[key[0]].get(key[1],key[2]),key[0],version,additional,key[2])
        except TargetAvailabilityError as error:
            if json.dumps(entry['classification'],sort_keys=True)!=json.dumps(error.classification,sort_keys=True):raise ValueError('Target availability classification differs from SDK replay')
            target_unavailable[key]=error.classification
        except ValueError as error:raise ValueError('Target availability classification does not match SDK failure') from error
        else:raise ValueError('Target availability classification does not match available SDK candidate')
    # A report's helper imports are part of its compile context. Preserve them
    # on the public descriptor and replay through the single-record authoring
    # path; no dependency catalog or verifier-only import may be needed later.
    def retain_import_context(record, key):
        imports = (set(expected[key]['imports']) if key in successful else set(additional)) - {key[0]}
        record['requiredImports'] = sorted(set(record.get('requiredImports', [])) | set(imports))
        if len(record['requiredImports']) > 32:
            raise ValueError('Exported import context exceeds 32 module names')
        return record
    for module, catalog in catalogs.items():
        for original in catalog.records():
            children=original.get('nativeVariants',[original])
            for record in children:
                key = (module, record['id'],record.get('variant'))
                retain_import_context(record,key)
                if key not in successful: continue
                standalone = SDKCatalog.from_records([record])
                replay = candidate_for(standalone, standalone.get(key[1],key[2]), module, version, [],key[2])
                if any(replay.get(field) != expected[key].get(field) for field in ('source','imports','specialization','variant')):
                    raise ValueError('Exported standalone native import/source contract differs')
    # Validate every module before writing anything. A failed validation must not
    # leave a partially certified descriptor directory for another tool to read.
    output.mkdir(parents=True)
    passed={entry_key(x) for x in report['passed']}
    specializations={entry_key(x):x['specialization'] for x in report['passed'] if 'specialization' in x}
    failed={entry_key(x):x['errors'] for x in report['failed']}
    skipped={entry_key(x):x['reason'] for x in report['skipped']}
    summaries={}
    for module,catalog in catalogs.items():
        counts={'indexed':0,'emittable_signatures':0,'native_tested':0,'native_specializations':0,'native_rejected':0,'target_skipped':0,'variants_indexed':0,'variant_emittable_signatures':0}
        with (output/(module+'.jsonl')).open('w') as stream:
            for parent in catalog.records():
                counts['indexed']+=1
                children=parent.get('nativeVariants',[parent])
                for record in children:
                    key=(module,record['id'],record.get('variant'))
                    retain_import_context(record, key)
                    status='untested';errors=[]
                    if key in passed:
                        status='passed'
                        counts['native_specializations' if key in specializations else 'native_tested']+=1
                    if key in failed: status='rejected';errors=failed[key];counts['native_rejected']+=1
                    if key in skipped: status='target_unavailable' if key in target_unavailable else 'skipped';errors=[skipped[key]];counts['target_skipped']+=1
                    record['nativeConformance']={'sdkEnvironment':environment_name,'status':status,'target':report['target'],'sdk':report['sdk'],'diagnostics':errors}
                    if key[2] is not None:record['nativeConformance']['variant']=key[2]
                    if key in specializations: record['nativeConformance']['specialization']=specializations[key]
                    if key in target_unavailable:record['nativeConformance']['classification']=target_unavailable[key]
                    if errors and key not in target_unavailable:
                        record['emittable']=False
                        record['unsupportedReasons']+=['Native '+status+': '+error for error in errors]
                    counts['variants_indexed']+=1
                    counts['variant_emittable_signatures']+=record['emittable']
                counts['emittable_signatures']+=parent['emittable']
                stream.write(json.dumps(parent)+'\n')
        summaries[module]=counts
    (output/'coverage.json').write_text(json.dumps({'target':report['target'],'modules':summaries},indent=2)+'\n')
    return summaries


def verify_and_index(database, source, module, report_path, *, limit=0, batch_size=200, ios_version='18.0', swift_version='5', additional_imports=(), type_modules=None,sdk_environment='iphonesimulator'):
    """Verify real SDK calls and atomically replace one catalog scope with evidence."""
    from .catalog import Catalog
    deployment_version(ios_version)
    if not isinstance(additional_imports,(list,tuple)) or len(additional_imports)>32:
        raise ValueError('Invalid additional imports')
    for name in additional_imports: _identifier(name)
    if swift_version not in ('5','6'): raise ValueError('Swift language version must be 5 or 6')
    if type(limit) is not int or limit < 0 or type(batch_size) is not int or batch_size < 1:
        raise ValueError('Invalid verification limits')
    report_path=Path(report_path)
    descriptors=report_path.with_suffix('.descriptors')
    if report_path.exists() or descriptors.exists():
        raise ValueError('Verification requires fresh report and descriptor paths')
    main(['--module',module+'='+str(source),'--limit',str(limit),'--batch-size',str(batch_size),
          '--output',str(report_path),'--ios-version',ios_version,'--swift-version',swift_version,'--sdk-environment',sdk_environment]+
         [item for name in additional_imports for item in ('--import',name)]+
         [item for name,path in (type_modules or {}).items() for item in ('--type-module',name+'='+str(path))],progress=False)
    summary=export_records({module:source},report_path,descriptors,type_modules=type_modules)[module]
    report=json.loads(report_path.read_text(),object_pairs_hook=unique_object)
    records_path=descriptors/(module+'.jsonl')
    report_hash=hashlib.sha256(report_path.read_bytes()).hexdigest()
    toolchain={'sdkEnvironment':report['sdkEnvironment'],'sdkSettingsSHA256':report['sdkSettingsSHA256'],'sdk':report['sdk'],'swift':report['swift'],'target':report['target'],'swiftLanguageVersion':report['swiftLanguageVersion'],'additionalImports':report['additionalImports']}
    evidence={'command':['xcrun','swiftc','-typecheck','-swift-version',report['swiftLanguageVersion'],'-target',report['target'],'-sdk',report['sdk'],'<generated Verify.swift>'],
              'toolchain':toolchain,'reportPath':str(report_path.resolve()),'reportSha256':report_hash,
              'verification':report['verification']}
    provenance={'inputs':report['inputs'],'typeInputs':report.get('typeInputs',{}),'compilerSources':report['compilerSources'],
                'reportPath':str(report_path.resolve()),'reportSha256':report_hash,
                'recordsSha256':hashlib.sha256(records_path.read_bytes()).hexdigest(),'toolchain':toolchain}
    passed_ids={entry['id'] for entry in report['passed']}
    compiled_ids=[]
    with records_path.open() as stream:
        for line in stream:
            if not line.strip(): continue
            record=json.loads(line,object_pairs_hook=unique_object)
            if record['emittable'] and record['id'] in passed_ids and 'specialization' not in record.get('nativeConformance',{}):
                compiled_ids.append(record['id'])
    with Catalog(database,write=True) as catalog, records_path.open() as stream:
        result=catalog.import_records('ios',module if sdk_environment=='iphonesimulator' else module+'@iphoneos',report['sdkVersion'],
            (json.loads(line,object_pairs_hook=unique_object) for line in stream if line.strip()),provenance,
            compiled={'ids':compiled_ids, 'evidence':evidence})
    return {**result,**summary,'report':str(report_path.resolve()),'verification':report['verification']}
