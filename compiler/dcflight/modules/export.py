"""Inspect hash-locked JVM bytecode; never execute dependency code or builds."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile
import zipfile
from .resolve import verify
from ..catalog import Catalog
from ..native_api import snapshot_android_source
from ..platforms.android_api import AndroidAPI, _safe_type

MAX_EXPANDED = 512 * 1024 * 1024
MAX_ENTRIES = 100000
MAX_CLASSES = 30000


def _entries(archive):
    entries=archive.infolist()
    if len(entries)>MAX_ENTRIES or sum(x.file_size for x in entries)>MAX_EXPANDED:
        raise ValueError('Module archive exceeds expansion limits')
    names=set()
    for item in entries:
        p=PurePosixPath(item.filename)
        if p.is_absolute() or '..' in p.parts or '\\' in item.filename or item.filename in names:
            raise ValueError('Unsafe or duplicate module archive path')
        names.add(item.filename)
        if item.file_size>MAX_EXPANDED or (item.compress_size and item.file_size/item.compress_size>1000):
            raise ValueError('Module archive compression limit exceeded')
    return entries


def _convert(output, bridges=(), inner_classes=None, *, jvm_descriptors=None, jvm_bindings=None, declaration_bindings=None):
    """Retain native declarations; free type variables remain explicitly unsupported."""
    blocks=[]; skipped=[]; current=None
    for line in output.splitlines():
        line=line.strip()
        if not line or line.startswith('Compiled from '): continue
        match=re.match(r'(.*?)\b(class|interface|enum)\s+([\w.$]+)(.*)\{$',line)
        if match:
            binary=match[3]; package,_,name=binary.rpartition('.')
            if not package:
                skipped.append({'declaration':line,'reason':'Default-package types cannot be emitted into packaged applications'});current=None;continue
            name=name.replace('$','.')
            if not _safe_type(package+'.'+name):
                skipped.append({'declaration':line,'reason':'Anonymous or unsupported source class name'});current=None;continue
            header=match[1]+match[2]+' '+name+match[4].replace('$','.')+'{'
            current={'package':package,'binary':binary,'name':name,'header':header,'members':[],'originals':{}};blocks.append(current)
        elif line=='}': current=None
        elif current and line.endswith(';'):
            if (current['binary'],line) in bridges:
                skipped.append({'declaration':line,'reason':'Compiler-generated JVM bridge method'})
                continue
            declaration=line.replace('$','.')
            ctor=re.match(r'((?:public|protected)\s+)(?:<[^>]+>\s+)?'+re.escape(current['binary'].replace('$','.'))+r'\(',declaration)
            if ctor:
                declaration=declaration.replace(current['binary'].replace('$','.')+'(',current['name'].rsplit('.',1)[-1]+'(',1);kind='ctor'
            else: kind='method' if '(' in declaration else 'field'
            current['members'].append(kind+' '+declaration)
            current['originals'][kind+' '+declaration]=line
        else: skipped.append({'declaration':line,'reason':'Unsupported javap declaration'})
    # A nested declaration's access/static flags belong to InnerClasses, not
    # the class-file ACC_* flags printed in javap's ordinary declaration.
    # Require its own verified entry and every enclosing class to be public.
    if inner_classes is not None:
        by_binary = {block['binary']: block for block in blocks}
        def accessible(binary, seen=()):
            if len(seen) >= 32 or binary in seen or binary not in by_binary:
                return False
            block = by_binary[binary]
            if 'public' not in block['header'].split():
                return False
            if '$' not in binary:
                return True
            entry = inner_classes.get(binary)
            return bool(entry and 'public' in entry[1]
                        and accessible(entry[0], (*seen, binary)))
        public_owners = {binary for binary in by_binary if accessible(binary)}
        for block in blocks:
            binary = block['binary']
            if '$' not in binary:
                continue
            entry = inner_classes.get(binary)
            if binary not in public_owners:
                block['header'] = re.sub(r'\bpublic\s+', '', block['header'])
                skipped.append({'declaration': binary,
                                'reason': 'Nested class or enclosing class is not verified public'})
            if entry and 'static' in entry[1]:
                block['header'] = 'static ' + block['header']
    rendered=[]
    for block in blocks:
        prefix='package '+block['package']+' {\n'+block['header']+'\n'
        # Covariant bridge methods share Java call identities. Preserve both in the
        # unsupported report rather than silently selecting an erased signature.
        by_id={};bad=[]
        for member in block['members']:
            parsed=AndroidAPI(prefix+member+'\n}\n}\n')
            if len(parsed.members)!=1:
                skipped.append({'declaration':member,'reason':'Unsupported metalava conversion'});continue
            identity=next(iter(parsed.members))
            if declaration_bindings is not None and jvm_descriptors is not None:
                desc=jvm_descriptors.get((block['binary'],block['originals'][member]))
                if desc is not None:
                    actual=parsed.members[identity]
                    binding=(block['binary'].replace('.','/'),'method' if actual.kind in ('method','ctor') else 'field','<init>' if actual.kind=='ctor' else actual.name,desc)
                    declaration_bindings.setdefault((identity,actual.declaration),set()).add(binding)
            by_id.setdefault(identity,[]).append(member)
        for identity, members in by_id.items():
            if len(members)>1:
                skipped.extend({'declaration':m,'reason':'Ambiguous JVM bridge/covariant signature: '+identity} for m in members)
            else:
                bad.append(members[0])
                if jvm_bindings is not None and jvm_descriptors is not None:
                    desc=jvm_descriptors.get((block['binary'],block['originals'][members[0]]))
                    if desc is not None:
                        parsed=AndroidAPI(prefix+members[0]+'\n}\n}\n');member=next(iter(parsed.members.values()))
                        jvm_bindings[identity]={'owner':block['binary'].replace('.','/'),'kind':'method' if member.kind in ('method','ctor') else 'field','name':'<init>' if member.kind=='ctor' else member.name,'descriptor':desc}
        rendered.append(prefix+'\n'.join(bad)+'\n}\n}\n')
    return '\n'.join(rendered),skipped


def _bridge_declarations(verbose):
    """Read ACC_BRIDGE from javap's class-file flags, not overload heuristics."""
    owner=None;declaration=None;result=set()
    for line in verbose.splitlines():
        if line.startswith('Classfile '):owner=None;declaration=None
        match=re.match(r'^.*?\b(?:class|interface|enum)\s+([\w.$]+)',line) if line and not line[0].isspace() else None
        if match:owner=match[1]
        if line.startswith('  ') and not line.startswith('    ') and line.rstrip().endswith(';'):
            declaration=line.strip()
        elif line.strip().startswith('flags:') and 'ACC_BRIDGE' in line and owner and declaration:
            result.add((owner,declaration))
    return result


