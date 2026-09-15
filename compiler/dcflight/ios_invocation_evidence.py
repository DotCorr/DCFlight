"""Bounded, development-time proof for exact iOS operations and actor contexts.

Conditional proofs never promote a whole SDK descriptor. Native source is always
regenerated from freshly hashed graphs, and selected passes are recompiled.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,subprocess,tempfile
from pathlib import Path
from .platforms.ios_api import SDKCatalog,Reference,_identifier
from .symbolgraph import graph_paths
from .ios_sdk_environment import locate, target as sdk_target, validate_report

KIND='dcflight.ios.invocations.v1'
MARKER='conditional native invocation proof required'
CONTEXTS=('main','nonisolated')

def certificate_digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()).hexdigest()

def _hash(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def _toolchain(sdk_environment='iphonesimulator'):
    return {**locate(sdk_environment),'swift':subprocess.check_output(['xcrun','swiftc','--version'],text=True,stderr=subprocess.STDOUT).strip()}

def _sources(paths):return [{'path':str(Path(p).resolve()),'sha256':_hash(p)} for p in paths]

def _read_paths(rows):
    if not isinstance(rows,list) or not 1<=len(rows)<=256:raise ValueError('Expected bounded SDK input paths')
    result=[]
    for row in rows:
        if not isinstance(row,dict) or set(row)!={'path','sha256'} or not isinstance(row['path'],str) or _hash(row['path'])!=row['sha256']:
            raise ValueError('SDK graph input changed')
        path=Path(row['path'])
        if path in result:raise ValueError('Duplicate graph input')
        result.append(path)
    return result

def _key(row):return (row['id'],row.get('variant'),row['operation'],row['actorContext'])

def _variants(value,identities):
    from .ios_native_variants import validate_identity
    if not isinstance(value,dict) or len(value)>128 or not set(value)<=set(identities):raise ValueError('Invalid invocation variant selections')
    for variant in value.values():validate_identity(variant)
    return value

def _selected_record(catalog,identity,variants):
    record=catalog.get(identity,variants.get(identity)).to_dict()
    if identity in variants:record['variant']=variants[identity]
    return record

def _probes(catalog,identities,contexts,imports,version,variants=None):
    variants=_variants(variants or {},identities)
    probes=[]
    for identity in identities:
        selected=catalog.select(identity,variants.get(identity))
        api=selected.get(identity)
        # Generic receivers retain the established separate specialization path.
        if api.unsupported:raise ValueError('Invocation proof does not lower unsupported API: '+identity)
        operations=['get'] if api.kind.endswith('property') else ['call']
        if api.writable and api.kind.endswith('property'):operations.append('set')
        for operation in operations:
            for context in contexts:
                row={'id':identity,'operation':operation,'actorContext':context,'specialization':None,**({'variant':variants[identity]} if identity in variants else {})}
                try:
                    params=[];receiver=None
                    if api.kind in ('method','property'):
                        mutable=api.mutating if operation!='set' else api.setter_mutating is not False and api.owner_kind!='class'
                        receiver=Reference('receiver',api.owner,mutable=mutable)
                        params.append(('inputReceiver' if mutable else 'receiver')+': '+api.owner)
                    elif api.owner_kind=='protocol' and api.kind in ('static_method','static_property'):
                        receiver=Reference('receiver','any '+api.owner+'.Type');params.append('receiver: '+receiver.type)
                    values=[]
                    for i,param in enumerate(api.parameters):
                        name='p'+str(i);params.append(name+': '+('inout ' if param.inout else '@escaping ' if param.escaping else '')+param.type);values.append(Reference(name,param.type,mutable=param.inout))
                    if operation=='set':
                        params.append('value: '+api.result)
                        emitted=selected.emit_set(identity,Reference('value',api.result),receiver=receiver,ios_version=version,actor_context=context)
                    else:emitted=selected.emit_call(identity,values,receiver=receiver,ios_version=version,allow_async=True,allow_throws=True,actor_context=context)
                    effects=(' async' if operation!='set' and (api.async_ or api.actor_isolation=='instance') else '')+(' throws' if operation!='set' and api.throws else '')
                    prelude='var receiver = inputReceiver; ' if receiver and receiver.mutable else ''
                    body=emitted.expression if operation=='set' else 'let _: '+emitted.result_type+' = '+emitted.expression
                    header='\n'.join('import '+m for m in sorted(set(emitted.imports)|set(imports)))
                    name='dcflight_invocation_'+certificate_digest(row)[:16]
                    row['source']=header+'\n'+('@MainActor ' if context=='main' else 'nonisolated ')+'func '+name+'('+', '.join(params)+')'+effects+' { '+prelude+body+' }\n'
                except ValueError as error:row.update(source=None,generationDiagnostic=str(error))
                probes.append(row)
    return probes

def _compile(source,report):
    with tempfile.TemporaryDirectory(prefix='dcflight-ios-invocation-') as temporary:
        path=Path(temporary)/'probe.swift';path.write_text(source)
        command=['xcrun','swiftc','-typecheck','-swift-version','6','-target',report['target'],'-sdk',report['sdk'],str(path)]
        result=subprocess.run(command,capture_output=True,text=True,timeout=60)
        return result.returncode==0,(result.stderr or result.stdout)[-16000:]

def verify_invocations(graphs,module,identities,output,*,contexts=('main','nonisolated'),additional_imports=(),type_modules=None,ios_version=(18,0),sdk_environment='iphonesimulator',variant_selections=None):
    from .ios_verification import compiler_sources
    output=Path(output)
    if output.exists():raise ValueError('Use a fresh invocation report path')
    _identifier(module)
    if not isinstance(identities,(list,tuple)) or not 1<=len(identities)<=128 or len(set(identities))!=len(identities):raise ValueError('Provide1..128 distinct SDK IDs')
    if not contexts or len(set(contexts))!=len(contexts) or any(c not in CONTEXTS for c in contexts):raise ValueError('Explicit main/nonisolated contexts required')
    if not isinstance(ios_version,(tuple,list)) or len(ios_version)!=2 or any(type(v) is not int or v<0 for v in ios_version):raise ValueError('Invalid iOS target version')
    variants=_variants({} if variant_selections is None else variant_selections,identities)
    imports=list(additional_imports)
    if len(imports)>32:raise ValueError('Too many imports')
    for m in imports:_identifier(m)
    paths=graph_paths(graphs);type_modules=type_modules or {}
    if len(type_modules)>32:raise ValueError('Too many type modules')
    for m in type_modules:_identifier(m)
    types={m:graph_paths(p) for m,p in type_modules.items()};catalog=SDKCatalog.from_symbolgraphs(paths,module,type_graphs=types)
    report={'kind':KIND,'module':module,'ids':list(identities),'contexts':list(contexts),'iosVersion':list(ios_version),'target':sdk_target(sdk_environment,ios_version),'swiftLanguageVersion':'6','inputs':_sources(paths),'typeInputs':{m:_sources(p) for m,p in types.items()},'additionalImports':imports,'compilerSources':compiler_sources(),'compilerUnchanged':True,**_toolchain(sdk_environment),'descriptors':[_selected_record(catalog,i,variants) for i in identities],'invocations':[]}
    if variants:report['variantSelections']=dict(variants)
    for probe in _probes(catalog,identities,contexts,imports,ios_version,variants):
        if probe['source'] is None:probe.update(status='skipped',diagnostics=[probe['generationDiagnostic']])
        else:
            passed,diagnostic=_compile(probe['source'],report);probe.update(status='passed' if passed else 'rejected',diagnostics=[] if passed else [diagnostic or 'Native compiler rejected invocation'])
        report['invocations'].append(probe)
    report['compilerUnchanged']=compiler_sources()==report['compilerSources']
    if not report['compilerUnchanged']:raise ValueError('Compiler changed during invocation verification')
    _validate(report)
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
    return report

def _validate(report):
    from .ios_verification import compiler_sources
    fields={'kind','module','ids','contexts','iosVersion','target','swiftLanguageVersion','inputs','typeInputs','additionalImports','compilerSources','compilerUnchanged','sdk','sdkVersion','sdkSettingsSHA256','swift','descriptors','invocations'}
    if not isinstance(report,dict) or set(report) not in (fields,fields|{'sdkEnvironment'},fields|{'variantSelections'},fields|{'sdkEnvironment','variantSelections'}) or report['kind']!=KIND:raise ValueError('Malformed invocation report')
    if report['compilerUnchanged'] is not True or report['compilerSources']!=compiler_sources():raise ValueError('Invocation proof requires current compiler')
    env=validate_report(report)
    if any(report.get(k,'iphonesimulator' if k=='sdkEnvironment' else None)!=v for k,v in _toolchain(env).items()):raise ValueError('Invocation proof SDK/compiler identity mismatch')
    version=report['iosVersion']
    if not isinstance(version,list) or len(version)!=2 or any(type(v) is not int or v<0 for v in version) or report['target']!=sdk_target(env,version) or report['swiftLanguageVersion']!='6':raise ValueError('Invalid invocation target')
    ids=report['ids'];contexts=report['contexts'];_identifier(report['module'])
    if not isinstance(ids,list) or not 1<=len(ids)<=128 or any(not isinstance(i,str) or not i for i in ids) or len(set(ids))!=len(ids):raise ValueError('Malformed invocation IDs')
    if not isinstance(contexts,list) or not contexts or len(contexts)>2 or any(c not in CONTEXTS for c in contexts) or len(set(contexts))!=len(contexts):raise ValueError('Malformed invocation contexts')
    imports=report['additionalImports'];types=report['typeInputs']
    if not isinstance(imports,list) or len(imports)>32 or not isinstance(types,dict) or len(types)>32:raise ValueError('Malformed import metadata')
    for m in imports+list(types):_identifier(m)
    catalog=SDKCatalog.from_symbolgraphs(_read_paths(report['inputs']),report['module'],type_graphs={m:_read_paths(rows) for m,rows in types.items()})
    variants=_variants(report.get('variantSelections',{}),ids)
    if report['descriptors']!=[_selected_record(catalog,i,variants) for i in ids]:raise ValueError('Invocation descriptors differ from actual SDK input')
    expected=_probes(catalog,ids,contexts,imports,version,variants);rows=report['invocations']
    if not isinstance(rows,list) or len(rows)!=len(expected):raise ValueError('Incomplete invocation evidence')
    by_key={}
    for row in rows:
        if not isinstance(row,dict) or set(row)-{'id','operation','actorContext','specialization','source','generationDiagnostic','status','diagnostics','variant'} or not {'id','operation','actorContext','specialization','source','status','diagnostics'}<=set(row):raise ValueError('Malformed invocation row')
        if not isinstance(row['id'],str) or row['operation'] not in ('get','set','call') or row['actorContext'] not in CONTEXTS or row['specialization'] is not None:raise ValueError('Unsupported invocation key or specialization')
        key=_key(row)
        if key in by_key:raise ValueError('Duplicate invocation evidence')
        if row['status'] not in ('passed','rejected','skipped') or not isinstance(row['diagnostics'],list) or any(not isinstance(d,str) or not d for d in row['diagnostics']):raise ValueError('Invalid invocation status/diagnostics')
        if (row['status']=='passed')!= (not row['diagnostics']):raise ValueError('Missing rejection diagnostics')
        by_key[key]=row
    for probe in expected:
        row=by_key.get(_key(probe))
        if row is None or any(row.get(k)!=v for k,v in probe.items()) or (row['status']=='skipped')!=(probe['source'] is None):raise ValueError('Invocation source/context does not match regenerated SDK probe')
    return catalog,by_key

def conditional_records(report):
    _validate(report);certificate={'report':copy.deepcopy(report),'sha256':certificate_digest(report)}
    return [{**copy.deepcopy(record),'emittable':False,'unsupportedReasons':[*record['unsupportedReasons'],MARKER],'nativeInvocationEvidence':certificate} for record in report['descriptors']]

def select_invocation(record,request,cache=None):
    evidence=record.get('nativeInvocationEvidence')
    if not isinstance(evidence,dict) or set(evidence)!={'report','sha256'} or certificate_digest(evidence['report'])!=evidence['sha256']:raise ValueError('Invocation certificate changed')
    report=evidence['report'];catalog,rows=_validate(report)
    variants=report.get('variantSelections',{})
    base=_selected_record(catalog,record['id'],variants)
    if request.get('variant') != base.get('variant'):raise ValueError('Conditional invocation variant differs')
    expected={**base,'emittable':False,'unsupportedReasons':[*base['unsupportedReasons'],MARKER],'nativeInvocationEvidence':evidence}
    if record!=expected:raise ValueError('Conditional descriptor differs from SDK-bound proof')
    context=request.get('actorContext')
    if context not in CONTEXTS:raise ValueError('Conditional invocation requires explicit actor context')
    if request.get('sdkEnvironment','iphonesimulator')!=report.get('sdkEnvironment','iphonesimulator'):raise ValueError('Conditional invocation requires verified SDK environment')
    if request.get('iosVersion',[18,0])!=report['iosVersion']:raise ValueError('Conditional invocation requires verified iOS version')
    operation='set' if 'set' in request else 'get' if base['kind'].endswith('property') else 'call'
    row=rows.get((record['id'],base.get('variant'),operation,context))
    if row is None or row['status']!='passed':raise ValueError('Native invocation is not verified in this operation/context')
    key=(evidence['sha256'],_key(row))
    if cache is None or key not in cache:
        passed,diagnostic=_compile(row['source'],report)
        if not passed:raise ValueError('Native invocation revalidation failed: '+diagnostic)
        _validate(report)  # Inputs and compiler must also remain stable during compilation.
        if cache is not None:cache.add(key)
    # Only this exact request receives the normal descriptor. No stored promotion.
    return {**base,'requiredImports':sorted(set(base['requiredImports'])|set(report['additionalImports']))}


def add_arguments(parser):
    parser.add_argument('--variant',action='append',default=[],metavar='SDK_ID=VARIANT');parser.add_argument('graphs');parser.add_argument('--module',required=True);parser.add_argument('--id',action='append',required=True);parser.add_argument('--context',action='append',choices=CONTEXTS);parser.add_argument('--report',required=True);parser.add_argument('--records');parser.add_argument('--import',dest='imports',action='append',default=[]);parser.add_argument('--type-module',action='append',default=[]);parser.add_argument('--ios-version',default='18.0');parser.add_argument('--sdk-environment',choices=('iphonesimulator','iphoneos'),default='iphonesimulator')

def run(args):
    from .ios_verification import deployment_version,parse_type_modules
    if args.records and Path(args.records).exists():raise ValueError('Use fresh descriptor output')
    variants={}
    for entry in getattr(args,'variant',[]):
        if '=' not in entry:raise ValueError('Variant requires SDK_ID=VARIANT')
        identity,variant=entry.rsplit('=',1)
        if identity in variants:raise ValueError('Duplicate variant selection')
        variants[identity]=variant
    report=verify_invocations(args.graphs,args.module,args.id,args.report,contexts=args.context or CONTEXTS,additional_imports=args.imports,type_modules=parse_type_modules(args.type_module),ios_version=deployment_version(args.ios_version),sdk_environment=args.sdk_environment,variant_selections=variants)
    if args.records:Path(args.records).write_text(''.join(json.dumps(r)+'\n' for r in conditional_records(report)))
    counts={s:sum(r['status']==s for r in report['invocations']) for s in ('passed','rejected','skipped')}
    return {'conditionalInvocations':counts,'wholeDescriptorPromotions':0,'report':args.report,'passed':bool(counts['passed']) and not counts['rejected'] and not counts['skipped']}

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);add_arguments(parser)
    result=run(parser.parse_args(argv));print(json.dumps(result));return 0 if result['passed'] else 1
