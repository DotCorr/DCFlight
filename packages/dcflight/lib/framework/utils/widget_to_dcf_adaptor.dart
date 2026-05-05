/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:flutter/widgets.dart';
import 'package:dcflight/dcflight.dart';

/// Legacy adaptor for embedding Flutter widgets inside DCFlight.
///
/// DCFlight now standardizes on native rendering only. Mixed Flutter-widget
/// embedding depended on platform channels and is intentionally disabled.
class WidgetToDCFAdaptor extends DCFStatelessComponent {
  /// Builder function that creates the widget - called on every render to get fresh state
  final Widget Function() widgetBuilder;
  
  /// Layout properties
  final DCFLayout? layout;
  
  /// Style properties
  final DCFStyleSheet? styleSheet;
  
  /// Create a widget adaptor with a builder (recommended - widget rebuilds on state changes)
  WidgetToDCFAdaptor.builder({
    required this.widgetBuilder,
    this.layout,
    this.styleSheet,
    super.key,
  });
  
  /// Create a widget adaptor with a static widget (widget won't update on state changes)
  /// Use WidgetToDCFAdaptor.builder() for reactive widgets
  WidgetToDCFAdaptor({
    required Widget widget,
    this.layout,
    this.styleSheet,
    super.key,
  }) : widgetBuilder = (() => widget);
  
  static void clearAllForHotRestart() {
    // Intentionally a no-op. The adaptor is disabled and no mixed widget state is kept.
  }
  
  @override
  DCFComponentNode render() {
    throw UnsupportedError(
      'WidgetToDCFAdaptor was removed from the active runtime because it relied on platform channels. '
      'DCFlight now supports native rendering only through FFI on iOS and JNI on Android.',
    );
  }
}
