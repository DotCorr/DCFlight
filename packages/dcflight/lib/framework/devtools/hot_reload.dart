/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:dcflight/framework/renderer/engine/engine_api.dart';
import 'package:dcflight/framework/utils/dcf_dart_compat.dart' show kDebugMode;
import 'package:dcflight/framework/utils/dcf_logger.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_ffi_wrapper.dart';
import 'package:dcflight/framework/renderer/interface/dcflight_jni_wrapper.dart'
    show DCFlightJniWrapper;

/// Hot reload / hot restart handling for the flutter_zero runtime.
///
/// Flutter Zero retains [PlatformDispatcher] from dart:ui and adds
/// [PlatformDispatcher.instance.registerHotRestartListener] for restart events.
/// We use that for restart cleanup and keep our own [HotReloadDetector] for
/// explicit reload triggering (invoked by the engine when needed).
class HotReloadDetector {
  static HotReloadDetector? _instance;
  static HotReloadDetector get instance {
    _instance ??= HotReloadDetector._();
    return _instance!;
  }

  bool _isInitialized = false;

  HotReloadDetector._();

  /// Initialize the hot reload detector.
  void initialize() {
    if (!kDebugMode || _isInitialized) return;
    _isInitialized = true;
  }

  /// Cleanup.
  void dispose() {
    if (!_isInitialized) return;
    _isInitialized = false;
  }

  /// Handle hot reload – clear native views and re-sync the engine root.
  Future<void> handleHotReload() async {
    if (!kDebugMode) return;
    try {
      await _cleanupNativeViews();
      final engine = DCFEngineAPI.instance;
      await engine.isReady;
      await engine.recreateRootNativeViews();
    } catch (e, stackTrace) {
      DCFLogger.error('Failed to handle hot reload: $e', tag: 'HOT_RELOAD');
      // ignore: avoid_print
      print('Hot reload error: $e\n$stackTrace');
    }
  }

  Future<void> _cleanupNativeViews() async {
    try {
      if (Platform.isIOS) {
        await DCFlightFfiWrapper.cleanupViews();
      } else if (Platform.isAndroid) {
        await DCFlightJniWrapper.cleanupViews();
      }
    } catch (_) {
      // Non-critical.
    }
  }
}

/// Install flutter_zero's hot restart listener via [PlatformDispatcher].
///
/// The callback fires before Dart re-runs [main()] on hot restart so we can
/// clean up native state first.
void installHotRestartListener(Future<void> Function() onRestart) {
  if (!kDebugMode) return;
  try {
    PlatformDispatcher.instance.registerHotRestartListener(() {
      onRestart().catchError((e) {
        // ignore: avoid_print
        print('[DCFlight] Hot restart cleanup error: $e');
      });
    });
  } catch (_) {
    // PlatformDispatcher may not expose this API in all engine variants –
    // fall back silently.
  }
}

/// Manually trigger a hot reload cycle (for testing / tooling).
void triggerManualHotReload() {
  if (kDebugMode) {
    HotReloadDetector.instance.handleHotReload().catchError((e) {
      // ignore: avoid_print
      print('Hot reload error: $e');
    });
  }
}
