/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Backdrop blur filter
class SkiaBackdropBlur extends DCFStatelessComponent {
  final double blur;
  final String? style; // normal, solid, outer, inner
  
  SkiaBackdropBlur({
    required this.blur,
    this.style,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaBackdropBlur',
      elementProps: {
        'blur': blur,
        if (style != null) 'style': style,
      },
      children: const [],
    );
  }
}

/// Backdrop color matrix filter
class SkiaBackdropColorMatrix extends DCFStatelessComponent {
  /// 5x4 color matrix (20 values)
  final List<double> matrix;
  
  SkiaBackdropColorMatrix({
    required this.matrix,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'SkiaBackdropColorMatrix',
      elementProps: {
        'matrix': matrix,
      },
      children: const [],
    );
  }
}

