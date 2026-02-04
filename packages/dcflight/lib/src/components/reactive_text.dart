/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';

/// Reactive text component that auto-updates when signal changes
/// This is a pure signals component - changes directly update the native view
class DCFReactiveText extends DCFStatelessComponent {
  /// Reactive content - can be a signal or computed value
  final dynamic content; // String | ReactiveSignal<String> | String Function()
  
  final DCFTextProps textProps;
  final DCFLayout layout;
  final DCFStyleSheet styleSheet;
  final Color? textColor;
  final Map<String, dynamic>? events;

  DCFReactiveText({
    required this.content,
    this.textProps = const DCFTextProps(),
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    this.textColor,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Merge styles just like regular DCFText
    final defaultTextStyleSheet = const DCFStyleSheet(backgroundColor: DCFColors.transparent);
    final mergedStyleSheet = defaultTextStyleSheet.merge(styleSheet);
    
    const defaultTextLayout = DCFLayout(
      flexShrink: 1,
      minWidth: 0,
    );
    final mergedLayout = defaultTextLayout.merge(layout);
    
    // Pass reactive content directly to props
    // The engine will handle signal tracking and subscriptions
    Map<String, dynamic> props = {
      'content': content, // Can be String, ReactiveSignal, or Function
      ...textProps.toMap(),
      ...mergedLayout.toMap(),
      ...mergedStyleSheet.toMap(),
      if (textColor != null) 'textColor': DCFColors.toNativeString(textColor!),
      '_systemVersion': SystemStateManager.version,
      ...(events ?? {}),
    };

    return DCFElement(
      type: 'Text',
      elementProps: props,
      children: [],
    );
  }
}
