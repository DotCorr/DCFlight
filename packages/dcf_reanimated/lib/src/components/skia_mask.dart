/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Mask component for masking content
class SkiaMask extends DCFStatelessComponent {
  /// Mask mode (alpha or luminance)
  final String? mode; // "alpha" or "luminance"
  
  /// Whether to clip the mask
  final bool? clip;
  
  /// Children to be masked
  final List<DCFComponentNode> children;
  
  /// Mask element (first child is the mask, rest are content)
  final DCFComponentNode? mask;
  
  SkiaMask({
    this.mode,
    this.clip,
    this.children = const [],
    this.mask,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    final allChildren = mask != null ? [mask!, ...children] : children;
    
    return DCFElement(
      type: 'SkiaMask',
      elementProps: {
        if (mode != null) 'mode': mode,
        if (clip != null) 'clip': clip,
      },
      children: allChildren,
    );
  }
}

