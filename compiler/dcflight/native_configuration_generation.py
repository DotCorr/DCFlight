"""Development-time native metadata emission; native build tools own validation."""
import copy
import json
import plistlib
import re
import xml.etree.ElementTree as ET
from dataclasses import replace
from .backends import Artifact
from .native_configuration import NativeConfiguration, plist_dict, manifest_xml
from .native_metadata import _read, ANDROID
from .validate import Diagnostic

RECEIPT='.dcflight/native-configuration.json'
ENTITLEMENTS='Native/App.entitlements'
ET.register_namespace('android',ANDROID)
ET.register_namespace('tools','http://schemas.android.com/tools')

def configuration(app,output):
    config=getattr(app,'native_configuration',None)
    if config is not None:return config
    previous=_read(output,RECEIPT)
    if previous is None:return None
    data=json.loads(previous)
    # Keep the established native project binding valid when authored keys clear.
    from .native_configuration import lower_native_configuration
    return lower_native_configuration({'android':{'sourceSets':data['sourceSets']}})

def prepare_android(config,artifacts,output):
    relative='android/app/src/main/AndroidManifest.xml'
    planned=artifacts[relative]
    base=ET.fromstring(planned.content)
    overlay=manifest_xml(config.android_manifest,config.android_namespaces) if config.android_manifest else ET.Element('manifest')
    if overlay.tag!='manifest':raise Diagnostic('Android configuration root must be manifest')
    if 'package' in overlay.attrib:
        raise Diagnostic('Android package identity comes from app.id, not manifest configuration')
    if len(overlay.findall('application'))>1:raise Diagnostic('Manifest requires at most one application element')
    required=list(base.findall('uses-permission'))
    for permission in required:
        name=permission.get('{'+ANDROID+'}name')
        matches=[node for node in overlay.findall('uses-permission') if node.get('{'+ANDROID+'}name')==name]
        if len(matches)>1:raise Diagnostic('Duplicate authored permission: '+str(name))
        if matches:
            node=matches[0]
            if (node.get('{'+ANDROID+'}maxSdkVersion') is not None
                    or node.get('{http://schemas.android.com/tools}node') in ('remove','removeAll')):
                raise Diagnostic('Authored manifest restricts required permission: '+str(name))
        else:overlay.insert(0,copy.deepcopy(permission))
        effective=matches[0] if matches else overlay[0]
        effective.set('{http://schemas.android.com/tools}node','replace')
        base.remove(permission)
    if required and any(n.get('{http://schemas.android.com/tools}node')=='removeAll' for n in overlay.findall('uses-permission')):
        raise Diagnostic('Manifest removeAll contradicts required permissions')
    application=base.find('application')
    for key in ('usesCleartextTraffic','networkSecurityConfig'):
        attribute='{'+ANDROID+'}'+key
        if attribute in application.attrib:
            target=overlay.find('application')
            if target is None:target=ET.SubElement(overlay,'application')
            target.attrib.setdefault(attribute,application.attrib.pop(attribute))
    used=set()
    for node in overlay.iter():
        for name in [node.tag,*node.attrib]:
            if name.startswith('{'):used.add(name[1:].split('}',1)[0])
    # QName-valued attributes (such as tools:replace) can reference a prefix
    # whose namespace is otherwise unused in element/attribute names.
    for prefix,uri in config.android_namespaces:
        if uri not in used:overlay.set('xmlns:'+prefix,uri)
    for source_set in config.android_source_sets:
        # Namespace/path validation is already performed by the canonical IR.
        path='android/app/src/'+source_set+'/AndroidManifest.xml'
        artifacts[path]=Artifact(ET.tostring(overlay,encoding='unicode')+'\n')
    artifacts[relative]=Artifact(ET.tostring(base,encoding='unicode')+'\n',planned.ownership)

def finish_ios(config,artifacts,output):
    from .native_metadata import PLISTS
    values=plist_dict(config.ios_info_plist)
    original=plistlib.loads(artifacts['ios/Native/AppInfo.plist'].content.encode())
    for name in ('CFBundleIdentifier','CFBundleExecutable','CFBundleName','CFBundleDisplayName','CFBundlePackageType'):
        if name in values and values[name]!=original[name]:
            raise Diagnostic('Info.plist '+name+' conflicts with generated app identity')
    original.update(values)
    content=plistlib.dumps(original,sort_keys=True).decode()
    for path in PLISTS:
        if 'ios/'+path in artifacts:artifacts['ios/'+path]=Artifact(content)
    artifacts['ios/'+ENTITLEMENTS]=Artifact(plistlib.dumps(plist_dict(config.ios_entitlements),sort_keys=True).decode())
    path='ios/App.xcodeproj/project.pbxproj';planned=artifacts[path]
    old=_read(output,path)
    if old is not None:
        bindings=re.findall(r'\bCODE_SIGN_ENTITLEMENTS\s*=\s*([^;]+);',old)
        if len(bindings)!=len(re.findall(r'\bINFOPLIST_FILE\s*=',old)) or not bindings or any(v.strip().strip('"')!=ENTITLEMENTS for v in bindings):
            raise Diagnostic('Existing user-owned Xcode project needs CODE_SIGN_ENTITLEMENTS = Native/App.entitlements in each app build configuration; use a new output directory or bind it explicitly. No files were changed.')
    text=planned.content.replace('INFOPLIST_FILE = Native/AppInfo.plist;',
        'INFOPLIST_FILE = Native/AppInfo.plist; CODE_SIGN_ENTITLEMENTS = '+ENTITLEMENTS+';')
    if 'CODE_SIGN_ENTITLEMENTS = '+ENTITLEMENTS+';' not in text:
        raise Diagnostic('Cannot bind generated entitlement file to Xcode project')
    artifacts[path]=Artifact(text,planned.ownership)

def receipt(config,artifacts,targets,output):
    old=_read(output,RECEIPT)
    previous=json.loads(old) if old else {}
    platforms=set(previous.get('platforms',[]))|set(targets)
    artifacts[RECEIPT]=Artifact(json.dumps({'version':1,'sourceSets':list(config.android_source_sets) if 'android' in targets else previous.get('sourceSets',list(config.android_source_sets)),
        'platforms':sorted(platforms),'scope':'Native configuration generation; signing authorization and runtime permission grants are external.'},indent=2)+'\n')
