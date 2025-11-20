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
export 'framework/devtools/hot_reload_listener.dart';

export 'framework/renderer/interface/interface.dart';
export 'framework/renderer/interface/interface_impl.dart';

export 'framework/constants/layout/yoga_enums.dart';
export 'framework/constants/layout/layout_properties.dart';
export 'framework/constants/layout/layout_config.dart';
export 'package:dcflight/framework/constants/layout/absolute_layout.dart';
export 'framework/constants/style/style_properties.dart';
export 'framework/constants/style/color_utils.dart';

export 'framework/utils/screen_utilities.dart';
export 'framework/utils/dcf_logger.dart';

export 'framework/devtools/hot_restart.dart';
export 'framework/protocol/component_registry.dart';
export 'framework/protocol/plugin_protocol.dart';
export 'framework/components/portal/dcf_portal.dart';
export 'framework/components/portal/dcf_portal_target.dart';
export 'framework/utils/widget_to_dcf_adaptor.dart';
export 'framework/worklets/worklet.dart';
import 'package:dcflight/framework/components/component_node.dart';

import 'framework/renderer/engine/engine_api.dart';
import 'framework/renderer/interface/interface.dart';
import 'framework/utils/screen_utilities.dart';
import 'framework/protocol/plugin_protocol.dart';
export 'framework/renderer/interface/tunnel.dart';
import 'framework/devtools/hot_restart.dart';
import 'framework/utils/dcf_logger.dart';
import 'framework/devtools/hot_reload_listener.dart';
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

    final bridge = NativeBridgeFactory.create();
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
  static Future<void> go({required DCFComponentNode app}) async {
    await _initialize();

    DCFLogger.setInstanceId(DateTime.now().millisecondsSinceEpoch.toString());
    DCFLogger.setProjectId(_getProjectId());

    if (!const bool.fromEnvironment('dart.vm.product')) {
      print('🔥 DCFlight: Starting hot reload listener...');
      await HotReloadListener.start();
      print('🔥 DCFlight: Hot reload listener started successfully');
    }

    final wasHotRestart = await HotRestartDetector.detectAndCleanup();

    final vdom = DCFEngineAPI.instance;

    final mainApp = app;

    await vdom.createRoot(mainApp);

    if (wasHotRestart) {}

    vdom.isReady.whenComplete(() async {});
  }
}
