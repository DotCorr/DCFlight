#!/usr/bin/env python3
"""Report-only native verification of retained, provenance-bound SDK graphs."""
import argparse,concurrent.futures,gzip,hashlib,json,os,re,shutil,signal,subprocess,sys,time,zipfile,stat
from pathlib import Path
DEPENDENCIES={'CoreLocation':['Contacts'],'Photos':['UIKit'],'UserNotifications':['CoreLocation','Intents'],'Compression':['Foundation'],'UIKit':['CloudKit'],'AVFoundation':['CoreImage']}
LAUNCH='import sys;sys.path.insert(0,sys.argv[1]);from dcflight.ios_verification import main;sys.exit(main(sys.argv[2:]))'
def sha(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def read(path):return json.loads(Path(path).read_text())
def write(path,data):
 tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(data,indent=2)+'\n');tmp.replace(path)
def check(ok,message):
 if not ok:raise ValueError(message)
def owned(root,name):
 check(isinstance(name,str) and re.fullmatch(r'[A-Za-z0-9_.@-]+',name) is not None,'Invalid artifact name')
 p=root/name;check(not p.is_symlink() and p.is_file(),'Missing or linked artifact: '+str(p));return p
def safe_output(path):
 path=Path(os.path.abspath(path))
 for item in [*reversed(path.parents),path]:
  if not item.is_symlink():continue
  allowed={'/tmp':'/private/tmp','/var':'/private/var'}
  target=allowed.get(str(item))
  check(item!=path and sys.platform=='darwin' and target is not None and item.lstat().st_uid==0 and str(item.resolve())==target,'Symlink output ancestor/destination')
  for folder in (Path('/private'),Path(target)):
   check(not folder.is_symlink() and folder.is_dir() and folder.stat().st_uid==0,'Untrusted standard alias destination')
  check(not (Path('/private').stat().st_mode & 0o022),'Writable /private alias parent')
 if path.exists():
  for item in path.rglob('*'):check(not item.is_symlink(),'Symlink output artifact/cache')
 return path.resolve()
def compiler(site):return {str(p.relative_to(site/'dcflight')):sha(p) for p in sorted((site/'dcflight').rglob('*.py'))}
def wheel_identity(wheel,site,expected):
 check(sha(wheel)==expected,'Wheel SHA mismatch')
 with zipfile.ZipFile(wheel) as z:
  files={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.startswith('dcflight/') and n.endswith('.py')}
 actual={'dcflight/'+n:v for n,v in compiler(site).items()}
 check(files==actual and bool(actual),'Extracted compiler differs from wheel')
 return compiler(site)
def command_output(args):return subprocess.check_output(args,text=True,timeout=30).strip()
def toolchain(sdk_environment='iphonesimulator'):
 from dcflight.ios_sdk_environment import locate
 identity=locate(sdk_environment);sdk=identity['sdk']
 return {**identity,'sdk':sdk, 'sdkSettingsSHA256':sha(Path(sdk)/'SDKSettings.json'),'swift':command_output(['xcrun','swiftc','--version']),'swiftBinarySHA256':sha(command_output(['xcrun','--find','swiftc'])),'xcode':command_output(['xcodebuild','-version'])}
