"""Validate planned nominal subsets against original SDK symbols before native use."""
import hashlib,json,re
from pathlib import Path
from collections import defaultdict
from itertools import chain
MAX_REFERENCES=16384
MAX_ID_LENGTH=8192
MAX_TOTAL_REFERENCES=4000000
MAX_SELECTED_ROWS=65536
MAX_SELECTED_BYTES=512*1024*1024

def validate_batch(path,capture,records):
 from dcflight import ios_type_dependencies as core
 from dcflight.symbolgraph import symbols
 from dcflight.c_callback_recovery import reject_symlinks
 path=Path(path).absolute();reject_symlinks(path);capture=Path(capture).resolve()
 def read(p,limit=16*1024*1024):
  reject_symlinks(p);return json.loads(core.read_bounded(p,limit),object_pairs_hook=core.unique_object)
 def check(value,reason):
  if not value:raise ValueError(reason)
 def artifact(root,relative):
  check(isinstance(relative,str),'Invalid plan artifact');parts=Path(relative)
  check(not parts.is_absolute() and '..' not in parts.parts,'Escaping plan artifact')
  p=root/parts;reject_symlinks(p);check(p.is_file(),'Missing plan artifact');return p
 batch=read(path/'batch.json');check(batch.get('kind')=='dcflight.ios.exact-type-batch.v1' and batch.get('nativeTested')==0,'Invalid batch identity')
 modules=batch.get('modules');successful={m for m,r in records.items() if r['status']=='success'}
 check(isinstance(modules,list) and len(modules)==len(successful) and {r.get('module') for r in modules}==successful,'Incomplete batch scope set')
 inputs={str(capture/m/'symbolgraphs'/g['name']):g['sha256'] for m in successful for g in records[m]['graphs']}
 statuses={str(capture/m/'status.json'):r['statusSHA256'] for m,r in records.items()}
 check(batch.get('inputGraphs')==inputs and batch.get('inputStatuses')==statuses,'Batch capture identity differs')
 # Keep compact hashes, not complete nominal JSON objects, from one bounded scan.
 nominals=defaultdict(list);wanted=defaultdict(set);local=defaultdict(set);count=0;reference_count=0;nominal_count=0
 for m in sorted(successful):
  for g in records[m]['graphs']:
   source=capture/m/'symbolgraphs'/g['name'];check(core.sha(source)==g['sha256'],'Original graph changed')
   for symbol in core.snapshot_symbols(source,g['sha256']):
    count+=1;check(count<=1000000,'Plan replay symbol bound exceeded')
    identity=symbol.get('identifier',{}).get('precise');kind=symbol.get('kind',{}).get('identifier')
    for reference in chain(core.refs(symbol.get('declarationFragments',[])),core.refs(symbol.get('functionSignature',{}))):
     check(len(reference)<=MAX_ID_LENGTH,'Referenced type ID length exceeds bound')
     if reference not in wanted[m]:
      check(reference_count<MAX_TOTAL_REFERENCES,'Plan replay reference bound exceeded')
      wanted[m].add(reference);reference_count+=1
    if kind not in core.NOMINALS:continue
    local[m].add(identity);parts=symbol.get('pathComponents',[])
    if not parts or any(not isinstance(x,str) or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',x) for x in parts):continue
    nominal_count+=1;check(nominal_count<=1000000,'Plan nominal bound exceeded')
    nominals[identity].append((m,str(source),kind,tuple(parts),core.object_sha(symbol)))
 result={};hashes={'batch':core.sha(path/'batch.json')};checked={};bridge_index={}
 from dcflight.ios_bridge_types import bridge_contracts,enrichment
 for row in modules:
  m=row['module'];ids=wanted[m]-local[m];selection=[];chosen={};reason=None;selected_rows=0;selected_bytes=0
  if row.get('status')=='rejected':
   check(isinstance(row.get('reason'),str) and row['reason'] and row.get('nativeTested')==0,'Invalid rejected plan receipt')
   result[m]={'status':'rejected','reason':row['reason']};continue
  check(len(ids)<=MAX_REFERENCES,'Referenced type IDs exceed bound')
  dependencies={item[0] for identity in ids for item in nominals.get(identity,[]) if item[0]!=m}
  for dependency in sorted(dependencies):
   if dependency not in bridge_index:
    bridge_index[dependency]=bridge_contracts([capture/dependency/'symbolgraphs'/g['name'] for g in records[dependency]['graphs']],dependency)
  extras,bridge_evidence=enrichment(bridge_index,ids,m);ids=ids|extras
  check(len(ids)<=MAX_REFERENCES,'Enriched type IDs exceed bound')
  for identity in sorted(ids):
   prior_key=None
   for dep,source,kind,parts,symbol_sha in nominals.get(identity,[]):
    if dep==m:continue
    match_key=(dep,kind,parts)
    if prior_key is not None and prior_key!=match_key:reason=reason or 'Ambiguous referenced SDK nominal: '+identity
    prior_key=match_key
    selected_rows+=1;selected_bytes+=len(json.dumps((identity,dep,source,kind,parts,symbol_sha)).encode())
    check(selected_rows<=MAX_SELECTED_ROWS and selected_bytes<=MAX_SELECTED_BYTES,'Selected nominal rows/bytes exceed bound')
    selection.append({'id':identity,'module':dep,'kind':kind,'spelling':'.'.join(parts),'source':source,'sourceSHA256':inputs[source],'normalizedSymbolSHA256':symbol_sha})
    key=(dep,source);old=chosen.setdefault(key,{}).get(identity)
    if old is not None and old!=symbol_sha:reason=reason or 'Conflicting duplicate SDK nominal in one source: '+identity
    chosen[key][identity]=symbol_sha
  if len({d for d,_ in chosen})>32:reason=reason or 'More than32 exact type dependencies; narrow selected identities'
  check(row.get('status')=='planned' and reason is None,'Invalid planned scope: '+str(reason))
  check(row.get('path')=='plans/'+m,'Invalid plan location');folder=path/'plans'/m;planfile=artifact(folder,'type-dependencies.json');plan=read(planfile)
  check(core.sha(planfile)==row.get('manifestSHA256'),'Plan manifest hash differs');hashes[m]=row['manifestSHA256']
  check(plan.get('module')==m and plan.get('selectedIdentities') is None and plan.get('inputGraphs')==inputs and plan.get('nativeTested')==0,'Plan source identity differs')
  check(plan.get('selectedNominals')==selection,'Plan nominal selection differs from SDK; regenerate bridge-aware plans')
  check(plan.get('bridgeEnrichment',[])==bridge_evidence,'Plan bridge conformance evidence differs from SDK')
  bridge_relationships={}
  for contract in bridge_evidence:
   dependency=contract['module']
   for entry in contract['conformances']+contract['memberships']:
    for g in records[dependency]['graphs']:
     if g['sha256']==entry['sourceSHA256']:
      key=(dependency,str(capture/dependency/'symbolgraphs'/g['name']));chosen.setdefault(key,{})
      bridge_relationships.setdefault(key,{})[core.object_sha(entry['relationship'])]=entry['relationship']
  context={k:records[m]['provenance'].get(k,'iphonesimulator' if k=='sdkEnvironment' else None) for k in ('sdk','sdkVersion','sdkSettingsSHA256','target','sdkEnvironment')}
  check(plan.get('context')==context,'Plan SDK context differs')
  expected_statuses={n:{'path':str(capture/n/'status.json'),'sha256':records[n]['statusSHA256'],'provenance':records[n]['provenance']} for n in successful}
  check(plan.get('captureStatuses')==expected_statuses,'Plan source statuses differ')
  derived=plan.get('derived');check(isinstance(derived,list) and len(derived)==len(chosen),'Incomplete derived graphs');seen=set();type_inputs=defaultdict(list);type_paths={}
  for item in derived:
   key=(item.get('module'),item.get('source'));check(key in chosen and key not in seen,'Unexpected derived source');seen.add(key)
   p=artifact(folder,item.get('path'));check(core.sha(p)==item.get('sha256') and item.get('sourceSHA256')==inputs[key[1]],'Derived graph hash differs')
   doc=read(p,core.MAX_GRAPH);check(set(doc)=={'module','symbols','relationships'} and doc['module']=={'name':key[0]} and doc['relationships']==[bridge_relationships[key][k] for k in sorted(bridge_relationships.get(key,{}))] and isinstance(doc['symbols'],list),'Invalid derived graph structure')
   actual={};check(len(doc['symbols'])==len(chosen[key]),'Derived symbol count differs')
   for s in doc['symbols']:
    identifier=s.get('identifier',{}).get('precise');check(identifier not in actual,'Duplicate derived symbol');actual[identifier]=core.object_sha(s)
   check(actual==chosen[key],'Derived nominal differs from original SDK')
   type_inputs[key[0]].append({'name':p.name,'sha256':item['sha256']});type_paths[key[0]]=str(p.parent)
  check(plan.get('typeModules')=={n:'types/'+n for n in type_inputs},'Type paths differ')
  for n,p in type_paths.items():check(sorted(x.name for x in core.directory_entries(Path(p),512))==sorted(x['name'] for x in type_inputs[n]),'Unexpected derived artifacts')
  # Retained originals and primary aliases must be byte-identical SDK files.
  retain=plan.get('retained');check(isinstance(retain,list),'Missing retained originals')
  expected_sources={str(capture/m/'symbolgraphs'/g['name']) for g in records[m]['graphs']}|{source for _,source in chosen}
  check(len(retain)==len(expected_sources) and {r.get('source') for r in retain}==expected_sources,'Retained source set differs')
  for item in retain:
   p=artifact(folder,item.get('original'));info=p.stat();key=(info.st_dev,info.st_ino)
   if key not in checked:checked[key]=core.sha(p)
   check(checked[key]==inputs[item['source']]==item.get('sha256'),'Retained original differs')
  primary=plan.get('primaryArtifacts');check(isinstance(primary,list) and len(primary)==len(records[m]['graphs']),'Primary graph count differs')
  for index,g in enumerate(records[m]['graphs']):
   item=primary[index];p=artifact(folder,item.get('path'));check(item=={'path':'primary/'+str(index)+'-'+g['name'],'sha256':g['sha256']} and core.sha(p)==g['sha256'],'Primary graph differs')
  result[m]={'status':'planned','typeInputs':{n:sorted(v,key=lambda x:x['name']) for n,v in type_inputs.items()},'typePaths':type_paths}
 # Capture bytes are independently checked again by the enclosing coordinator.
 return {'batch':str(path),'hashes':hashes,'producer':batch.get('compilerSources'),'modules':result}
