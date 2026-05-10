/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

// DCFlight – flutter_zero runtime, fully diverged from Google Flutter.
// No package:flutter imports exist in this library.

library;

import 'dart:io';

// ─── Public API exports ────────────────────────────────────────────────────
export 'framework/constants/style/dcf_colors.dart';
export 'framework/theme/dcf_theme.dart';
export 'framework/utils/dcf_dart_compat.dart'; // Color, kDebugMode, debugPrint, kIsWeb

export 'dart:async';
export 'framework/renderer/engine/index.dart';

export 'framework/renderer/interface/interface.dart';
export 'framework/renderer/interface/native_platform.dart';
export 'framework/events/event_registry.dart';

// Reactive signals – pure fine-grained reactivity (RECOMMENDED API)
export 'framework/hooks/reactive_signal.dart'
    show ReactiveSignal, ComputedSignal, signal, computed, effect;
export 'framework/worklets/worklet.dart';
export 'framework/constants/layout/yoga_enums.dart';
export 'framework/constants/layout/layout_properties.dart';
export 'framework/constants/layout/layout_config.dart';
export 'package:dcflight/framework/constants/layout/absolute_layout.dart';
export 'framework/constants/style/style_properties.dart';
export 'framework/constants/style/gradient.dart';
export 'framework/constants/style/color_utils.dart';

export 'framework/utils/screen_utilities.dart';
export 'framework/utils/font_scale.dart';
export 'framework/utils/system_state_manager.dart';
export 'framework/utils/dcf_logger.dart';

export 'framework/devtools/hot_restart.dart';
export 'framework/devtools/hot_reload.dart' show HotReloadDetector, triggerManualHotReload;
export 'framework/protocol/component_registry.dart';
export 'framework/protocol/plugin_protocol.dart';
export 'src/components/portal/dcf_portal.dart';
export 'src/components/portal/dcf_portal_target.dart';
export 'framework/utils/widget_to_dcf_adaptor.dart';
export 'src/components/view_component.dart';
export 'src/components/text_component.dart';
export 'src/components/reactive_text.dart';
export 'src/components/scroll_view_component.dart';
export 'src/components/dc_logo.dart';
export 'src/components/error_boundary.dart';
export 'src/components/touchable_opacity_component.dart';
export 'src/components/button_component.dart';
export 'framework/renderer/interface/tunnel.dart';

export 'package:equatable/equatable.dart';

// ─── Internal imports ──────────────────────────────────────────────────────
import 'src/components/component_node.dart';
import 'src/components/core_wrapper.dart';
import 'framework/renderer/engine/engine_api.dart';
import 'framework/renderer/interface/interface.dart';
import 'framework/utils/screen_utilities.dart';
import 'framework/protocol/plugin_protocol.dart';
import 'framework/devtools/hot_restart.dart';
import 'framework/devtools/hot_reload.dart';
import 'framework/utils/dcf_logger.dart';
import 'framework/utils/dcf_dart_compat.dart' show kDebugMode;

// ─── DCFlight ─────────────────────────────────────────────────────────────

/// DCFlight Framework entry points.
class DCFlight {
  /// Set the global log level for DCFlight framework.
  static void setLogLevel(DCFLogLevel level) => DCFLogger.setLevel(level);

  /// Get the current log level.
  static DCFLogLevel get logLevel => DCFLogger.currentLevel;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  static Future<bool> _initialize() async {
    // flutter_zero: no WidgetsFlutterBinding needed – the engine starts Dart
    // directly and the platform bridge initialises from the native side.
    final bridge = PlatformInterface.instance;
    await bridge.initialize();

    await DCFEngineAPI.instance.init(bridge);
    PluginRegistry.instance.registerPlugin(CorePlugin.instance);

    return true;
  }

  static String _getProjectId() {
    try {
      final currentDir = Directory.current;
      final pubspecFile = File('${currentDir.path}/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final nameMatch = RegExp(r'name:\s*([^\s]+)').firstMatch(content);
        if (nameMatch != null) return nameMatch.group(1)!;
      }
      return currentDir.path.split('/').last;
    } catch (_) {
      return 'unknown_project';
    }
  }

  // ---------------------------------------------------------------------------
  // go() – start the application
  // ---------------------------------------------------------------------------

  /// Start the application with the given root [DCFComponentNode].
  ///
  /// This is the only call you need in [main()]. DCFlight automatically wraps
  /// the tree in an error boundary and a system-change listener.
  static Future<void> go({required DCFComponentNode app}) async {
    await _initialize();

    DCFLogger.setInstanceId(DateTime.now().millisecondsSinceEpoch.toString());
    DCFLogger.setProjectId(_getProjectId());

    // ── Hot restart detection (uses session tokens via FFI/JNI) ──────────────
    final wasHotRestart = await HotRestartDetector.detectAndCleanup();

    final engine = DCFEngineAPI.instance;

    if (wasHotRestart) {
      await engine.forceFullTreeReRender();
    }

    // ── Install flutter_zero hot restart listener ─────────────────────────────
    // Fires before main() reruns so we can clean up native state.
    installHotRestartListener(() async {
      await HotReloadDetector.instance.handleHotReload();
    });

    // ── Build root ────────────────────────────────────────────────────────────
    // CoreWrapper listens to OS-level changes (font scale, language, etc.)
    await engine.createRoot(CoreWrapper(app));

    // Defer one dimension refresh so native is ready.
    Future.delayed(const Duration(milliseconds: 250), () {
      ScreenUtilities.instance.refreshDimensions();
    });

    if (kDebugMode) {
      HotReloadDetector.instance.initialize();
    }
  }
}