def extraction(root,producer):
 """Validate archived producer separately from current verifier/compiler."""
 result={}
 for folder in sorted(p for p in root.iterdir() if p.is_dir()):
  check(not folder.is_symlink(),'Linked module directory')
  check(re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',folder.name) is not None,'Invalid module name')
  status_path=owned(folder,'status.json');status=read(status_path)
  check(status.get('module')==folder.name,'Module identity mismatch')
  provenance=status.get('provenance',{})
  if status.get('status')=='success':
   check(provenance.get('compilerSources')==producer['compilerSources'],'Original producer compiler identity mismatch')
   check(provenance.get('extractorSHA256')==producer['harnessSHA256'],'Original extractor identity mismatch')
  row={'status':status.get('status'),'statusSHA256':sha(status_path),'provenance':provenance,'graphs':[]}
  if row['status']=='success':
   archive=status.get('artifacts',{}).get('records')
   check(isinstance(archive,dict) and set(archive)=={'path','sha256'},'Missing archived descriptor manifest')
   recordfile=owned(folder,archive['path']);check(sha(recordfile)==archive['sha256'],'Archived descriptor hash mismatch');row['recordsSHA256']=archive['sha256']
   graphroot=folder/'symbolgraphs';check(graphroot.is_dir() and not graphroot.is_symlink(),'Missing retained graphs')
   graphrows=status.get('artifacts',{}).get('graphs',[]);check(bool(graphrows),'No retained graph proof')
   names=[]
   for item in graphrows:
    p=owned(graphroot,item['path']);check(sha(p)==item['sha256'],'Compressed graph hash mismatch')
    check(item.get('compression')=='gzip','Only original retained gzip graphs accepted')
    h=hashlib.sha256();size=0
    with gzip.open(p,'rb') as f:
     for b in iter(lambda:f.read(1024*1024),b''):
      size+=len(b);check(size<=512*1024*1024,'Expanded graph exceeds bound');h.update(b)
    check(h.hexdigest()==item['rawSHA256'],'Original raw graph hash mismatch')
    names.append(p.name);row['graphs'].append({'name':p.name,'sha256':item['sha256'],'rawSHA256':item['rawSHA256']})
   check(sorted(names)==sorted(p.name for p in graphroot.iterdir()) and len(set(names))==len(names),'Retained graph set mismatch')
   check(not (folder/'qualifier-recovery.json').exists() and not (graphroot/'qualifier-recovery.json').exists(),'Derived recovery bundle is not original SDK input')
  else:check(row['status']=='failed','Unknown extraction state')
  result[folder.name]=row
 check(bool(result),'Empty extraction inventory')
 inventory=root/'inventory.json'
 if inventory.exists():check(set(result)=={x['module'] for x in read(inventory) if not x['excluded']},'Extraction inventory is incomplete')
 return result

def classify(report,module,expected,identity,tools,ios_version=(18,0)):
 check(report.get('compilerSources')==identity,'Native report compiler differs')
 from dcflight.ios_sdk_environment import validate_report, target as sdk_target
 env=tools.get('sdkEnvironment','iphonesimulator');check(validate_report(report)==env,'Native SDK environment differs')
 check(report.get('target')==sdk_target(env,ios_version) and report.get('swiftLanguageVersion')=='6' and report.get('actorContext')=='main','Native target/context differs')
 for k in ('sdk','sdkVersion','swift'):check(report.get(k)==tools[k],'Native toolchain differs: '+k)
 check(report.get('inputs')==expected['inputs'] and report.get('typeInputs')==expected['typeInputs'] and report.get('additionalImports')==expected['imports'],'Native graph inputs differ')
 for count,items in [('nativeTested','passed'),('failedCount','failed'),('skippedCount','skipped')]:check(type(report.get(count)) is int and report[count]==len(report.get(items,[])),'Incomplete native report')
 check(report.get('candidateCount')==report['nativeTested']+report['failedCount'],'Partial native report')
 generic=sum('specialization' in x for x in report['passed'])
 status='native_failures' if report['failedCount'] else 'native_passes' if report['nativeTested'] else 'no_candidates'
 return {'status':status,'ordinaryPasses':report['nativeTested']-generic,'specializedPasses':generic,'nativeFailures':report['failedCount'],'targetSkipped':report['skippedCount'],'coverage':report['coverage'][module]}

def parse_version(value):
 check(isinstance(value,str) and re.fullmatch(r"[1-9][0-9]{0,2}\.(?:0|[1-9][0-9]{0,2})",value) is not None,"iOS version requires major.minor integer components")
 return tuple(map(int,value.split(".")))

def load_plans(path,root,records):
 import importlib.util
 helper=Path(__file__).with_name('ios_type_plan_validation.py')
 spec=importlib.util.spec_from_file_location('dcflight_sdk_plan_validation',helper);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 return module.validate_batch(path,root,records)

def run(args):
 ios_version=parse_version(getattr(args,"ios_version","18.0"))
 wheel=args.wheel.resolve();site=args.site.resolve();root=args.extraction.resolve();out=safe_output(args.output)
 sys.path.insert(0,str(site))
 check(1<=args.jobs<=4 and args.timeout>=1 and args.min_free_mb>=256,'Invalid resource bounds')
 before=wheel_identity(wheel,site,args.wheel_sha256)
 check(sha(args.producer_report)==args.producer_sha256,'Producer receipt SHA differs')
 producer=read(args.producer_report);check(producer.get('status')=='completed' and producer.get('producerUnchanged') is True and producer.get('exitCode')==0,'Unverified extraction producer')
 sdk_environment=getattr(args,'sdk_environment','iphonesimulator')
 from dcflight import ios_sdk_environment as environment_module
 check(sha(environment_module.__file__)==before.get('ios_sdk_environment.py'),'SDK environment helper differs from selected wheel')
 from dcflight.ios_sdk_environment import target as sdk_target,validate_target
 records=extraction(root,producer);tools=toolchain(sdk_environment)
 for row in records.values():
  if row['status']!='success':continue
  check(row['provenance'].get('sdkEnvironment','iphonesimulator')==sdk_environment,'Extraction SDK environment differs')
  validate_target(sdk_environment,row['provenance'].get('target'))
  for k in ('sdk','sdkVersion','swift','xcode','sdkSettingsSHA256'):check(row['provenance'].get(k)==tools[k],'Installed SDK differs from original extraction: '+k)
 selected=sorted(args.module or records)
 check(len(set(selected))==len(selected) and all(n in records for n in selected),'Unknown/duplicate requested module')
 plan_path=getattr(args,'type_plans',None);check(not(plan_path and args.dependencies),'Use either type plans or whole-graph dependencies')
 plans=load_plans(plan_path,root,records) if plan_path else None
 dependencies={} if plans else DEPENDENCIES if args.dependencies is None else read(args.dependencies)
 for module,names in dependencies.items():check(module in records and isinstance(names,list) and len(names)<=32 and len(set(names))==len(names) and all(n in records for n in names),'Invalid dependency configuration')
 key={'wheelSHA256':args.wheel_sha256,'compilerSources':before,'producerReportSHA256':args.producer_sha256,'harnessSHA256':sha(__file__),'extractions':records,'toolchain':tools,'dependencies':dependencies,'typePlans':plans,'planValidatorSHA256':sha(Path(__file__).with_name('ios_type_plan_validation.py')) if plans else None,'inventorySHA256':sha(root/'inventory.json'),'selectedModules':selected,'target':sdk_target(sdk_environment,ios_version),'swiftVersion':'6','batchSize':200}
 check(not out.exists() or args.resume,'Output exists; use explicit --resume')
 out.mkdir(parents=True,exist_ok=True)
 if (out/'identity.json').exists():check(read(out/'identity.json')==key,'Resume identity mismatch')
 else:check(not any(out.iterdir()),'Nonempty unowned output');write(out/'identity.json',key)
 result={};pending=[]
 for module in selected:
  receipt=out/(module+'.receipt.json')
  if args.resume and receipt.exists():
   row=read(receipt);check(row.get('identitySHA256')==digest(key),'Resume receipt identity differs')
   check(row.get('module')==module,'Resume receipt module differs')
   if row.get('status') in ('native_passes','native_failures','no_candidates'):check(bool(row.get('reportSHA256')),'Resume native receipt lacks report')
   if row.get('status')=='extraction_failed':check(records[module]['status']=='failed','Resume extraction failure differs')
   if row.get('reportSHA256'):
    report=out/(module+'.json');check(sha(report)==row['reportSHA256'],'Resume report corrupted')
    expected=expectation(module,records,dependencies,plans);classified=classify(read(report),module,expected,before,tools,ios_version)
    check(all(row.get(k)==v for k,v in classified.items()),'Resume classification differs')
   if row.get('status')=='dependency_plan_rejected':check(plans and plans['modules'].get(module,{}).get('status')=='rejected' and row.get('reason')==plans['modules'][module]['reason'],'Resume plan rejection differs')
   if row['status'] in ('native_passes','native_failures','no_candidates','extraction_failed','dependency_plan_rejected'):result[module]=row;continue
  pending.append(module)
 def worker(module):
  row={'module':module,'identitySHA256':digest(key)}
  if records[module]['status']!='success':return {**row,'status':'extraction_failed'}
  if plans and plans['modules'][module]['status']=='rejected':return {**row,'status':'dependency_plan_rejected','reason':plans['modules'][module]['reason']}
  deps=dependencies.get(module,[])
  if any(records[n]['status']!='success' for n in deps):return {**row,'status':'dependency_extraction_failed'}
  if shutil.disk_usage(out).free<args.min_free_mb*1024*1024:return {**row,'status':'disk_floor'}
  report=out/(module+'.json');report.unlink(missing_ok=True)
  cache=out/('.cache-'+module);cache.mkdir(exist_ok=True)
  command=[sys.executable,'-I','-c',LAUNCH,str(site),'--module',module+'='+str(root/module/'symbolgraphs'),'--limit','0','--batch-size','200','--ios-version','.'.join(map(str,ios_version)),'--sdk-environment',sdk_environment,'--swift-version','6','--output',str(report)]
  for dep in deps:command+=['--import',dep,'--type-module',dep+'='+str(root/dep/'symbolgraphs')]
  if plans:
   for dep,path in sorted(plans['modules'][module]['typePaths'].items()):command+=['--type-module',dep+'='+path]
  env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','TMPDIR':str(cache),'CLANG_MODULE_CACHE_PATH':str(cache/'clang'),'SWIFT_MODULECACHE_PATH':str(cache/'swift')}
  started=time.monotonic();status=None
  process=None
  try:
   with (out/(module+'.log')).open('w') as log:
    process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    while process.poll() is None:
     if time.monotonic()-started>args.timeout:status='timeout'
     elif shutil.disk_usage(out).free<args.min_free_mb*1024*1024:status='disk_floor'
     if status:break
     time.sleep(.25)
  finally:
   try:
    if process is not None:
     try:live=process.poll() is None
     except Exception:live=True
     if live:
      try:os.killpg(process.pid,signal.SIGKILL)
      except ProcessLookupError:pass
      process.wait(timeout=10)
   finally:
    if cache.exists():
     check(not cache.is_symlink(),'Cache replaced by symlink');shutil.rmtree(cache)
  row.update(command=command,exitCode=process.returncode,seconds=round(time.monotonic()-started,2))
  if status:return {**row,'status':status}
  if process.returncode not in (0,1) or not report.exists():return {**row,'status':'verifier_error'}
  try:row.update(classify(read(report),module,expectation(module,records,dependencies,plans),before,tools,ios_version))
  except (ValueError,KeyError,TypeError) as error:return {**row,'status':'invalid_report','error':str(error)}
  if (process.returncode==0)!=(row['status']=='native_passes'):return {**row,'status':'invalid_report','error':'Native exit code contradicts complete report'}
  row['reportSHA256']=sha(report);return row
 with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
  futures={pool.submit(worker,module):module for module in pending}
  for future in concurrent.futures.as_completed(futures):
   module=futures[future]
   try:row=future.result()
   except Exception as error:row={'module':module,'identitySHA256':digest(key),'status':'coordinator_error','error':str(error)}
   check(wheel_identity(wheel,site,args.wheel_sha256)==before,'Compiler changed while verifying')
   write(out/(module+'.receipt.json'),row);result[module]=row
   print(module,row['status'],flush=True);write(out/'summary.json',{'identitySHA256':digest(key),'complete':False,'modules':result})
 check(wheel_identity(wheel,site,args.wheel_sha256)==before,'Final wheel/compiler changed')
 check(sha(args.producer_report)==args.producer_sha256 and sha(__file__)==key['harnessSHA256'] and sha(root/'inventory.json')==key['inventorySHA256'],'Final evidence identity changed')
 check(extraction(root,producer)==records,'Extraction inputs changed during verification')
 check(toolchain(sdk_environment)==tools,'SDK/compiler toolchain changed during verification')
 if plans:
  check(sha(Path(__file__).with_name('ios_type_plan_validation.py'))==key['planValidatorSHA256'],'Plan validator changed')
  check(load_plans(plan_path,root,records)==plans,'Type plans changed during verification')
 final={'identitySHA256':digest(key),'complete':True,'compilerUnchanged':True,'modules':result,'catalogMutation':False,'scope':'Ordinary and explicit generic specialization native Swift typechecking only. Unsupported descriptors, skipped targets, failed extraction and empty candidate sets are not passes; no execution or whole-platform support claim.'}
 write(out/'summary.json',final)
 return 1 if any(r['status'] not in ('native_passes','no_candidates','extraction_failed') for r in result.values()) else 0

def expectation(module,records,deps,plans=None):
 def inputs(name):return [{k:v for k,v in row.items() if k in ('name','sha256')} for row in records[name]['graphs']]
 if plans:
  return {'inputs':{module:inputs(module)},'typeInputs':plans['modules'][module].get('typeInputs',{}),'imports':[]}
 names=deps.get(module,[])
 return {'inputs':{module:inputs(module)},'typeInputs':{n:inputs(n) for n in names},'imports':names}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('wheel','site','extraction','producer-report','output'):p.add_argument('--'+name,type=Path,required=True)
 for name in ('wheel-sha256','producer-sha256'):p.add_argument('--'+name,required=True)
 p.add_argument('--ios-version',default='18.0')
 p.add_argument('--sdk-environment',choices=('iphonesimulator','iphoneos'),default='iphonesimulator')
 p.add_argument('--type-plans',type=Path);p.add_argument('--dependencies',type=Path);p.add_argument('--module',action='append');p.add_argument('--resume',action='store_true');p.add_argument('--jobs',type=int,default=1);p.add_argument('--timeout',type=int,default=3600);p.add_argument('--min-free-mb',type=int,default=2048)
 return run(p.parse_args())
if __name__=='__main__':sys.exit(main())
