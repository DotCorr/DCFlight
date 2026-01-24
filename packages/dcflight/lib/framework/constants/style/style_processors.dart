/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/material.dart';

/// Style processors normalize and preprocess style values before they're sent to native.
/// This ensures consistent behavior across platforms and validates input values.
///
/// Usage:
/// ```dart
/// final processedColor = processColor(Colors.blue);
/// final processedTransform = processTransform([{'rotate': '45deg'}]);
/// ```

/// Processes color values into a normalized format for native platforms.
///
/// Supports multiple color formats:
/// - Flutter Color objects
/// - Hex strings: '#ff0000', '#ff0000ff', '#f00'
/// - RGB strings: 'rgb(255, 0, 0)'
/// - RGBA strings: 'rgba(255, 0, 0, 1.0)'
/// - HSL strings: 'hsl(0, 100%, 50%)'
/// - HSLA strings: 'hsla(0, 100%, 50%, 1.0)'
/// - Named colors: 'red', 'blue', 'transparent', etc.
///
/// Returns a 32-bit integer in ARGB format (0xAARRGGBB) for native platforms.
/// Returns null if color cannot be parsed.
///
/// Example:
/// ```dart
/// processColor(Colors.blue)           // 0xFF0000FF
/// processColor('#ff0000')            // 0xFFFF0000
/// processColor('rgb(255, 0, 0)')     // 0xFFFF0000
/// processColor('transparent')         // 0x00000000
/// ```
int? processColor(dynamic color) {
  if (color == null) return null;

  // Flutter Color object
  if (color is Color) {
    return color.value; // Already in ARGB format
  }

  // String color
  if (color is String) {
    return normalizeColor(color);
  }

  // Integer color (already processed)
  if (color is int) {
    // Validate it's a 32-bit unsigned integer
    if (color >= 0 && color <= 0xFFFFFFFF) {
      return color;
    }
  }

  return null;
}

/// Normalizes color strings to 32-bit ARGB integers.
///
/// Supports all CSS color formats plus platform-specific formats.
/// This is the core color parsing logic used by processColor().
///
/// Example:
/// ```dart
/// normalizeColor('#ff0000')        // 0xFFFF0000
/// normalizeColor('rgb(255,0,0)')    // 0xFFFF0000
/// normalizeColor('transparent')    // 0x00000000
/// ```
int? normalizeColor(String color) {
  final trimmed = color.trim().toLowerCase();

  // Handle platform-specific prefix (dcf:)
  if (trimmed.startsWith('dcf:')) {
    return normalizeColor(trimmed.substring(4));
  }

  // Transparent
  if (trimmed == 'transparent') {
    return 0x00000000;
  }

  // Named colors
  final namedColor = _namedColors[trimmed];
  if (namedColor != null) {
    return namedColor;
  }

  // Hex colors: #rgb, #rrggbb, #rrggbbaa
  if (trimmed.startsWith('#')) {
    return _parseHexColor(trimmed);
  }

  // RGB/RGBA: rgb(r, g, b) or rgba(r, g, b, a)
  final rgbMatch = RegExp(r'rgba?\(([^)]+)\)').firstMatch(trimmed);
  if (rgbMatch != null) {
    return _parseRgbColor(rgbMatch.group(1)!);
  }

  // HSL/HSLA: hsl(h, s%, l%) or hsla(h, s%, l%, a)
  final hslMatch = RegExp(r'hsla?\(([^)]+)\)').firstMatch(trimmed);
  if (hslMatch != null) {
    return _parseHslColor(hslMatch.group(1)!);
  }

  return null;
}

