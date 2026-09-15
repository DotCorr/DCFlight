"""Explicit, development-time derived graphs for lost outer callback qualifiers.

Original SDK graph bytes are retained; no importer consults hidden sidecars and
no application carries this tool. A derived graph still needs native verification.
"""
import copy,gzip,hashlib,io,json,os,re,selectors,subprocess,time
from pathlib import Path
from .symbolgraph import graph_paths
from .platforms.ios_api import SDKCatalog
from .platforms.swift_types import parse_type

MAX_ID=4096
MAX_OUTPUT=8*1024*1024
MAX_GRAPH=128*1024*1024

def sha(data):return hashlib.sha256(data).hexdigest()
def mangled(identity):
    if not isinstance(identity,str) or not identity.startswith('s:') or len(identity)>MAX_ID or not re.fullmatch(r'[A-Za-z0-9_$]+',identity[2:]):raise ValueError('Unsupported Swift precise identity')
    return '$s'+identity[2:]

def demangle(ids,executable):
    if not 1<=len(ids)<=64 or sum(len(mangled(i)) for i in ids)>65536:raise ValueError('Demangler batch exceeds bound')
    command=[str(executable),'--expand','--tree-only',*[mangled(i) for i in ids]]
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ);chunks=[];size=0;deadline=time.monotonic()+30
    try:
        while True:
            remaining=deadline-time.monotonic()
            if remaining<=0:raise ValueError('Demangler timeout')
            ready=selector.select(min(remaining,1))
            if not ready:continue
            chunk=os.read(process.stdout.fileno(),65536)
            if not chunk:break
            size+=len(chunk)
            if size>MAX_OUTPUT:raise ValueError('Demangler output exceeds8MiB')
            chunks.append(chunk)
        if process.wait(timeout=max(0.1,deadline-time.monotonic())):raise ValueError('Native demangler failed')
        output=b''.join(chunks).decode('utf-8')
    finally:
        selector.close();process.stdout.close()
        if process.poll() is None:process.kill();process.wait()
    parts=re.split(r'(?m)^Demangling for ',output)
    if parts[0].strip():raise ValueError('Unexpected demangler output')
    result={}
    for part in parts[1:]:
        identity,separator,tree=part.partition('\n')
        if not separator or identity in result:raise ValueError('Ambiguous demangler identity')
        result[identity]=tree
    if set(result)!={mangled(i) for i in ids}:raise ValueError('Demangler returned different identities')
    return {i:result[mangled(i)] for i in ids}

def tree(text):
    if not isinstance(text,str) or len(text.encode())>MAX_OUTPUT:raise ValueError('Expanded tree exceeds bound')
    root=None;stack=[];count=0
    for line in text.splitlines():
        if not line.strip():continue
        match=re.fullmatch(r'( *)kind=([A-Za-z][A-Za-z0-9_]*)(?:, (.*))?',line)
        if not match or len(match[1])%2:raise ValueError('Malformed demangler tree')
        depth=len(match[1])//2;count+=1
        if depth>64 or count>32768 or depth>len(stack):raise ValueError('Unbounded/ambiguous demangler tree')
        node={'kind':match[2],'attributes':match[3] or '', 'children':[]}
        if depth==0:
            if root is not None:raise ValueError('Multiple demangler roots')
            root=node
        else:stack[depth-1]['children'].append(node)
        stack=stack[:depth]+[node]
    if root is None:raise ValueError('Empty demangler tree')
    return root

def one(node,kind):
    children=[n for n in node['children'] if n['kind']==kind]
    if len(children)!=1:raise ValueError('Expected exactly one '+kind)
    return children[0]
def unwrap(node,kind):
    if node['kind']!=kind or len(node['children'])!=1:raise ValueError('Ambiguous '+kind+' wrapper')
    return node['children'][0]
def identifier(node):
    match=re.fullmatch(r'text=("(?:\\.|[^"\\])*")',node['attributes'])
    if not match:raise ValueError('Malformed function name identity')
    return json.loads(match[1])

def concurrent_parameters(text,name,arity):
    """Return only outer callback markers; never search descendant markers."""
    root=tree(text)
    function=unwrap(root,'Global')
    if function['kind']!='Function':raise ValueError('Only direct non-generic function nodes supported')
    if identifier(one(function,'Identifier'))!=name:raise ValueError('Demangled function identity differs from graph')
    typ=unwrap(one(function,'Type'),'Type')
    if typ['kind']!='FunctionType':raise ValueError('Unsupported generic/curried function type')
    args=unwrap(one(typ,'ArgumentTuple'),'ArgumentTuple');args=unwrap(args,'Type')
    if args['kind']=='Tuple':
        values=[]
        for element in args['children']:
            if element['kind']!='TupleElement':raise ValueError('Ambiguous argument tuple')
            values.append(unwrap(one(element,'Type'),'Type'))
    elif arity==1:values=[args]
    else:raise ValueError('Ambiguous callable arity')
    if len(values)!=arity:raise ValueError('Demangled parameter count differs from graph')
    result=[]
    for index,node in enumerate(values):
        if node['kind']!='FunctionType':continue
        markers=[c for c in node['children'] if c['kind']=='ConcurrentFunctionType']
        if len(markers)>1 or any(m['children'] or m['attributes'] for m in markers):raise ValueError('Malformed concurrent function marker')
        if markers:result.append(index)
    return result

