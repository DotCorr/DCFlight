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

  /// NOTE: Color removed - use StyleSheet.primaryColor instead

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
    // Color removed - use StyleSheet.primaryColor
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
      ...eventMap,
    };

    // Color removed - native components use StyleSheet.primaryColor

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
        // Color removed
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