/// Parses hex color strings (#rgb, #rrggbb, #rrggbbaa).
int? _parseHexColor(String hex) {
  final hexValue = hex.substring(1);
  
  if (hexValue.length == 3) {
    // #rgb -> #rrggbb
    final r = int.parse(hexValue[0] + hexValue[0], radix: 16);
    final g = int.parse(hexValue[1] + hexValue[1], radix: 16);
    final b = int.parse(hexValue[2] + hexValue[2], radix: 16);
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }
  
  if (hexValue.length == 6) {
    // #rrggbb -> #ffrrggbb
    final value = int.parse(hexValue, radix: 16);
    return (0xFF << 24) | value;
  }
  
  if (hexValue.length == 8) {
    // #rrggbbaa -> #aarrggbb (ARGB format)
    final value = int.parse(hexValue, radix: 16);
    // Convert from RRGGBBAA to AARRGGBB
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
  
  return null;
}

/// Parses RGB/RGBA color strings.
int? _parseRgbColor(String rgb) {
  final parts = rgb.split(',').map((s) => s.trim()).toList();
  if (parts.length < 3) return null;
  
  final r = _parseColorComponent(parts[0]);
  final g = _parseColorComponent(parts[1]);
  final b = _parseColorComponent(parts[2]);
  final a = parts.length > 3 ? _parseAlphaComponent(parts[3]) : 255;
  
  if (r == null || g == null || b == null || a == null) return null;
  
  return (a << 24) | (r << 16) | (g << 8) | b;
}

/// Parses HSL/HSLA color strings.
int? _parseHslColor(String hsl) {
  final parts = hsl.split(',').map((s) => s.trim()).toList();
  if (parts.length < 3) return null;
  
  final h = _parseHue(parts[0]);
  final s = _parsePercentage(parts[1]);
  final l = _parsePercentage(parts[2]);
  final a = parts.length > 3 ? _parseAlphaComponent(parts[3]) : 255;
  
  if (h == null || s == null || l == null || a == null) return null;
  
  final rgb = _hslToRgb(h, s, l);
  return (a << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2];
}

int? _parseColorComponent(String component) {
  final value = int.tryParse(component);
  if (value == null) return null;
  return value.clamp(0, 255);
}

int? _parseAlphaComponent(String component) {
  final value = double.tryParse(component);
  if (value == null) return null;
  // Alpha can be 0.0-1.0 or 0-255
  if (value <= 1.0) {
    return (value * 255).round().clamp(0, 255);
  }
  return value.round().clamp(0, 255);
}

double? _parseHue(String hue) {
  final value = double.tryParse(hue.replaceAll('deg', '').trim());
  if (value == null) return null;
  // Normalize to 0-360 range
  return ((value % 360 + 360) % 360) / 360.0;
}

double? _parsePercentage(String percentage) {
  final value = double.tryParse(percentage.replaceAll('%', '').trim());
  if (value == null) return null;
  return (value.clamp(0, 100) / 100.0);
}

/// Converts HSL to RGB.
List<int> _hslToRgb(double h, double s, double l) {
  double r, g, b;
  
  if (s == 0) {
    r = g = b = l; // achromatic
  } else {
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = _hueToRgb(p, q, h + 1/3);
    g = _hueToRgb(p, q, h);
    b = _hueToRgb(p, q, h - 1/3);
  }
  
  return [
    (r * 255).round().clamp(0, 255),
    (g * 255).round().clamp(0, 255),
    (b * 255).round().clamp(0, 255),
  ];
}

double _hueToRgb(double p, double q, double t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1/6) return p + (q - p) * 6 * t;
  if (t < 1/2) return q;
  if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
  return p;
}

