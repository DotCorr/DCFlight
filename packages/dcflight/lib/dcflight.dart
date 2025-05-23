// Main entry point for the DCFlight framework
library dcflight;

export 'package:dcflight/framework/utilities/flutter_framework.dart' hide PlatformDispatcher,
   Widget,View,StatefulWidget,State,BuildContext,MethodChannel,MethodCall,MethodCodec,PlatformException,AssetBundle,AssetBundleImageKey,AssetBundleImageProvider,ImageConfiguration,ImageStreamListener,ImageStream,ImageStreamCompleter,ImageInfo,ImageProvider,ImageErrorListener,ImageCache,Text,TextStyle,TextPainter,TextSpan,TextHeightBehavior,RenderBox,RenderObject,RenderObjectElement,RenderObjectWidget,StatefulElement,Element,ElementVisitor,WidgetInspectorService;
// Core Infrastructure
export 'framework/renderer/vdom/vdom.dart';
export 'framework/renderer/vdom/vdom_node.dart';
export 'framework/renderer/vdom/vdom_element.dart';
export 'framework/renderer/vdom/reconciler.dart';
export 'framework/renderer/vdom/fragment.dart';
export 'framework/renderer/vdom/component/component.dart';
export 'framework/renderer/vdom/component/state_hook.dart';
// Native Bridge System
export 'framework/renderer/interface/interface.dart' ;
export 'framework/renderer/interface/interface_impl.dart';

// Core Constants and Properties - explicitly exported for component developers
export 'framework/constants/yoga_enums.dart';
export 'framework/constants/layout_properties.dart';
export 'framework/constants/style_properties.dart';

// Utilities
export 'framework/utilities/screen_utilities.dart';


// Component Protocol Interfaces - no implementations
export 'framework/protocol/component_protocol.dart';
export 'framework/protocol/component_registry.dart';
export 'framework/protocol/plugin_protocol.dart';

// Application Entry Point
// import 'package:dcflight/framework/protocol/component_protocol.dart';
// import 'package:dcflight/framework/protocol/component_registry.dart';

import 'package:dcflight/framework/protocol/component_protocol.dart';
import 'package:dcflight/framework/protocol/component_registry.dart';

import 'framework/renderer/vdom/vdom.dart';
import 'framework/renderer/vdom/component/component.dart';
import 'framework/renderer/interface/interface.dart';
import 'framework/utilities/screen_utilities.dart';
import 'framework/protocol/plugin_protocol.dart';
import 'package:flutter/material.dart';

/// DCFlight Framework entry points
class DCFlight {
  /// Initialize the DCFlight framework
  static Future<bool> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize platform dispatcher
    final bridge = NativeBridgeFactory.create();
    // PlatformDispatcher.initializeInstance(bridge);
    await bridge.initialize();
    
    // Initialize screen utilities
    ScreenUtilities.instance.refreshDimensions();
    
    // Register core plugin
    PluginRegistry.instance.registerPlugin(CorePlugin.instance);
    
    return true;
  }
  
  /// Start the application with the given root component
  static Future<void> start({required Component app}) async {
  await   _initialize();
    // Create VDOM instance
    final vdom = VDom();
    
    // Create our main app component
    final mainApp = app;
    
    // Create a component node
    final appNode = vdom.createComponent(mainApp);
    
    // Render the component to native UI
    await vdom.renderToNative(appNode, parentId: "root", index: 0);
    
    // Wait for the VDom to be ready
    vdom.isReady.whenComplete(() async {
      debugPrint('VDOM is ready to calculate');
      await vdom.calculateAndApplyLayout().then((v) {
        debugPrint('VDOM layout applied from entry point');
      });
    });
  }
  /// Register a component definition with the framework
  static void registerComponentDefinition(ComponentDefinition definition) {
    ComponentRegistry.instance.registerComponentDefinition(definition);
  }
}

