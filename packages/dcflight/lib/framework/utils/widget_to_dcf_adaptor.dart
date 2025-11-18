/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/widgets.dart';
import 'package:dcflight/dcflight.dart';

/// Adaptor to embed Flutter widgets directly into DCFlight native components
/// 
/// This directly embeds Flutter's rendering pipeline into native components
/// without using platform views, providing high performance integration.
class WidgetToDCFAdaptor extends DCFStatelessComponent {
  /// The Flutter widget to embed
  final Widget widget;
  
  /// Layout properties
  final DCFLayout? layout;
  
  /// Style properties
  final DCFStyleSheet? styleSheet;
  
  /// Create a widget adaptor
  WidgetToDCFAdaptor({
    required this.widget,
    this.layout,
    this.styleSheet,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    final nativeProps = <String, dynamic>{
      "widgetType": widget.runtimeType.toString(),
    };
    
    // Store widget data - the native side will use Flutter's rendering pipeline
    if (layout != null) {
      nativeProps.addAll(layout!.toMap());
    }
    
    if (styleSheet != null) {
      nativeProps.addAll(styleSheet!.toMap());
    }
    
    return DCFElement(
      type: "FlutterWidget",
      elementProps: nativeProps,
      children: [],
    );
  }
}

/// Helper to create a widget adaptor with a builder
WidgetToDCFAdaptor widgetToDCF({
  required Widget Function() builder,
  DCFLayout? layout,
  DCFStyleSheet? styleSheet,
  String? key,
}) {
  return WidgetToDCFAdaptor(
    widget: builder(),
    layout: layout,
    styleSheet: styleSheet,
    key: key,
  );
}