def insert_attribute(fragments,typ):
    text=''.join(f.get('spelling','') for f in fragments)
    if not text.endswith(typ) or ':' not in text[:-len(typ)]:raise ValueError('Callback signature does not match graph fragments')
    offset=len(text)-len(typ);result=copy.deepcopy(fragments);position=0
    for fragment in result:
        value=fragment.get('spelling','')
        if position<=offset<=position+len(value):
            at=offset-position;fragment['spelling']=value[:at]+'@Sendable '+value[at:];return result
        position+=len(value)
    raise ValueError('Missing callback insertion point')

def recover(graphs,module,output,*,demangler,interface=None):
    paths=graph_paths(graphs);output=Path(output)
    if output.exists():raise ValueError('Recovery requires fresh output directory')
    if len(paths)>256:raise ValueError('Too many source graphs')
    for path in paths:
        if path.stat().st_size>MAX_GRAPH:raise ValueError('SDK graph exceeds128MiB')
        opener=gzip.open if path.suffix=='.gz' else open
        with opener(path,'rb') as stream:
            total=0
            for chunk in iter(lambda:stream.read(65536),b''):
                total+=len(chunk)
                if total>MAX_GRAPH:raise ValueError('Expanded SDK graph exceeds128MiB')
    snapshots={path:sha(path.read_bytes()) for path in paths}
    def check_sources():
        if graph_paths(graphs)!=paths or any(sha(path.read_bytes())!=digest for path,digest in snapshots.items()):raise ValueError("SDK graph inputs changed during recovery")
    catalog=SDKCatalog.from_symbolgraphs(paths,module)
    check_sources()
    candidates={}
    for identity,api in catalog.apis.items():
        if api.kind not in ('function','method','static_method') or not identity.startswith('s:'):continue
        indices=[]
        for i,p in enumerate(api.parameters):
            try:typ=parse_type(p.type)
            except ValueError:continue
            if typ.name=='$function' and not typ.optional and 'Sendable' not in typ.attributes and '@Sendable' not in p.type and not p.inout and not p.autoclosure:indices.append(i)
        if indices:
            try:mangled(identity)
            except ValueError:continue
            candidates[identity]=indices
    if len(candidates)>100000:raise ValueError('Too many callback candidates')
    executable=Path(demangler).resolve();tool_hash=sha(executable.read_bytes());trees={};batch=[];size=0
    for identity in sorted(candidates):
        if len(batch)==64 or size+len(mangled(identity))>65536:
            trees.update(demangle(batch,executable));batch=[];size=0
        batch.append(identity);size+=len(mangled(identity))
    if batch:trees.update(demangle(batch,executable))
    replacements={};skipped={}
    for identity,indices in candidates.items():
        api=catalog.get(identity)
        try:found=concurrent_parameters(trees[identity],api.path[-1].partition('(')[0],len(api.parameters))
        except ValueError as error:skipped[identity]=str(error);continue
        selected=sorted(set(found)&set(indices))
        if selected:replacements[identity]=selected
    # Stage outputs only after the bounded native extraction/structural pass.
    check_sources()
    output.mkdir(parents=True);(output/'original').mkdir();rows=[];changes=[]
    for path in paths:
        raw=path.read_bytes()
        if len(raw)>MAX_GRAPH:raise ValueError('SDK graph exceeds128MiB')
        if sha(raw)!=snapshots[path]:raise ValueError('SDK graph inputs changed during recovery')
        with (gzip.GzipFile(fileobj=io.BytesIO(raw)) if path.suffix=='.gz' else io.BytesIO(raw)) as stream:
            content=stream.read(MAX_GRAPH+1)
        if len(content)>MAX_GRAPH:raise ValueError('Expanded SDK graph exceeds128MiB')
        from .frontends import unique_object
        document=json.loads(content,object_pairs_hook=unique_object)
        for symbol in document.get('symbols',[]):
            identity=symbol.get('identifier',{}).get('precise');indices=replacements.get(identity)
            if not indices:continue
            api=catalog.get(identity);params=symbol.get('functionSignature',{}).get('parameters',[])
            if len(params)!=len(api.parameters):raise ValueError('Duplicate graph member parameter mismatch')
            original_symbol_hash=sha(json.dumps(symbol,sort_keys=True).encode())
            for index in indices:params[index]['declarationFragments']=insert_attribute(params[index]['declarationFragments'],api.parameters[index].type)
            changes.append({'graph':path.name.removesuffix('.gz'),'id':identity,'parameterIndices':indices,'originalSymbolSHA256':original_symbol_hash,'expandedTree':trees[identity],'treeSHA256':sha(trees[identity].encode())})
        destination=output/path.name.removesuffix('.gz');derived=json.dumps(document,ensure_ascii=True,separators=(',',':')).encode()+b'\n'
        (output/'original'/path.name).write_bytes(raw);destination.write_bytes(derived)
        rows.append({'original':'original/'+path.name,'originalSHA256':sha(raw),'derived':destination.name,'derivedSHA256':sha(derived)})
    derived=SDKCatalog.from_symbolgraphs(graph_paths(output),module)
    if set(derived.apis)!=set(catalog.apis):raise ValueError('Recovery changed native identities')
    from dataclasses import replace
    for identity,api in catalog.apis.items():
        params=tuple(replace(p,type='@Sendable '+p.type) if i in replacements.get(identity,[]) else p for i,p in enumerate(api.parameters))
        if derived.get(identity)!=replace(api,parameters=params):raise ValueError('Recovery changed non-qualifier API metadata: '+identity)
    if sha(executable.read_bytes())!=tool_hash:raise ValueError('Demangler changed during recovery')
    report={'kind':'dcflight.swift.outer-callback-qualifiers.v1','module':module,'demangler':str(executable),'demanglerSHA256':tool_hash,'graphs':rows,'changes':changes,'skipped':skipped,'scope':'Derived graph qualifier recovery only, not native conformance or original SDK output; original bytes retained alongside derived graph files.'}
    if interface:
        if Path(interface).stat().st_size>MAX_GRAPH:raise ValueError('SDK interface exceeds128MiB')
        raw=Path(interface).read_bytes();(output/'original/interface.swiftinterface').write_bytes(raw);report['interface']={'path':'original/interface.swiftinterface','sha256':sha(raw)}
    check_sources()
    (output/'qualifier-recovery.json').write_text(json.dumps(report,indent=2)+'\n');return report


