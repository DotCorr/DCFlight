"""Generated app metadata behind stable, user-owned native project bindings."""
import plistlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from html import escape
from .backends import Artifact
from .sync import safe_path
from .validate import Diagnostic

ANDROID='http://schemas.android.com/apk/res/android'
RESOURCE='@string/native_app_name'
PLISTS=('Native/AppInfo.plist','Native/TransportInfo.plist','Native/ServiceInfo.plist')


def _read(output,relative):
    root=Path(output).absolute()
    if root.is_symlink():raise Diagnostic('Symlink output root')
    path=safe_path(root,relative)
    return path.read_text() if path.is_file() else None


def finalize_metadata(app,targets,artifacts,output):
    from .native_configuration_generation import configuration, prepare_android, finish_ios, receipt
    native_config=configuration(app,output)
    if native_config is not None and 'android' in targets:
        prepare_android(native_config,artifacts,output)
    # Xcode expands build-setting references even inside literal plist strings.
    if 'ios' in targets and re.search(r'\$[({]',app.name):
        raise Diagnostic('app.name: native build-setting references are unsupported')
    if 'android' in targets:
        relative='android/app/src/main/AndroidManifest.xml'
        planned=artifacts[relative]
        old=_read(output,relative)
        if old is not None:
            try:
                root=ET.fromstring(old);applications=root.findall('application')
                if len(applications)!=1:raise ValueError('Expected one application')
                label=applications[0].get('{'+ANDROID+'}label')
                # A preserved user manifest must still satisfy generated requirements.
                planned_root=ET.fromstring(planned.content)
                for required in planned_root.findall('uses-permission'):
                    name=required.get('{'+ANDROID+'}name')
                    matches=[entry for entry in root.findall('uses-permission') if entry.get('{'+ANDROID+'}name')==name]
                    if not any(all(entry.get(key)==value for key,value in required.attrib.items())
                               and entry.get('{'+ANDROID+'}maxSdkVersion')==required.get('{'+ANDROID+'}maxSdkVersion')
                               and entry.get('{http://schemas.android.com/tools}node') not in ('remove','removeAll')
                               for entry in matches):
                        raise Diagnostic('Existing user-owned Android manifest is missing or restricts required permission '+str(name)+'. Update its declaration or generate into a new directory; no files were changed.')
            except (ET.ParseError,ValueError) as error:
                raise Diagnostic('Cannot verify user-owned Android manifest: '+str(error))
            if label not in (RESOURCE,app.name):
                raise Diagnostic('User-owned Android manifest does not follow authored app.name. Set application android:label="'+RESOURCE+'" or use a new output directory; the manifest was not changed.')
        planned_label='android:label="'+escape(app.name,quote=True)+'"'
        if planned_label not in planned.content:raise Diagnostic('Generated Android manifest lacks the authored label binding')
        artifacts[relative]=Artifact(planned.content.replace(planned_label,'android:label="'+RESOURCE+'"',1),planned.ownership)
        # Android resource quoting preserves leading/trailing spaces and quotes.
        literal='"'+app.name.replace('\\','\\\\').replace('"','\\"')+'"'
        artifacts['android/app/src/main/res/values/native_app.xml']=Artifact('<?xml version="1.0" encoding="utf-8"?>\n<resources><string name="native_app_name" translatable="false">'+escape(literal,quote=False)+'</string></resources>\n')
    if 'ios' in targets:
        project='ios/App.xcodeproj/project.pbxproj';planned=artifacts[project]
        info={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)',
              'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0',
              'CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0','CFBundleVersion':'1',
              'LSRequiresIPhoneOS':True,'UILaunchScreen':{},
              'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False}}
        for relative in PLISTS[1:]:
            if 'ios/'+relative in artifacts:info.update(plistlib.loads(artifacts['ios/'+relative].content.encode()))
        info.update(CFBundleDisplayName=app.name,CFBundleName=app.name)
        content=plistlib.dumps(info,sort_keys=True).decode()
        artifacts['ios/Native/AppInfo.plist']=Artifact(content)
        # Keep existing supported generated plist bindings stable, including when
        # adding/removing transport or device features changes backend defaults.
        old=_read(output,project)
        if old is not None:
            bindings=re.findall(r'\bINFOPLIST_FILE\s*=\s*([^;]+);',old)
            bindings=[value.strip().strip('"') for value in bindings]
            if bindings:
                if any(value not in PLISTS for value in bindings) or any(value.strip() != 'NO' for value in re.findall(r'\bGENERATE_INFOPLIST_FILE\s*=\s*([^;]+);',old)):
                    raise Diagnostic('User-owned Xcode project uses custom Info.plist configuration. Bind the target to Native/AppInfo.plist with GENERATE_INFOPLIST_FILE=NO or use a new output directory; the project was not changed.')
                for binding in bindings:artifacts['ios/'+binding]=Artifact(content)
            else:
                names=re.findall(r'INFOPLIST_KEY_CFBundleDisplayName\s*=\s*("(?:\\.|[^"\\])*"|[^;]+);',old)
                import json
                try:names=[json.loads(n) if n.startswith('"') else n.strip() for n in names]
                except ValueError:names=[]
                if not names or any(name!=app.name for name in names):
                    raise Diagnostic('User-owned Xcode project does not follow authored app.name. Bind the target to Native/AppInfo.plist with GENERATE_INFOPLIST_FILE=NO or use a new output directory; the project was not changed.')
        text=planned.content.replace('GENERATE_INFOPLIST_FILE = YES;','GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Native/AppInfo.plist;')
        for relative in PLISTS[1:]:text=text.replace('INFOPLIST_FILE = '+relative+';','INFOPLIST_FILE = Native/AppInfo.plist;')
        import json
        text=text.replace('INFOPLIST_KEY_CFBundleDisplayName = '+json.dumps(app.name,ensure_ascii=False)+'; ','')
        artifacts[project]=Artifact(text,planned.ownership)

    if native_config is not None:
        if 'ios' in targets:finish_ios(native_config,artifacts,output)
        receipt(native_config,artifacts,targets,output)
