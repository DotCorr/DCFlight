import json
from . import Artifact, HEADER
from .common import expression, symbol, expand
from ..ir import ScalarType


PROJECT = '''// !$*UTF8*$!
{
 archiveVersion = 1;
 classes = {};
 objectVersion = 77;
 objects = {
  100000000000000000000001 = {isa = PBXProject; attributes = {LastUpgradeCheck = 1600;}; buildConfigurationList = 100000000000000000000008; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = 100000000000000000000002; productRefGroup = 100000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (100000000000000000000005);};
  100000000000000000000002 = {isa = PBXGroup; children = (100000000000000000000003, 100000000000000000000004); sourceTree = "<group>";};
  100000000000000000000003 = {isa = PBXFileSystemSynchronizedRootGroup; path = App; sourceTree = "<group>";};
  100000000000000000000004 = {isa = PBXGroup; children = (100000000000000000000006); name = Products; sourceTree = "<group>";};
  100000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = 100000000000000000000009; buildPhases = (100000000000000000000007); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = (100000000000000000000003); name = App; productName = App; productReference = 100000000000000000000006; productType = "com.apple.product-type.application";};
  100000000000000000000006 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = App.app; sourceTree = BUILT_PRODUCTS_DIR;};
  100000000000000000000007 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;};
  100000000000000000000008 = {isa = XCConfigurationList; buildConfigurations = (100000000000000000000010, 100000000000000000000011); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
  100000000000000000000009 = {isa = XCConfigurationList; buildConfigurations = (100000000000000000000012, 100000000000000000000013); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
  100000000000000000000010 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0;}; name = Debug;};
  100000000000000000000011 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0;}; name = Release;};
  100000000000000000000012 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = __APP_ID__; PRODUCT_NAME = App; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; INFOPLIST_KEY_CFBundleDisplayName = __APP_NAME__; ALWAYS_SEARCH_USER_PATHS = NO;}; name = Debug;};
  100000000000000000000013 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = __APP_ID__; PRODUCT_NAME = App; SWIFT_VERSION = 5.0; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; INFOPLIST_KEY_CFBundleDisplayName = __APP_NAME__; ALWAYS_SEARCH_USER_PATHS = NO;}; name = Release;};
 };
 rootObject = 100000000000000000000001;
}
'''


class IOS:
    target = 'ios'

    def generate(self, app, registry):
        files = {}
        def put(path, content, ownership='generated'):
            files['ios/' + path] = Artifact(content, ownership)
        put('App.xcodeproj/project.pbxproj', PROJECT.replace('__APP_ID__', app.id).replace('__APP_NAME__', json.dumps(app.name, ensure_ascii=False)), 'user')
        put('App/User/AppMain.swift', HEADER + '''import SwiftUI
@main
struct AppMain: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { RootView(model: model).padding() }
    }
}
''', 'user')
        put('App/Generated/RootView.swift', HEADER + '''import SwiftUI
struct RootView: View {
    @ObservedObject var model: AppModel
    var body: some View { ''' + symbol(app.root.id) + '''(model: model) }
}
''')
        types = {ScalarType.STRING: 'String', ScalarType.INT: 'Int32', ScalarType.BOOL: 'Bool'}
        state = '\n'.join('    @Published var s_' + s.name + ': ' + types[s.initial.type] + ' = ' + expression(s.initial, 'ios') for s in app.states)
        methods = []
        for action in app.actions:
            target = 's_' + str(action.target)
            if action.operation == 'increment':
                body = target + ' = ' + target + ' == Int32.max ? Int32.min : ' + target + ' + 1'
            elif action.operation == 'toggle':
                body = target + '.toggle()'
            elif action.operation == 'set':
                body = target + ' = ' + expression(action.value, 'ios').replace('model.s_', 'self.s_')
            else:
                body = 'UserActions.a_' + action.id + '(self)'
            methods.append('    func a_' + action.id + '() { ' + body + ' }')
        put('App/Generated/AppModel.swift', HEADER + 'import Combine\nfinal class AppModel: ObservableObject {\n' + state + '\n' + '\n'.join(methods) + '\n}\n')
        for node in app.nodes():
            props = node.props()
            mapping = registry.get(node.capability)['targets']['ios']
            values = {key: expression(value, 'ios') for key, value in props.items()}
            values.update(children='\n'.join(symbol(c.id) + '(model: model)' for c in node.children), action='model.a_' + str(node.action))
            for key, spec in registry.get(node.capability)['properties'].items():
                if spec.get('binding'):
                    values['binding_' + key] = '$model.s_' + props[key].name
            if node.capability == 'native':
                values['symbol'] = 'v_' + props['symbol'].value
            body = expand(mapping['expression'], values)
            put('App/Generated/Nodes/' + symbol(node.id) + '.swift', HEADER + 'import SwiftUI\nstruct ' + symbol(node.id) + ': View {\n    @ObservedObject var model: AppModel\n    var body: some View {\n' + body + '\n    }\n}\n')
        return files