def _inner_class_declarations(verbose):
    """Read only a class's own InnerClasses entry from exact-file javap output."""
    owner = None
    in_inner_classes = False
    result = {}
    for line in verbose.splitlines():
        if line.startswith('Classfile '):
            owner = None
            in_inner_classes = False
        match = re.match(r'^.*?\b(?:class|interface|enum)\s+([\w.$]+)', line) if line and not line[0].isspace() else None
        if match:
            owner = match[1]
        if line == 'InnerClasses:':
            in_inner_classes = True
            continue
        if line and not line[0].isspace():
            in_inner_classes = False
        if not in_inner_classes or owner is None:
            continue
        entry = re.fullmatch(r'\s*((?:(?:public|private|protected|static|final|abstract|interface|synthetic|annotation|enum)\s+)*)'
                             r'#\d+\s*=\s*#\d+\s+of\s+#\d+;\s*//\s*([\w$]+)=class\s+([\w/$]+)\s+of\s+class\s+([\w/$]+)\s*', line)
        if not entry:
            continue
        binary, outer = entry[3].replace('/', '.'), entry[4].replace('/', '.')
        if binary != owner or binary != outer + '$' + entry[2]:
            continue
        value = (outer, tuple(entry[1].split()))
        if binary in result and result[binary] != value:
            raise ValueError('Conflicting JVM InnerClasses metadata: ' + binary)
        result[binary] = value
    return result


