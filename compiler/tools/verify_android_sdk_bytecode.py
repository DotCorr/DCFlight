#!/usr/bin/env python3
"""Inspect all platform stub classes and compile direct calls; never run Android code."""
import argparse,hashlib,json,os,re,selectors,shutil,signal,stat,subprocess,sys,time
from pathlib import Path
from dcflight.modules.export import index_android_sdk
from dcflight.platforms.android_api import AndroidAPI
from dcflight.android_availability_probe import probe
from dcflight.android_class_dependencies import dependency_references
from dcflight.ios_verification import compiler_sources


def open_bounded_input(path, limit):
    # NONBLOCK prevents a replacement FIFO from hanging during open; fstat
    # validates the descriptor actually read, not only its pathname.
    fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK|os.O_NOFOLLOW)
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size>limit:
            raise ValueError('SDK input exceeds regular-file size bound')
        stream=os.fdopen(fd,'rb');fd=None
        return stream
    finally:
        if fd is not None:os.close(fd)

def digest(path, *, limit=None, deadline=None, disk_path=None):
    h=hashlib.sha256();total=0
    if limit is not None:
        info=Path(path).stat()
        if not stat.S_ISREG(info.st_mode) or info.st_size>limit:
            raise ValueError('SDK hash input exceeds regular-file size bound')
    with (Path(path).open('rb') if limit is None else open_bounded_input(path,limit)) as f:
        while True:
            if deadline is not None and time.monotonic()>=deadline:
                raise ValueError('SDK hash deadline reached')
            if disk_path is not None and shutil.disk_usage(disk_path).free<1024*1024*1024:
                raise ValueError('SDK hash disk floor reached')
            block=f.read(65536 if limit is None else min(65536,limit-total+1))
            if not block:break
            total+=len(block)
            if limit is not None and total>limit:raise ValueError('SDK hash input exceeds size bound')
            h.update(block)
    return h.hexdigest()


def bounded_copy(source, destination, *, limit, deadline, disk_path, disk_floor=1024*1024*1024):
    """Capture bounded exact input bytes; do not trust a pre-read file size alone."""
    source_stat = Path(source).stat()
    if not stat.S_ISREG(source_stat.st_mode):
        raise ValueError('SDK snapshot input must be a regular file')
    if source_stat.st_size > limit:
        raise ValueError('SDK input exceeds snapshot size bound')
    total = 0
    with open_bounded_input(source,limit) as src, Path(destination).open('xb') as dst:
        while True:
            if time.monotonic() >= deadline:
                raise ValueError('SDK snapshot deadline reached')
            if shutil.disk_usage(disk_path).free < disk_floor + 65536:
                raise ValueError('SDK snapshot disk floor reached')
            block = src.read(min(65536, limit-total+1))
            if not block:
                break
            total += len(block)
            if total > limit:
                raise ValueError('SDK input exceeds snapshot size bound')
            dst.write(block)


def bounded_run(command, log, *, deadline, disk_path, max_bytes=32*1024*1024, disk_floor=1024*1024*1024):
    """One process group, an overall deadline, and live disk/output guards."""
    if time.monotonic() >= deadline:
        raise ValueError('SDK verification deadline reached')
    if shutil.disk_usage(disk_path).free < disk_floor:
        raise ValueError('SDK verification disk floor reached')
    process = None
    selector = selectors.DefaultSelector()
    total = 0
    try:
        with Path(log).open('xb') as stream:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            selector.register(process.stdout, selectors.EVENT_READ)
            while selector.get_map():
                if time.monotonic() >= deadline:
                    raise ValueError('SDK verification deadline reached')
                if shutil.disk_usage(disk_path).free < disk_floor:
                    raise ValueError('SDK verification disk floor reached')
                for key, _ in selector.select(min(.1, max(0, deadline-time.monotonic()))):
                    block = os.read(key.fileobj.fileno(), 65536)
                    if not block:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(block)
                    if total > max_bytes:
                        raise ValueError('SDK verification output bound reached')
                    stream.write(block)
            remaining = deadline-time.monotonic()
            if remaining <= 0:
                raise ValueError('SDK verification deadline reached')
            code = process.wait(timeout=remaining)
        return code, Path(log).read_text(errors='replace')
    finally:
        selector.close()
        if process is not None:
            # Kill the complete group even when the driver exits before its children.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            process.stdout.close()