def verify_bundle(output):
    """Check explicit provenance bundle without SDK tools or implicit sidecars."""
    root=Path(output).resolve();path=root/'qualifier-recovery.json'
    if path.is_symlink():raise ValueError('Recovery manifest is a symlink')
    if path.stat().st_size>64*1024*1024:raise ValueError('Recovery manifest exceeds64MiB')
    from .frontends import unique_object
    report=json.loads(path.read_text(),object_pairs_hook=unique_object)
    if report.get('kind')!='dcflight.swift.outer-callback-qualifiers.v1':raise ValueError('Wrong recovery manifest')
    rows=report.get('graphs')
    if not isinstance(rows,list) or not 1<=len(rows)<=256:raise ValueError('Invalid recovery graph list')
    def owned(name):
        if not isinstance(name,str):raise ValueError('Invalid recovery artifact path')
        relative=Path(name)
        if relative.is_absolute() or '..' in relative.parts:raise ValueError('Recovery path escapes bundle')
        target=root/relative
        if any((root/Path(*relative.parts[:i])).is_symlink() for i in range(1,len(relative.parts)+1)):raise ValueError('Recovery artifact or parent is a symlink')
        target.resolve().relative_to(root)
        if target.stat().st_size>MAX_GRAPH:raise ValueError('Recovery artifact exceeds128MiB')
        return target
    expected=[]
    for row in rows:
        if not isinstance(row,dict) or set(row)!={'original','originalSHA256','derived','derivedSHA256'}:raise ValueError('Invalid recovery graph entry')
        original,derived=owned(row['original']),owned(row['derived'])
        if sha(original.read_bytes())!=row['originalSHA256'] or sha(derived.read_bytes())!=row['derivedSHA256']:raise ValueError('Recovery graph hash mismatch')
        if derived.parent!=root or original.parent!=root/'original':raise ValueError('Wrong recovery graph location')
        expected.append(derived.name)
    if sorted(expected)!=[p.name for p in graph_paths(root)] or len(set(expected))!=len(expected):raise ValueError('Recovery graph set mismatch')
    if 'interface' in report:
        item=report['interface']
        if not isinstance(item,dict) or set(item)!={'path','sha256'} or sha(owned(item['path']).read_bytes())!=item['sha256']:raise ValueError('Recovery interface hash mismatch')
    # A checked bundle proves retention/hash continuity, not native conformance
    # or authenticity of an externally supplied demangler. Verify native calls.
    return {'verified':True,'manifestSHA256':sha(path.read_bytes()),'graphs':rows,'interface':report.get('interface'),'scope':'Retained original/derived artifact hashes only; native verification is separate.'}
