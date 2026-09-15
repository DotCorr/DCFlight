"""Exact SDK ReferenceConvertible contracts for member-facing bridged types.

No spelling-only substitution or Objective-C-to-Swift identity equivalence is
inferred: both nominal identities, the alias and the conformance are retained.
"""
from __future__ import annotations
import hashlib,json,re
from pathlib import Path
from .symbolgraph import symbols
PROTOCOL='s:10Foundation20ReferenceConvertibleP'
MAX_NOMINALS=65536
MAX_PAIRS=4096
IDENT=re.compile(r'[A-Za-z_][A-Za-z_0-9]*')
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()).hexdigest()

def bridge_contracts(paths,module):
    # Callers supply the same SDK graph inputs that are bound by producer hashes.
    from .ios_type_dependencies import sha,snapshot_symbols
    paths=tuple(paths)
    if len(paths)>256:raise ValueError('Bridge source graph count exceeds bound')
    nominals={};aliases=[];conformances=[];memberships=[];count=0;alias_targets={};generic_values=set()
    for raw_path in paths:
        path=Path(raw_path);source=sha(path)
        def relation(row):
            if row.get('kind')=='memberOf':
                if len(memberships)>=MAX_NOMINALS:raise ValueError('Bridge membership bound exceeded')
                memberships.append({'relationship':row,'sourceSHA256':source})
            if row.get('kind')=='conformsTo' and row.get('target')==PROTOCOL:
                if row.get('swiftConstraints') or set(row)-{'kind','source','target','targetFallback','swiftConstraints'}:return
                if len(conformances)>=MAX_PAIRS:raise ValueError('Bridge conformance bound exceeded')
                conformances.append({'relationship':row,'sourceSHA256':source})
        for symbol in snapshot_symbols(path,source,relationship_handler=relation):
            kind=symbol.get('kind',{}).get('identifier');parts=symbol.get('pathComponents',[])
            if kind not in ('swift.class','swift.struct','swift.enum','swift.typealias') or not parts or any(not isinstance(p,str) or not IDENT.fullmatch(p) for p in parts):continue
            count+=1
            if count>MAX_NOMINALS:raise ValueError('Bridge nominal index bound exceeded')
            precise=symbol.get('identifier',{}).get('precise')
            if not isinstance(precise,str) or len(precise)>8192:raise ValueError('Invalid bridge nominal identity')
            declaration=''.join(f.get('spelling','') for f in symbol.get('declarationFragments',[]))
            if symbol.get('swiftGenerics',{}).get('parameters') or re.search(r'\b(?:struct|enum)\s+'+re.escape(parts[-1])+r'\s*<',declaration):generic_values.add(precise)
            record={'id':precise,'module':module,'spelling':'.'.join(parts),'sourceSHA256':source,'symbolSHA256':digest(symbol),'kind':kind,'availability':symbol.get('availability',[])}
            prior=nominals.setdefault(precise,[])
            if any((p['spelling'],p['kind'])!=(record['spelling'],record['kind']) for p in prior):raise ValueError('Conflicting bridge nominal identity')
            if record not in prior:prior.append(record)
            if kind=='swift.typealias' and len(parts)==2 and parts[-1]=='ReferenceType':
                fragments=symbol.get('declarationFragments',[]);targets=[f for f in fragments if f.get('kind')=='typeIdentifier'];text=''.join(f.get('spelling','') for f in fragments)
                if len(targets)!=1 or not re.fullmatch(r'typealias\s+ReferenceType\s*=\s*'+re.escape(targets[0].get('spelling','')),text):continue
                target=targets[0].get('preciseIdentifier')
                if precise in alias_targets and alias_targets[precise]!=target:raise ValueError('Conflicting bridge ReferenceType identity')
                alias_targets[precise]=target
                if len(aliases)>=MAX_PAIRS:raise ValueError('Bridge alias bound exceeded')
                aliases.append((parts[0],targets[0].get('preciseIdentifier'),record))
    results={};by_name={}
    for records in nominals.values():
        records.sort(key=digest)
        if records[0]['id'] not in generic_values and records[0]['kind'] in ('swift.struct','swift.enum'):by_name.setdefault(records[0]['spelling'],[]).append(records)
    for value_name,reference_id,alias in aliases:
        references=nominals.get(reference_id,[])
        if not references or any(r['kind']!='swift.class' for r in references):continue
        values=by_name.get(value_name,[])
        if len(values)>1:raise ValueError('Ambiguous bridged Swift value identity')
        if not values:continue
        value=values[0]
        owners=[r for r in memberships if r['relationship'].get('source')==alias['id']]
        if any(r['relationship'].get('target')!=value[0]['id'] for r in owners):raise ValueError('Conflicting bridge alias owner identity')
        if not owners or any(r['relationship'].get('swiftConstraints') or set(r['relationship'])-{'kind','source','target','sourceOrigin','targetFallback','swiftConstraints'} for r in owners):continue
        owners=sorted(owners,key=digest)
        relations=sorted([r for r in conformances if r['relationship'].get('source')==value[0]['id']],key=digest)
        if not relations:continue
        contract={'module':module,'reference':references,'value':value,'alias':[alias],'conformances':relations,'memberships':owners}
        key=(reference_id,value_name)
        if key in results:
            old=results[key]
            if old['value']!=value or old['reference']!=references:raise ValueError('Conflicting bridged type pair')
            if alias not in old['alias']:old['alias'].append(alias);old['alias'].sort(key=digest)
            for owner in owners:
                if owner not in old['memberships']:old['memberships'].append(owner)
            old['memberships'].sort(key=digest)
        else:results[key]=contract
        if len(results)>MAX_PAIRS:raise ValueError('Bridge pair bound exceeded')
    return results

