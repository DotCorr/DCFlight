"""One bounded exact-ID SDK index for many independent dependency plans."""
from __future__ import annotations
import json,os,re,shutil,sqlite3,tempfile,time,hashlib
from pathlib import Path
from . import ios_type_dependencies as single
from .symbolgraph import symbols
from .c_callback_recovery import reject_symlinks

MAX_INDEX_BYTES=1024**3
MAX_SYMBOLS=1000000
MAX_REFERENCE_ROWS=4000000
MAX_BATCH_BYTES=2*1024**3
MAX_BATCH_ENTRIES=262144
MAX_SELECTED_ROWS=65536
MAX_SELECTED_BYTES=512*1024*1024

def plan_batch(capture,output,*,modules=None,timeout=1800,disk_floor=1024**3,progress=None):
 if type(timeout) is not int or not 1<=timeout<=7200 or type(disk_floor) is not int or disk_floor<0:raise ValueError('Invalid batch budget')
 if modules is not None and (not isinstance(modules,(list,tuple)) or not 1<=len(modules)<=512 or any(not isinstance(x,str) for x in modules) or len(set(modules))!=len(modules)):raise ValueError('Invalid batch modules')
 if modules is not None:
  for module in modules:single.name(module)
 output=Path(output).absolute();reject_symlinks(output)
 if output.exists():raise ValueError('Batch planning requires fresh output')
 deadline=time.monotonic()+timeout;output.parent.mkdir(parents=True,exist_ok=True)
 def budget():
  if time.monotonic()>deadline:raise ValueError('Batch planner deadline exceeded')
  if shutil.disk_usage(output.parent).free<disk_floor:raise ValueError('Batch planner disk floor reached')
 from .ios_verification import compiler_sources
 producer=compiler_sources()
 budget();sources=single.load_capture(capture);budget()
 if not sources:raise ValueError('No successful SDK extraction inputs')
 selected=sorted(sources) if modules is None else sorted(modules)
 if set(selected)-set(sources):raise ValueError('Requested primary lacks verified retained extraction')
 contexts={m:{k:r['status']['provenance'].get(k,'iphonesimulator' if k=='sdkEnvironment' else None) for k in ('sdk','sdkVersion','sdkSettingsSHA256','target','sdkEnvironment')} for m,r in sources.items()}
 if any(c!=contexts[selected[0]] for c in contexts.values()):raise ValueError('Mixed SDK extraction environments/targets')
 capture_entries=single.directory_entries(Path(capture).resolve(),512)
 status_hashes={str(p/'status.json'):single.sha(p/'status.json',8*1024*1024) for p in capture_entries if p.is_dir()}
 input_hashes={str(p):single.expected_hash(r,p) for r in sources.values() for p in r['paths']}
 def unchanged():
  budget()
  if single.directory_entries(Path(capture).resolve(),512)!=capture_entries:raise ValueError('SDK capture module set changed')
  for path,value in status_hashes.items():
   if single.sha(Path(path),8*1024*1024)!=value:raise ValueError('SDK extraction status changed')
  for row in sources.values():
   budget()
   if single.sha(row['path'],8*1024*1024)!=row['statusSHA256'] or single.bounded_graph_paths(row['path'].parent/'symbolgraphs')!=sorted(row['paths']):raise ValueError('SDK capture changed during batch planning')
   for p in row['paths']:
    budget()
    if single.sha(p)!=input_hashes[str(p)]:raise ValueError('SDK graph changed during batch planning')
 with tempfile.TemporaryDirectory(prefix='.type-batch-',dir=output.parent) as temporary:
  stage=Path(temporary);pool=stage/'originals';pool.mkdir();plans=stage/'plans';plans.mkdir();database=stage/'index.sqlite';db=sqlite3.connect(database);snapshots={};scan_count=0;symbol_count=0;reference_rows=0
  def output_budget():
   budget();physical=0;seen=set();entries=0
   pending=[stage]
   while pending:
    with os.scandir(pending.pop()) as children:
     for child in children:
      entries+=1
      if entries>MAX_BATCH_ENTRIES:raise ValueError('Batch output entry count exceeds bound')
      if child.is_symlink():raise ValueError('Unexpected batch output symlink')
      if child.is_dir(follow_symlinks=False):pending.append(child.path);continue
      info=child.stat(follow_symlinks=False);key=(info.st_dev,info.st_ino)
      if key not in seen:physical+=info.st_size;seen.add(key)
      if physical>MAX_BATCH_BYTES:raise ValueError('Batch output exceeds2GiB')
   return physical
  try:
   db.execute('PRAGMA page_size=4096');db.execute('PRAGMA max_page_count='+str(max(1,MAX_INDEX_BYTES//4096)))
   db.executescript('CREATE TABLE refs(module TEXT,identity TEXT,ref TEXT,UNIQUE(module,identity,ref));CREATE TABLE members(module TEXT,identity TEXT,nominal INTEGER);CREATE INDEX member_lookup ON members(module,identity);CREATE TABLE nominals(identity TEXT,module TEXT,path TEXT,kind TEXT,parts TEXT,symbol TEXT);CREATE INDEX nominal_lookup ON nominals(identity,module);')
   for module,row in sorted(sources.items()):
    for path in row['paths']:
     budget();snapshot=pool/(str(scan_count)+'-'+path.name);single.copy_checked(path,snapshot,input_hashes[str(path)]);snapshots[str(path)]=snapshot;scan_count+=1
     for symbol in symbols(snapshot):
      symbol_count+=1
      if symbol_count>MAX_SYMBOLS:raise ValueError('Batch symbol count exceeds bound')
      identity=symbol.get('identifier',{}).get('precise');kind=symbol.get('kind',{}).get('identifier');nominal=kind in single.NOMINALS
      db.execute('INSERT INTO members VALUES (?,?,?)',(module,identity,int(nominal)))
      references=set(single.refs(symbol.get('declarationFragments',[])))|set(single.refs(symbol.get('functionSignature',{})))
      if len(references)>16384 or any(len(x)>8192 for x in references):raise ValueError('Referenced type IDs exceed bound')
      db.executemany('INSERT OR IGNORE INTO refs VALUES (?,?,?)',((module,identity,x) for x in references));reference_rows+=len(references)
      if reference_rows>MAX_REFERENCE_ROWS:raise ValueError('Batch reference count exceeds bound')
      parts=symbol.get('pathComponents',[])
      if nominal and parts and all(isinstance(p,str) and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',p) for p in parts):
       raw=json.dumps(symbol,separators=(',',':'))
       if len(raw.encode())>single.MAX_GRAPH:raise ValueError('Batch nominal exceeds graph bound')
       db.execute('INSERT INTO nominals VALUES (?,?,?,?,?,?)',(identity,module,str(path),kind,json.dumps(parts),raw))
      if symbol_count%256==0:
       budget()
       if database.stat().st_size>MAX_INDEX_BYTES:raise ValueError('Batch index exceeds1GiB')
     db.commit();output_budget()
     if database.stat().st_size>MAX_INDEX_BYTES:raise ValueError('Batch index exceeds1GiB')
     if progress:progress({'phase':'index','graphs':scan_count,'symbols':symbol_count})
   unchanged();results=[];bridge_index={}
   from .ios_bridge_types import bridge_contracts
   def copy_snapshot(source,destination,expected):
    budget();source=Path(source);snapshot=snapshots[str(source)]
    if input_hashes[str(source)]!=expected:raise ValueError('Snapshot source identity differs')
    os.link(snapshot,destination)
   for module in selected:
    budget();wanted={r[0] for r in db.execute('SELECT DISTINCT ref FROM refs WHERE module=? AND ref NOT IN (SELECT identity FROM members WHERE module=? AND nominal=1 AND identity IS NOT NULL) LIMIT 16385',(module,module))}
    try:
     if len(wanted)>16384 or any(len(x)>8192 for x in wanted):raise ValueError('Referenced type IDs exceed bound')
     matches={};selected_bytes=0;selected_rows=0;scanned={p:sha for p,sha in input_hashes.items() if p not in {str(x) for x in sources[module]['paths']}}
     for identity in sorted(wanted):
      for dependency,path,kind,parts,raw in db.execute('SELECT module,path,kind,parts,symbol FROM nominals WHERE identity=? AND module!=? ORDER BY module,path,rowid',(identity,module)):
       selected_rows+=1;selected_bytes+=len(raw.encode('utf-8'))
       if selected_rows>MAX_SELECTED_ROWS or selected_bytes>MAX_SELECTED_BYTES:raise ValueError('Selected nominal rows/bytes exceed bound')
       budget()
       key=(dependency,kind,tuple(json.loads(parts)));prior=matches.setdefault(identity,{'key':key,'symbols':[]})
       if prior['key']!=key:raise ValueError('Ambiguous referenced SDK nominal: '+identity)
       prior['symbols'].append((Path(path),json.loads(raw)))
     for dependency in sorted({match['key'][0] for match in matches.values()}):
      if dependency not in bridge_index:
       budget();bridge_index[dependency]=bridge_contracts(sources[dependency]['paths'],dependency);budget()
     def bridge_lookup(ids):
      count=0;size=0
      for identity in sorted(ids):
       for dependency,path,raw in db.execute('SELECT module,path,symbol FROM nominals WHERE identity=? AND module!=? ORDER BY module,path,rowid',(identity,module)):
        count+=1;size+=len(raw.encode())
        if count>MAX_SELECTED_ROWS or size>MAX_SELECTED_BYTES:raise ValueError('Bridge selected rows/bytes exceed bound')
        budget();yield dependency,Path(path),json.loads(raw)
     report=single._publish_plan(sources,module,plans/module,None,wanted,matches,scanned,contexts[module],verify=budget,copy_input=copy_snapshot,input_hashes=input_hashes,bridge_index=bridge_index,bridge_lookup=bridge_lookup)
     results.append({'module':module,'status':'planned','path':'plans/'+module,'manifestSHA256':single.sha(plans/module/'type-dependencies.json'),'dependencies':len(report['typeModules']),'nativeTested':0})
    except ValueError as error:
     budget();results.append({'module':module,'status':'rejected','reason':str(error),'nativeTested':0})
    output_budget()
    if progress:progress({'phase':'plan',**results[-1]})
   unchanged()
  except sqlite3.Error as error:raise ValueError('Batch index failure: '+str(error)) from error
  finally:db.close()
  database.unlink();budget()
  # Count physical shared retention once; each public plan remains a normal
  # regular-file tree. Hardlinks share immutable planning artifacts only.
  physical=0;seen=set();entries=0
  for path in stage.rglob('*'):
   entries+=1
   if entries>MAX_BATCH_ENTRIES:raise ValueError('Batch output entry count exceeds bound')
   if not path.is_file():continue
   info=path.stat();key=(info.st_dev,info.st_ino)
   if key not in seen:physical+=info.st_size;seen.add(key)
   if physical>MAX_BATCH_BYTES:raise ValueError('Batch output exceeds2GiB')
  for original,snapshot in snapshots.items():
   budget()
   if single.sha(snapshot)!=input_hashes[original]:raise ValueError('Retained SDK snapshot changed')
  if compiler_sources()!=producer:raise ValueError('Batch planner producer changed')
  manifest={'kind':'dcflight.ios.exact-type-batch.v1','inputGraphs':input_hashes,'symbolScans':scan_count,'symbolsIndexed':symbol_count,'bridgeGraphScans':sum(len(sources[m]['paths']) for m in bridge_index),'indexRemoved':True,'compilerSources':producer,'inputStatuses':status_hashes,'physicalBytesBeforeManifest':physical,'modules':results,'nativeTested':0,'retention':'Regular hardlinked immutable original/primary files; modifying one alias invalidates linked plan hashes. Derived subsets are separate regular files.'}
  (stage/'batch.json').write_text(json.dumps(manifest,indent=2)+'\n')
  if physical+(stage/'batch.json').stat().st_size>MAX_BATCH_BYTES:raise ValueError('Batch output exceeds2GiB')
  budget();reject_symlinks(output)
  if output.exists():raise ValueError('Batch output appeared during planning')
  stage.rename(output)
 return manifest
