/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Slider value change callback data
class DCFSliderValueData {
  /// Current slider value (0.0 to 1.0)
  final double value;
  
  /// Whether the change was from user interaction
  final bool fromUser;
  
  /// Timestamp of the change
  final DateTime timestamp;

  DCFSliderValueData({
    required this.value,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFSliderValueData.fromMap(Map<dynamic, dynamic> data) {
    return DCFSliderValueData(
      value: (data['value'] as num).toDouble(),
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Slider sliding start callback data
class DCFSliderStartData {
  /// Whether the start was from user interaction
  final bool fromUser;
  
  /// Timestamp of the start
  final DateTime timestamp;

  DCFSliderStartData({
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFSliderStartData.fromMap(Map<dynamic, dynamic> data) {
    return DCFSliderStartData(
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Slider sliding complete callback data
class DCFSliderCompleteData {
  /// Final slider value (0.0 to 1.0)
  final double value;
  
  /// Whether the completion was from user interaction
  final bool fromUser;
  
  /// Timestamp of the completion
  final DateTime timestamp;

  DCFSliderCompleteData({
    required this.value,
    this.fromUser = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFSliderCompleteData.fromMap(Map<dynamic, dynamic> data) {
    return DCFSliderCompleteData(
      value: (data['value'] as num).toDouble(),
      fromUser: data['fromUser'] as bool? ?? true,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// 🚀 DCF Slider Component
///
/// A slider component that provides native platform behavior.
class DCFSlider extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.immediate;

  /// Current value of the slider
  final double value;

  /// Minimum value of the slider
  final double minimumValue;

  /// Maximum value of the slider
  final double maximumValue;

  /// Step value for discrete increments
  final double? step;

  /// Called when slider value changes
  final Function(DCFSliderValueData)? onValueChange;

  /// Called when user starts sliding
  final Function(DCFSliderStartData)? onSlidingStart;

  /// Called when user finishes sliding
  final Function(DCFSliderCompleteData)? onSlidingComplete;

  /// Whether the slider is disabled
  final bool disabled;

  /// Explicit color override: minimumTrackColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for minimum track
  final Color? minimumTrackColor;

  /// Explicit color override: maximumTrackColor (overrides StyleSheet.secondaryColor)
  /// If provided, this will override the semantic secondaryColor for maximum track
  final Color? maximumTrackColor;

  /// Explicit color override: thumbColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for thumb
  final Color? thumbColor;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  DCFSlider({
    super.key,
    required this.value,
    this.minimumValue = 0.0,
    this.maximumValue = 1.0,
    this.step,
    this.onValueChange,
    this.onSlidingStart,
    this.onSlidingComplete,
    this.disabled = false,
    this.minimumTrackColor,
    this.maximumTrackColor,
    this.thumbColor,
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    this.events,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    if (onValueChange != null) {
      eventMap['onValueChange'] = (Map<dynamic, dynamic> data) {
        onValueChange!(DCFSliderValueData.fromMap(data));
      };
    }

    if (onSlidingStart != null) {
      eventMap['onSlidingStart'] = (Map<dynamic, dynamic> data) {
        onSlidingStart!(DCFSliderStartData.fromMap(data));
      };
    }

    if (onSlidingComplete != null) {
      eventMap['onSlidingComplete'] = (Map<dynamic, dynamic> data) {
        onSlidingComplete!(DCFSliderCompleteData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
      'value': value,
      'minimumValue': minimumValue,
      'maximumValue': maximumValue,
      'disabled': disabled,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      if (minimumTrackColor != null) 'minimumTrackColor': DCFColors.toNativeString(minimumTrackColor!),
      if (maximumTrackColor != null) 'maximumTrackColor': DCFColors.toNativeString(maximumTrackColor!),
      if (thumbColor != null) 'thumbColor': DCFColors.toNativeString(thumbColor!),
      ...eventMap,
    };

    if (step != null) {
      props['step'] = step;
    }

    return DCFElement(
      type: 'Slider',
      elementProps: props,
      children: [],
    );
  }
}
