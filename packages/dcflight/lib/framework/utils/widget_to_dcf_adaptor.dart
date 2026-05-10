/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';

/// Legacy adaptor for embedding Flutter widgets inside DCFlight.
///
/// DCFlight now runs on the flutter_zero runtime (no dart:ui rendering) so this
/// adaptor is permanently disabled. It is kept as a stub so that any existing
/// call sites produce a clear [UnsupportedError] rather than a missing-symbol
/// compile error.
class WidgetToDCFAdaptor extends DCFStatelessComponent {
  // ignore: unused_field
  final dynamic _unused;
  final DCFLayout? layout;
  final DCFStyleSheet? styleSheet;

  WidgetToDCFAdaptor.builder({
    required dynamic widgetBuilder,
    this.layout,
    this.styleSheet,
    super.key,
  }) : _unused = widgetBuilder;

  WidgetToDCFAdaptor({
    required dynamic widget,
    this.layout,
    this.styleSheet,
    super.key,
  }) : _unused = widget;

  static void clearAllForHotRestart() {
    // no-op – no mixed widget state exists.
  }

  @override
  DCFComponentNode render() {
    throw UnsupportedError(
      'WidgetToDCFAdaptor is not available on the flutter_zero runtime. '
      'DCFlight renders native views exclusively via FFI (iOS) and JNI (Android).',
    );
  }
}