def validate_contracts(contracts,imports):
    if not isinstance(contracts,(list,tuple)) or len(contracts)>64:raise ValueError('Invalid bridge resolution evidence')
    for c in contracts:
        if not isinstance(c,dict) or set(c)!={'module','reference','value','alias','conformances','memberships'} or c['module'] not in imports:raise ValueError('Invalid bridge resolution evidence')
        for field in ('reference','value','alias'):
            if not isinstance(c[field],list) or not 1<=len(c[field])<=256:raise ValueError('Invalid bridge source records')
            for r in c[field]:
                if not isinstance(r,dict) or set(r)!={'id','module','spelling','sourceSHA256','symbolSHA256','kind','availability'}:raise ValueError('Invalid bridge source record')
                if r['module']!=c['module'] or not isinstance(r['id'],str) or not r['id'] or len(r['id'])>8192:raise ValueError('Invalid bridge source identity')
                if not isinstance(r['spelling'],str) or not all(IDENT.fullmatch(x) for x in r['spelling'].split('.')):raise ValueError('Invalid bridge spelling')
                for k in ('sourceSHA256','symbolSHA256'):
                    if not isinstance(r[k],str) or not re.fullmatch('[0-9a-f]{64}',r[k]):raise ValueError('Invalid bridge source digest')
                if not isinstance(r['availability'],list):raise ValueError('Invalid bridge availability')
            if len({(r['id'],r['spelling'],r['kind']) for r in c[field]})!=1:raise ValueError('Conflicting bridge identity')
        v=c['value'][0]
        if v['kind'] not in ('swift.struct','swift.enum') or c['reference'][0]['kind']!='swift.class' or c['alias'][0]['kind']!='swift.typealias' or c['alias'][0]['spelling']!=v['spelling']+'.ReferenceType':raise ValueError('Invalid bridge roles')
        if not isinstance(c['conformances'],list) or not 1<=len(c['conformances'])<=256:raise ValueError('Invalid bridge conformance')
        for record in c['conformances']:
            if not isinstance(record,dict) or set(record)!={'relationship','sourceSHA256'} or not isinstance(record['sourceSHA256'],str) or not re.fullmatch('[0-9a-f]{64}',record['sourceSHA256']):raise ValueError('Invalid bridge conformance provenance')
            rel=record['relationship']
            if not isinstance(rel,dict) or rel.get('kind')!='conformsTo' or rel.get('source')!=v['id'] or rel.get('target')!=PROTOCOL or rel.get('swiftConstraints') or set(rel)-{'kind','source','target','targetFallback','swiftConstraints'}:raise ValueError('Invalid bridge conformance identity')
        if not isinstance(c['memberships'],list) or not 1<=len(c['memberships'])<=256:raise ValueError('Invalid bridge membership')
        aliases={r['id'] for r in c['alias']};seen=set()
        for record in c['memberships']:
            if not isinstance(record,dict) or set(record)!={'relationship','sourceSHA256'} or not isinstance(record['sourceSHA256'],str) or not re.fullmatch('[0-9a-f]{64}',record['sourceSHA256']):raise ValueError('Invalid bridge membership provenance')
            rel=record['relationship']
            if not isinstance(rel,dict) or rel.get('kind')!='memberOf' or rel.get('source') not in aliases or rel.get('target')!=v['id'] or rel.get('swiftConstraints') or set(rel)-{'kind','source','target','sourceOrigin','targetFallback','swiftConstraints'}:raise ValueError('Invalid bridge membership identity')
            seen.add(rel['source'])
        if seen!=aliases:raise ValueError('Missing bridge alias ownership')
    return tuple(contracts)


def enrichment(index,wanted,primary):
    """Return exact extra nominal IDs and conformance evidence, not guessed types."""
    selected=[];extra=set()
    for module,contracts in sorted(index.items()):
        if module==primary:continue
        for (reference_id,spelling),contract in sorted(contracts.items()):
            if reference_id not in wanted:continue
            selected.append(contract)
            for role in ('reference','value','alias'):
                extra.update(r['id'] for r in contract[role])
            if len(selected)>MAX_PAIRS or len(extra)>16384:raise ValueError('Bridge enrichment exceeds bound')
    return extra,selected
