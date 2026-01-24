/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Utility to handle border layout by "inflating" padding.
/// 
/// Yoga's border property affects layout size but doesn't push children inward
/// if padding is 0. This utility automatically adds border width to padding
/// so children never overlap with the border.
class StyleWrapperUtil {
  /// Adjusts an element's props to account for border width in the layout.
  /// 
  /// Returns a new map of props with "inflated" padding.
  static Map<String, dynamic> wrapIfNeeded(Map<String, dynamic> props) {
    // 1. Extract border widths (default to 0)
    final double bw = _toDouble(props['borderWidth']);
    final double btw = _toDouble(props['borderTopWidth']) != 0 ? _toDouble(props['borderTopWidth']) : bw;
    final double brw = _toDouble(props['borderRightWidth']) != 0 ? _toDouble(props['borderRightWidth']) : bw;
    final double bbw = _toDouble(props['borderBottomWidth']) != 0 ? _toDouble(props['borderBottomWidth']) : bw;
    final double blw = _toDouble(props['borderLeftWidth']) != 0 ? _toDouble(props['borderLeftWidth']) : bw;

    // If no borders, return original props
    if (btw == 0 && brw == 0 && bbw == 0 && blw == 0) {
      return props;
    }

    // 2. Create a copy of props to modify
    final newProps = Map<String, dynamic>.from(props);

    // 3. Extract existing padding
    final double p = _toDouble(props['padding']);
    final double ph = _toDouble(props['paddingHorizontal']) != 0 ? _toDouble(props['paddingHorizontal']) : p;
    final double pv = _toDouble(props['paddingVertical']) != 0 ? _toDouble(props['paddingVertical']) : p;
    
    final double pt = _toDouble(props['paddingTop']) != 0 ? _toDouble(props['paddingTop']) : pv;
    final double pr = _toDouble(props['paddingRight']) != 0 ? _toDouble(props['paddingRight']) : ph;
    final double pb = _toDouble(props['paddingBottom']) != 0 ? _toDouble(props['paddingBottom']) : pv;
    final double pl = _toDouble(props['paddingLeft']) != 0 ? _toDouble(props['paddingLeft']) : ph;

    // 4. Inflate padding with border widths
    newProps['paddingTop'] = pt + btw;
    newProps['paddingRight'] = pr + brw;
    newProps['paddingBottom'] = pb + bbw;
    newProps['paddingLeft'] = pl + blw;

    // Clean up generic padding props to avoid conflicts
    newProps.remove('padding');
    newProps.remove('paddingHorizontal');
    newProps.remove('paddingVertical');

    return newProps;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
