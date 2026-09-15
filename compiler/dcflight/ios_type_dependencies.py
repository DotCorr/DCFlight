"""Derive bounded SDK type graphs by exact referenced nominal identity only."""
from __future__ import annotations
import gzip,hashlib,json,re,shutil,tempfile,os,stat
from contextlib import contextmanager
from pathlib import Path
from .symbolgraph import symbols,graph_paths
from .frontends import unique_object

NOMINALS={'swift.class','swift.struct','swift.enum','swift.protocol','swift.actor','swift.typealias'}
MAX_GRAPH=512*1024*1024
MAX_RETAINED=512*1024*1024

@contextmanager
def regular_input(path,limit):
 try:fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK|getattr(os,'O_NOFOLLOW',0))
 except OSError as error:raise ValueError('Unsafe retained input') from error
 with os.fdopen(fd,'rb') as stream:
  info=os.fstat(stream.fileno())
  if not stat.S_ISREG(info.st_mode) or info.st_size>limit:raise ValueError('Nonregular or oversized retained input')
  yield stream

def chunks(stream,limit):
 size=0
 for block in iter(lambda:stream.read(min(1024*1024,limit+1)),b''):
  size+=len(block)
  if size>limit:raise ValueError('Retained input grew beyond bound')
  yield block

class BoundedReader:
 def __init__(self,stream,limit):self.stream=stream;self.limit=limit;self.read_bytes=0
 def read(self,size=-1):
  remaining=self.limit-self.read_bytes
  data=self.stream.read(min(size,remaining+1) if size>=0 else remaining+1);self.read_bytes+=len(data)
  if self.read_bytes>self.limit:raise ValueError('Encoded graph grew beyond bound')
  return data

def sha(path,limit=None):
 limit=MAX_GRAPH if limit is None else limit;h=hashlib.sha256()
 with regular_input(path,limit) as stream:
  for block in chunks(stream,limit):h.update(block)
 return h.hexdigest()

def read_bounded(path,limit):
 with regular_input(path,limit) as stream:return b''.join(chunks(stream,limit))
def object_sha(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()).hexdigest()
def name(value):
 if not isinstance(value,str) or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',value):raise ValueError('Invalid SDK module name')
 return value

def refs(value,depth=0):
 if depth>64:raise ValueError('SDK fragment nesting exceeds bound')
 if isinstance(value,dict):
  if value.get('kind')=='typeIdentifier' and isinstance(value.get('preciseIdentifier'),str):yield value['preciseIdentifier']
  for child in value.values():yield from refs(child,depth+1)
 elif isinstance(value,list):
  for child in value:yield from refs(child,depth+1)

def copy_checked(source,destination,expected):
 h=hashlib.sha256();size=0
 with regular_input(source,MAX_GRAPH) as src,Path(destination).open('xb') as dst:
  for block in iter(lambda:src.read(1024*1024),b''):
   size+=len(block)
   if size>MAX_GRAPH:raise ValueError('SDK graph grew beyond bound')
   h.update(block);dst.write(block)
 if h.hexdigest()!=expected:raise ValueError('SDK graph changed before snapshot')

def snapshot_symbols(path,expected,*,relationship_handler=None):
 with tempfile.TemporaryDirectory(prefix='type-input-') as temporary:
  snapshot=Path(temporary)/path.name;copy_checked(path,snapshot,expected)
  yield from symbols(snapshot,relationship_handler=relationship_handler,max_bytes=MAX_GRAPH)

def expected_hash(row,path):return next(x['sha256'] for x in row['status']['artifacts']['graphs'] if x['path']==path.name)

def directory_entries(path,limit):
 result=[]
 with os.scandir(path) as entries:
  for entry in entries:
   if len(result)>=limit:raise ValueError('Directory entry count exceeds bound')
   result.append(Path(entry.path))
 return sorted(result)

def bounded_graph_paths(path):
 paths=[p for p in directory_entries(path,512) if p.name.endswith(('.symbols.json','.symbols.json.gz'))]
 names=[p.name[:-3] if p.name.endswith('.gz') else p.name for p in paths]
 if not paths or len(set(names))!=len(names):raise ValueError('Missing or duplicate retained graph')
 return paths

