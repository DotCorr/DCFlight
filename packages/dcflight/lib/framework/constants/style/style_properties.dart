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
  final String? pointerEvents; // Changed from bool? to String? to match iOS implementation

  /// Create a style sheet with visual styling properties
  const StyleSheet({
    this.borderRadius,
    this.borderTopLeftRadius,
    this.borderTopRightRadius,
    this.borderBottomLeftRadius,
    this.borderBottomRightRadius,
    this.borderColor, // Removed default value to allow adaptive theming
    this.borderWidth,
    this.backgroundColor,
    this.backgroundGradient,
    this.opacity,
    this.shadowColor, // Removed default value to allow adaptive theming
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
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    // Add border style properties
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
      // Preserve alpha channel - use full ARGB value
      final alpha = (borderColor!.a * 255.0).round() & 0xff;
      if (alpha == 0) {
        map['borderColor'] = 'transparent';
      } else if (alpha == 255) {
        // Fully opaque - use standard hex format
        final hexValue = borderColor!.toARGB32() & 0xFFFFFF;
        map['borderColor'] = '#${hexValue.toRadixString(16).padLeft(6, '0')}';
      } else {
        // Semi-transparent - include alpha in ARGB format
        final argbValue = borderColor!.toARGB32();
        map['borderColor'] = '#${argbValue.toRadixString(16).padLeft(8, '0')}';
      }
    }
    if (borderWidth != null) map['borderWidth'] = borderWidth;

    // Add background and opacity
    if (backgroundColor != null) {
      // Preserve alpha channel - use full ARGB value
      final alpha = (backgroundColor!.a * 255.0).round() & 0xff;
      if (alpha == 0) {
        map['backgroundColor'] = 'transparent';
      } else if (alpha == 255) {
        // Fully opaque - use standard hex format
        final hexValue = backgroundColor!.toARGB32() & 0xFFFFFF;
        map['backgroundColor'] = '#${hexValue.toRadixString(16).padLeft(6, '0')}';
      } else {
        // Semi-transparent - include alpha in ARGB format
        final argbValue = backgroundColor!.toARGB32();
        map['backgroundColor'] = '#${argbValue.toRadixString(16).padLeft(8, '0')}';
      }
    }
    if (backgroundGradient != null) map['backgroundGradient'] = backgroundGradient!.toMap();
    if (opacity != null) map['opacity'] = opacity;

    // Add shadow properties
    if (shadowColor != null) {
      // Preserve alpha channel - use full ARGB value
      final alpha = (shadowColor!.a * 255.0).round() & 0xff;
      if (alpha == 0) {
        map['shadowColor'] = 'transparent';
      } else if (alpha == 255) {
        // Fully opaque - use standard hex format
        final hexValue = shadowColor!.toARGB32() & 0xFFFFFF;
        map['shadowColor'] = '#${hexValue.toRadixString(16).padLeft(6, '0')}';
      } else {
        // Semi-transparent - include alpha in ARGB format
        final argbValue = shadowColor!.toARGB32();
        map['shadowColor'] = '#${argbValue.toRadixString(16).padLeft(8, '0')}';
      }
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

  /// Create a new StyleSheet by merging this one with another
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
    String? pointerEvents, // Changed from bool? to String?
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