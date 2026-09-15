"""Bounded static dependency inspection; not an attestation against renamed code."""
import json,re,struct,os,stat
from pathlib import Path

FORBIDDEN=re.compile(r'\b(dcflight|flutter|flutter_zero|dart:ffi|libdart|DartVM|JavaScriptCore|WKWebView|android\.webkit|ReactNative|libhermes|yoga|FlutterEngine|DartExecutor|FlutterJNI|FlutterLoader|ReactNativeHost|ReactInstanceManager|HermesExecutor)\b',re.I)
IDENTITY=re.compile(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+')
MAX_SOURCE=16*1024*1024
MAX_DEX=128*1024*1024
MAX_STRINGS=1000000

def read_source(path):
    try: fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK|getattr(os,'O_NOFOLLOW',0))
    except OSError as error:raise ValueError('Unsafe source input') from error
    with os.fdopen(fd,'rb') as stream:
        info=os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size>MAX_SOURCE:raise ValueError('Nonregular/oversized audit input')
        data=stream.read(MAX_SOURCE+1)
        if len(data)>MAX_SOURCE:raise ValueError('Audit input grew beyond bound')
    return data.decode('utf8')

def application_identity(root):
    path=Path(root)/'.dcflight/source.json'
    if not path.is_file():return None
    from .frontends import unique_object
    value=json.loads(read_source(path),object_pairs_hook=unique_object).get('appId')
    if not isinstance(value,str) or not IDENTITY.fullmatch(value):raise ValueError('Invalid source application identity')
    return value

def _self_name(value,app_id):
    return bool(app_id and (value==app_id or value.startswith(app_id+'.')))

def source_reference(text,suffix,app_id=None):
    """Exclude declaration/data positions, preserving dependency/dynamic strings."""
    if re.search(r'(?:loadLibrary|dlopen|NSClassFromString|forName)\s*\(\s*[\"\'](?:dart|hermes|jsc|v8)[\"\']',text):return True
    # Parse only metadata value positions that carry the application's own identity/name.
    if suffix=='.plist':
        import plistlib
        data=plistlib.loads(text.encode())
        if isinstance(data,dict):
            for key in ('CFBundleIdentifier','CFBundleName','CFBundleDisplayName'):
                if key=='CFBundleIdentifier' and data.get(key) not in (app_id,'$(PRODUCT_BUNDLE_IDENTIFIER)'):continue
                data.pop(key,None)
            text=repr(data)
    elif suffix=='.xml':
        import xml.etree.ElementTree as ET
        node=ET.fromstring(text)
        if node.tag=='resources':
            for child in list(node):
                if child.tag=='string' and child.attrib.get('name')in ('app_name','native_app_name'):node.remove(child)
        if app_id and node.tag=='manifest' and node.attrib.get('package')==app_id:node.attrib.pop('package')
        text=ET.tostring(node,encoding='unicode')
    # Mask comments and tokenize strings; strings in dependency/loading positions
    # remain inspected. Ordinary UI display text is a data position.
    token=re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
    chunks=[];position=0
    for match in token.finditer(text):
        chunks.append(text[position:match.start()]);raw=match.group();before=text[max(0,match.start()-100):match.start()]
        if raw.startswith(('//','/*')):replacement=' '
        else:
            value=raw[1:-1]
            identity_field=re.search(r'(?:\bnamespace|\bapplicationId|\bPRODUCT_BUNDLE_IDENTIFIER)\s*(?:=\s*)?$',before)
            ui_data=re.search(r'(?:\bText|\bsetText|\.navigationTitle)\s*\(\s*$',before)
            plain_literal='\\(' not in value and '$' not in value
            replacement='""' if plain_literal and ((identity_field and value==app_id) or ui_data) else raw
        chunks.append(replacement);position=match.end()
    chunks.append(text[position:]);scanned=''.join(chunks)
    if app_id and not app_id.startswith(('dcflight','io.flutter','com.facebook.react','com.facebook.hermes')):
        # Language package/import/qualified type identifiers are outside literals.
        # Do not rewrite coordinates, loader names or other dependency strings.
        string=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
        parts=[];end=0
        def own_code(s):
            s=re.sub(r'(?<![\w.])'+re.escape(app_id)+r'(?=\b)', '__APPLICATION_ID__',s)
            return s
        for m in string.finditer(scanned):parts.extend((own_code(scanned[end:m.start()]),m.group()));end=m.end()
        parts.append(own_code(scanned[end:]));scanned=''.join(parts)
    return bool(FORBIDDEN.search(scanned))

