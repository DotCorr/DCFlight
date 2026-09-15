"""Compile exact typed Android invocations; never promote unbound catalog records."""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,signal,stat,subprocess,time
from pathlib import Path
from .catalog import Catalog
from .native_api import NativeAPI
from .ios_verification import compiler_sources
from .c_callback_recovery import reject_symlinks

MAX_REQUESTS=4096

def _read(path,maximum,deadline):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size>maximum:raise ValueError('Expected bounded regular input')
        chunks=[];count=0
        with os.fdopen(fd,'rb') as stream:
            fd=None
            while True:
                if time.monotonic()>deadline:raise ValueError('Verification deadline exceeded')
                chunk=stream.read(min(65536,maximum-count+1))
                if not chunk:break
                count+=len(chunk)
                if count>maximum:raise ValueError('Input exceeds byte bound')
                chunks.append(chunk)
        return b''.join(chunks)
    finally:
        if fd is not None:os.close(fd)


def _capture(path,destination,maximum,deadline,root,min_free):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    digest=hashlib.sha256();count=0
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size>maximum:raise ValueError('Expected bounded regular SDK input')
        with os.fdopen(fd,'rb') as source,destination.open('xb') as target:
            fd=None
            while True:
                if time.monotonic()>deadline:raise ValueError('Verification deadline exceeded')
                if shutil.disk_usage(root).free<min_free+65536:raise ValueError('SDK capture disk floor reached')
                chunk=source.read(min(65536,maximum-count+1))
                if not chunk:break
                count+=len(chunk)
                if count>maximum:raise ValueError('SDK input exceeds byte bound')
                target.write(chunk);digest.update(chunk)
        return digest.hexdigest()
    finally:
        if fd is not None:os.close(fd)


