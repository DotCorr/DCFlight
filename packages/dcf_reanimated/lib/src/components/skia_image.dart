/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'skia_shapes.dart';

/// Image component for rendering images
class SkiaImage extends SkiaShape {
  /// Image source (asset path, network URL, or image data)
  final dynamic image;
  
  /// Position and size
  final double x;
  final double y;
  final double? width;
  final double? height;
  
  /// Fit mode (contain, cover, fill, fitHeight, fitWidth, scaleDown, none)
  final String? fit;
  
  /// Image alignment
  final String? alignment; // center, topLeft, topRight, etc.
  
  SkiaImage({
    required this.image,
    required this.x,
    required this.y,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    super.color,
    super.opacity,
    super.blendMode,
    super.antiAlias,
    super.zIndex,
    super.children,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaImage',
      elementProps: {
        'image': image is String ? image : image.toString(),
        'x': x,
        'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (fit != null) 'fit': fit,
        if (alignment != null) 'alignment': alignment,
        ...getPaintProps(),
      },
      children: children,
    );
  }
}

