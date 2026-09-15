"""Development-time deployment contract and conservative Xcode binding checks."""
import copy,json,re
from .validate import Diagnostic
from .backends import Artifact


def deployment_target(app):
    config=getattr(app,'native_configuration',None)
    return config.ios_deployment_target if config is not None else (17,0)


def operation_for_app(definition,target):
    result=copy.deepcopy(definition)
    implementation=result['implementations']['ios']
    explicit=implementation.get('iosVersion')
    if explicit is not None:
        if (not isinstance(explicit,list) or len(explicit)!=2 or any(type(v) is not int or v<0 for v in explicit)):
            raise Diagnostic('Native operation iosVersion requires [major, minor]')
        if tuple(explicit)>target:
            raise Diagnostic('Native operation '+definition['name']+' requires iOS '+'.'.join(map(str,explicit))+' above app deployment target '+'.'.join(map(str,target))+'. Set nativeConfiguration.ios.deploymentTarget intentionally; availability fallback is not implemented.')
    else:implementation['iosVersion']=list(target)
    return result


# Parse only data, never evaluate project text. This bounded OpenStep subset
# covers ordinary generated Xcode projects and rejects unfamiliar syntax.
def _project(text):
    if len(text)>4*1024*1024:raise ValueError('Xcode project exceeds supported size')
    token=re.compile(r'\s+|//[^\n]*(?:\n|$)|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,"]+')
    tokens=[];position=0
    for match in token.finditer(text):
        if match.start()!=position:raise ValueError('Unsupported Xcode project syntax')
        position=match.end();s=match.group()
        if s.isspace() or s.startswith('//') or s.startswith('/*'):continue
        tokens.append((s,'quoted' if s.startswith('"') else 'plain'))
    if position!=len(text) or len(tokens)>200000:raise ValueError('Unsupported Xcode project syntax')
    index=0
    def take():
        nonlocal index
        if index>=len(tokens):raise ValueError('Incomplete Xcode project')
        item=tokens[index];index+=1;return item
    def expect(s):
        if take()!=(s,'plain'):raise ValueError('Malformed Xcode project')
    def value(depth=0):
        if depth>64:raise ValueError('Xcode project nesting exceeds64')
        item,kind=take()
        if kind=='quoted':return json.loads(item)
        if item=='{':
            result={}
            while index<len(tokens) and tokens[index]!=('}','plain'):
                key=value(depth+1)
                if not isinstance(key,str) or key in result:raise ValueError('Duplicate/invalid Xcode project key')
                expect('=');result[key]=value(depth+1);expect(';')
            expect('}');return result
        if item=='(':
            result=[]
            while index<len(tokens) and tokens[index]!=(')','plain'):
                result.append(value(depth+1))
                if tokens[index]==(',','plain'):take()
                elif tokens[index]!=(')','plain'):raise ValueError('Malformed Xcode array')
            expect(')');return result
        if item in '{}()=;,':raise ValueError('Unexpected Xcode delimiter')
        return item
    result=value()
    if index!=len(tokens) or not isinstance(result,dict):raise ValueError('Trailing Xcode project data')
    return result


def check_binding(text,target):
    try:
        doc=_project(text);objects=doc['objects'];project=objects[doc['rootObject']]
        if project['isa']!='PBXProject':raise ValueError('Missing project root')
        targets=[objects[t] for t in project['targets'] if objects[t].get('productType')=='com.apple.product-type.application']
        if len(targets)!=1:raise ValueError('Expected one application target')
        if targets[0].get('isa')!='PBXNativeTarget':raise ValueError('Invalid application target')
        config_list=objects[targets[0]['buildConfigurationList']]
        if config_list.get('isa')!='XCConfigurationList':raise ValueError('Invalid target configuration list')
        configs=config_list['buildConfigurations']
        if not configs:raise ValueError('Missing app build configurations')
        for key in configs:
            config=objects[key]
            if config['isa']!='XCBuildConfiguration':raise ValueError('Invalid app build configuration')
            binding=objects[config['baseConfigurationReference']]
            if (binding['isa']!='PBXFileReference' or binding['path']!='Native/Logic.xcconfig' or binding.get('sourceTree')!='SOURCE_ROOT'):
                raise ValueError('Missing generated target xcconfig binding')
            # Target build settings override xcconfig, including SDK-qualified
            # forms; reject all such overrides even if currently equal.
            if any(k=='IPHONEOS_DEPLOYMENT_TARGET' or k.startswith('IPHONEOS_DEPLOYMENT_TARGET[') for k in config.get('buildSettings',{})):
                raise ValueError('Target build settings override generated deployment target')
    except (ValueError,KeyError,TypeError,IndexError) as error:
        raise Diagnostic('Xcode deployment binding: '+str(error)+'. Bind Native/Logic.xcconfig as every app target configuration base and remove target-level IPHONEOS_DEPLOYMENT_TARGET overrides. User-owned project was not edited.') from error


def finish(app,artifacts,output):
    from .sync import safe_path
    target=deployment_target(app);relative='ios/App.xcodeproj/project.pbxproj'
    path=safe_path(output,relative)
    check_binding(path.read_text() if path.is_file() else artifacts[relative].content,target)
    config='ios/Native/Logic.xcconfig'
    artifacts[config]=Artifact(artifacts[config].content+'\n// Authored iOS deployment minimum.\nIPHONEOS_DEPLOYMENT_TARGET = '+'.'.join(map(str,target))+'\n')
