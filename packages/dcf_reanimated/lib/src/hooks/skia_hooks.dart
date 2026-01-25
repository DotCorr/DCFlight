/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart';

/// Hook for path interpolation
/// Interpolates between different path values based on progress
class SkiaPathInterpolation {
  final double progress;
  final List<double> inputRange;
  final List<String> outputRange; // SVG path strings
  
  SkiaPathInterpolation({
    required this.progress,
    required this.inputRange,
    required this.outputRange,
  });
  
  /// Get interpolated path string
  String getPath() {
    if (inputRange.isEmpty || outputRange.isEmpty) return "";
    if (progress <= inputRange.first) return outputRange.first;
    if (progress >= inputRange.last) return outputRange.last;
    
    // Find the range
    for (int i = 0; i < inputRange.length - 1; i++) {
      if (progress >= inputRange[i] && progress <= inputRange[i + 1]) {
        final t = (progress - inputRange[i]) / (inputRange[i + 1] - inputRange[i]);
        // Simple interpolation - in production would use proper path interpolation
        return outputRange[i]; // Placeholder
      }
    }
    
    return outputRange.last;
  }
}

/// Hook for path value animation
class SkiaPathValue {
  final String Function(String path) transform;
  final String defaultValue;
  
  SkiaPathValue({
    required this.transform,
    this.defaultValue = "",
  });
  
  String getPath(String basePath) {
    return transform(basePath);
  }
}

/// Hook for clock (time in milliseconds)
class SkiaClock {
  final int startTime;
  
  SkiaClock() : startTime = DateTime.now().millisecondsSinceEpoch;
  
  int get value => DateTime.now().millisecondsSinceEpoch - startTime;
}

/// Hook for texture creation from React elements
/// Note: This would require native implementation
class SkiaTexture {
  final dynamic source; // Image source, picture, or element
  final Size? size;
  
  SkiaTexture({
    required this.source,
    this.size,
  });
}

/// Hook for image as texture
class SkiaImageAsTexture {
  final dynamic imageSource; // Asset path, network URL, etc.
  
  SkiaImageAsTexture({
    required this.imageSource,
  });
}

/// Hook for picture as texture
class SkiaPictureAsTexture {
  final dynamic picture; // SkPicture object
  final Size? size;
  
  SkiaPictureAsTexture({
    required this.picture,
    this.size,
  });
}

/// Hook for rect buffer (for Atlas API)
class SkiaRectBuffer {
  final int count;
  final void Function(Rect rect, int index) initializer;
  final List<Rect> _rects = [];
  
  SkiaRectBuffer({
    required this.count,
    required this.initializer,
  }) {
    for (int i = 0; i < count; i++) {
      final rect = Rect.zero;
      initializer(rect, i);
      _rects.add(rect);
    }
  }
  
  List<Rect> get rects => _rects;
}

/// Hook for RSXform buffer (rotate-scale transforms)
class SkiaRSXformBuffer {
  final int count;
  final void Function(RSXform xform, int index) initializer;
  final List<RSXform> _xforms = [];
  
  SkiaRSXformBuffer({
    required this.count,
    required this.initializer,
  }) {
    for (int i = 0; i < count; i++) {
      final xform = RSXform(0, 0, 0, 0);
      initializer(xform, i);
      _xforms.add(xform);
    }
  }
  
  List<RSXform> get xforms => _xforms;
}

/// Rotate-scale transform
class RSXform {
  double scos;
  double ssin;
  double tx;
  double ty;
  
  RSXform(this.scos, this.ssin, this.tx, this.ty);
  
  void set(double scos, double ssin, double tx, double ty) {
    this.scos = scos;
    this.ssin = ssin;
    this.tx = tx;
    this.ty = ty;
  }
}