def load_capture(root):
 root=Path(root).resolve();result={};count=0;expanded=0
 for folder in directory_entries(root,512):
  if not folder.is_dir():continue
  name(folder.name)
  if folder.is_symlink():raise ValueError('Linked SDK module directory')
  status=folder/'status.json'
  if status.is_symlink() or not status.is_file() or status.stat().st_size>8*1024*1024:raise ValueError('Missing or oversized SDK status')
  status_bytes=read_bounded(status,8*1024*1024)
  data=json.loads(status_bytes,object_pairs_hook=unique_object)
  if not isinstance(data,dict):raise ValueError('Invalid SDK status')
  if data.get('module')!=folder.name:raise ValueError('SDK status module mismatch')
  if data.get('status')=='failed':continue
  if not isinstance(data.get('provenance'),dict):raise ValueError('Invalid SDK status provenance')
  if data.get('status')!='success' or data.get('proofReusable') is not True or data.get('extractionProvenanceVerified') is not True:raise ValueError('Unverified SDK extraction cannot provide type evidence')
  directory=folder/'symbolgraphs'
  if directory.is_symlink() or not directory.is_dir():raise ValueError('Missing retained SDK graphs')
  entries=data.get('artifacts',{}).get('graphs',[])
  if not isinstance(entries,list) or not 1<=len(entries)<=256:raise ValueError('Invalid retained graph list')
  paths=[]
  for row in entries:
   if not isinstance(row,dict):raise ValueError('Invalid retained graph entry')
   basename=row.get('path')
   if not isinstance(basename,str) or Path(basename).name!=basename or basename in ('.','..'):raise ValueError('Invalid retained graph path')
   p=directory/basename
   if p.is_symlink() or not p.is_file() or p.stat().st_size>MAX_GRAPH or sha(p)!=row.get('sha256'):raise ValueError('Retained graph changed or exceeds bound')
   h=hashlib.sha256();total=0
   with regular_input(p,MAX_GRAPH) as encoded_stream:
    stream=gzip.GzipFile(fileobj=BoundedReader(encoded_stream,MAX_GRAPH)) if p.suffix=='.gz' else encoded_stream
    for block in iter(lambda:stream.read(1024*1024),b''):
     total+=len(block)
     if total>MAX_GRAPH:raise ValueError('Expanded SDK graph exceeds bound')
     expanded+=len(block)
     if expanded>4*1024*1024*1024:raise ValueError('SDK capture exceeds4GiB expanded scan bound')
     h.update(block)
   if h.hexdigest()!=row.get('rawSHA256',row.get('sha256')):raise ValueError('Raw SDK graph hash mismatch')
   paths.append(p);count+=1
   if count>4096:raise ValueError('Too many SDK graph inputs')
  if sorted(paths)!=bounded_graph_paths(directory) or len(set(paths))!=len(paths):raise ValueError('SDK graph set mismatch')
  result[folder.name]={'paths':paths,'status':data,'statusSHA256':hashlib.sha256(status_bytes).hexdigest(),'path':status}
  if len(result)>512:raise ValueError('Too many SDK modules')
 return result

