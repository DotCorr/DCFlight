/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Helper to collect shape data from Canvas children
class SkiaShapeCollector {
  /// Collect all shape elements from children and serialize them
  static List<Map<String, dynamic>> collectShapes(List<DCFComponentNode> children) {
    final shapes = <Map<String, dynamic>>[];
    
    for (final child in children) {
      if (child is DCFElement) {
        final shapeData = _extractShapeData(child);
        if (shapeData != null) {
          shapes.add(shapeData);
        }
        
        // Recursively collect from nested children (for Groups)
        if (child.children.isNotEmpty) {
          shapes.addAll(collectShapes(child.children));
        }
      }
    }
    
    return shapes;
  }
  
  /// Extract shape data from a DCFElement
  static Map<String, dynamic>? _extractShapeData(DCFElement element) {
    final type = element.type;
    
    // Only process Skia shape types
    if (!type.startsWith('Skia')) {
      return null;
    }
    
    final props = Map<String, dynamic>.from(element.elementProps);
    props['_type'] = type;
    
    return props;
  }
}

