"""Prospective bounded Swift execution snapshots; never upgrades historical proof."""
from __future__ import annotations
import hashlib,json,os,platform,resource,signal,stat,subprocess,tempfile,time,shutil
from pathlib import Path
from .ios_sdk_environment import locate,target,validate_target
from .c_callback_recovery import reject_symlinks

MAX_FILES=65536
MAX_BYTES=8*1024**3
MAX_FILE_BYTES=1024**3
MAX_SCAN_SECONDS=180

def digest(raw):return hashlib.sha256(raw).hexdigest()
def encoded(value):return (json.dumps(value,sort_keys=True,separators=(',',':'))+'\n').encode()
def stable_file(path,deadline=None):
    deadline=time.monotonic()+MAX_SCAN_SECONDS if deadline is None else deadline
    try:fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK|getattr(os,'O_NOFOLLOW',0))
    except OSError as error:raise ValueError('Unsafe execution input') from error
    h=hashlib.sha256();size=0
    with os.fdopen(fd,'rb') as stream:
        before=os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_size>MAX_FILE_BYTES:raise ValueError('Unsupported or oversized execution input')
        while True:
            if time.monotonic()>deadline:raise ValueError('Execution scan deadline exceeded')
            block=stream.read(1024*1024)
            if not block:break
            size+=len(block)
            if size>MAX_FILE_BYTES:raise ValueError('Execution input grew beyond bound')
            h.update(block)
        after=os.fstat(stream.fileno())
    final=path.lstat();key=lambda x:(x.st_dev,x.st_ino,x.st_size,x.st_mtime_ns,x.st_ctime_ns,x.st_mode)
    if key(before)!=key(after) or key(after)!=key(final) or size!=before.st_size:raise ValueError('Execution input changed while hashing')
    return {'sha256':h.hexdigest(),'bytes':size,'mode':stat.S_IMODE(before.st_mode)}


def snapshot(roots):
    """Complete trees, including link topology; external/dangling links reject."""
    if not isinstance(roots,dict) or not 1<=len(roots)<=4:raise ValueError('Invalid execution roots')
    paths={name:Path(p).resolve(strict=True) for name,p in roots.items()}
    if any(not isinstance(name,str) or not name.isidentifier() or not p.is_dir() for name,p in paths.items()):raise ValueError('Invalid execution root')
    started=time.monotonic();rows=[];total=0;scheduled=len(paths)
    for name,root in sorted(paths.items()):
        stack=[root]
        while stack:
            path=stack.pop();info=path.lstat();relative=str(path.relative_to(root))
            row={'root':name,'path':relative,'mode':stat.S_IMODE(info.st_mode)}
            if stat.S_ISLNK(info.st_mode):
                resolved=path.resolve(strict=True)
                if not any(resolved==r or r in resolved.parents for r in paths.values()):raise ValueError('Execution tree contains external symlink')
                row.update(kind='symlink',target=os.readlink(path),resolved=str(resolved))
            elif stat.S_ISDIR(info.st_mode):
                row['kind']='directory';children=[]
                with os.scandir(path) as entries:
                    for child in entries:
                        scheduled+=1
                        if scheduled>MAX_FILES or time.monotonic()-started>MAX_SCAN_SECONDS:raise ValueError('Execution directory exceeds bounded scan')
                        children.append(Path(child.path))
                stack.extend(sorted(children,reverse=True))
            elif stat.S_ISREG(info.st_mode):
                row.update(kind='file',**stable_file(path,started+MAX_SCAN_SECONDS));total+=row['bytes']
            else:raise ValueError('Execution tree contains unsupported special file')
            rows.append(row)
            if len(rows)>MAX_FILES or total>MAX_BYTES or time.monotonic()-started>MAX_SCAN_SECONDS:raise ValueError('Execution snapshot exceeds bounded scan')
    result={'roots':{k:str(v) for k,v in sorted(paths.items())},'entries':rows,'bytes':total,'files':sum(r['kind']=='file' for r in rows)}
    return result

