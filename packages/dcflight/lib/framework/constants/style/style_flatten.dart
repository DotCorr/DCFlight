/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'style_properties.dart';

/// Flattens an array of style objects into a single aggregated style object.
///
/// This is useful when merging multiple styles, where later styles override earlier ones.
/// Style IDs are resolved to their full objects before merging.
///
/// Usage:
/// ```dart
/// final baseStyle = DCFStyleSheet(backgroundColor: Colors.white);
/// final overrideStyle = DCFStyleSheet(backgroundColor: Colors.blue);
/// final merged = flattenStyle([baseStyle, overrideStyle]);
/// // Result: backgroundColor is Colors.blue (override wins)
/// ```
///
/// You can also pass a single style:
/// ```dart
/// final style = DCFStyleSheet(backgroundColor: Colors.red);
/// final flattened = flattenStyle(style);
/// // Result: same style, but resolved if it has an ID
/// ```
///
/// Style precedence:
/// - Later styles override earlier ones
/// - Specific properties override general ones (e.g., borderTopWidth overrides borderWidth)
/// - backgroundGradient overrides backgroundColor
DCFStyleSheet? flattenStyle(dynamic style) {
  if (style == null) {
    return null;
  }

  // Single style object
  if (style is DCFStyleSheet) {
    return style;
  }

  // Array of styles - merge them
  if (style is List) {
    if (style.isEmpty) {
      return null;
    }

    DCFStyleSheet? result;
    for (final item in style) {
      if (item is DCFStyleSheet) {
        if (result == null) {
          result = item;
        } else {
          result = result.merge(item);
        }
      }
    }

    return result;
  }

  return null;
}

/// Flattens and merges multiple style objects into one.
///
/// This is a convenience function that ensures all styles are properly merged
/// with correct precedence rules.
///
/// Example:
/// ```dart
/// final merged = mergeStyles([
///   DCFStyleSheet(backgroundColor: Colors.white, borderRadius: 8),
///   DCFStyleSheet(backgroundColor: Colors.blue), // Overrides white
///   DCFStyleSheet(borderRadius: 12), // Overrides 8
/// ]);
/// // Result: backgroundColor=blue, borderRadius=12
/// ```
DCFStyleSheet mergeStyles(List<DCFStyleSheet> styles) {
  if (styles.isEmpty) {
    return const DCFStyleSheet();
  }

  DCFStyleSheet result = styles.first;
  for (var i = 1; i < styles.length; i++) {
    result = result.merge(styles[i]);
  }

  return result;
}
