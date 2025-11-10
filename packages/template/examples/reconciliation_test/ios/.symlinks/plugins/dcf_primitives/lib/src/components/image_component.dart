/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Image load callback data
class DCFImageLoadData {
  /// Whether the load was successful
  final bool success;
  
  /// Image dimensions
  final double width;
  final double height;
  
  /// Timestamp of the load event
  final DateTime timestamp;

  DCFImageLoadData({
    required this.success,
    required this.width,
    required this.height,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFImageLoadData.fromMap(Map<dynamic, dynamic> data) {
    return DCFImageLoadData(
      success: data['success'] as bool,
      width: (data['width'] as num).toDouble(),
      height: (data['height'] as num).toDouble(),
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Image error callback data
class DCFImageErrorData {
  /// Error message
  final String message;
  
  /// Error code
  final String? code;
  
  /// Timestamp of the error
  final DateTime timestamp;

  DCFImageErrorData({
    required this.message,
    this.code,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from raw map data
  factory DCFImageErrorData.fromMap(Map<dynamic, dynamic> data) {
    return DCFImageErrorData(
      message: data['message'] as String,
      code: data['code'] as String?,
      timestamp: data['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

/// Image properties
class DCFImageProps {
  /// The image source URI (can be a network URL or local resource)
  final String source;

  /// Resize mode for the image - type-safe enum
  final DCFImageResizeMode? resizeMode;

  /// Whether to fade in the image when loaded
  final bool? fadeDuration;

  /// Placeholder image to show while loading
  final String? placeholder;


  /// Create image props
  const DCFImageProps({
    required this.source,
    this.resizeMode,
    this.fadeDuration,
    this.placeholder,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'isRelativePath': false,
      if (resizeMode != null) 'resizeMode': resizeMode!.name,
      if (fadeDuration != null) 'fadeDuration': fadeDuration,
      if (placeholder != null) 'placeholder': placeholder,
    };
  }
}

/// An image component implementation using StatelessComponent
class DCFImage extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// The image properties
  final DCFImageProps imageProps;

  /// The layout properties
  final DCFLayout layout;

  /// The styleSheet properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Load event handler - receives type-safe image load data
  final Function(DCFImageLoadData)? onLoad;

  /// Error event handler - receives type-safe error data
  final Function(DCFImageErrorData)? onError;

  /// Create an image component
  DCFImage({
    required this.imageProps,
    this.layout = const DCFLayout(height: 50, width: 200),
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
        onLoad!(DCFImageLoadData.fromMap(data));
      };
    }

    if (onError != null) {
      eventMap['onError'] = (Map<dynamic, dynamic> data) {
        onError!(DCFImageErrorData.fromMap(data));
      };
    }

    Map<String, dynamic> props = {
      ...imageProps.toMap(),
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'Image',
      elementProps: props,
      children: [],
    );
  }
}

/// Image resize modes - type-safe options for image resizing
enum DCFImageResizeMode {
  cover,
  contain,
  stretch,
  repeat,
  center,
}

extension DCFImageResizeModeExtension on DCFImageResizeMode {
  String get name {
    switch (this) {
      case DCFImageResizeMode.cover:
        return 'cover';
      case DCFImageResizeMode.contain:
        return 'contain';
      case DCFImageResizeMode.stretch:
        return 'stretch';
      case DCFImageResizeMode.repeat:
        return 'repeat';
      case DCFImageResizeMode.center:
        return 'center';
    }
  }
}
