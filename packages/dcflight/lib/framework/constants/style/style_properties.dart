/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';
import 'gradient.dart';
import 'hit_slop.dart';

/// StyleSheet for visual styling properties
class StyleSheet extends Equatable {
  // Border styles
  final dynamic borderRadius;
  final dynamic borderTopLeftRadius;
  final dynamic borderTopRightRadius;
  final dynamic borderBottomLeftRadius;
  final dynamic borderBottomRightRadius;
  final Color? borderColor;
  final dynamic borderWidth;

  // Background and opacity
  final Color? backgroundColor;
  final DCFGradient? backgroundGradient;
  final double? opacity;

  // Shadow properties
  final Color? shadowColor;
  final double? shadowOpacity;
  final dynamic shadowRadius;
  final dynamic shadowOffsetX;
  final dynamic shadowOffsetY;
  final dynamic elevation;

  // Hit area expansion
  final DCFHitSlop? hitSlop;

  // Accessibility properties
  final bool? accessible;
  final String? accessibilityLabel;
  final String? testID;
  final String? pointerEvents;

  /// Create a style sheet with visual styling properties
  const StyleSheet({
    this.borderRadius,
    this.borderTopLeftRadius,
    this.borderTopRightRadius,
    this.borderBottomLeftRadius,
    this.borderBottomRightRadius,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor,
    this.backgroundGradient,
    this.opacity,
    this.shadowColor,
    this.shadowOpacity,
    this.shadowRadius,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.elevation,
    this.hitSlop,
    this.accessible,
    this.accessibilityLabel,
    this.testID,
    this.pointerEvents,
  });

  /// Convert style properties to a map for serialization
  /// CRITICAL FIX: Ensure proper precedence order when both backgroundColor and backgroundGradient are present
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    // CRITICAL FIX: Add border style properties FIRST (they need to be applied before gradients)
    if (borderRadius != null) map['borderRadius'] = borderRadius;
    if (borderTopLeftRadius != null) {
      map['borderTopLeftRadius'] = borderTopLeftRadius;
    }
    if (borderTopRightRadius != null) {
      map['borderTopRightRadius'] = borderTopRightRadius;
    }
    if (borderBottomLeftRadius != null) {
      map['borderBottomLeftRadius'] = borderBottomLeftRadius;
    }
    if (borderBottomRightRadius != null) {
      map['borderBottomRightRadius'] = borderBottomRightRadius;
    }
    if (borderColor != null) {
      map['borderColor'] = _colorToString(borderColor!);
    }
    if (borderWidth != null) map['borderWidth'] = borderWidth;

    // Add background color - this will be overridden by gradient if both are present
    if (backgroundColor != null) {
      map['backgroundColor'] = _colorToString(backgroundColor!);
    }

    // CRITICAL FIX: Add gradient AFTER backgroundColor so it can reference border radius
    // The native side will handle precedence correctly
    if (backgroundGradient != null) {
      map['backgroundGradient'] = backgroundGradient!.toMap();
    }

    if (opacity != null) map['opacity'] = opacity;

    // Add shadow properties
    if (shadowColor != null) {
      map['shadowColor'] = _colorToString(shadowColor!);
    }
    if (shadowOpacity != null) map['shadowOpacity'] = shadowOpacity;
    if (shadowRadius != null) map['shadowRadius'] = shadowRadius;
    if (shadowOffsetX != null) map['shadowOffsetX'] = shadowOffsetX;
    if (shadowOffsetY != null) map['shadowOffsetY'] = shadowOffsetY;
    if (elevation != null) map['elevation'] = elevation;

    // Add hit slop
    if (hitSlop != null) map['hitSlop'] = hitSlop!.toMap();

    // Add accessibility properties
    if (accessible != null) map['accessible'] = accessible;
    if (accessibilityLabel != null) {
      map['accessibilityLabel'] = accessibilityLabel;
    }
    if (testID != null) map['testID'] = testID;
    if (pointerEvents != null) map['pointerEvents'] = pointerEvents;