def export_android(lock, catalog, *, javap='javap', sdk=35):
    lock=Path(lock).resolve();data=verify(lock)
    if data['module']['platform']!='android': raise ValueError('Android bytecode export requires an Android module')
    return _export_bytecode(lock.parent,data['artifacts'],catalog,javap=javap,sdk=sdk,
        scope='module:'+data['module']['id']+':'+data['module']['revision'],
        origin={'nativeModule':data['module'],'lockSha256':hashlib.sha256(lock.read_bytes()).hexdigest()})


def index_android_core(archive,catalog,*,javap='javap',sdk=35):
    """Inspect the supplied Android SDK's core classes; never bundle the SDK JAR."""
    if type(sdk) is not int or sdk<1:raise ValueError('SDK level must be a positive integer')
    archive=Path(archive).resolve()
    if archive.suffix!='.jar':raise ValueError('Android SDK archive must be a JAR')
    from .manifest import digest
    fingerprint=digest(archive)
    return _export_bytecode(archive.parent,[{'path':archive.name,'sha256':fingerprint}],catalog,javap=javap,sdk=sdk,
        scope='core-bytecode',origin={'sdkArchiveSha256':fingerprint,'sdkArchiveName':archive.name,
        'dependencyKind':'platform-sdk','namespaces':['java','javax','org.w3c.dom','org.xml.sax']},
        prefixes=('java.','javax.','org.w3c.dom.','org.xml.sax.'))