def _run(command,log,deadline,root,min_free):
    with log.open('xb') as stream:
        process=subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            while process.poll() is None:
                if time.monotonic()>deadline:raise ValueError('Native verification deadline exceeded')
                if log.stat().st_size>32*1024*1024:raise ValueError('Native diagnostics exceed byte bound')
                if shutil.disk_usage(root).free<min_free:raise ValueError('Native verification disk floor reached')
                time.sleep(.05)
            code=process.returncode
        finally:
            try:os.killpg(process.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            process.wait()
    return code,_read(log,32*1024*1024,deadline).decode('utf-8',errors='replace')


def _digest(value):return hashlib.sha256(value).hexdigest()
def _canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()


def _selection(catalog,request):
    with Catalog(catalog) as c:
        record=c.get('android',request['id'],request.get('scope'));source=c.source('android',record['scope'])
    return {'record':record,'source':source}


def verify(catalog,requests,sdk,javac,output,*,api_level=36,timeout=600,min_free_mb=1024,progress=None):
    if type(api_level) is not int or not 1<=api_level<=999:raise ValueError('Explicit integer base API level required')
    if type(timeout) is not int or not 1<=timeout<=3600 or type(min_free_mb) is not int or min_free_mb<1:raise ValueError('Invalid verifier bounds')
    if not isinstance(requests,list) or not 1<=len(requests)<=MAX_REQUESTS or len(_canonical(requests))>8*1024*1024:raise ValueError('Expected bounded nonempty explicit request list')
    if any(not isinstance(q,dict) or q.get('platform')!='android' or not isinstance(q.get('id'),str) for q in requests):raise ValueError('Expected typed Android requests')
    # Detach caller-owned nested containers before callbacks or native work.
    requests_raw=_canonical(requests);requests=json.loads(requests_raw)
    deadline=time.monotonic()+timeout;before=compiler_sources();output=Path(output).absolute();reject_symlinks(output)
    if output.exists():raise ValueError('Verification output must be fresh')
    output.mkdir(parents=True);floor=min_free_mb*1024*1024
    if shutil.disk_usage(output).free<floor+512*1024*1024:raise ValueError('Insufficient disk headroom for SDK capture')
    sdk=Path(sdk);sdk_copy=output/'android.jar'
    if sdk.name!='android.jar':raise ValueError('Expected platform android.jar')
    properties_path=sdk.parent/'source.properties';properties_raw=_read(properties_path,65536,deadline);properties={}
    for line in properties_raw.decode('utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):continue
        key,separator,value=line.partition('=')
        if not separator or key in properties:raise ValueError('Malformed SDK properties')
        properties[key]=value.strip()
    if (properties.get('AndroidVersion.ApiLevel')!=str(api_level) or properties.get('AndroidVersion.IsBaseSdk')!='true'
            or any(properties.get(key,'') for key in ('AndroidVersion.CodeName','Platform.CodeName','AndroidVersion.BetaVersion'))
            or properties.get('AndroidVersion.PreviewSdkInt','0')!='0'
            or properties.get('AndroidVersion.ApiLevelMinor','0')!='0'):
        raise ValueError('Exact non-preview base SDK properties must match API level; minor SDKs are unsupported')
    (output/'source.properties').write_bytes(properties_raw)
    sdk_hash=_capture(sdk,sdk_copy,512*1024*1024,deadline,output,floor)
    (output/'requests.json').write_bytes(requests_raw);api=NativeAPI(catalog);selected=[];rows=[];methods=[];sources={};source_table={}
    java=Path(javac).resolve();java_hash=_digest(_read(java,64*1024*1024,deadline))
    code,version=_run([str(java),'-version'],output/'javac-version.log',deadline,output,floor)
    if code:raise ValueError('Native Java compiler version query failed')
    for index,request in enumerate(requests):
        if time.monotonic()>deadline:raise ValueError('Verification deadline exceeded')
        selection=_selection(catalog,request);source=selection['source'];provenance=source['provenance']
        if str(source['sdk'])!=str(api_level):raise ValueError('Catalog source SDK differs from requested compile level')
        if provenance.get('sdkArchiveSha256',sdk_hash)!=sdk_hash:raise ValueError('Catalog SDK archive identity differs')
        # Use the same bounded retained-source path guard as application checking.
        from .android_deployment_validation import _snapshot
        scope=selection['record']['scope']
        if scope in source_table:
            if source_table[scope]!=source:raise ValueError('Catalog source changed during emission')
        else:
            raw=_snapshot(Path(catalog).resolve().parent,provenance,128*1024*1024)
            sources[provenance['sourceRelativePath']]=provenance['sourceSha256'];del raw
            source_table[scope]=source
        compact={'record':selection['record'],'sourceScope':scope,'sourceSHA256':_digest(_canonical(source))}
        selected.append(compact);entry={'index':index,'requestSHA256':_digest(_canonical(request)),'descriptorSHA256':_digest(_canonical(compact)),'compiled':False,'runtimeSupported':None}
        try:
            result=api.emit(request)
            refs={}
            for value in [request.get('receiver'),*request.get('arguments',[]),request.get('set')]:
                if isinstance(value,dict) and set(value)=={'ref','type'}:
                    if value['ref'] in refs and refs[value['ref']]!=value['type']:raise ValueError('Conflicting external reference types')
                    refs[value['ref']]=value['type']
            parameters=', '.join(typ+' '+name for name,typ in refs.items())
            body=('return ' if result['resultType']!='void' else '')+result['source']+';'
            method='public static '+result['resultType']+' verify'+str(index)+'('+parameters+') throws Throwable { '+body+' }'
            entry.update(source=result['source'],resultType=result['resultType'],methodSHA256=_digest(method.encode()))
            methods.append((index,method))
        except ValueError as error:entry['emissionRejected']=str(error)
        rows.append(entry)
    (output/'selections.json').write_bytes(_canonical(selected));(output/'sources.json').write_bytes(_canonical(source_table));commands=[];batch_number=0
    def compile_group(group):
        nonlocal batch_number
        folder=output/('batch-'+str(batch_number));batch_number+=1;folder.mkdir();path=folder/'SpecializationProbe.java'
        source='public class SpecializationProbe {\n'+'\n'.join(method for _,method in group)+'\n}\n';path.write_text(source)
        command=[str(java),'-proc:none','-source','8','-target','8','-Xlint:unchecked','-Werror','-bootclasspath',str(sdk_copy),'-classpath',str(sdk_copy),'-d',str(folder),str(path)]
        code,diagnostic=_run(command,folder/'compile.log',deadline,output,floor);commands.append({'command':command,'sourceSHA256':_digest(source.encode()),'exitCode':code})
        if code==0:
            for index,_ in group:rows[index]['compiled']=True
        elif len(group)>1:
            middle=len(group)//2;compile_group(group[:middle]);compile_group(group[middle:])
        else:rows[group[0][0]]['diagnostic']=diagnostic[-8000:]
    for offset in range(0,len(methods),100):
        compile_group(methods[offset:offset+100])
        if progress:progress({'processed':min(offset+100,len(methods)),'candidates':len(requests),'compiled':sum(row['compiled'] for row in rows)})
    if _digest(_read(sdk_copy,512*1024*1024,deadline))!=sdk_hash:raise ValueError('Captured SDK changed during verification')
    if _digest(_read(sdk,512*1024*1024,deadline))!=sdk_hash or _digest(_read(java,64*1024*1024,deadline))!=java_hash:raise ValueError('Native compiler or SDK changed during verification')
    if _read(properties_path,65536,deadline)!=properties_raw:raise ValueError('SDK properties changed during verification')
    if before!=compiler_sources():raise ValueError('Compiler source changed during verification')
    for request,selection in zip(requests,selected):
        current=_selection(catalog,request)
        if current['record']!=selection['record'] or current['source']!=source_table[selection['sourceScope']]:raise ValueError('Selected catalog evidence changed during verification')
    for path,digest in sources.items():
        from .android_deployment_validation import _snapshot
        _snapshot(Path(catalog).resolve().parent,{'sourceRelativePath':path,'sourceSha256':digest},128*1024*1024)
    report={'passed':all(row['compiled'] for row in rows),'kind':'dcflight.android.explicit-specializations.v1','compilerSources':before,'compilerUnchanged':True,'sdkSHA256':sdk_hash,'sdkPropertiesSHA256':_digest(properties_raw),'apiLevel':api_level,'javac':{'path':str(java),'sha256':java_hash,'version':version.strip()},'requestsSHA256':_digest(requests_raw),'selectionsSHA256':_digest(_canonical(selected)),'sourcesSHA256':_digest(_canonical(source_table)),'requestCount':len(requests),'compiledCount':sum(row['compiled'] for row in rows),'rows':rows,'commands':commands,'scope':'Exact typed invocations only; no unbound descriptor promotion, catalog mutation, minimum-runtime or device-execution credit.'}
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report


def add_arguments(parser):
    parser.add_argument('requests',type=Path,help='Typed request list or specialization plan JSON')
    parser.add_argument('--sdk',type=Path,required=True)
    parser.add_argument('--javac',type=Path,required=True)
    parser.add_argument('--api-level',type=int,default=36)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--timeout',type=int,default=600)
    parser.add_argument('--min-free-mb',type=int,default=1024)


def run(args):
    from .frontends import read_json
    import sys
    raw=_read(args.requests,8*1024*1024,time.monotonic()+10);document=read_json(raw.decode('utf-8'))
    requests=document.get('requests') if isinstance(document,dict) else document
    return verify(args.catalog,requests,args.sdk,args.javac,args.output,api_level=args.api_level,timeout=args.timeout,min_free_mb=args.min_free_mb,
                  progress=lambda row:print(json.dumps(row),file=sys.stderr,flush=True))