    return map;
  }

  /// CRITICAL FIX: Centralized color conversion to ensure consistency
  String _colorToString(Color color) {
    // Check for transparency first (same pattern across all color conversions)
    final alpha = (color.a * 255.0).round() & 0xff;
    if (alpha == 0) {
      return 'transparent';
    } else if (alpha == 255) {
      // Fully opaque - use standard hex format
      final hexValue = color.toARGB32() & 0xFFFFFF;
      return '#${hexValue.toRadixString(16).padLeft(6, '0')}';
    } else {
      // Semi-transparent - include alpha in ARGB format
      final argbValue = color.toARGB32();
      return '#${argbValue.toRadixString(16).padLeft(8, '0')}';
    }
  }

  /// Create a new StyleSheet by merging this one with another
  /// CRITICAL FIX: Ensure gradient takes precedence over backgroundColor when merging
  StyleSheet merge(StyleSheet other) {
    return StyleSheet(
      borderRadius: other.borderRadius ?? borderRadius,
      borderTopLeftRadius: other.borderTopLeftRadius ?? borderTopLeftRadius,
      borderTopRightRadius: other.borderTopRightRadius ?? borderTopRightRadius,
      borderBottomLeftRadius:
          other.borderBottomLeftRadius ?? borderBottomLeftRadius,
      borderBottomRightRadius:
          other.borderBottomRightRadius ?? borderBottomRightRadius,
      borderColor: other.borderColor ?? borderColor,
      borderWidth: other.borderWidth ?? borderWidth,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      backgroundGradient: other.backgroundGradient ?? backgroundGradient,
      opacity: other.opacity ?? opacity,
      shadowColor: other.shadowColor ?? shadowColor,
      shadowOpacity: other.shadowOpacity ?? shadowOpacity,
      shadowRadius: other.shadowRadius ?? shadowRadius,
      shadowOffsetX: other.shadowOffsetX ?? shadowOffsetX,
      shadowOffsetY: other.shadowOffsetY ?? shadowOffsetY,
      elevation: other.elevation ?? elevation,
      hitSlop: other.hitSlop ?? hitSlop,
      accessible: other.accessible ?? accessible,
      accessibilityLabel: other.accessibilityLabel ?? accessibilityLabel,
      testID: other.testID ?? testID,
      pointerEvents: other.pointerEvents ?? pointerEvents,
    );
  }

  /// Create a copy of this StyleSheet with certain properties modified
  StyleSheet copyWith({
    dynamic borderRadius,
    dynamic borderTopLeftRadius,
    dynamic borderTopRightRadius,
    dynamic borderBottomLeftRadius,
    dynamic borderBottomRightRadius,
    Color? borderColor,
    dynamic borderWidth,
    Color? backgroundColor,
    DCFGradient? backgroundGradient,
    double? opacity,
    Color? shadowColor,
    double? shadowOpacity,
    dynamic shadowRadius,
    dynamic shadowOffsetX,
    dynamic shadowOffsetY,
    dynamic elevation,
    DCFHitSlop? hitSlop,
    bool? accessible,
    String? accessibilityLabel,
    String? testID,
    String? pointerEvents,
  }) {
    return StyleSheet(
      borderRadius: borderRadius ?? this.borderRadius,
      borderTopLeftRadius: borderTopLeftRadius ?? this.borderTopLeftRadius,
      borderTopRightRadius: borderTopRightRadius ?? this.borderTopRightRadius,
      borderBottomLeftRadius:
          borderBottomLeftRadius ?? this.borderBottomLeftRadius,
      borderBottomRightRadius:
          borderBottomRightRadius ?? this.borderBottomRightRadius,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      opacity: opacity ?? this.opacity,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowRadius: shadowRadius ?? this.shadowRadius,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      elevation: elevation ?? this.elevation,
      hitSlop: hitSlop ?? this.hitSlop,
      accessible: accessible ?? this.accessible,
      accessibilityLabel: accessibilityLabel ?? this.accessibilityLabel,
      testID: testID ?? this.testID,
      pointerEvents: pointerEvents ?? this.pointerEvents,
    );
  }

  /// CRITICAL FIX: Add validation method to check for conflicting styles
  List<String> validateStyles() {
    final warnings = <String>[];

    // Check for potential conflicts
    if (backgroundColor != null && backgroundGradient != null) {
      warnings.add(
          'Both backgroundColor and backgroundGradient are set. backgroundGradient will take precedence.');
    }

    // Check for border radius conflicts
    if (borderRadius != null &&
        (borderTopLeftRadius != null ||
            borderTopRightRadius != null ||
            borderBottomLeftRadius != null ||
            borderBottomRightRadius != null)) {
      warnings.add(
          'Both borderRadius and specific corner radii are set. Specific corners will take precedence.');
    }

    // Check for shadow/elevation conflicts
    if (elevation != null &&
        (shadowColor != null ||
            shadowOpacity != null ||
            shadowRadius != null ||
            shadowOffsetX != null ||
            shadowOffsetY != null)) {
      warnings.add(
          'Both elevation and specific shadow properties are set. Specific shadow properties will take precedence.');
    }

    return warnings;
  }

  /// CRITICAL FIX: Add helper method to check if this style has corner radius
  bool get hasCornerRadius {
    return borderRadius != null ||
        borderTopLeftRadius != null ||
        borderTopRightRadius != null ||
        borderBottomLeftRadius != null ||
        borderBottomRightRadius != null;
  }

  /// CRITICAL FIX: Add helper method to check if this style has shadow properties
  bool get hasShadow {
    return shadowColor != null ||
        shadowOpacity != null ||
        shadowRadius != null ||
        shadowOffsetX != null ||
        shadowOffsetY != null ||
        elevation != null;
  }

  /// CRITICAL FIX: Add helper method to get effective corner radius value
  double? get effectiveCornerRadius {
    if (borderTopLeftRadius != null ||
        borderTopRightRadius != null ||
        borderBottomLeftRadius != null ||
        borderBottomRightRadius != null) {
      // Return the first specified corner radius as they should all be the same for consistency
      return (borderTopLeftRadius ??
              borderTopRightRadius ??
              borderBottomLeftRadius ??
              borderBottomRightRadius)
          ?.toDouble();
    }
    return borderRadius?.toDouble();
  }

  /// List of all style property names for easy identification
  static const List<String> all = [
    'borderRadius',
    'borderTopLeftRadius',
    'borderTopRightRadius',
    'borderBottomLeftRadius',
    'borderBottomRightRadius',
    'borderColor',
    'borderWidth',
    'backgroundColor',
    'backgroundGradient',
    'opacity',
    'shadowColor',
    'shadowOpacity',
    'shadowRadius',
    'shadowOffsetX',
    'shadowOffsetY',
    'elevation',
    'hitSlop',
    'accessible',
    'accessibilityLabel',
    'testID',
    'pointerEvents',
  ];

  /// Helper method to check if a property is a style property
  static bool isStyleProperty(String propName) {
    return all.contains(propName);
  }

  /// CRITICAL FIX: Add debug method to print style information
  void debugPrint() {
    print('StyleSheet Debug Info:');
    print('  Border Radius: $borderRadius');
    print(
        '  Corner Radii: TL=$borderTopLeftRadius, TR=$borderTopRightRadius, BL=$borderBottomLeftRadius, BR=$borderBottomRightRadius');
    print('  Border: color=$borderColor, width=$borderWidth');
    print(
        '  Background: color=$backgroundColor, gradient=${backgroundGradient != null ? 'present' : 'none'}');
    print(
        '  Shadow: color=$shadowColor, opacity=$shadowOpacity, radius=$shadowRadius, offset=($shadowOffsetX,$shadowOffsetY)');
    print('  Elevation: $elevation');
    print('  Opacity: $opacity');

    final warnings = validateStyles();
    if (warnings.isNotEmpty) {
      print('  WARNINGS:');
      for (final warning in warnings) {
        print('    - $warning');
      }
    }
  }

  @override
  List<Object?> get props => [
        borderRadius,
        borderTopLeftRadius,
        borderTopRightRadius,
        borderBottomLeftRadius,
        borderBottomRightRadius,
        borderColor,
        borderWidth,
        backgroundColor,
        backgroundGradient,
        opacity,
        shadowColor,
        shadowOpacity,
        shadowRadius,
        shadowOffsetX,
        shadowOffsetY,
        elevation,
        hitSlop,
        accessible,
        accessibilityLabel,
        testID,
        pointerEvents,
      ];
}
