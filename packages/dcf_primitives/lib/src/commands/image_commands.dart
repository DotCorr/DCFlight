/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for Image imperative control
/// These commands are passed as props and trigger native image actions without callbacks

/// Base class for all Image commands
abstract class ImageCommand {
  const ImageCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to update the image source
class SetImageCommand extends ImageCommand {
  final String imageSource; // URL, asset path, or base64 string
  final String? sourceType; // url, asset, base64
  final bool? animated; // Whether to animate the image change
  final double? duration; // Animation duration in seconds
  final String? transition; // Transition type (fade, slide, etc.)
  
  const SetImageCommand({
    required this.imageSource,
    this.sourceType,
    this.animated,
    this.duration,
    this.transition,
  });
  
  @override
  String get type => 'setImage';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'imageSource': imageSource,
      if (sourceType != null) 'sourceType': sourceType,
      if (animated != null) 'animated': animated,
      if (duration != null) 'duration': duration,
      if (transition != null) 'transition': transition,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetImageCommand && 
           other.imageSource == imageSource &&
           other.sourceType == sourceType &&
           other.animated == animated &&
           other.duration == duration &&
           other.transition == transition;
  }
  
  @override
  int get hashCode => Object.hash(imageSource, sourceType, animated, duration, transition);
  
  @override
  String toString() => 'SetImageCommand(imageSource: $imageSource, sourceType: $sourceType, animated: $animated, duration: $duration, transition: $transition)';
}

/// Command to clear image cache
class ClearCacheCommand extends ImageCommand {
  final String? imageUrl; // Specific image URL to clear (optional)
  final bool clearAll; // Whether to clear all cached images
  
  const ClearCacheCommand({
    this.imageUrl,
    this.clearAll = false,
  });
  
  @override
  String get type => 'clearCache';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'clearAll': clearAll,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClearCacheCommand && 
           other.imageUrl == imageUrl &&
           other.clearAll == clearAll;
  }
  
  @override
  int get hashCode => Object.hash(imageUrl, clearAll);
  
  @override
  String toString() => 'ClearCacheCommand(imageUrl: $imageUrl, clearAll: $clearAll)';
}

/// Command to preload an image
class PreloadImageCommand extends ImageCommand {
  final String imageSource; // URL or asset path
  final String? sourceType; // url, asset
  final int? priority; // Loading priority (1-10, higher is more important)
  
  const PreloadImageCommand({
    required this.imageSource,
    this.sourceType,
    this.priority,
  });
  
  @override
  String get type => 'preloadImage';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'imageSource': imageSource,
      if (sourceType != null) 'sourceType': sourceType,
      if (priority != null) 'priority': priority,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreloadImageCommand && 
           other.imageSource == imageSource &&
           other.sourceType == sourceType &&
           other.priority == priority;
  }
  
  @override
  int get hashCode => Object.hash(imageSource, sourceType, priority);
  
  @override
  String toString() => 'PreloadImageCommand(imageSource: $imageSource, sourceType: $sourceType, priority: $priority)';
}

/// Command to resize image
class ResizeImageCommand extends ImageCommand {
  final double width;
  final double height;
  final bool? maintainAspectRatio;
  final bool? animated; // Whether to animate the resize
  final double? duration; // Animation duration in seconds
  
  const ResizeImageCommand({
    required this.width,
    required this.height,
    this.maintainAspectRatio = true,
    this.animated,
    this.duration,
  });
  
  @override
  String get type => 'resizeImage';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'width': width,
      'height': height,
      if (maintainAspectRatio != null) 'maintainAspectRatio': maintainAspectRatio,
      if (animated != null) 'animated': animated,
      if (duration != null) 'duration': duration,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResizeImageCommand && 
           other.width == width &&
           other.height == height &&
           other.maintainAspectRatio == maintainAspectRatio &&
           other.animated == animated &&
           other.duration == duration;
  }
  
  @override
  int get hashCode => Object.hash(width, height, maintainAspectRatio, animated, duration);
  
  @override
  String toString() => 'ResizeImageCommand(width: $width, height: $height, maintainAspectRatio: $maintainAspectRatio, animated: $animated, duration: $duration)';
}

/// Command to apply image filter/effect
class ApplyImageFilterCommand extends ImageCommand {
  final String filterType; // blur, sepia, grayscale, brightness, contrast, etc.
  final double? intensity; // Filter intensity (0.0 to 1.0)
  final bool? animated; // Whether to animate the filter application
  final double? duration; // Animation duration in seconds
  
  const ApplyImageFilterCommand({
    required this.filterType,
    this.intensity,
    this.animated,
    this.duration,
  });
  
  @override
  String get type => 'applyImageFilter';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'filterType': filterType,
      if (intensity != null) 'intensity': intensity,
      if (animated != null) 'animated': animated,
      if (duration != null) 'duration': duration,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApplyImageFilterCommand && 
           other.filterType == filterType &&
           other.intensity == intensity &&
           other.animated == animated &&
           other.duration == duration;
  }
  
  @override
  int get hashCode => Object.hash(filterType, intensity, animated, duration);
  
  @override
  String toString() => 'ApplyImageFilterCommand(filterType: $filterType, intensity: $intensity, animated: $animated, duration: $duration)';
}