def dex_references(data,application_id=None):
    """Inspect class definitions, type references, and engine-like dynamic strings.

    String constants are not automatically runtime dependencies. Unknown reflection,
    obfuscation, native behavior and renamed engines require build/runtime inspection.
    """
    if application_id is not None and (not isinstance(application_id,str) or not IDENTITY.fullmatch(application_id)):
        raise ValueError('Invalid APK application identity')
    if len(data)>MAX_DEX or len(data)<112 or not re.fullmatch(b'dex\n0(?:3[5-9]|4[01])\x00',data[:8]):raise ValueError('Unsupported or oversized DEX')
    u32=lambda offset:struct.unpack_from('<I',data,offset)[0]
    if u32(32)!=len(data) or u32(36)!=112 or u32(40)!=0x12345678:raise ValueError('Invalid DEX header')
    def table(count_offset,width):
        count=u32(count_offset);offset=u32(count_offset+4)
        if count>MAX_STRINGS or (count and offset<112) or offset+count*width>len(data):raise ValueError('DEX table exceeds bounds')
        return count,offset
    ns,so=table(56,4);nt,to=table(64,4);nc,co=table(96,32)
    strings=[];string_bytes=0
    for i in range(ns):
        offset=u32(so+i*4)
        if offset<112 or offset>=len(data):raise ValueError('Invalid DEX string offset')
        for n in range(5):
            if offset>=len(data):raise ValueError('Truncated DEX string length')
            byte=data[offset];offset+=1
            if not byte&128:break
        else:raise ValueError('Invalid DEX string length')
        end=data.find(b'\0',offset,min(len(data),offset+1024*1024+1))
        if end<0:raise ValueError('Oversized or unterminated DEX string')
        string_bytes+=end-offset
        if string_bytes>MAX_DEX:raise ValueError('DEX decoded string bytes exceed bound')
        strings.append(data[offset:end].decode('utf8',errors='replace'))
    types=[]
    for i in range(nt):
        index=u32(to+i*4)
        if index>=ns:raise ValueError('Invalid DEX type index')
        types.append(strings[index])
    defined=[]
    for i in range(nc):
        index=u32(co+i*32)
        if index>=nt:raise ValueError('Invalid DEX class index')
        defined.append(types[index])
    def forbidden_type(value):
        value=value.lstrip('[')
        if value.startswith('L') and value.endswith(';'):value=value[1:-1].replace('/','.')
        value=value.replace('/','.')
        if re.search(r'^(dcflight|io\.flutter|com\.facebook\.(react|hermes)|org\.mozilla\.javascript|com\.eclipsesource\.v8)(\.|$)',value,re.I):return True
        if _self_name(value,application_id):value=value[len(application_id):]
        return bool(FORBIDDEN.search(value) or re.search(r'^(dcflight|io\.flutter|com\.facebook\.(react|hermes)|org\.mozilla\.javascript|com\.eclipsesource\.v8)(\.|$)',value,re.I))
    platform_web={v for v in types if v.lstrip('[').startswith('Landroid/webkit/')}
    bad_types=sorted({v for v in types if forbidden_type(v) and (v not in platform_web or v in defined)})
    # Exact module/class/library spellings can drive reflection or dynamic loading.
    # Prose such as "DCFlight Device QA" does not name a runtime artifact.
    dynamic=[];type_set=set(types)
    for value in strings:
        if value in type_set:continue
        if re.fullmatch(r'[A-Za-z_$][A-Za-z0-9_.$/:;-]*',value) and forbidden_type(value):dynamic.append(value)
    return {'definedClasses':len(defined),'referencedTypes':len(types),'prohibitedTypes':bad_types,'dynamicRuntimeNames':sorted(set(dynamic)),'platformWebTypeReferences':sorted(platform_web),'scope':'DEX defined/referenced types and recognizable dynamic runtime names; arbitrary reflection, obfuscation and renamed engines are not certified.'}
