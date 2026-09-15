"""Copy verified native package artifacts into ordinary, self-contained projects."""
import hashlib
import json
from pathlib import Path
import re
import zipfile
from ..backends import Artifact
from .resolve import verify


def generate_modules(app, source, targets, artifacts):
    evidence=[];android_files={};native_libraries={};permissions=set();replaced_maven={};dependency_versions={}
    for ref in app.modules:
        if ref.platform not in targets:continue
        path=(Path(source).resolve().parent/ref.lock).resolve()
        lock=verify(path);module=lock['module']
        if (module['id'],module['platform'])!=(ref.id,ref.platform):raise ValueError('Native module reference differs from lock')
        if ref.platform!='android':raise ValueError('SPM project integration is not yet implemented; use a user-owned native project dependency')
        if lock['verification'].get('resolved') is not True:raise ValueError('Native module has not resolved runtime dependencies')
        permissions.update(module['permissions'])
        aligned=lock.get('resolutionContext') == {'kind':'androidRuntimeClasspath','configuration':'debugRuntimeClasspath','localArtifactsReplaceMaven':True}
        if 'resolutionContext' in lock and not aligned:raise ValueError('Unsupported native module resolution context')
        for item in lock['artifacts']:
            file=path.parent/item['path']
            if file.suffix not in ('.jar','.aar') or item.get('classifier') in ('sources','javadoc'):raise ValueError('Module lock must contain native runtime AAR/JAR artifacts')
            coordinate=item['coordinate']
            if not isinstance(coordinate,str) or not re.fullmatch(r'[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+',coordinate):raise ValueError('Invalid locked Maven coordinate')
            group,name,version=coordinate.split(':')
            identity=(group,name)
            if identity in dependency_versions and dependency_versions[identity]!=version:raise ValueError('Native modules need a jointly aligned dependency lock: '+group+':'+name)
            dependency_versions[identity]=version
            if aligned:
                identity=(group,name)
                if identity in replaced_maven and replaced_maven[identity]!=version:raise ValueError('Conflicting aligned native dependency versions: '+group+':'+name)
                replaced_maven[identity]=version
            previous=android_files.get(coordinate)
            if previous:
                if previous[1]!=item['sha256']:raise ValueError('Conflicting native dependency: '+coordinate)
                continue
            name=item['sha256'][:16]+'-'+file.name
            if not re.fullmatch(r'[A-Za-z0-9_.-]+',name):raise ValueError('Unsafe artifact filename')
            relative='android/app/libs/'+name
            artifacts[relative]=Artifact(file.read_bytes())
            android_files[coordinate]=(name,item['sha256'])
            if file.suffix=='.aar':
                from .export import _entries
                with zipfile.ZipFile(file) as archive:
                    for entry in _entries(archive):
                        if not re.fullmatch(r'jni/(arm64-v8a|armeabi-v7a|x86|x86_64)/lib[A-Za-z0-9_.-]+\.so',entry.filename):continue
                        if app.logic and not entry.filename.startswith('jni/arm64-v8a/'):continue
                        if entry.file_size>256*1024*1024:raise ValueError('Oversized native module library')
                        library='lib/'+entry.filename[4:]
                        digest=hashlib.sha256(archive.read(entry)).hexdigest()
                        if library in native_libraries and native_libraries[library]!=digest:raise ValueError('Conflicting native library: '+library)
                        native_libraries[library]=digest
        evidence.append({'module':module,'lockSha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                         'artifacts':[{k:v for k,v in a.items() if k!='path'} for a in lock['artifacts']],
                         'verification':lock['verification']})
    if android_files:
        lines=['// Content-locked native dependencies. No compiler component is linked.','dependencies {']
        lines += ["    implementation files('libs/"+name+"')" for name,sha in sorted(android_files.values())]
        lines += ['}',"android { packaging { jniLibs { keepDebugSymbols += ['**/*.so'] } } }"]
        if replaced_maven:
            lines += ['// The entire compatible app runtime graph was content-locked together.',
                      '// Its verified local artifacts replace Maven copies of the same modules.',
                      "if (!providers.gradleProperty('nativeModuleRelock').isPresent()) {",
                      "configurations.matching { it.name.endsWith('CompileClasspath') || it.name.endsWith('RuntimeClasspath') }.configureEach {"]
            lines += ["    exclude group: '"+group+"', module: '"+name+"'" for group,name in sorted(replaced_maven)]
            lines += ['}', '}']
        if app.logic:
            lines.append("android { defaultConfig { ndk { abiFilters 'arm64-v8a' } } }")
        artifacts['android/app/native-modules.gradle']=Artifact('\n'.join(lines)+'\n')
        key='android/app/build.gradle';build=artifacts[key]
        artifacts[key]=Artifact(build.content+"\napply from: 'native-modules.gradle'\n",build.ownership)
        key='android/app/src/main/AndroidManifest.xml';manifest=artifacts[key]
        content=manifest.content
        for permission in sorted(permissions):
            if 'android:name="'+permission+'"' not in content:
                content,count=re.subn(r'(?=<application(?:\s|/?>))','<uses-permission android:name="'+permission+'"/>\n',content,count=1)
                if count!=1:raise ValueError('Android manifest has no application element for native module permissions')
        artifacts[key]=Artifact(content,manifest.ownership)
    if evidence:
        artifacts['.dcflight/modules.json']=Artifact(json.dumps({'modules':evidence,'nativeLibraries':native_libraries},indent=2,sort_keys=True)+'\n')
    return artifacts
