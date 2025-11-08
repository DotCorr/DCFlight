/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// 🚀 DCF Spinner/Activity Indicator Component
///
/// A spinner component that provides native platform activity indicator behavior.
class DCFSpinner extends DCFStatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// Whether the spinner is animating
  final bool animating;

  /// Size style of the spinner
  final String style;

  /// Explicit color override: spinnerColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for spinner
  final Color? spinnerColor;

  /// Whether to hide when stopped
  final bool hidesWhenStopped;


  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  DCFSpinner({
    super.key,
    this.animating = true,
    this.style = 'medium',
    this.spinnerColor,
    this.hidesWhenStopped = true,
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    this.events,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    Map<String, dynamic> props = {
      'animating': animating,
      'style': style,
      'hidesWhenStopped': hidesWhenStopped,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      if (spinnerColor != null) 'spinnerColor': DCFColors.toNativeString(spinnerColor!),
      ...eventMap,
    };

    return DCFElement(
      type: 'Spinner',
      elementProps: props,
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        animating,
        style,
        spinnerColor,
        hidesWhenStopped,
        layout,
        styleSheet,
        events,
        key,
      ];
}

/// Spinner style constants
class DCFSpinnerStyle {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
}
