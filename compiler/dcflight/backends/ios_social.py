"""Emit reusable, concrete native social features from shared service/tab declarations."""
import plistlib
from pathlib import Path
from . import HEADER
from .common import expression, symbol
from .ios_presentation import color, ICONS
from ..ir import Literal, ScalarType, Theme
from ..shared_logic import c_alias

FEATURES={'camera':'CameraScreen','inbox':'InboxScreen','stories':'StoriesScreen','friendMap':'FriendMapScreen','account':'AccountScreen'}
TEMPLATES=Path(__file__).parent/'templates/ios_social'


def quoted(value):return expression(Literal(value,ScalarType.STRING),'ios')


def render(node, app):
    if node.capability in FEATURES:return FEATURES[node.capability]+'()', ''
    if node.capability=='tab':return symbol(node.children[0].id)+'(model: model)', ''
    if node.capability!='tabs':return None
    declarations='    @EnvironmentObject private var socialSession: SocialSession\n    @AppStorage("selected-tab") private var selectedTab = '+quoted(node.children[0].id)+'\n'
    children=[];modern=[];inbox=None
    for tab in node.children:
        props=tab.props();icon=ICONS[props['icon'].value]
        title=expression(props['title'],'ios');identifier=quoted('tab.'+tab.id)
        children.append(symbol(tab.id)+'(model: model).tabItem { Label('+title+', systemImage: '+quoted(icon)+').accessibilityLabel('+title+').accessibilityIdentifier('+identifier+') }.tag('+quoted(tab.id)+')')
        modern.append('Tab('+title+', systemImage: '+quoted(icon)+', value: '+quoted(tab.id)+') { '+symbol(tab.id)+'(model: model) }.accessibilityIdentifier('+identifier+')')
        if any(desc.capability=='inbox' for desc in _walk(tab)):inbox=tab.id
    body='Group { if #available(iOS 18.0, *) { TabView(selection: $selectedTab) {\n'+'\n'.join(modern)+'\n} } else { TabView(selection: $selectedTab) {\n'+'\n'.join(children)+'\n} } }.tint(SocialTheme.text)'
    camera_tabs=[tab.id for tab in node.children if any(desc.capability=='camera' for desc in _walk(tab))]
    if camera_tabs:
        body+='\n.preferredColorScheme(['+', '.join(quoted(tab) for tab in camera_tabs)+'].contains(selectedTab) ? .dark : nil)'
        body+='\n.tint(['+', '.join(quoted(tab) for tab in camera_tabs)+'].contains(selectedTab) ? SocialTheme.accent : SocialTheme.text)'
    if inbox:
        body+='\n.onChange(of: socialSession.conversationRoute) { _, route in if route != nil { selectedTab = '+quoted(inbox)+' } }'
    body+='\n.onAppear { if !['+', '.join(quoted(tab.id) for tab in node.children)+'].contains(selectedTab) { selectedTab = '+quoted(node.children[0].id)+' } }'
    return body,declarations


def _walk(node):
    yield node
    for child in node.children:yield from _walk(child)


def _policy(app, name, arguments):
    if app.logic and any(function.name==name for function in app.logic.functions):
        function=next(f for f in app.logic.functions if f.name==name)
        if function.returns.value!='uint32' or any(p.value!='uint32' for p in function.parameters) or len(function.parameters)!=len(arguments):
            raise ValueError('Social policy '+name+' must match its uint32 ABI contract')
        return c_alias(app,name)+'('+', '.join(arguments)+')'
    raise ValueError("Missing required shared social policy: " + name)


def artifacts(app):
    if app.service is None:return {}
    theme=app.theme or Theme()
    tokens='\n'.join('    static let '+key+' = '+color(getattr(theme,key)) for key in ('accent','background','surface','text','muted','danger'))
    configuration='''import SwiftUI

enum SocialConfiguration {
    static let baseURL = '''+quoted(app.service.base_url.rstrip('/'))+'''
    static let appName = '''+quoted(app.name)+'''
    static let urlScheme = '''+quoted(app.id)+'''
}
enum SocialTheme {
'''+tokens+'\n    static let radius:CGFloat = '+str(theme.radius)+'\n    static let padding:CGFloat = '+str(theme.padding)+'\n}\n'
    can_send=_policy(app,'canSendMessage',['UInt32(clamping: count)','hasPhoto ? 1 : 0'])
    can_upload=_policy(app,'canUploadPhoto',['UInt32(clamping: bytes)'])
    remaining=_policy(app,'remainingStorySeconds',['UInt32(clamping: age)'])
    publish=_policy(app,'shouldPublishLocation',['consent ? 1 : 0','permission ? 1 : 0'])
    configuration+='''enum SocialPolicy {
    static func canSend(text:String,hasPhoto:Bool)->Bool {
        let count=text.trimmingCharacters(in:.whitespacesAndNewlines).unicodeScalars.count
        return '''+can_send+''' != 0
    }
    static func canUpload(bytes:Int)->Bool { '''+can_upload+''' != 0 }
    static func remaining(story:Story,now:Date)->Int {
        let seconds=Int(now.timeIntervalSince1970)
        let age=max(0,seconds-story.createdAt)
        return min(max(0,story.expiresAt-seconds),Int('''+remaining+'''))
    }
    static func shouldPublish(consent:Bool,permission:Bool)->Bool { '''+publish+''' != 0 }
}
'''
    files={'App/Generated/Social/Configuration.swift':HEADER+configuration}
    for path in sorted(TEMPLATES.glob('*.swift')):files['App/Generated/Social/'+path.name]=HEADER+path.read_text()
    info={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':app.name,'CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0','CFBundleVersion':'1','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'CFBundleURLTypes':[{'CFBundleURLName':app.id,'CFBundleURLSchemes':[app.id]}]}
    capabilities={node.capability for node in app.nodes()}
    if 'camera' in capabilities:info['NSCameraUsageDescription']='Take photos you choose to share with your friends.'
    if 'friendMap' in capabilities:info['NSLocationWhenInUseUsageDescription']='Share your location with friends only when you turn sharing on.'
    if app.service.development:info['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
    files['Native/ServiceInfo.plist']=plistlib.dumps(info,sort_keys=True).decode()
    return files


def app_main():
    return HEADER+'''import SwiftUI
@main
struct AppMain:App {
    @StateObject private var model=AppModel()
    @StateObject private var socialSession=SocialSession()
    var body:some Scene {
        WindowGroup {
            SocialGate { RootView(model:model) }.environmentObject(socialSession)
                .onOpenURL { url in
                    guard url.scheme==SocialConfiguration.urlScheme,url.host=="conversation" else{return}
                    let id=url.path.trimmingCharacters(in:CharacterSet(charactersIn:"/"))
                    guard id.count==32,id.allSatisfy({"0123456789abcdef".contains($0)}) else{return}
                    socialSession.conversationRoute=id
                }
        }
    }
}
'''
