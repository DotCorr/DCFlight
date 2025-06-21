/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';
import '../commands/image_commands.dart';

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
  
  /// Whether to use adaptive theming
  final bool adaptive;
  
  /// Create image props
  const DCFImageProps({
    required this.source,
    this.resizeMode,
    this.fadeDuration,
    this.placeholder,
    this.adaptive = true,
  });
  
  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'isRelativePath': false,
      'adaptive': adaptive,
      if (resizeMode != null) 'resizeMode': resizeMode!.name,
      if (fadeDuration != null) 'fadeDuration': fadeDuration,
      if (placeholder != null) 'placeholder': placeholder,
    };
  }
}

/// An image component implementation using StatelessComponent
class DCFImage extends StatelessComponent {
  /// The image properties
  final DCFImageProps imageProps;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The styleSheet properties
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;
  
  /// Load event handler - receives Map<dynamic, dynamic> with image load data
  final Function(Map<dynamic, dynamic>)? onLoad;
  
  /// Error event handler - receives Map<dynamic, dynamic> with error data
  final Function(Map<dynamic, dynamic>)? onError;
  
  /// Command to execute on the Image (replaces imperative method calls)
  /// Commands are processed immediately by native code and don't trigger re-renders
  final ImageCommand? command;
  
  /// Create an image component
  DCFImage({
    required this.imageProps,
       this.layout = const LayoutProps(
     height: 50,width: 200
    ),
    this.styleSheet = const StyleSheet(),
    this.onLoad,
    this.onError,
    this.events,
    this.command,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};
    
    if (onLoad != null) {
      eventMap['onLoad'] = onLoad;
    }
    
    if (onError != null) {
      eventMap['onError'] = onError;
    }

    // Serialize command if provided
    Map<String, dynamic> props = {
      ...imageProps.toMap(),
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };
    
    // Add command to props if provided - this enables the new prop-based pattern
    if (command != null) {
      props['command'] = command!.toMap();
    }

    return DCFElement(
      type: 'Image',
      props: props,
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
