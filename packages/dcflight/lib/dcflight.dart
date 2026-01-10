/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


library;

import 'dart:io';
export 'framework/constants/style/dcf_colors.dart';
export 'framework/theme/dcf_theme.dart';
export 'package:dcflight/framework/utils/flutter_framework_interop.dart'
    hide
        Colors,
        PlatformDispatcher,
        Widget,
        View,
        StatefulWidget,
        State,
        BuildContext,
        MethodChannel,
        MethodCall,
        MethodCodec,
        PlatformException,
        AssetBundle,
        AssetBundleImageKey,
        AssetBundleImageProvider,
        ImageConfiguration,
        ImageStreamListener,
        ImageStream,
        ImageStreamCompleter,
        ImageInfo,
        ImageProvider,
        ImageErrorListener,
        ImageCache,
        Text,
        TextStyle,
        TextPainter,
        TextSpan,
        TextHeightBehavior,
        RenderBox,
        RenderObject,
        RenderObjectElement,
        RenderObjectWidget,
        StatefulElement,
        Element,
        ElementVisitor,
        WidgetInspectorService;

export 'dart:async';
export 'framework/renderer/engine/index.dart';
// Hot reload is handled via Flutter's built-in system - no custom listener needed

export 'framework/renderer/interface/interface.dart';
export 'framework/renderer/interface/interface_impl.dart';
export 'framework/worklets/worklet.dart';
export 'framework/constants/layout/yoga_enums.dart';
export 'framework/constants/layout/layout_properties.dart';
export 'framework/constants/layout/layout_config.dart';
export 'package:dcflight/framework/constants/layout/absolute_layout.dart';
export 'framework/constants/style/style_properties.dart';
export 'framework/constants/style/gradient.dart'; // Export DCFGradient
export 'framework/constants/style/color_utils.dart';

export 'framework/utils/screen_utilities.dart';
export 'framework/utils/font_scale.dart';
export 'framework/utils/system_state_manager.dart';
export 'framework/utils/dcf_logger.dart';

export 'framework/devtools/hot_restart.dart';
export 'framework/protocol/component_registry.dart';
export 'framework/protocol/plugin_protocol.dart';
export 'src/components/portal/dcf_portal.dart';
export 'src/components/portal/dcf_portal_target.dart';
export 'framework/utils/widget_to_dcf_adaptor.dart';
export 'src/components/view_component.dart';
export 'src/components/text_component.dart';
export 'src/components/scroll_view_component.dart';
// export 'src/components/scroll_content_view_component.dart';
export 'src/components/dc_logo.dart';
export 'src/components/error_boundary.dart';
export 'src/components/touchable_opacity_component.dart';
export 'src/components/button_component.dart';
import 'package:dcflight/src/components/component_node.dart';
import 'package:dcflight/src/components/root_error_boundary.dart';
import 'package:dcflight/src/components/core_wrapper.dart';

import 'framework/renderer/engine/engine_api.dart';
import 'framework/renderer/interface/interface.dart';
import 'framework/utils/screen_utilities.dart';
import 'framework/protocol/plugin_protocol.dart';
export 'framework/renderer/interface/tunnel.dart';
import 'framework/devtools/hot_restart.dart';
import 'framework/utils/dcf_logger.dart';
import 'framework/devtools/hot_reload.dart';
import 'package:flutter/material.dart';
import 'framework/utils/flutter_widget_renderer.dart';
export 'package:equatable/equatable.dart';

/// DCFlight Framework entry points
class DCFlight {
  /// Set the global log level for DCFlight framework
  static void setLogLevel(DCFLogLevel level) {
    DCFLogger.setLevel(level);
  }

  /// Get the current log level
  static DCFLogLevel get logLevel => DCFLogger.currentLevel;

  /// Initialize the DCFlight framework
  static Future<bool> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Use singleton instance to ensure event handler is set on the same instance
    final bridge = PlatformInterface.instance;
    await bridge.initialize();

    ScreenUtilities.instance.refreshDimensions();

    await DCFEngineAPI.instance.init(bridge);

    PluginRegistry.instance.registerPlugin(CorePlugin.instance);
    
    // Initialize FlutterWidgetRenderer for WidgetToDCFAdaptor support
    FlutterWidgetRenderer.initialize();

    return true;
  }

  /// Get project identifier for log isolation
  static String _getProjectId() {
    try {
      final currentDir = Directory.current;
      final pubspecFile = File('${currentDir.path}/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final nameMatch = RegExp(r'name:\s*([^\s]+)').firstMatch(content);
        if (nameMatch != null) {
          return nameMatch.group(1)!;
        }
      }
      return currentDir.path.split('/').last;
    } catch (e) {
      return 'unknown_project';
    }
  }

  /// Start the application with the given root component
  /// The framework automatically wraps the app in an error boundary for crash protection
  /// (React Native-style - developers don't need to manually wrap their app)
  static Future<void> go({required DCFComponentNode app}) async {
    await _initialize();

    DCFLogger.setInstanceId(DateTime.now().millisecondsSinceEpoch.toString());
    DCFLogger.setProjectId(_getProjectId());

    final wasHotRestart = await HotRestartDetector.detectAndCleanup();

    final vdom = DCFEngineAPI.instance;

    // CRASH PROTECTION: Automatically wrap app in error boundary at framework level
    // This provides React Native-style crash protection without requiring developers
    // to manually wrap their app components
    // 
    // Core Wrapper: Wrap in SystemChangeListener to listen to OS-level changes
    // (font scale, language, etc.) and trigger re-renders when they occur
    final coreWrapper = CoreWrapper(app);
    final mainApp = RootErrorBoundary(coreWrapper);

    await vdom.createRoot(mainApp);
    
    // Create minimal Flutter widget for hot reload detection
    // This widget uses reassemble() which Flutter calls automatically on hot reload
    // When Flutter hot reloads, reassemble() is called, which notifies VDOM to update
    if (!const bool.fromEnvironment('dart.vm.product')) {
      runApp(_DCFlightHotReloadDetector());
    }

    if (wasHotRestart) {
      print('🔥 DCFlight: Hot restart detected');
    }

    vdom.isReady.whenComplete(() async {});
  }
}

/// Minimal Flutter widget that detects hot reload via reassemble()
/// Flutter automatically calls reassemble() on all State objects during hot reload
/// This widget is invisible and only exists to detect hot reload and notify VDOM
class _DCFlightHotReloadDetector extends StatefulWidget {
  @override
  State<_DCFlightHotReloadDetector> createState() => _DCFlightHotReloadDetectorState();
}

class _DCFlightHotReloadDetectorState extends State<_DCFlightHotReloadDetector> {
  @override
  void initState() {
    super.initState();
    HotReloadDetector.instance.initialize();
  }
  
  /// Flutter calls this automatically when hot reload happens
  /// This is the standard Flutter hot reload detection mechanism
  @override
  void reassemble() {
    super.reassemble();
    print('🔥 DCFlight: Hot reload detected via reassemble() - notifying VDOM...');
    // Notify VDOM to update when Flutter hot reloads
    HotReloadDetector.instance.handleHotReload();
  }
  
  @override
  Widget build(BuildContext context) {
    // Return minimal transparent widget - this widget is invisible
    // It only exists to detect hot reload via reassemble()
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(), // Completely invisible
      ),
    );
  }
}


