"""Explicit SDK-derived C callback conventions; development-time metadata only."""
import copy,gzip,hashlib,io,json,os,re,selectors,signal,stat,subprocess,sys,time
from dataclasses import replace
from pathlib import Path
from .platforms.ios_api import SDKCatalog
from .platforms.swift_types import parse_type
from .symbolgraph import graph_paths

MAX_GRAPH=128*1024*1024
MAX_AST=8*1024*1024
MAX_TOTAL=512*1024*1024

def sha(raw):return hashlib.sha256(raw).hexdigest()
def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
    return h.hexdigest()
def identifier(value):
    if not isinstance(value,str) or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',value):raise ValueError('Unsupported native identifier')
    return value

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


def capture(command, *, timeout=60):
    proc=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
    selector=selectors.DefaultSelector();selector.register(proc.stdout,selectors.EVENT_READ)
    chunks=[];size=0;deadline=time.monotonic()+timeout
    try:
        while True:
            if time.monotonic()>deadline:raise ValueError('Native AST extraction timed out')
            if not selector.select(0.2):continue
            chunk=os.read(proc.stdout.fileno(),65536)
            if not chunk:break
            size+=len(chunk)
            if size>MAX_AST:raise ValueError('Native AST output exceeds bound')
            chunks.append(chunk)
        result=b''.join(chunks).decode('utf-8')
        if proc.wait(timeout=1):raise ValueError('Native AST extraction failed: '+result[:2000])
        return result
    finally:
        selector.close();proc.stdout.close()
        # The driver may have spawned swift-frontend; own and stop the whole group.
        try:os.killpg(proc.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        proc.wait(timeout=5)

def declaration(ast,module,name,sdk):
    """Accept the actual declref, never a compiler-inserted conversion type."""
    if len(ast.encode())>MAX_AST:raise ValueError('AST exceeds bound')
    lines=[line for line in ast.splitlines() if re.match(r'\s*\(declref_expr\b',line)]
    if len(lines)!=1:raise ValueError('Expected exactly one direct native declaration reference')
    line=lines[0]
    fields={}
    for key in ['type','decl']:
        values=re.findall(r'\b'+key+r'=("(?:[^"\\]|\\.)*")',line)
        if len(values)!=1:raise ValueError('Unsupported AST declaration schema')
        fields[key]=json.loads(values[0])
    if 'function_ref=unapplied' not in line:raise ValueError('Unsupported applied AST reference')
    match=re.fullmatch(re.escape(module)+r'\.\(file\)\.'+re.escape(name)+r'(?:\([A-Za-z_0-9:]*\))?@(.+):(\d+):(\d+)',fields['decl'])
    if not match:raise ValueError('AST module or C function identity mismatch')
    header=Path(match[1]).resolve();sdk=Path(sdk).resolve()
    try:header.relative_to(sdk)
    except ValueError:raise ValueError('Native declaration is outside selected SDK')
    if header.suffix!='.h' or not header.is_file() or header.stat().st_size>MAX_GRAPH:raise ValueError('Unsupported SDK header')
    raw=header.read_bytes();lines=raw.splitlines();number=int(match[2]);column=int(match[3])
    if not 1<=number<=len(lines) or not 1<=column<=len(lines[number-1]):raise ValueError('Native C declaration header position is outside source')
    token=lines[number-1][column-1:]
    if (column>1 and (chr(lines[number-1][column-2]).isalnum() or lines[number-1][column-2]==95)) or not re.match(re.escape(name.encode())+rb'\s*\(',token):raise ValueError('Native C declaration does not match exact header token')
    return fields['type'],{'path':str(header),'sha256':sha(raw),'line':number,'column':column,'declaration':lines[number-1].decode('utf-8')}

def recover_types(api,native):
    actual=parse_type(native)
    if actual.name!='$function' or actual.optional or actual.attributes or actual.effects or actual.labels:raise ValueError('Unsupported outer C function type')
    if len(actual.arguments)!=len(api.parameters)+1 or actual.arguments[-1]!=parse_type(api.result):raise ValueError('Native arity or result differs')
    replacements={}
    for index,(param,found) in enumerate(zip(api.parameters,actual.arguments[:-1])):
        original=parse_type(param.type)
        if original==found:continue
        if original.name!='$function' or 'convention(c)' in original.attributes or found.name!='$function' or 'convention(c)' not in found.attributes:raise ValueError('Difference is not an outer C callback convention')
        stripped=replace(found,attributes=tuple(a for a in found.attributes if a!='convention(c)'))
        if stripped!=original:raise ValueError('Native callback differs beyond calling convention')
        # Preserve source spelling and its exact optional grouping.
        if original.optional:
            if not param.type.startswith('(') or not param.type.endswith(')?'):raise ValueError('Unsupported optional callback spelling')
            corrected='(@convention(c) '+param.type[1:]
        else:corrected='@convention(c) '+param.type
        if parse_type(corrected)!=found:raise ValueError('Recovered callback does not roundtrip')
        replacements[index]=corrected
    if not replacements:raise ValueError('No missing callback convention found')
    return replacements

def patch_parameter(fragments,old,new):
    text=''.join(f.get('spelling','') for f in fragments)
    if not text.endswith(old) or ':' not in text[:-len(old)]:raise ValueError('Parameter fragments do not match signature')
    insertion=1 if parse_type(old).optional else 0
    offset=len(text)-len(old)+insertion;result=copy.deepcopy(fragments);position=0
    for fragment in result:
        value=fragment.get('spelling','')
        if position<=offset<=position+len(value):
            at=offset-position;fragment['spelling']=value[:at]+'@convention(c) '+value[at:]
            if ''.join(f.get('spelling','') for f in result)!=text[:-len(old)]+new:raise ValueError('Callback patch changed structure')
            return result
        position+=len(value)
    raise ValueError('Missing insertion point')

def recover(graphs,module,identities,output,*,swiftc,sdk,target):
    identifier(module);sdk=Path(sdk).resolve();swiftc=Path(swiftc).resolve();output=Path(output)
    output=output.absolute();reject_symlinks(output)
    if output.exists():raise ValueError('Recovery requires fresh output')
    if not isinstance(identities,(list,tuple)) or not 1<=len(identities)<=16 or len(set(identities))!=len(identities):raise ValueError('Recovery requires1..16 unique identities')
    names={}
    for identity in identities:
        if not isinstance(identity,str) or not re.fullmatch(r'c:@F@[A-Za-z_][A-Za-z_0-9]*',identity):raise ValueError('Only simple global external C function USRs supported')
        names[identity]=identity[5:]
    if not re.fullmatch(r'arm64-apple-ios[0-9]+(?:\.[0-9]+){0,2}-simulator',target):raise ValueError('Unsupported native target')
    paths=graph_paths(graphs)
    if not 1<=len(paths)<=256:raise ValueError('Invalid SDK graph set')
    snapshots={str(p.resolve()):digest(p) for p in paths}
    documents=[];raw_snapshots=[];total=0;expanded_total=0
    from .frontends import unique_object
    for path in paths:
        if path.stat().st_size>MAX_GRAPH:raise ValueError('Graph exceeds bound')
        encoded=path.read_bytes()
        if sha(encoded)!=snapshots[str(path.resolve())]:raise ValueError('Graph changed before snapshot retention')
        total+=len(encoded)
        if total>MAX_TOTAL:raise ValueError('Graph snapshots exceed total bound')
        with (gzip.GzipFile(fileobj=io.BytesIO(encoded)) if path.suffix=='.gz' else io.BytesIO(encoded)) as f:raw=f.read(MAX_GRAPH+1)
        if len(raw)>MAX_GRAPH:raise ValueError('Expanded graph exceeds bound')
        expanded_total+=len(raw)
        if expanded_total>MAX_TOTAL:raise ValueError('Expanded graph snapshots exceed total bound')
        raw_snapshots.append(encoded);documents.append(json.loads(raw,object_pairs_hook=unique_object))
    reject_symlinks(output);output.mkdir(parents=True);(output/'original').mkdir();(output/'evidence').mkdir()
    retained=[]
    for index,(path,encoded) in enumerate(zip(paths,raw_snapshots)):
        original=output/'original'/(str(index)+'-'+path.name);original.write_bytes(encoded);retained.append(original)
    catalog=SDKCatalog.from_symbolgraphs(retained,module)
    for identity,name in names.items():
        api=catalog.get(identity)
        if api.kind!='function' or api.module!=module or len(api.path)!=1 or api.path[0].partition('(')[0]!=name:raise ValueError('Graph is not the requested unambiguous global C function')
        if any(p.inout or p.autoclosure for p in api.parameters):raise ValueError('Unsupported parameter semantics')
    from .ios_verification import compiler_sources
    frontend=swiftc.parent/'swift-frontend'
    if not frontend.is_file():raise ValueError('Missing native Swift frontend executable')
    provenance={'swiftFrontend':str(frontend),'swiftFrontendSHA256':digest(frontend),'swiftc':str(swiftc),'swiftcSHA256':digest(swiftc),'swiftVersion':capture([str(swiftc),'--version']),'sdk':str(sdk),'sdkSettingsSHA256':digest(sdk/'SDKSettings.json'),'target':target,'compilerSources':compiler_sources(),'recoverySHA256':digest(__file__),'inputGraphs':snapshots}
    replacements={};changes=[]
    for index,(identity,name) in enumerate(names.items()):
        probe=output/'evidence'/('probe'+str(index)+'.swift');probe.write_text('import '+module+'\nlet inspectCallback = '+name+'\n')
        command=[str(swiftc),'-dump-ast','-module-name','DCCallbackProbe','-swift-version','6','-sdk',str(sdk),'-target',target,'-module-cache-path',str(output/'cache'),str(probe)]
        ast=capture(command);astpath=probe.with_suffix('.ast');astpath.write_text(ast)
        native,header=declaration(ast,module,name,sdk);types=recover_types(catalog.get(identity),native);replacements[identity]=types
        changes.append({'id':identity,'nativeType':native,'parameters':types,'header':header,'probe':str(probe.relative_to(output)),'probeSHA256':digest(probe),'ast':str(astpath.relative_to(output)),'astSHA256':digest(astpath),'command':command})
    graphrows=[]
    for index,(path,document) in enumerate(zip(paths,documents)):
        for symbol in document.get('symbols',[]):
            identity=symbol.get('identifier',{}).get('precise')
            if identity not in replacements:continue
            api=catalog.get(identity);params=symbol.get('functionSignature',{}).get('parameters',[])
            if len(params)!=len(api.parameters):raise ValueError('Duplicate symbol signature mismatch')
            for i,new in replacements[identity].items():params[i]['declarationFragments']=patch_parameter(params[i]['declarationFragments'],api.parameters[i].type,new)
        original=retained[index]
        if digest(original)!=snapshots[str(path.resolve())]:raise ValueError('Retained original graph changed')
        derived=output/(str(index)+'.symbols.json');derived.write_text(json.dumps(document,separators=(',',':'))+'\n')
        graphrows.append({'original':str(original.relative_to(output)),'originalSHA256':digest(original),'derived':derived.name,'derivedSHA256':digest(derived)})
    after=SDKCatalog.from_symbolgraphs(graph_paths(output),module)
    if set(after.apis)!=set(catalog.apis):raise ValueError('Recovery changed identities')
    for identity,api in catalog.apis.items():
        params=tuple(replace(p,type=replacements.get(identity,{}).get(i,p.type)) for i,p in enumerate(api.parameters))
        if after.get(identity)!=replace(api,parameters=params):raise ValueError('Recovery changed unrelated API metadata: '+identity)
    if snapshots!={str(p.resolve()):digest(p) for p in graph_paths(graphs)} or digest(swiftc)!=provenance['swiftcSHA256'] or digest(sdk/'SDKSettings.json')!=provenance['sdkSettingsSHA256'] or digest(frontend)!=provenance['swiftFrontendSHA256'] or compiler_sources()!=provenance['compilerSources']:raise ValueError('Native recovery inputs changed')
    if any(digest(row['header']['path'])!=row['header']['sha256'] for row in changes):raise ValueError('SDK header changed')
    report={'kind':'dcflight.c-callback-convention.v1','provenance':provenance,'graphs':graphrows,'changes':changes,'scope':'Explicit version-bound AST derived metadata only; no native call executed and no conformance promotion.'}
    (output/'recovery.json').write_text(json.dumps(report,indent=2)+'\n');return report
