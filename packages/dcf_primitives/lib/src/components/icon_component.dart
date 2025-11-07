/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
export 'package:dcf_primitives/src/components/dictionary/dcf_icons_dict.dart';

/// Icon load callback data
class DCFIconLoadData {
  /// Whether the load was successful
  final bool success;
  
  /// Timestamp of the load event
  final DateTime timestamp;

  DCFIconLoadData({
    required this.success,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFIconLoadData.fromMap(Map<dynamic, dynamic> data) {
    return DCFIconLoadData(
      success: data['success'] as bool,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Icon error callback data
class DCFIconErrorData {
  /// Error message
  final String message;
  
  /// Error code
  final String? code;
  
  /// Timestamp of the error
  final DateTime timestamp;

  DCFIconErrorData({
    required this.message,
    this.code,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFIconErrorData.fromMap(Map<dynamic, dynamic> data) {
    return DCFIconErrorData(
      message: data['message'] as String,
      code: data['code'] as String?,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Icon properties
class DCFIconProps extends Equatable {
  /// The name of the icon
  final String name;

  /// Size of the icon

  /// NOTE: Color removed - use StyleSheet.primaryColor instead

  /// Package where the icon is defined
  final String package;

  /// Whether to use adaptive theming
  final bool adaptive;

  /// Create icon props
  /// NOTE: Use StyleSheet.primaryColor for icon color instead of color prop
  const DCFIconProps({
    required this.name,
    // Color removed - use StyleSheet.primaryColor
    this.package = 'dcf_primitives',
    this.adaptive = true,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'package': package,
      'isRelativePath': false,
      'adaptive': adaptive,
      // Color removed - native components use StyleSheet.primaryColor
    };
  }

  @override
  List<Object?> get props => [
        name,
        // Color removed
        package,
        adaptive,
      ];
}

/// An icon component implementation using StatelessComponent
class DCFIcon extends DCFStatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// The icon properties
  final DCFIconProps iconProps;

  /// The layout properties
  final DCFLayout layout;

  /// The styleSheet properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Load event handler - receives type-safe icon load data
  final Function(DCFIconLoadData)? onLoad;

  /// Error event handler - receives type-safe error data
  final Function(DCFIconErrorData)? onError;

  /// Create an icon component
  DCFIcon({
    required this.iconProps,
    this.layout = const DCFLayout(height: 20, width: 20),
    this.styleSheet = const DCFStyleSheet(),
    this.onLoad,
    this.onError,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    Map<String, dynamic> eventMap = events ?? {};

    if (onLoad != null) {
      eventMap['onLoad'] = (Map<dynamic, dynamic> data) {
        onLoad!(DCFIconLoadData.fromMap(data));
      };
    }

    if (onError != null) {
      eventMap['onError'] = (Map<dynamic, dynamic> data) {
        onError!(DCFIconErrorData.fromMap(data));
      };
    }

    return DCFElement(
      type: 'DCFIcon',
      elementProps: {
        ...iconProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        iconProps,
        layout,
        styleSheet,
        events,
        onLoad,
        onError,
        key,
      ];
}