def same_snapshot(before,after):
    if before!=after:raise ValueError('Native SDK/toolchain changed during execution')

def discover(environment):
    # Bound discovery calls made by the shared environment helper as well.
    from .ios_sdk_environment import sdk_settings
    sdk=subprocess.check_output(['/usr/bin/xcrun','--sdk',environment,'--show-sdk-path'],text=True,timeout=15).strip()
    identity={'sdk':sdk,**sdk_settings(sdk,environment)}
    swiftc=Path(subprocess.check_output(['/usr/bin/xcrun','--find','swiftc'],text=True,timeout=15).strip())
    frontend=Path(subprocess.check_output(['/usr/bin/xcrun','--find','swift-frontend'],text=True,timeout=15).strip())
    toolchain=next((p for p in swiftc.parents if p.name.endswith('.xctoolchain')),None)
    if toolchain is None:raise ValueError('Swift compiler is outside a selected toolchain')
    driver=toolchain/'usr/bin/swift-driver'
    if not driver.is_file() or not frontend.is_file():raise ValueError('Missing Swift driver/frontend')
    tools={name:{'path':str(p),'resolved':str(p.resolve(strict=True)),**stable_file(p.resolve(strict=True))} for name,p in [('swiftc',swiftc),('driver',driver),('frontend',frontend)]}
    for value in tools.values():
        if toolchain.resolve() not in Path(value['resolved']).parents:raise ValueError('Resolved Swift executable escaped selected toolchain')
    return identity,tools,{'sdk':Path(identity['sdk']).resolve(strict=True),'toolchain':toolchain.resolve(strict=True)}

def stop_group(process):
    try:os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    process.wait(timeout=10)
    deadline=time.monotonic()+3
    while True:
        try:os.killpg(process.pid,0)
        except (ProcessLookupError, PermissionError):return
        if time.monotonic()>deadline:raise ValueError('Owned native process group did not disappear')
        time.sleep(0.05)

def work_budget(work):
    if shutil.disk_usage(work).free<256*1024*1024:raise ValueError('Native execution disk floor reached')
    total=0;count=0;stack=[work]
    while stack:
        directory=stack.pop()
        with os.scandir(directory) as entries:
            for entry in entries:
                count+=1
                if count>MAX_FILES:raise ValueError('Native working directory entry bound exceeded')
                if entry.is_symlink():continue
                if entry.is_dir(follow_symlinks=False):stack.append(entry.path)
                else:total+=entry.stat(follow_symlinks=False).st_size
                if total>512*1024*1024:raise ValueError('Native working directory exceeds512MiB')