/// Processes transform arrays into a normalized transform matrix.
///
/// Accepts a list of transform operations:
/// ```dart
/// [
///   {'translateX': 10},
///   {'translateY': 20},
///   {'rotate': '45deg'},
///   {'scale': 1.5},
///   {'scaleX': 2.0},
///   {'scaleY': 0.5},
/// ]
/// ```
///
/// Returns a map with processed transform values:
/// ```dart
/// {
///   'translateX': 10.0,
///   'translateY': 20.0,
///   'rotateInDegrees': 45.0,
///   'scaleX': 2.0,
///   'scaleY': 0.5,
/// }
/// ```
///
/// Example:
/// ```dart
/// final transform = processTransform([
///   {'rotate': '90deg'},
///   {'scale': 2.0},
/// ]);
/// // Result: {'rotateInDegrees': 90.0, 'scaleX': 2.0, 'scaleY': 2.0}
/// ```
Map<String, dynamic>? processTransform(dynamic transform) {
  if (transform == null) return null;
  
  if (transform is! List) {
    // Single transform operation
    if (transform is Map) {
      return _processTransformMap(transform);
    }
    return null;
  }
  
  // Merge multiple transform operations
  final result = <String, dynamic>{};
  for (final op in transform) {
    if (op is Map) {
      final processed = _processTransformMap(op);
      if (processed != null) {
        result.addAll(processed);
      }
    }
  }
  
  return result.isEmpty ? null : result;
}

Map<String, dynamic>? _processTransformMap(Map<dynamic, dynamic> op) {
  final result = <String, dynamic>{};
  
  op.forEach((key, value) {
    final keyStr = key.toString();
    
    if (keyStr == 'translateX' || keyStr == 'translateY') {
      result[keyStr] = _parseNumber(value);
    } else if (keyStr == 'rotate') {
      final degrees = _parseAngle(value);
      if (degrees != null) {
        result['rotateInDegrees'] = degrees;
      }
    } else if (keyStr == 'scale') {
      final scale = _parseNumber(value);
      if (scale != null) {
        result['scaleX'] = scale;
        result['scaleY'] = scale;
      }
    } else if (keyStr == 'scaleX' || keyStr == 'scaleY') {
      result[keyStr] = _parseNumber(value);
    }
  });
  
  return result.isEmpty ? null : result;
}

double? _parseNumber(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

double? _parseAngle(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final match = RegExp(r'(-?\d+\.?\d*)\s*(deg|rad)?').firstMatch(value);
    if (match != null) {
      final numValue = double.tryParse(match.group(1)!);
      if (numValue == null) return null;
      final unit = match.group(2) ?? 'deg';
      if (unit == 'rad') {
        return numValue * 180 / 3.141592653589793;
      }
      return numValue;
    }
  }
  return null;
}

/// Processes shadow properties into a normalized format.
///
/// Validates and normalizes shadow properties for consistent rendering.
/// Returns a map with processed shadow values or null if invalid.
///
/// Example:
/// ```dart
/// final shadow = processShadow({
///   'shadowColor': Colors.black,
///   'shadowOpacity': 0.5,
///   'shadowRadius': 10.0,
///   'shadowOffsetX': 2.0,
///   'shadowOffsetY': 4.0,
/// });
/// ```
Map<String, dynamic>? processShadow(Map<String, dynamic>? shadow) {
  if (shadow == null) return null;
  
  final result = <String, dynamic>{};
  
  if (shadow.containsKey('shadowColor')) {
    final color = processColor(shadow['shadowColor']);
    if (color != null) {
      result['shadowColor'] = color;
    }
  }
  
  if (shadow.containsKey('shadowOpacity')) {
    final opacity = _parseNumber(shadow['shadowOpacity']);
    if (opacity != null) {
      result['shadowOpacity'] = opacity.clamp(0.0, 1.0);
    }
  }
  
  if (shadow.containsKey('shadowRadius')) {
    final radius = _parseNumber(shadow['shadowRadius']);
    if (radius != null && radius >= 0) {
      result['shadowRadius'] = radius;
    }
  }
  
  if (shadow.containsKey('shadowOffsetX')) {
    result['shadowOffsetX'] = _parseNumber(shadow['shadowOffsetX']);
  }
  
  if (shadow.containsKey('shadowOffsetY')) {
    result['shadowOffsetY'] = _parseNumber(shadow['shadowOffsetY']);
  }
  
  return result.isEmpty ? null : result;
}