def verify(archive,output,java_home,*,batch_size=256,deadline_seconds=1800,progress=None):
    if type(batch_size) is not int or not 1<=batch_size<=512:raise ValueError('Batch size must be1..512')
    if type(deadline_seconds) is not int or not 60<=deadline_seconds<=3600:raise ValueError('Deadline must be60..3600 seconds')
    archive=Path(archive).resolve();output=Path(output).absolute();java_home=Path(java_home).resolve()
    if any(p.is_symlink() for p in [output,*output.parents]):raise ValueError('Use an owned output without symlink ancestors')
    if output.exists():raise ValueError('Use a fresh output directory')
    if shutil.disk_usage(output.parent).free<1024*1024*1024:raise ValueError('Keep at least1GiB disk free')
    before=compiler_sources();harness_hash=digest(__file__);started=time.monotonic();deadline=started+deadline_seconds;output.mkdir(parents=True)
    inputs=output/'inputs';inputs.mkdir();sdk=inputs/'android.jar';properties=inputs/'source.properties'
    bounded_copy(archive,sdk,limit=512*1024*1024,deadline=deadline,disk_path=output)
    bounded_copy(archive.parent/'source.properties',properties,limit=65536,deadline=deadline,disk_path=output)
    sdk_hash=digest(sdk);props_hash=digest(properties)
    if sdk_hash!=digest(archive,limit=512*1024*1024,deadline=deadline,disk_path=output) or props_hash!=digest(archive.parent/'source.properties',limit=65536,deadline=deadline,disk_path=output):raise ValueError('SDK inputs changed during capture')
    javac=java_home/'bin/javac';javap=java_home/'bin/javap';catalog=output/'catalog.sqlite'
    def run(command, log):
        return bounded_run(command, log, deadline=deadline, disk_path=output)
    version_status, version = run([str(javac), '-version'], output/'javac-version.log')
    if version_status: raise ValueError('Cannot identify Java compiler')
    toolchain={'javac':str(javac),'javap':str(javap),'javacSHA256':digest(javac),'javapSHA256':digest(javap),'javacVersion':version.strip()}
    # Importing can invoke many javap processes. Isolate the complete phase in
    # the same bounded process-group contract as native compilation.
    worker=output/'index-worker.py'
    worker.write_text('import json,sys\nsys.path[:]=' + repr(sys.path) + '\nfrom pathlib import Path\nfrom dcflight.modules.export import index_android_sdk\nr=index_android_sdk(Path(sys.argv[1]),Path(sys.argv[2]),javap=Path(sys.argv[3]))\nPath(sys.argv[4]).write_text(json.dumps(r,indent=2)+"\\n")\n')
    worker_status, worker_log=run([sys.executable,str(worker),str(sdk),str(catalog),str(javap),str(output/'import.json')],output/'index.log')
    if worker_status: raise ValueError('SDK index worker failed: '+worker_log[-4000:])
    imported=json.loads((output/'import.json').read_text())
    source=output/imported['provenance']['sourceRelativePath'];api=AndroidAPI.from_file(source,api_level=int(imported['provenance']['sdkIdentity']))
    candidates=sorted((m for m in api.members.values() if m.emittable),key=lambda m:m.id)
    if not candidates or len(candidates)>200000:raise ValueError('Invalid bounded native candidate count')
    work=output/'native';work.mkdir();passed=[];failed=[];commands=[];sources={};forbidden=[]
    for offset in range(0,len(candidates),batch_size):
        pending=candidates[offset:offset+batch_size];attempt=0
        while pending:
            attempt+=1
            if attempt>batch_size+1:raise ValueError('Native batch retry bound reached')
            name='SdkProbe'+str(offset)+'_'+str(attempt);path=work/(name+'.java')
            path.write_text('public class '+name+' {\n'+'\n'.join(probe(api,m,i) for i,m in enumerate(pending))+'\n}\n');sources[path.name]=digest(path)
            command=[str(javac),'-proc:none','-source','8','-target','8','-bootclasspath',str(sdk),'-classpath',str(sdk),'-Xmaxerrs','100','-Xlint:unchecked','-Werror','-encoding','UTF-8','-d',str(work),str(path)]
            code,diagnostics=run(command,path.with_suffix('.log'));commands.append(command)
            if code==0:
                compiled=path.with_suffix('.class')
                if not compiled.is_file():raise ValueError('Native compiler omitted expected probe class')
                status,listing=run([str(javap),'-verbose',str(compiled)],path.with_suffix('.dependencies'))
                if status:raise ValueError('Cannot inspect compiled native references')
                references=dependency_references(listing);forbidden.extend(references)
                if references:failed.extend({'id':m.id,'diagnostics':['Forbidden runtime dependency']} for m in pending)
                else:passed.extend(m.id for m in pending)
                break
            bad={}
            for match in re.finditer(re.escape(str(path))+r':(\d+): (?:error|warning): ([^\n]+)',diagnostics):
                index=int(match[1])-2
                if 0<=index<len(pending):bad.setdefault(index,[]).append(match[2])
            if not bad:
                failed.extend({'id':m.id,'diagnostics':['Native batch failed without attributable diagnostics',diagnostics[-4000:]]} for m in pending);break
            failed.extend({'id':pending[i].id,'diagnostics':errors} for i,errors in sorted(bad.items()));pending=[m for i,m in enumerate(pending) if i not in bad]
        state={'processed':min(offset+batch_size,len(candidates)),'candidates':len(candidates),'passed':len(passed),'failed':len(failed)}
        (output/'progress.json').write_text(json.dumps(state)+'\n')
        if progress:progress(state)
    unchanged=(harness_hash==digest(__file__) and before==compiler_sources() and sdk_hash==digest(sdk)==digest(archive,limit=512*1024*1024,deadline=deadline,disk_path=output) and props_hash==digest(properties)==digest(archive.parent/'source.properties',limit=65536,deadline=deadline,disk_path=output) and toolchain['javacSHA256']==digest(javac) and toolchain['javapSHA256']==digest(javap))
    report={'kind':'dcflight.android.sdk-bytecode-compile.v1','scope':imported['provenance']['sdkIdentity'],'dependencyKind':'platform-sdk','sourcePropertiesSHA256':props_hash,'sdkSHA256':sdk_hash,'apiSourceSHA256':digest(source),'compilerSources':before,'compilerUnchanged':unchanged,'harnessSHA256':harness_hash,'indexWorkerSHA256':digest(worker),'toolchain':toolchain,'classesInspected':imported['classesInspected'],'parserStatistics':api.stats(),'candidateCount':len(candidates),'passed':passed,'failed':failed,'runtimeDependencyScanPassed':not forbidden,'forbiddenReferences':sorted(set(forbidden)),'probeSourceSHA256':sources,'commands':commands,'minimumApi':None,'runtimeAvailability':None,'permissions':None,'flagState':None,'verification':'All emittable signatures attempted against exact SDK boot stubs; no device execution or API availability certification.'}
    (output/'native-report.json').write_text(json.dumps(report,indent=2)+'\n')
    if not unchanged:raise ValueError('Compiler or SDK/toolchain inputs changed; no certification')
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--android-jar',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--batch-size',type=int,default=256);p.add_argument('--deadline-seconds',type=int,default=1800);a=p.parse_args()
    r=verify(a.android_jar,a.output,a.java_home,batch_size=a.batch_size,deadline_seconds=a.deadline_seconds,progress=lambda x:print(json.dumps(x),flush=True));print(json.dumps({'report':str(a.output/'native-report.json'),'passed':len(r['passed']),'failed':len(r['failed'])}));return 1 if r['failed'] else 0
if __name__=='__main__':raise SystemExit(main())