def index_android_sdk(archive,catalog,*,javap='javap',sdk=None,api_versions=None):
    """Inspect all SDK stub classes; this platform archive is never a runtime module."""
    archive=Path(archive).resolve()
    if archive.name!='android.jar':raise ValueError('Expected the platform android.jar')
    properties=archive.parent/'source.properties'
    if not properties.is_file() or properties.stat().st_size>65536:raise ValueError('Missing bounded SDK source.properties')
    raw=properties.read_bytes();values={}
    for line in raw.decode('utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):continue
        key,separator,value=line.partition('=')
        if not separator or key in values:raise ValueError('Malformed or duplicate SDK property')
        values[key]=value.strip()
    identity=values.get('AndroidVersion.ApiLevel','')
    if not re.fullmatch(r'[1-9][0-9]*',identity):raise ValueError('Minor or unknown Android SDK versions are not yet supported: '+identity)
    level=int(identity)
    if sdk is not None and (type(sdk) is not int or sdk!=level):raise ValueError('Requested SDK differs from platform metadata')
    if values.get('AndroidVersion.IsBaseSdk')!='true' or values.get('AndroidVersion.CodeName','') or values.get('Platform.CodeName','') or values.get('AndroidVersion.PreviewSdkInt','0')!='0' or values.get('AndroidVersion.BetaVersion',''):
        raise ValueError('Only identified non-preview base platform SDKs are supported')
    from .manifest import digest
    availability=None
    if api_versions is not None:
        from ..android_api_versions import APIVersions,read_api_versions
        xml_bytes=read_api_versions(api_versions)
        availability=(APIVersions(xml_bytes),xml_bytes)
    fingerprint=digest(archive)
    return _export_bytecode(archive.parent,[{'path':archive.name,'sha256':fingerprint}],catalog,javap=javap,sdk=level,availability=availability,
        scope='sdk-bytecode:'+identity,origin={'sdkArchiveSha256':fingerprint,'sdkArchiveName':archive.name,
        'dependencyKind':'platform-sdk','classSelection':'all archive classes; public callable validation remains fail-closed',
        'sdkIdentity':identity,'sdkProperties':values,'sdkPropertiesSha256':hashlib.sha256(raw).hexdigest(),
        'availabilityMetadata':'Bytecode signatures only; minimum API, permissions, flags, nullability and thread annotations not recovered'})


def _export_bytecode(source_root,artifact_records,catalog,*,javap,sdk,scope,origin,prefixes=(),availability=None):
    version=subprocess.run([str(javap),'-version'],capture_output=True,text=True,check=True,timeout=15).stdout.strip()
    artifacts=[];total=0;classes={};ignored=[]
    with tempfile.TemporaryDirectory(prefix='dcflight-bytecode-') as temp:
        jars=[];class_files={}
        for artifact in artifact_records:
            source=source_root/artifact['path']
            if source.suffix not in ('.aar','.jar'):
                ignored.append({'path':artifact['path'],'reason':'No JVM bytecode archive'});continue
            if artifact['sha256'] in artifacts:continue
            artifacts.append(artifact['sha256'])
            if source.stat().st_size>MAX_EXPANDED:raise ValueError('Module archive file size exceeds limit')
            archive_bytes=source.read_bytes()
            if len(archive_bytes)>MAX_EXPANDED or hashlib.sha256(archive_bytes).hexdigest()!=artifact['sha256']:
                raise ValueError('Archive changed during inspection')
            with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
                entries=_entries(archive)
                if source.suffix=='.jar': contents=[archive_bytes]
                else: contents=[archive.read(x) for x in entries if x.filename=='classes.jar' or (x.filename.startswith('libs/') and x.filename.endswith('.jar'))]
            for content in contents:
                total+=len(content)
                if total>MAX_EXPANDED: raise ValueError('Module aggregate expansion limit exceeded')
                path=Path(temp)/f'{len(jars)}.jar';path.write_bytes(content);jars.append(path)
                with zipfile.ZipFile(io.BytesIO(content)) as jar:
                    entries=_entries(jar)
                    total+=sum(x.file_size for x in entries)
                    if total>MAX_EXPANDED: raise ValueError('Module aggregate expansion limit exceeded')
                    for item in entries:
                        if not item.filename.endswith('.class') or item.filename.startswith('META-INF/'):continue
                        name=item.filename[:-6].replace('/','.')
                        if name.endswith(('module-info','package-info')):continue
                        if prefixes and not name.startswith(prefixes):continue
                        if not re.fullmatch(r'[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*',name):
                            ignored.append({'path':item.filename,'reason':'Unsupported Java binary name'});continue
                        bytecode=jar.read(item)
                        fingerprint=hashlib.sha256(bytecode).hexdigest()
                        if name in classes and classes[name]!=fingerprint:raise ValueError('Conflicting class definitions: '+name)
                        if name not in classes:
                            exact=Path(temp)/('class'+str(len(classes))+'.class')
                            exact.write_bytes(bytecode)
                            class_files[name]=exact
                        classes[name]=fingerprint
                        if len(classes)>MAX_CLASSES:raise ValueError('Module class count limit exceeded')
        if not classes:raise ValueError('Module contains no exportable JVM classes')
        outputs=[];names=sorted(classes);bridges=set();inner_classes={};jvm_descriptors={};jvm_bindings={};signature_outputs=[];signature_bytes=0
        for offset in range(0,len(names),80):
            output=Path(temp)/'batch.txt';errors=Path(temp)/'errors.txt'
            with output.open('w') as stdout, errors.open('w') as stderr:
                result=subprocess.run([str(javap),'-public',*(['-s'] if availability is not None else []),*[str(class_files[name]) for name in names[offset:offset+80]]],stdout=stdout,stderr=stderr,text=True,timeout=120)
            if result.returncode:
                with errors.open() as stream: detail=stream.read(2000)
                raise ValueError('javap inspection failed: '+detail)
            if output.stat().st_size>32*1024*1024:raise ValueError('javap declaration batch exceeds limit')
            text=output.read_text()
            if availability is not None:
                signature_bytes+=len(text.encode('utf-8'))
                if signature_bytes>128*1024*1024:raise ValueError('JVM signature snapshot exceeds bound')
                signature_outputs.append(text)
                from ..android_api_versions import declaration_descriptors
                batch_descriptors=declaration_descriptors(text)
                if set(jvm_descriptors)&set(batch_descriptors):raise ValueError('Duplicate JVM declaration binding')
                jvm_descriptors.update(batch_descriptors)
                text='\n'.join(line for line in text.split('\n') if not line.startswith('    descriptor:'))
            inspected=re.findall(r'^.*?\b(?:class|interface|enum)\s+([\w.$]+)[^\n]*\{\s*$',text,re.MULTILINE)
            if sorted(inspected)!=sorted(names[offset:offset+80]):
                raise ValueError('Class bytecode identity differs from its locked archive entry')
            outputs.append(text)
            verbose=Path(temp)/'verbose.txt'
            with verbose.open('w') as stream:
                detail=subprocess.run([str(javap),'-public','-v',*[str(class_files[name]) for name in names[offset:offset+80]]],stdout=stream,stderr=subprocess.PIPE,text=True,timeout=120)
            if detail.returncode or verbose.stat().st_size>32*1024*1024:
                raise ValueError('Cannot inspect bounded JVM member flags')
            verbose_text = verbose.read_text()
            bridges.update(_bridge_declarations(verbose_text))
            inner_classes.update(_inner_class_declarations(verbose_text))
            if sum(map(len,outputs))>128*1024*1024:raise ValueError('javap declaration output exceeds limit')
        native='\n'.join(outputs)
        text,skipped=_convert(native,bridges,inner_classes,jvm_descriptors=jvm_descriptors if availability else None,jvm_bindings=jvm_bindings if availability else None);api=AndroidAPI(text,api_level=sdk)
        records=api.records();availability_provenance={}
        if availability is not None:
            table,xml_bytes=availability;matched=0
            for record in records:
                identity=jvm_bindings.get(record['id'])
                facts=table.lookup(**identity) if identity else None
                if facts is not None:
                    record['availability'].update(facts);matched+=1
            signatures_path=Path(temp)/'jvm-signatures.txt';signatures_path.write_text('\n'.join(signature_outputs))
            signatures_snapshot=snapshot_android_source(catalog,signatures_path)
            xml_path=Path(temp)/'api-versions.xml';xml_path.write_bytes(xml_bytes)
            xml_snapshot=snapshot_android_source(catalog,xml_path)
            availability_provenance={'availabilityJvmSignatures':signatures_snapshot,'availabilityXml':xml_snapshot,'availabilityXmlSHA256':table.sha256,'availabilityExactMatches':matched,'availabilityJvmBindings':len(jvm_bindings),'availabilityJvmDescriptorMode':'javap-public-signatures','availabilityUnknownMembers':len(records)-matched,'availabilityMetadata':'Exact schema3 JVM identities; permissions, flags, thread and nullability remain unknown'}
        if not any(r['emittable'] for r in records):raise ValueError('Module has no supported public callable/field signatures')
        source=Path(temp)/'api.txt';source.write_text(text)
        snapshot=snapshot_android_source(catalog,source)
        raw=Path(temp)/'javap.txt';raw.write_text(native)
        raw_snapshot=snapshot_android_source(catalog,raw)
        provenance={**snapshot,**origin,**availability_provenance,'parser':'javap-exact-bytecode-to-metalava-v4','bridgeMethodsExcluded':len(bridges),'innerClassEntriesVerified':len(inner_classes),'classResolution':'exact-verified-class-files','javapVersion':version,'rawJavapRelativePath':raw_snapshot['sourceRelativePath'],'artifactSha256':artifacts,'javapOutputSha256':hashlib.sha256(native.encode()).hexdigest(),'classCount':len(classes),'statistics':api.stats(),'unsupportedDeclarations':skipped+ignored,'compiled':False,'executed':False}
        with Catalog(catalog,write=True) as target:
            imported=target.import_records('android',scope,str(sdk),records,provenance)
        return {**imported,'classesInspected':len(classes),'emittable':sum(r['emittable'] for r in records),'unsupportedDeclarations':len(skipped)+len(ignored),'compiled':False,'executed':False,'provenance':provenance}