def run(source,output,*,sdk_environment='iphonesimulator',ios_version=(18,0),swift_version='6',timeout=180):
    """Typecheck one new bounded source with a separately linked execution receipt."""
    if not isinstance(source,str) or not source or len(source.encode())>1024*1024:raise ValueError('Native source requires1..1MiB UTF8 bytes')
    if swift_version not in ('5','6') or type(timeout) is not int or not 1<=timeout<=600:raise ValueError('Invalid native execution options')
    from .ios_verification import compiler_sources
    producer_sources=compiler_sources()
    helper_hash=digest(Path(__file__).read_bytes())
    triple=target(sdk_environment,ios_version);validate_target(sdk_environment,triple)
    output=Path(output).absolute();reject_symlinks(output)
    if output.exists():raise ValueError('Execution evidence requires fresh output')
    identity,tools,roots=discover(sdk_environment);os_build=subprocess.check_output(['/usr/bin/sw_vers','-buildVersion'],text=True,timeout=15).strip()
    before_time=time.monotonic();before=snapshot(roots);snapshot_seconds=time.monotonic()-before_time
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.native-execution-',dir=output.parent) as temporary:
        work=Path(temporary);(work/'home').mkdir();(work/'tmp').mkdir();(work/'cache').mkdir();sourcepath=work/'Verify.swift';raw=source.encode();sourcepath.write_bytes(raw)
        env={'PATH':'/usr/bin:/bin','HOME':str(work/'home'),'TMPDIR':str(work/'tmp'),'LANG':'C','LC_ALL':'C','CLANG_MODULE_CACHE_PATH':str(work/'cache'),'SWIFT_MODULECACHE_PATH':str(work/'cache')}
        command=[tools['swiftc']['path'],'-typecheck','-swift-version',swift_version,'-target',triple,'-sdk',identity['sdk'],'-module-cache-path',str(work/'cache'),str(sourcepath)]
        work_budget(work);started=time.monotonic();budget_checked=started
        with (work/'native.log').open('wb') as log:
            process=subprocess.Popen(command,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            try:
                deadline=time.monotonic()+timeout
                while process.poll() is None:
                    if time.monotonic()-budget_checked>=0.25:
                        work_budget(work);budget_checked=time.monotonic()
                    if time.monotonic()>deadline:raise TimeoutError('Native invocation exceeded timeout')
                    if (work/'native.log').stat().st_size>8*1024*1024:raise ValueError('Native diagnostics exceeded8MiB')
                    time.sleep(0.05)
                code=process.wait()
                if (work/'native.log').stat().st_size>8*1024*1024:raise ValueError('Native diagnostics exceeded8MiB')
            finally:stop_group(process)
        work_budget(work)
        elapsed=time.monotonic()-started
        after=snapshot(roots);same_snapshot(before,after)
        current_identity,current_tools,current_roots=discover(sdk_environment)
        if (identity,tools,roots)!=(current_identity,current_tools,current_roots) or subprocess.check_output(['/usr/bin/sw_vers','-buildVersion'],text=True,timeout=15).strip()!=os_build:raise ValueError('Resolved native execution context changed')
        if sourcepath.read_bytes()!=raw:raise ValueError('Native source changed during execution')
        if compiler_sources()!=producer_sources:raise ValueError('Execution producer changed during invocation')
        if digest(Path(__file__).read_bytes())!=helper_hash:raise ValueError('Execution helper changed during invocation')
        report={'kind':'dcflight.ios.execution-baseline.v1','sourceSHA256':digest(raw),'command':command,'commandSHA256':digest(encoded(command)),'exitCode':code,'target':triple,'swiftLanguageVersion':swift_version,'sdkEnvironment':sdk_environment,'scope':'One prospective native typecheck; no catalog or import-contract certification.'}
        report_bytes=encoded(report);(work/'native-report.json').write_bytes(report_bytes);manifest_bytes=encoded(before);(work/'execution-inputs.json').write_bytes(manifest_bytes)
        cache_bytes=sum(p.stat().st_size for p in (work/'cache').rglob('*') if p.is_file())
        receipt={'kind':'dcflight.ios.native-execution-identity.v1','nativeReportSHA256':digest(report_bytes),'inputManifestSHA256':digest(manifest_bytes),'inputSnapshotUnchanged':True,'sdk':identity,'tools':tools,'os':{'build':os_build,'system':platform.system(),'machine':platform.machine()},'environment':env,'cwd':str(work),'freshOwnedModuleCache':True,'helperSHA256':helper_hash,'producerSources':producer_sources,'metrics':{'snapshotSeconds':snapshot_seconds,'nativeSeconds':elapsed,'snapshotFiles':before['files'],'snapshotBytes':before['bytes'],'moduleCacheBytes':cache_bytes,'collectorMaxResidentSetSize':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss},'limitations':['Before/after content snapshots detect persistent changes, not privileged transient change-and-restore during invocation.','Host OS system libraries are scoped by OS build and architecture, not a content-addressed OS image.','This receipt is prospective local execution evidence, not a signature or retrospective compatibility permission.']}
        (work/'execution-receipt.json').write_bytes(encoded(receipt))
        import shutil
        for folder in ('home','tmp','cache'):shutil.rmtree(work/folder)
        reject_symlinks(output)
        if output.exists():raise ValueError('Execution output appeared before publication')
        work.rename(output)
    return receipt