/// Processes aspect ratio values.
///
/// Accepts numeric values and returns a normalized double.
/// Validates that aspect ratio is positive.
///
/// Example:
/// ```dart
/// processAspectRatio(16 / 9)  // 1.777...
/// processAspectRatio('16/9')  // 1.777...
/// ```
double? processAspectRatio(dynamic value) {
  if (value == null) return null;
  
  if (value is num) {
    final ratio = value.toDouble();
    return ratio > 0 ? ratio : null;
  }
  
  if (value is String) {
    // Handle '16/9' format
    final parts = value.split('/');
    if (parts.length == 2) {
      final width = double.tryParse(parts[0].trim());
      final height = double.tryParse(parts[1].trim());
      if (width != null && height != null && height > 0) {
        return width / height;
      }
    }
  }
  
  return null;
}

/// CSS named colors mapping to ARGB integers.
const Map<String, int> _namedColors = {
  'transparent': 0x00000000,
  'aliceblue': 0xFFF0F8FF,
  'antiquewhite': 0xFFFAEBD7,
  'aqua': 0xFF00FFFF,
  'aquamarine': 0xFF7FFFD4,
  'azure': 0xFFF0FFFF,
  'beige': 0xFFF5F5DC,
  'bisque': 0xFFFFE4C4,
  'black': 0xFF000000,
  'blanchedalmond': 0xFFFFEBCD,
  'blue': 0xFF0000FF,
  'blueviolet': 0xFF8A2BE2,
  'brown': 0xFFA52A2A,
  'burlywood': 0xFFDEB887,
  'cadetblue': 0xFF5F9EA0,
  'chartreuse': 0xFF7FFF00,
  'chocolate': 0xFFD2691E,
  'coral': 0xFFFF7F50,
  'cornflowerblue': 0xFF6495ED,
  'cornsilk': 0xFFFFF8DC,
  'crimson': 0xFFDC143C,
  'cyan': 0xFF00FFFF,
  'darkblue': 0xFF00008B,
  'darkcyan': 0xFF008B8B,
  'darkgoldenrod': 0xFFB8860B,
  'darkgray': 0xFFA9A9A9,
  'darkgrey': 0xFFA9A9A9,
  'darkgreen': 0xFF006400,
  'darkkhaki': 0xFFBDB76B,
  'darkmagenta': 0xFF8B008B,
  'darkolivegreen': 0xFF556B2F,
  'darkorange': 0xFFFF8C00,
  'darkorchid': 0xFF9932CC,
  'darkred': 0xFF8B0000,
  'darksalmon': 0xFFE9967A,
  'darkseagreen': 0xFF8FBC8F,
  'darkslateblue': 0xFF483D8B,
  'darkslategray': 0xFF2F4F4F,
  'darkslategrey': 0xFF2F4F4F,
  'darkturquoise': 0xFF00CED1,
  'darkviolet': 0xFF9400D3,
  'deeppink': 0xFFFF1493,
  'deepskyblue': 0xFF00BFFF,
  'dimgray': 0xFF696969,
  'dimgrey': 0xFF696969,
  'dodgerblue': 0xFF1E90FF,
  'firebrick': 0xFFB22222,
  'floralwhite': 0xFFFFFAF0,
  'forestgreen': 0xFF228B22,
  'fuchsia': 0xFFFF00FF,
  'gainsboro': 0xFFDCDCDC,
  'ghostwhite': 0xFFF8F8FF,
  'gold': 0xFFFFD700,
  'goldenrod': 0xFFDAA520,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'green': 0xFF008000,
  'greenyellow': 0xFFADFF2F,
  'honeydew': 0xFFF0FFF0,
  'hotpink': 0xFFFF69B4,
  'indianred': 0xFFCD5C5C,
  'indigo': 0xFF4B0082,
  'ivory': 0xFFFFFFF0,
  'khaki': 0xFFF0E68C,
  'lavender': 0xFFE6E6FA,
  'lavenderblush': 0xFFFFF0F5,
  'lawngreen': 0xFF7CFC00,
  'lemonchiffon': 0xFFFFFACD,
  'lightblue': 0xFFADD8E6,
  'lightcoral': 0xFFF08080,
  'lightcyan': 0xFFE0FFFF,
  'lightgoldenrodyellow': 0xFFFAFAD2,
  'lightgray': 0xFFD3D3D3,
  'lightgrey': 0xFFD3D3D3,
  'lightgreen': 0xFF90EE90,
  'lightpink': 0xFFFFB6C1,
  'lightsalmon': 0xFFFFA07A,
  'lightseagreen': 0xFF20B2AA,
  'lightskyblue': 0xFF87CEFA,
  'lightslategray': 0xFF778899,
  'lightslategrey': 0xFF778899,
  'lightsteelblue': 0xFFB0C4DE,
  'lightyellow': 0xFFFFFFE0,
  'lime': 0xFF00FF00,
  'limegreen': 0xFF32CD32,
  'linen': 0xFFFAF0E6,
  'magenta': 0xFFFF00FF,
  'maroon': 0xFF800000,
  'mediumaquamarine': 0xFF66CDAA,
  'mediumblue': 0xFF0000CD,
  'mediumorchid': 0xFFBA55D3,
  'mediumpurple': 0xFF9370DB,
  'mediumseagreen': 0xFF3CB371,
  'mediumslateblue': 0xFF7B68EE,
  'mediumspringgreen': 0xFF00FA9A,
  'mediumturquoise': 0xFF48D1CC,
  'mediumvioletred': 0xFFC71585,
  'midnightblue': 0xFF191970,
  'mintcream': 0xFFF5FFFA,
  'mistyrose': 0xFFFFE4E1,
  'moccasin': 0xFFFFE4B5,
  'navajowhite': 0xFFFFDEAD,
  'navy': 0xFF000080,
  'oldlace': 0xFFFDF5E6,
  'olive': 0xFF808000,
  'olivedrab': 0xFF6B8E23,
  'orange': 0xFFFFA500,
  'orangered': 0xFFFF4500,
  'orchid': 0xFFDA70D6,
  'palegoldenrod': 0xFFEEE8AA,
  'palegreen': 0xFF98FB98,
  'paleturquoise': 0xFFAFEEEE,
  'palevioletred': 0xFFDB7093,
  'papayawhip': 0xFFFFEFD5,
  'peachpuff': 0xFFFFDAB9,
  'peru': 0xFFCD853F,
  'pink': 0xFFFFC0CB,
  'plum': 0xFFDDA0DD,
  'powderblue': 0xFFB0E0E6,
  'purple': 0xFF800080,
  'rebeccapurple': 0xFF663399,
  'red': 0xFFFF0000,
  'rosybrown': 0xFFBC8F8F,
  'royalblue': 0xFF4169E1,
  'saddlebrown': 0xFF8B4513,
  'salmon': 0xFFFA8072,
  'sandybrown': 0xFFF4A460,
  'seagreen': 0xFF2E8B57,
  'seashell': 0xFFFFF5EE,
  'sienna': 0xFFA0522D,
  'silver': 0xFFC0C0C0,
  'skyblue': 0xFF87CEEB,
  'slateblue': 0xFF6A5ACD,
  'slategray': 0xFF708090,
  'slategrey': 0xFF708090,
  'snow': 0xFFFFFAFA,
  'springgreen': 0xFF00FF7F,
  'steelblue': 0xFF4682B4,
  'tan': 0xFFD2B48C,
  'teal': 0xFF008080,
  'thistle': 0xFFD8BFD8,
  'tomato': 0xFFFF6347,
  'turquoise': 0xFF40E0D0,
  'violet': 0xFFEE82EE,
  'wheat': 0xFFF5DEB3,
  'white': 0xFFFFFFFF,
  'whitesmoke': 0xFFF5F5F5,
  'yellow': 0xFFFFFF00,
  'yellowgreen': 0xFF9ACD32,
};