def plan(capture,module,output,*,identities=None):
 name(module);output=Path(output).absolute()
 # Standard temporary aliases are handled by the compiler-owned path guard.
 from .c_callback_recovery import reject_symlinks
 reject_symlinks(output)
 if output.exists():raise ValueError('Type dependency planning requires fresh output')
 sources=load_capture(capture)
 if module not in sources:raise ValueError('Primary module has no verified retained extraction')
 if identities is not None and (not isinstance(identities,(list,tuple)) or not 1<=len(identities)<=10000 or any(not isinstance(x,str) for x in identities) or len(set(identities))!=len(identities)):raise ValueError('Invalid requested SDK identities')
 selected=set(identities) if identities is not None else None;found=set();wanted=set();local=set()
 for path in sources[module]['paths']:
  for symbol in snapshot_symbols(path,expected_hash(sources[module],path)):
   identity=symbol.get('identifier',{}).get('precise')
   if symbol.get('kind',{}).get('identifier') in NOMINALS:local.add(identity)
   if selected is None or identity in selected:
    found.add(identity);wanted.update(refs(symbol.get('declarationFragments',[])));wanted.update(refs(symbol.get('functionSignature',{})))
 if selected is not None and selected-found:raise ValueError('Requested SDK identity not present')
 wanted-=local
 if len(wanted)>16384 or any(len(x)>8192 for x in wanted):raise ValueError('Referenced type IDs exceed bound')
 matches={};scanned={};context_keys=('sdk','sdkVersion','sdkSettingsSHA256','target','sdkEnvironment')
 primary_context={k:sources[module]['status']['provenance'].get(k,'iphonesimulator' if k=='sdkEnvironment' else None) for k in context_keys}
 for dependency,row in sorted(sources.items()):
  if dependency==module:continue
  context={k:row['status'].get('provenance',{}).get(k,'iphonesimulator' if k=='sdkEnvironment' else None) for k in context_keys}
  if context!=primary_context:raise ValueError('Mixed SDK extraction environments/targets')
  for path in row['paths']:
   scanned[str(path)]=expected_hash(row,path)
   for symbol in snapshot_symbols(path,scanned[str(path)]):
    identity=symbol.get('identifier',{}).get('precise')
    if identity not in wanted or symbol.get('kind',{}).get('identifier') not in NOMINALS:continue
    parts=symbol.get('pathComponents',[])
    if not parts or any(not isinstance(x,str) or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',x) for x in parts):continue
    key=(dependency,symbol['kind']['identifier'],tuple(parts))
    prior=matches.setdefault(identity,{'key':key,'symbols':[]})
    if prior['key']!=key:raise ValueError('Ambiguous referenced SDK nominal: '+identity)
    prior['symbols'].append((path,symbol))
 return _publish_plan(sources,module,output,selected,wanted,matches,scanned,primary_context)

def _publish_plan(sources,module,output,selected,wanted,matches,scanned,primary_context,*,verify=None,copy_input=None,input_hashes=None,bridge_index=None,bridge_lookup=None):
 from .c_callback_recovery import reject_symlinks
 copy_input = copy_checked if copy_input is None else copy_input
 from .ios_bridge_types import bridge_contracts,enrichment
 if bridge_index is None:
  bridge_index={dependency:bridge_contracts(sources[dependency]['paths'],dependency) for dependency in sorted({m['key'][0] for m in matches.values()})}
 extra,bridge_evidence=enrichment(bridge_index,set(matches),module)
 missing=extra-set(matches)
 if missing:
  if bridge_lookup is None:
   def bridge_lookup(ids):
    for dependency in sorted({c['module'] for c in bridge_evidence}):
     for path in sources[dependency]['paths']:
      for symbol in snapshot_symbols(path,expected_hash(sources[dependency],path)):
       if symbol.get('identifier',{}).get('precise') in ids:
        yield dependency,path,symbol
  added=0;added_bytes=0
  for dependency,path,symbol in bridge_lookup(missing):
   added+=1;added_bytes+=len(json.dumps(symbol).encode())
   if added>65536 or added_bytes>MAX_RETAINED:raise ValueError('Bridge selected symbols exceed bound')
   identity=symbol['identifier']['precise'];key=(dependency,symbol['kind']['identifier'],tuple(symbol['pathComponents']))
   prior=matches.setdefault(identity,{'key':key,'symbols':[]})
   if prior['key']!=key:raise ValueError('Ambiguous bridge nominal identity')
   prior['symbols'].append((Path(path),symbol))
  if missing-set(matches):raise ValueError('Bridge proof nominal missing from retained input')
 bridge_relationships={}
 for contract in bridge_evidence:
  dependency=contract['module']
  for entry in contract['conformances']+contract['memberships']:
   paths=[p for p in sources[dependency]['paths'] if expected_hash(sources[dependency],p)==entry['sourceSHA256']]
   if not paths:raise ValueError('Bridge conformance source missing')
   for path in paths:
    values=bridge_relationships.setdefault((dependency,path),{})
    values[object_sha(entry['relationship'])]=entry['relationship']
 dependencies=sorted({m['key'][0] for m in matches.values()})
 if len(dependencies)>32:raise ValueError('More than32 exact type dependencies; narrow selected identities')
 chosen={};selection=[]
 for identity,match in sorted(matches.items()):
  for path,symbol in match['symbols']:
   bucket=chosen.setdefault((match['key'][0],path),{})
   if identity in bucket and bucket[identity]!=symbol:raise ValueError('Conflicting duplicate SDK nominal in one source: '+identity)
   bucket[identity]=symbol
   selection.append({'id':identity,'module':match['key'][0],'kind':match['key'][1],'spelling':'.'.join(match['key'][2]),'source':str(path),'sourceSHA256':scanned[str(path)],'normalizedSymbolSHA256':object_sha(symbol)})
 for key in bridge_relationships:chosen.setdefault(key,{})
 retain=set(sources[module]['paths'])|{p for _,p in chosen}
 if sum(p.stat().st_size for p in retain)+sum(p.stat().st_size for p in sources[module]['paths'])>MAX_RETAINED:raise ValueError('Retained dependency bundle exceeds512MiB')
 def unchanged():
  if verify is not None:
   verify();return
  for row in sources.values():
   if sha(row['path'],8*1024*1024)!=row['statusSHA256'] or bounded_graph_paths(row['path'].parent/'symbolgraphs')!=sorted(row['paths']):raise ValueError('SDK capture changed during dependency planning')
   for p in row['paths']:
    original=next(x['sha256'] for x in row['status']['artifacts']['graphs'] if x['path']==p.name)
    if sha(p)!=original:raise ValueError('SDK graph changed during dependency planning')
 unchanged();reject_symlinks(output);output.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='.type-plan-',dir=output.parent) as temp:
  stage=Path(temp);rows=[]
  for index,path in enumerate(sorted(retain)):
   destination=stage/'original'/str(index)/path.name;destination.parent.mkdir(parents=True)
   expected=expected_hash(sources[module],path) if path in sources[module]['paths'] else scanned[str(path)]
   copy_input(path,destination,expected)
   rows.append({'source':str(path),'original':str(destination.relative_to(stage)),'sha256':expected})
  primary=stage/'primary';primary.mkdir()
  primary_rows=[]
  for index,path in enumerate(sources[module]['paths']):
   destination=primary/(str(index)+'-'+path.name);copy_input(path,destination,expected_hash(sources[module],path));primary_rows.append({'path':str(destination.relative_to(stage)),'sha256':expected_hash(sources[module],path)})
  derived=[]
  for index,((dependency,path),symbols_by_id) in enumerate(sorted(chosen.items(),key=lambda item:(item[0][0],str(item[0][1])))):
   destination=stage/'types'/dependency/(str(index)+'.symbols.json');destination.parent.mkdir(parents=True,exist_ok=True)
   document={'module':{'name':dependency},'symbols':[symbols_by_id[k] for k in sorted(symbols_by_id)],'relationships':[bridge_relationships[(dependency,path)][key] for key in sorted(bridge_relationships.get((dependency,path),{}))]}
   destination.write_text(json.dumps(document,separators=(',',':'))+'\n');derived.append({'module':dependency,'path':str(destination.relative_to(stage)),'sha256':sha(destination),'source':str(path),'sourceSHA256':scanned[str(path)]})
  unchanged()
  report={'kind':'dcflight.ios.exact-type-dependencies.v1','module':module,'selectedIdentities':sorted(selected) if selected is not None else None,'context':primary_context,'captureStatuses':{m:{'path':str(row['path']),'sha256':row['statusSHA256'],'provenance':row['status']['provenance']} for m,row in sources.items()},'inputGraphs':input_hashes if input_hashes is not None else {str(p):sha(p) for row in sources.values() for p in row['paths']},'retained':rows,'derived':derived,'selectedNominals':selection,**({'bridgeEnrichment':bridge_evidence} if bridge_evidence else {}),'unresolvedTypeIDs':sorted(wanted-set(matches)),'typeModules':{d:'types/'+d for d in dependencies},'primaryGraphs':'primary','primaryArtifacts':primary_rows,'nativeTested':0,'scope':'Exact-ID selected SDK nominal subsets with original retained bytes; no guessed spelling/import, callable promotion or native proof.'}
  (stage/'type-dependencies.json').write_text(json.dumps(report,indent=2)+'\n')
  if sum(p.stat().st_size for p in stage.rglob('*') if p.is_file())>MAX_RETAINED:raise ValueError('Retained dependency bundle exceeds512MiB')
  reject_symlinks(output)
  if output.exists():raise ValueError('Output appeared during dependency planning')
  stage.rename(output)
 return report
