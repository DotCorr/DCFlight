/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Main entry point for the DCFlight framework
library;

export 'package:dcflight/framework/utilities/flutter_framework_interop.dart'
    hide
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
// Core Infrastructure
export 'framework/renderer/engine/index.dart';
// Developer tools
export 'framework/devtools/hot_reload_listener.dart';

// Native Bridge System
export 'framework/renderer/interface/interface.dart';
export 'framework/renderer/interface/interface_impl.dart';

// Core Constants and Properties - explicitly exported for component developers
export 'framework/constants/layout/yoga_enums.dart';
export 'framework/constants/layout/layout_properties.dart';
export 'framework/constants/layout/layout_config.dart'; 
export 'package:dcflight/framework/constants/layout/absolute_layout.dart';
export 'framework/constants/style/style_properties.dart';
export 'framework/constants/style/color_utils.dart';

// Utilities
export 'framework/utilities/screen_utilities.dart';
export 'framework/utils/dcf_logger.dart';

// DevTools (debug mode only)
export 'framework/devtools/hot_restart.dart';
export 'package:dcf_primitives/dcf_primitives.dart';
export 'framework/protocol/component_registry.dart';
export 'framework/protocol/plugin_protocol.dart';
import 'package:dcflight/framework/renderer/engine/component/component_node.dart';

import 'framework/renderer/engine/engine_api.dart';
import 'framework/renderer/interface/interface.dart';
import 'framework/utilities/screen_utilities.dart';
import 'framework/protocol/plugin_protocol.dart';
export 'framework/renderer/interface/tunnel.dart';
import 'framework/devtools/hot_restart.dart';
import 'framework/utils/dcf_logger.dart';
import 'framework/devtools/hot_reload_listener.dart';
import 'package:flutter/material.dart';
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

    // Initialize platform dispatcher
    final bridge = NativeBridgeFactory.create();
    // PlatformDispatcher.initializeInstance(bridge);
    await bridge.initialize();

    // Initialize screen utilities
    ScreenUtilities.instance.refreshDimensions();

    // Initialize VDOM API with the bridge
    await DCFEngineAPI.instance.init(bridge);

    // Register core plugin
    PluginRegistry.instance.registerPlugin(CorePlugin.instance);

    return true;
  }

  /// Start the application with the given root component
  static Future<void> start({required DCFComponentNode app}) async {
    await _initialize();

    // Start hot reload listener in debug mode
    if (!const bool.fromEnvironment('dart.vm.product')) {
      await HotReloadListener.start();
    }

    // Check for hot restart and cleanup if needed (debug mode only)
    final wasHotRestart = await HotRestartDetector.detectAndCleanup();

    // Get the VDOM API instance
    final vdom = DCFEngineAPI.instance;

    // Create our main app component
    final mainApp = app;

    // Create root with this component
    await vdom.createRoot(mainApp);

    if (wasHotRestart) {}

    // Wait for the VDom to be ready
    vdom.isReady.whenComplete(() async {
      // Previously, we had to call `calculateLayout` manually.
      // Now, layout is automatically calculated when layout props change at the native side 🤯.
    });
  }
}

