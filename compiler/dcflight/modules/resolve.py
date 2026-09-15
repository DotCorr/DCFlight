"""Resolve through native package tools, then content-lock every binary artifact."""
from dataclasses import asdict
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
from .manifest import read_manifest,digest


def install(manifest, destination, *, gradle='gradle', java_home=None, android_project=None):
    m=read_manifest(manifest);dest=Path(destination).resolve()
    if android_project is not None and m.platform != 'android':raise ValueError('Android resolution context requires an Android module')
    if dest.exists():raise ValueError('Module destination exists; verify its lock or choose a new directory')
    dest.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='dcflight-module-',dir=dest.parent) as tmp:
        stage=Path(tmp);artifacts=[]
        if m.platform=='android':
            env=os.environ.copy()
            if java_home:
                env['JAVA_HOME']=str(java_home);env['PATH']=str(Path(java_home)/'bin')+os.pathsep+env.get('PATH','')
            (stage/'settings.gradle').write_text("rootProject.name = 'NativeModuleLock'\n")
            # Values are restricted Maven identifiers, not arbitrary Groovy input.
            (stage/'build.gradle').write_text("plugins { id 'base' }\nrepositories { google(); mavenCentral() }\nconfigurations { nativeModule { attributes { attribute(org.gradle.api.attributes.Usage.USAGE_ATTRIBUTE, objects.named(org.gradle.api.attributes.Usage, 'java-runtime')); attribute(org.gradle.api.attributes.Category.CATEGORY_ATTRIBUTE, objects.named(org.gradle.api.attributes.Category, 'library')) } } }\ndependencies { nativeModule '"+m.package+":"+m.revision+"' }\ntasks.register('resolveNativeModule') { doLast { def rows = configurations.nativeModule.resolvedConfiguration.resolvedArtifacts.collect { a -> [group:a.moduleVersion.id.group, name:a.name, version:a.moduleVersion.id.version, classifier:a.classifier, extension:a.extension, source:a.file.absolutePath] }.sort { a,b -> (a.group+':'+a.name+':'+a.version+':'+a.extension) <=> (b.group+':'+b.name+':'+b.version+':'+b.extension) }; file('resolved.json').text=groovy.json.JsonOutput.toJson(rows) } }\n")
            command=[str(gradle),'--no-daemon','resolveNativeModule'];working=stage
            if android_project is not None:
                working=Path(android_project).resolve()
                if not (working/'app/build.gradle').is_file():raise ValueError('Android resolution context requires a project with app/build.gradle')
                # Resolve the module WITH the app's native runtime graph. Local
                # file dependencies are not Maven resolvedArtifacts; they are
                # not relocked as anonymous duplicate libraries.
                quote=lambda text: "'"+str(text).replace('\\','\\\\').replace("'","\\'")+"'"
                script="""gradle.projectsEvaluated {
    def app = gradle.rootProject.project(':app')
    app.dependencies.add('implementation', __COORDINATE__)
    app.tasks.register('resolveAlignedNativeModule') { doLast {
        def rows = app.configurations.debugRuntimeClasspath.resolvedConfiguration.resolvedArtifacts.collect { a ->
            [group:a.moduleVersion.id.group,name:a.name,version:a.moduleVersion.id.version,classifier:a.classifier,extension:a.extension,source:a.file.absolutePath]
        }.sort { a,b -> (a.group+':'+a.name+':'+a.version+':'+a.extension) <=> (b.group+':'+b.name+':'+b.version+':'+b.extension) }
        new File(__OUTPUT__).text=groovy.json.JsonOutput.toJson(rows)
    } }
}
""".replace('__COORDINATE__',quote(m.package+':'+m.revision)).replace('__OUTPUT__',quote(stage/'resolved.json'))
                (stage/'align.gradle').write_text(script)
                command=[str(gradle),'--no-daemon','-PnativeModuleRelock=true','--init-script',str(stage/'align.gradle'),':app:resolveAlignedNativeModule']
            with (stage/'resolve.log').open('w') as log:
                result=subprocess.run(command,cwd=working,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
            if result.returncode:raise ValueError('Native package resolution failed: '+(stage/'resolve.log').read_text()[-5000:])
            for a in json.loads((stage/'resolved.json').read_text()):
                for key in ('group','name','version','extension'):
                    if not isinstance(a.get(key),str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*',a[key]):
                        raise ValueError('Invalid native resolver artifact identity')
                if a.get('classifier') in ('sources','javadoc'):raise ValueError('Native resolver selected documentation instead of runtime artifact')
                source=Path(a.pop('source'));key=a['group']+':'+a['name']+':'+a['version']
                name=source.name;folder=stage/'artifacts'/a['group']/a['name']/a['version'];folder.mkdir(parents=True,exist_ok=True)
                target=folder/name;shutil.copy2(source,target)
                artifacts.append({**a,'coordinate':key,'path':target.relative_to(stage).as_posix(),'sha256':digest(target)})
            if not artifacts:raise ValueError('Native resolver returned no artifacts')
            if not any(a['coordinate']==m.package+':'+m.revision for a in artifacts):raise ValueError('Host resolution changed the declared native module version')
        else:
            checkout=stage/'source'
            subprocess.run(['git','clone','--filter=blob:none','--no-checkout',m.package,str(checkout)],check=True,capture_output=True,timeout=180)
            subprocess.run(['git','-C',str(checkout),'fetch','--depth=1','origin',m.revision],check=True,capture_output=True,timeout=180)
            resolved=subprocess.check_output(['git','-C',str(checkout),'rev-parse','FETCH_HEAD'],text=True).strip()
            if resolved!=m.revision:raise ValueError('SPM commit identity mismatch')
            subprocess.run(['git','-C',str(checkout),'checkout','--detach',m.revision],check=True,capture_output=True,timeout=60)
            if not (checkout/'Package.swift').is_file():raise ValueError('Repository does not contain an SPM package')
            artifacts.append({'path':'source/Package.swift','sha256':digest(checkout/'Package.swift'),'gitCommit':resolved})
        artifacts=list({a['path']:a for a in artifacts}.values())
        lock={'schemaVersion':1,'module':asdict(m),'manifestSha256':digest(manifest),'artifacts':artifacts,'verification':{'resolved':m.platform=='android','sourcePinned':True,'compiled':False,'executed':False,'bindings':'not yet exported'}}
        if android_project is not None:
            lock['resolutionContext']={'kind':'androidRuntimeClasspath','configuration':'debugRuntimeClasspath','localArtifactsReplaceMaven':True}
        (stage/'module.lock.json').write_text(json.dumps(lock,indent=2,sort_keys=True)+'\n')
        shutil.copy2(manifest,stage/'module.json')
        shutil.copytree(stage,dest)
    return {'module':m.id,'lock':str(dest/'module.lock.json'),'artifacts':len(artifacts),'compiled':False,'executed':False}


def verify(lock_path):
    from ..frontends import read_json
    p=Path(lock_path).resolve();d=read_json(p.read_text());root=p.parent
    if not isinstance(d,dict) or type(d.get('schemaVersion')) is not int or d.get('schemaVersion')!=1 or not isinstance(d.get('artifacts'),list) or not d['artifacts']:raise ValueError('Invalid module lock')
    if digest(root/'module.json')!=d['manifestSha256']:raise ValueError('Module declaration changed since lock')
    m=read_manifest(root/'module.json')
    if asdict(m)!=dict(d['module'],permissions=tuple(d['module']['permissions']),products=tuple(d['module']['products'])):raise ValueError('Module lock identity differs from declaration')
    for a in d['artifacts']:
        f=(root/a['path']).resolve()
        if not f.is_relative_to(root) or not f.is_file() or digest(f)!=a['sha256']:raise ValueError('Native artifact integrity failure: '+a['path'])
    if m.platform=='ios':
        commit=subprocess.check_output(['git','-C',str(root/'source'),'rev-parse','HEAD'],text=True).strip()
        dirty=subprocess.check_output(['git','-C',str(root/'source'),'status','--porcelain'],text=True)
        if commit!=m.revision or dirty:raise ValueError('SPM checkout differs from pinned source')
    return d
