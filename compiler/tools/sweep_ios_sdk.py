#!/usr/bin/env python3
"""Resumable, bounded discovery/extraction of public installed iOS SDK modules."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import gzip
import hashlib
import json
import os
import stat
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.platforms.ios_api import SDKCatalog
from dcflight.symbolgraph import graph_paths
from dcflight.ios_verification import compiler_sources


def normalize_graphs(paths, module, output):
    # Use the same owner/actor-aware passes as native verification.
    catalog=SDKCatalog.from_symbolgraphs(paths,module)
    output=Path(output); reject_symlinks(output)
    temporary=exclusive_temp(output)
    counts={'indexed':0,'emittable_signatures':0,'native_tested':0};reasons={}
    with temporary.open('w') as stream:
        for api in catalog.apis.values():
            stream.write(json.dumps(api.to_dict(),ensure_ascii=False)+'\n')
            counts['indexed']+=1;counts['emittable_signatures']+=not api.unsupported
            for reason in api.unsupported:
                key=reason.partition(':')[0];reasons[key]=reasons.get(key,0)+1
    temporary.replace(output)
    return counts,reasons


def command(*args):
    return subprocess.check_output(args,text=True).strip()


def discover(sdk):
    found={}
    def add(name,source): found.setdefault(name,[]).append(str(source.relative_to(sdk)))
    for path in (sdk/'System/Library/Frameworks').glob('*.framework'): add(path.stem,path)
    for path in (sdk/'usr/lib/swift').glob('*.swiftmodule'): add(path.stem,path)
    for path in (sdk/'usr/include').rglob('*.modulemap'):
        for match in re.finditer(r'^(?:explicit\s+)?(?:framework\s+)?module\s+([A-Za-z_][A-Za-z_0-9]*)\s*(?:\[[^\]]*\]\s*)?\{',path.read_text(errors='replace'),re.MULTILINE):
            add(match.group(1),path)
    result=[]
    for name,sources in sorted(found.items()):
        category=('framework' if any(s.startswith('System/') for s in sources) else
                  'swift-overlay' if any(s.startswith('usr/lib/') for s in sources) else
                  'cxx-module' if any('/c++/' in s for s in sources) else 'c-header-module')
        reason=('underscore-prefixed implementation module' if name.startswith('_') else
                'C++ module requires a separate C++ ingestion adapter; not a Swift module' if category=='cxx-module' else None)
        result.append({'module':name,'sources':sources,'category':category,'excluded':reason is not None,
                       'exclusionReason':reason,'extractionAdapter':'cxx-required' if category=='cxx-module' else 'swift-symbolgraph'})
    return result


def selected_inventory(inventory, modules):
    """Explicitly named Swift modules may opt in; C++ requires its own adapter."""
    result=[dict(entry) for entry in inventory]
    if modules is None:return result
    named=set(modules)
    known={entry['module'] for entry in result}
    unknown=named-known
    if unknown:raise ValueError('Unknown SDK modules: '+', '.join(sorted(unknown)))
    for entry in result:
        if entry['module'] not in named:continue
        if entry.get('category')=='cxx-module' or entry.get('extractionAdapter')=='cxx-required':
            raise ValueError('C++ module requires a separate adapter: '+entry['module'])
        if entry.get('excluded'):
            if not entry['module'].startswith('_') or entry.get('extractionAdapter')!='swift-symbolgraph':
                raise ValueError('Module cannot use Swift extraction: '+entry['module'])
            entry['defaultExclusionReason']=entry.get('exclusionReason')
            entry['excluded']=False
            entry['exclusionReason']=None
            entry['selectionReason']='explicitly selected discovered underscore Swift module; public applicability unverified'
    return result


def preserve_explicit_modules(inventory, previous):
    """Keep prior opt-ins in an output whose producer provenance still matches."""
    if not isinstance(previous,list) or any(not isinstance(entry,dict) for entry in previous):
        raise ValueError('Invalid previous SDK inventory; existing artifacts preserved')
    names=[entry.get('module') for entry in previous]
    if any(not isinstance(name,str) for name in names) or len(set(names))!=len(names):
        raise ValueError('Invalid previous SDK module identities; existing artifacts preserved')
    result=inventory
    for entry in previous:
        if 'selectionReason' not in entry:continue
        proposed=selected_inventory(result,[entry['module']])
        expected=next(item for item in proposed if item['module']==entry['module'])
        if entry!=expected:
            raise ValueError('Prior explicit SDK applicability changed; choose a fresh output: '+entry['module'])
        result=proposed
    return result


def trusted_system_alias(path):
    """Accept only the root-owned macOS /var and /tmp ancestors, never output links."""
    expected={'/var':'/private/var','/tmp':'/private/tmp'}.get(str(path))
    if sys.platform!='darwin' or expected is None:return False
    try:
        link=os.lstat(path)
        if link.st_uid!=0 or not stat.S_ISLNK(link.st_mode):return False
        target=os.readlink(path)
        if target not in (expected,expected.lstrip('/')):return False
        private=os.lstat('/private');destination=os.lstat(expected)
        if private.st_uid!=0 or not stat.S_ISDIR(private.st_mode) or private.st_mode&0o022:return False
        if destination.st_uid!=0 or not stat.S_ISDIR(destination.st_mode):return False
        return Path(path).resolve()==Path(expected)
    except (OSError,RuntimeError):return False


def reject_symlinks(path):
    path=Path(path)
    if path.is_symlink():raise ValueError('Refusing symlink output: '+str(path))
    for parent in path.parents:
        if parent.is_symlink() and not trusted_system_alias(parent):raise ValueError('Refusing symlink output ancestor: '+str(parent))


def exclusive_temp(path):
    reject_symlinks(path)
    descriptor,name=tempfile.mkstemp(prefix=Path(path).name+'.',suffix='.tmp',dir=Path(path).parent)
    os.close(descriptor)
    return Path(name)


def atomic(path,data):
    temp=exclusive_temp(path)
    try:temp.write_text(json.dumps(data,indent=2)+'\n');temp.replace(path)
    finally:temp.unlink(missing_ok=True)


def read_status(path,module):
    try:
        reject_symlinks(path)
        status=json.loads(path.read_text())
        if not isinstance(status,dict) or status.get('module')!=module or status.get('status') not in ('success','failed'):
            raise ValueError('Invalid status object')
        if status['status']=='success':
            counts=status.get('counts')
            if not isinstance(counts,dict) or any(type(counts.get(k)) is not int or counts[k]<0 for k in ('indexed','emittable_signatures','native_tested')):
                raise ValueError('Invalid status counts')
        return status
    except (OSError,ValueError,TypeError) as error:
        return {'module':module,'status':'pending','resumeReason':'status receipt unreadable: '+str(error)}



def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''): h.update(block)
    return h.hexdigest()


def retain_graphs(paths, directory, keep_raw=False):
    """Copy inputs into owned storage; deterministic gzip retains exact original bytes."""
    directory=Path(directory);reject_symlinks(directory);directory.mkdir(parents=True,exist_ok=True)
    result=[]
    for index,source in enumerate(sorted(map(Path,paths))):
        # Stable index prevents collisions when callers supply files from multiple directories.
        name=f'{index:04d}-'+source.name.removesuffix('.gz')
        target=directory/(name if keep_raw else name+'.gz')
        temporary=exclusive_temp(target)
        raw_hash=hashlib.sha256()
        opener=gzip.open if source.suffix=='.gz' else open
        with opener(source,'rb') as src, temporary.open('wb') as dst:
            if keep_raw:
                for block in iter(lambda:src.read(1024*1024),b''):
                    raw_hash.update(block);dst.write(block)
            else:
                with gzip.GzipFile(filename='',mode='wb',fileobj=dst,mtime=0) as encoded:
                    for block in iter(lambda:src.read(1024*1024),b''):
                        raw_hash.update(block);encoded.write(block)
        temporary.replace(target)
        check=hashlib.sha256()
        with (open if keep_raw else gzip.open)(target,'rb') as stream:
            for block in iter(lambda:stream.read(1024*1024),b''):check.update(block)
        if check.hexdigest()!=raw_hash.hexdigest():raise ValueError('Retained graph content mismatch')
        result.append({'path':target.name,'sha256':digest(target),'rawSHA256':raw_hash.hexdigest(),'compression':'none' if keep_raw else 'gzip','bytes':target.stat().st_size})
    if not result:raise ValueError('No symbol graphs extracted')
    return result


def resume_problem(status,directory,provenance):
    """A status bit is not evidence: every retained artifact and producer must still match."""
    if status.get('provenance')!=provenance:return 'producer SDK/toolchain/compiler fingerprint changed or missing'
    if not status.get('proofReusable'):return 'raw graphs discarded; extraction is not replayable'
    try:
        artifacts=status.get('artifacts',{})
        if not isinstance(artifacts,dict):return 'invalid retained artifact manifest'
        graphs=artifacts.get('graphs',[])
        if not isinstance(graphs,list) or not graphs or any(not isinstance(g,dict) for g in graphs):return 'retained graph manifest missing or malformed'
        reject_symlinks(directory)
        for path in Path(directory).rglob('*'):
            if path.is_symlink():return 'symlink artifact is not owned output'
        def owned(name):
            if not isinstance(name,str) or Path(name).name!=name or name in ('.','..'):raise ValueError('invalid artifact path')
            return name
        records=artifacts['records'];path=Path(directory)/owned(records['path'])
        if digest(path)!=records['sha256']:return 'normalized records hash mismatch'
        actual=sorted(p.name for p in graph_paths(Path(directory)/'symbolgraphs'))
        if actual!=sorted(g['path'] for g in graphs):return 'retained graph file set changed'
        for graph in graphs:
            path=Path(directory)/'symbolgraphs'/owned(graph['path'])
            if digest(path)!=graph['sha256']:return 'retained graph hash mismatch'
            if graph['compression'] not in ('none','gzip'):return 'invalid graph encoding'
            h=hashlib.sha256()
            with (gzip.open if graph['compression']=='gzip' else open)(path,'rb') as stream:
                for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
            if h.hexdigest()!=graph['rawSHA256']:return 'raw graph hash mismatch'
    except (OSError,ValueError,KeyError,TypeError,EOFError,AttributeError) as error:return 'missing/corrupt retained artifacts: '+str(error)
    return None


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--jobs',type=int,default=2)
    p.add_argument('--timeout',type=int,default=180)
    p.add_argument('--target',default=None)
    p.add_argument('--sdk-environment',choices=('iphonesimulator','iphoneos'),default='iphonesimulator')
    p.add_argument('--retry-failures',action='store_true')
    mode=p.add_mutually_exclusive_group()
    mode.add_argument('--keep-graphs',action='store_true',help='Retain uncompressed graphs instead of default deterministic gzip')
    mode.add_argument('--discard-graphs',action='store_true',help='Explicitly discard graphs; output cannot be reused as proof or resumed as success')
    p.add_argument('--min-free-mb',type=int,default=768)
    p.add_argument('--modules',nargs='*',help='Exact discovered subset; named underscore Swift modules opt in, C++ modules reject')
    p.add_argument('--reuse',action='append',default=[],metavar='MODULE=DIR',help='Records original graph provenance as unverified')
    args=p.parse_args()
    if not 1<=args.jobs<=8: p.error('--jobs must be 1..8')
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    from dcflight.ios_sdk_environment import target as sdk_target, validate_target, sdk_settings
    args.target=args.target or sdk_target(args.sdk_environment,(18,0))
    validate_target(args.sdk_environment,args.target)
    sdk=Path(command('xcrun','--sdk',args.sdk_environment,'--show-sdk-path'))
    sdk_identity=sdk_settings(sdk,args.sdk_environment)
    try:inventory=selected_inventory(discover(sdk),args.modules)
    except ValueError as error:p.error(str(error))
    provenance={**sdk_identity,'sdk':str(sdk),'sdkVersion':command('xcrun','--sdk',args.sdk_environment,'--show-sdk-version'),
                'swift':command('xcrun','swiftc','--version'),'xcode':command('xcodebuild','-version'),'target':args.target,
                'compilerSources':compiler_sources(),'sdkSettingsSHA256':digest(sdk/'SDKSettings.json'),
                'swiftExtractorBinarySHA256':digest(Path(command('xcrun','--find','swift-symbolgraph-extract'))),
                'extractorSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'adapterSHA256':hashlib.sha256((Path(__file__).resolve().parents[1]/'dcflight/platforms/ios_api.py').read_bytes()).hexdigest()}
    if provenance['sdkVersion']!=sdk_identity['sdkVersion']:raise ValueError('SDK reported version differs from settings')
    for artifact in ('provenance.json','inventory.json','coverage.json'):
        reject_symlinks(out/artifact)
    previous=out/'provenance.json'
    if previous.exists() and json.loads(previous.read_text())!=provenance: p.error('SDK/toolchain/compiler/extractor changed; choose a new output directory (existing artifacts preserved)')
    prior_inventory=out/'inventory.json'
    if prior_inventory.exists():
        if not previous.exists():p.error('Existing SDK inventory lacks producer provenance; choose a fresh output')
        try:inventory=preserve_explicit_modules(inventory,json.loads(prior_inventory.read_text()))
        except (ValueError,TypeError) as error:p.error(str(error))
    atomic(previous,provenance)
    atomic(prior_inventory,inventory)
    reuse=dict(entry.split('=',1) for entry in args.reuse)
    def extract(entry):
        name=entry['module'];directory=out/name;reject_symlinks(directory);directory.mkdir(exist_ok=True);status_path=directory/'status.json'
        for path in directory.rglob('*'):
            reject_symlinks(path)
        resume_reason=None
        requested_inputs={str(path.resolve()):digest(path) for path in graph_paths(Path(reuse[name]))} if name in reuse else {}
        if status_path.exists():
            status=read_status(status_path,name);resume_reason=status.get('resumeReason')
            if status.get('status')=='success':
                resume_reason=resume_problem(status,directory,provenance)
                if status.get('reuseInputs',{})!=requested_inputs or status.get('extractionProvenanceVerified')!=(name not in reuse):
                    resume_reason='requested graph source changed'
                if resume_reason is None:return status
            elif status.get('status')=='failed' and not args.retry_failures:return status
            if resume_reason:print(json.dumps({'module':name,'resume':'stale','reason':resume_reason}),file=sys.stderr,flush=True)
        started=datetime.now(timezone.utc).isoformat()
        try:
            if shutil.disk_usage(out).free<args.min_free_mb*1024*1024: raise RuntimeError('Insufficient free disk space; extraction skipped')
            with tempfile.TemporaryDirectory(prefix='extract-',dir=directory) as temp:
                graphdir=Path(reuse[name]) if name in reuse else Path(temp)
                if name in reuse:
                    extraction='caller-supplied graphs; original extraction provenance unverified'
                else:
                    invocation=['xcrun','swift-symbolgraph-extract','-module-name',name,'-target',args.target,'-sdk',str(sdk),'-output-dir',str(graphdir),'-minimum-access-level','public']
                    proc=subprocess.run(invocation,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=args.timeout)
                    (directory/'extraction.log').write_text(proc.stdout)
                    if proc.returncode: raise RuntimeError('extractor exited '+str(proc.returncode))
                    extraction=' '.join(invocation)
                graphs=graph_paths(graphdir)
                retained=[]
                if not args.discard_graphs:
                    # Finish a new owned directory before replacing old evidence.
                    with tempfile.TemporaryDirectory(prefix='retain-',dir=directory) as holding:
                        staged=Path(holding)/'symbolgraphs'
                        retained=retain_graphs(graphs,staged,args.keep_graphs)
                        dest=directory/'symbolgraphs'
                        if dest.exists():shutil.rmtree(dest)
                        shutil.move(str(staged),str(dest))
                    graphs=graph_paths(dest)
                counts,reasons=normalize_graphs(graphs,name,directory/'records.jsonl')
                if compiler_sources()!=provenance['compilerSources'] or digest(Path(__file__))!=provenance['extractorSHA256']:
                    raise RuntimeError('Compiler/extraction harness changed during extraction; choose a fresh output')
                if digest(sdk/'SDKSettings.json')!=provenance['sdkSettingsSHA256']:
                    raise RuntimeError('SDK settings changed during extraction')
                if name in reuse and {str(path.resolve()):digest(path) for path in graph_paths(Path(reuse[name]))}!=requested_inputs:
                    raise RuntimeError('Caller-supplied graph inputs changed during extraction')
                artifacts={'graphs':retained,'records':{'path':'records.jsonl','sha256':digest(directory/'records.jsonl')}}
            status={'module':name,'status':'success','started':started,'finished':datetime.now(timezone.utc).isoformat(),
                    'counts':counts,'unsupportedReasons':reasons,'extraction':extraction,
                    'provenance':provenance,'artifacts':artifacts,'proofReusable':bool(retained),
                    'extractionProvenanceVerified':name not in reuse,'reuseInputs':requested_inputs,'resumeReason':resume_reason,'selectionReason':entry.get('selectionReason')}
        except Exception as error:
            status={'module':name,'status':'failed','started':started,'finished':datetime.now(timezone.utc).isoformat(),'error':str(error)}
        atomic(status_path,status);return status
    def summary():
        states=[]
        for entry in inventory:
            path=out/entry['module']/'status.json'
            status=read_status(path,entry['module']) if path.exists() else {**entry,'status':'excluded' if entry['excluded'] else 'pending'}
            states.append(status)
        result={'provenance':provenance,'modules':states,'totals':{key:sum(x.get('counts',{}).get(key,0) for x in states) for key in ('indexed','emittable_signatures','native_tested')}}
        result['moduleCounts']={kind:sum(x['status']==kind for x in states) for kind in ('success','failed','pending','excluded')}
        atomic(out/'coverage.json',result);return result
    selected=[e for e in inventory if not e['excluded'] and (args.modules is None or e['module'] in args.modules)]
    summary()
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for future in as_completed([pool.submit(extract,entry) for entry in selected]):
            status=future.result();summary()
            print(json.dumps({'module':status['module'],'status':status['status'],'counts':status.get('counts'),'error':status.get('error')}),flush=True)
    print(json.dumps(summary()['moduleCounts']))

if __name__=='__main__':main()
