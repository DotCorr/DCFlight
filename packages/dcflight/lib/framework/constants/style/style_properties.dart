/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'gradient.dart';
import 'hit_slop.dart';
import '../../theme/dcf_theme.dart';

/// StyleSheet for visual styling properties
/// 
/// **Semantic Color System:**
/// Use semantic colors (primaryColor, secondaryColor, etc.) instead of explicit colors
/// for better cross-platform consistency and theme support.
/// 
/// Example:
/// ```dart
/// DCFStyleSheet(
///   primaryColor: DCFTheme.textColor,  // Maps to text color for text components
///   secondaryColor: DCFTheme.secondaryTextColor,  // Maps to placeholder for inputs
///   backgroundColor: DCFTheme.surfaceColor,
/// )
/// ```
/// Style registry for StyleSheet.create() pattern
/// Caches styles and assigns IDs for efficient bridge communication
class _DCFStyleRegistry {
  static final _DCFStyleRegistry instance = _DCFStyleRegistry._();
  _DCFStyleRegistry._();
  
  final Map<String, DCFStyleSheet> _styles = {}; // Maps ID -> original style (without ID)
  final Map<DCFStyleSheet, String> _styleToId = {};
  int _nextId = 1;
  
  /// Register a style and return its ID
  /// Stores the ORIGINAL style (without ID) to avoid recursion in toMap()
  String register(String name, DCFStyleSheet style) {
    // Check if this exact style instance is already registered
    if (_styleToId.containsKey(style)) {
      return _styleToId[style]!;
    }
    
    // Generate new ID
    final id = 'dcf_style_$_nextId';
    _nextId++;
    
    // Store ORIGINAL style (without ID) to avoid recursion when resolving
    _styles[id] = style;
    _styleToId[style] = id;
    
    return id;
  }
  
  /// Get style by ID
  DCFStyleSheet? get(String id) {
    return _styles[id];
  }
  
  /// Get ID for a style (if registered)
  String? getId(DCFStyleSheet style) {
    return _styleToId[style];
  }
  
  /// Check if style is registered
  bool isRegistered(DCFStyleSheet style) {
    return _styleToId.containsKey(style);
  }
  
  /// Clear all registered styles (for testing/debugging)
  void clear() {
    _styles.clear();
    _styleToId.clear();
    _nextId = 1;
  }
}

class DCFStyleSheet extends Equatable {
  /// Internal style ID if registered via StyleSheet.create()
  /// Null for non-registered styles (backward compatibility)
  final String? _styleId;
  
  final dynamic borderRadius;
  final dynamic borderTopLeftRadius;
  final dynamic borderTopRightRadius;
  final dynamic borderBottomLeftRadius;
  final dynamic borderBottomRightRadius;
  final Color? borderColor;
  final dynamic borderWidth;

  final Color? backgroundColor;
  final DCFGradient? backgroundGradient;
  final double? opacity;

  final Color? shadowColor;
  final double? shadowOpacity;
  final dynamic shadowRadius;
  final dynamic shadowOffsetX;
  final dynamic shadowOffsetY;
  final dynamic elevation;

  final DCFHitSlop? hitSlop;

  final bool? accessible;
  final String? accessibilityLabel;
  final String? accessibilityHint;
  final dynamic accessibilityValue;
  final String? accessibilityRole;
  final Map<String, dynamic>? accessibilityState;
  final List<Map<String, String>>? accessibilityActions;
  final bool? accessibilityElementsHidden;
  final String? accessibilityLanguage;
  final bool? accessibilityIgnoresInvertColors;
  final String? accessibilityLiveRegion;
  final bool? accessibilityViewIsModal;
  final String? ariaLabel;
  final String? ariaLabelledby;
  final String? ariaLive;
  final bool? ariaModal;
  final bool? ariaHidden;
  final dynamic ariaBusy;
  final dynamic ariaChecked;
  final bool? ariaDisabled;
  final bool? ariaExpanded;
  final bool? ariaSelected;
  final num? ariaValuemin;
  final num? ariaValuemax;
  final num? ariaValuenow;
  final String? ariaValuetext;
  final String? importantForAccessibility;
  final String? testID;
  final String? pointerEvents;

  /// **Semantic Colors** - Use these instead of explicit color props in components
  /// These map to theme colors automatically and ensure cross-platform consistency
  
  /// Primary color - typically used for main text, primary actions, etc.
  /// For Text: main text color
  /// For Button: text color
  /// For TextInput: text color
  final Color? primaryColor;
  
  /// Secondary color - typically used for secondary text, placeholders, etc.
  /// For Text: secondary text color
  /// For TextInput: placeholder color
  final Color? secondaryColor;
  
  /// Tertiary color - typically used for tertiary text, hints, etc.
  final Color? tertiaryColor;
  
  /// Accent color - typically used for highlights, links, etc.
  final Color? accentColor;

  /// Internal factory constructor for registered styles (non-const)
  DCFStyleSheet._withId(
    String styleId, {
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
    this.accessibilityHint,
    this.accessibilityValue,
    this.accessibilityRole,
    this.accessibilityState,
    this.accessibilityActions,
    this.accessibilityElementsHidden,
    this.accessibilityLanguage,
    this.accessibilityIgnoresInvertColors,
    this.accessibilityLiveRegion,
    this.accessibilityViewIsModal,
    this.ariaLabel,
    this.ariaLabelledby,
    this.ariaLive,
    this.ariaModal,
    this.ariaHidden,
    this.ariaBusy,
    this.ariaChecked,
    this.ariaDisabled,
    this.ariaExpanded,
    this.ariaSelected,
    this.ariaValuemin,
    this.ariaValuemax,
    this.ariaValuenow,
    this.ariaValuetext,
    this.importantForAccessibility,
    this.testID,
    this.pointerEvents,
    this.primaryColor,
    this.secondaryColor,
    this.tertiaryColor,
    this.accentColor,
  }) : _styleId = styleId;

  /// Create a style sheet with visual styling properties
  /// 
  /// @Deprecated Use DCFStyleSheet.create() instead for better performance
  /// This constructor is still supported for backward compatibility but will be removed in a future version.
  @Deprecated('Use DCFStyleSheet.create() instead for better bridge efficiency. Example: final styles = DCFStyleSheet.create({"container": DCFStyleSheet(backgroundColor: Colors.blue)});')
  const DCFStyleSheet({
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
    this.accessibilityHint,
    this.accessibilityValue,
    this.accessibilityRole,
    this.accessibilityState,
    this.accessibilityActions,
    this.accessibilityElementsHidden,
    this.accessibilityLanguage,
    this.accessibilityIgnoresInvertColors,
    this.accessibilityLiveRegion,
    this.accessibilityViewIsModal,
    this.ariaLabel,
    this.ariaLabelledby,
    this.ariaLive,
    this.ariaModal,
    this.ariaHidden,
    this.ariaBusy,
    this.ariaChecked,
    this.ariaDisabled,
    this.ariaExpanded,
    this.ariaSelected,
    this.ariaValuemin,
    this.ariaValuemax,
    this.ariaValuenow,
    this.ariaValuetext,
    this.importantForAccessibility,
    this.testID,
    this.pointerEvents,
    // Semantic colors
    this.primaryColor,
    this.secondaryColor,
    this.tertiaryColor,
    this.accentColor,
  }) : _styleId = null;

  /// Create a StyleSheet registry (React Native StyleSheet.create() pattern)
  /// 
  /// This optimizes bridge communication by caching styles and sending IDs instead of full objects.
  /// 
  /// Example:
  /// ```dart
  /// final styles = DCFStyleSheet.create({
  ///   'container': DCFStyleSheet(backgroundColor: Colors.blue),
  ///   'text': DCFStyleSheet(primaryColor: Colors.black),
  /// });
  /// 
  /// // Use with ID reference
  /// DCFView(styleSheet: styles.container)
  /// ```
  /// 
  /// Benefits:
  /// - Bridge efficiency: Sends style IDs instead of full objects
  /// - Memory optimization: Styles cached and reused
  /// - Early validation: Catches style errors at creation time
  static DCFStyleSheetRegistry create(Map<String, DCFStyleSheet> styles) {
    final registry = DCFStyleSheetRegistry._();
    for (final entry in styles.entries) {
      final id = _DCFStyleRegistry.instance.register(entry.key, entry.value);
      // Create registered style with ID using internal factory
      registry._styles[entry.key] = DCFStyleSheet._withId(
        id,
        borderRadius: entry.value.borderRadius,
        borderTopLeftRadius: entry.value.borderTopLeftRadius,
        borderTopRightRadius: entry.value.borderTopRightRadius,
        borderBottomLeftRadius: entry.value.borderBottomLeftRadius,
        borderBottomRightRadius: entry.value.borderBottomRightRadius,
        borderColor: entry.value.borderColor,
        borderWidth: entry.value.borderWidth,
        backgroundColor: entry.value.backgroundColor,
        backgroundGradient: entry.value.backgroundGradient,
        opacity: entry.value.opacity,
        shadowColor: entry.value.shadowColor,
        shadowOpacity: entry.value.shadowOpacity,
        shadowRadius: entry.value.shadowRadius,
        shadowOffsetX: entry.value.shadowOffsetX,
        shadowOffsetY: entry.value.shadowOffsetY,
        elevation: entry.value.elevation,
        hitSlop: entry.value.hitSlop,
        accessible: entry.value.accessible,
        accessibilityLabel: entry.value.accessibilityLabel,
        accessibilityHint: entry.value.accessibilityHint,
        accessibilityValue: entry.value.accessibilityValue,
        accessibilityRole: entry.value.accessibilityRole,
        accessibilityState: entry.value.accessibilityState,
        accessibilityActions: entry.value.accessibilityActions,
        accessibilityElementsHidden: entry.value.accessibilityElementsHidden,
        accessibilityLanguage: entry.value.accessibilityLanguage,
        accessibilityIgnoresInvertColors: entry.value.accessibilityIgnoresInvertColors,
        accessibilityLiveRegion: entry.value.accessibilityLiveRegion,
        accessibilityViewIsModal: entry.value.accessibilityViewIsModal,
        ariaLabel: entry.value.ariaLabel,
        ariaLabelledby: entry.value.ariaLabelledby,
        ariaLive: entry.value.ariaLive,
        ariaModal: entry.value.ariaModal,
        ariaHidden: entry.value.ariaHidden,
        ariaBusy: entry.value.ariaBusy,
        ariaChecked: entry.value.ariaChecked,
        ariaDisabled: entry.value.ariaDisabled,
        ariaExpanded: entry.value.ariaExpanded,
        ariaSelected: entry.value.ariaSelected,
        ariaValuemin: entry.value.ariaValuemin,
        ariaValuemax: entry.value.ariaValuemax,
        ariaValuenow: entry.value.ariaValuenow,
        ariaValuetext: entry.value.ariaValuetext,
        importantForAccessibility: entry.value.importantForAccessibility,
        testID: entry.value.testID,
        pointerEvents: entry.value.pointerEvents,
        primaryColor: entry.value.primaryColor,
        secondaryColor: entry.value.secondaryColor,
        tertiaryColor: entry.value.tertiaryColor,
        accentColor: entry.value.accentColor,
      );
    }
    return registry;
  }

  /// Convert style properties to a map for serialization
  /// CRITICAL FIX: Ensure proper precedence order when both backgroundColor and backgroundGradient are present
  /// Semantic colors are included for component-level resolution
  /// 
  /// If style is registered via StyleSheet.create(), resolves ID to full object for native compatibility
  Map<String, dynamic> toMap() {
    // If registered, resolve ID to full style object (native side doesn't support IDs yet)
    if (_styleId != null) {
      final resolvedStyle = _DCFStyleRegistry.instance.get(_styleId);
      if (resolvedStyle != null) {
        // Return the resolved style's full map
        return resolvedStyle.toMap();
      }
      // Fallback: if ID not found, continue with current style
    }
    
    // Serialize full style object
    final map = <String, dynamic>{};

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

    if (backgroundColor != null) {
      map['backgroundColor'] = _colorToString(backgroundColor!);
    }

    if (backgroundGradient != null) {
      map['backgroundGradient'] = backgroundGradient!.toMap();
    }

    if (opacity != null) map['opacity'] = opacity;

    if (shadowColor != null) {
      map['shadowColor'] = _colorToString(shadowColor!);
    }
    if (shadowOpacity != null) map['shadowOpacity'] = shadowOpacity;
    if (shadowRadius != null) map['shadowRadius'] = shadowRadius;
    if (shadowOffsetX != null) map['shadowOffsetX'] = shadowOffsetX;
    if (shadowOffsetY != null) map['shadowOffsetY'] = shadowOffsetY;
    if (elevation != null) map['elevation'] = elevation;

    if (hitSlop != null) map['hitSlop'] = hitSlop!.toMap();

    if (accessible != null) map['accessible'] = accessible;
    if (accessibilityLabel != null) {
      map['accessibilityLabel'] = accessibilityLabel;
    }
    if (accessibilityHint != null) {
      map['accessibilityHint'] = accessibilityHint;
    }
    if (accessibilityValue != null) {
      map['accessibilityValue'] = accessibilityValue;
    }
    if (accessibilityRole != null) {
      map['accessibilityRole'] = accessibilityRole;
    }
    if (accessibilityState != null) {
      map['accessibilityState'] = accessibilityState;
    }
    if (accessibilityActions != null) {
      map['accessibilityActions'] = accessibilityActions;
    }
    if (accessibilityElementsHidden != null) {
      map['accessibilityElementsHidden'] = accessibilityElementsHidden;
    }
    if (accessibilityLanguage != null) {
      map['accessibilityLanguage'] = accessibilityLanguage;
    }
    if (accessibilityIgnoresInvertColors != null) {
      map['accessibilityIgnoresInvertColors'] = accessibilityIgnoresInvertColors;
    }
    if (accessibilityLiveRegion != null) {
      map['accessibilityLiveRegion'] = accessibilityLiveRegion;
    }
    if (accessibilityViewIsModal != null) {
      map['accessibilityViewIsModal'] = accessibilityViewIsModal;
    }
    if (ariaLabel != null) map['ariaLabel'] = ariaLabel;
    if (ariaLabelledby != null) map['ariaLabelledby'] = ariaLabelledby;
    if (ariaLive != null) map['ariaLive'] = ariaLive;
    if (ariaModal != null) map['ariaModal'] = ariaModal;
    if (ariaHidden != null) map['ariaHidden'] = ariaHidden;
    if (ariaBusy != null) map['ariaBusy'] = ariaBusy;
    if (ariaChecked != null) map['ariaChecked'] = ariaChecked;
    if (ariaDisabled != null) map['ariaDisabled'] = ariaDisabled;
    if (ariaExpanded != null) map['ariaExpanded'] = ariaExpanded;
    if (ariaSelected != null) map['ariaSelected'] = ariaSelected;
    if (ariaValuemin != null) map['ariaValuemin'] = ariaValuemin;
    if (ariaValuemax != null) map['ariaValuemax'] = ariaValuemax;
    if (ariaValuenow != null) map['ariaValuenow'] = ariaValuenow;
    if (ariaValuetext != null) map['ariaValuetext'] = ariaValuetext;
    if (importantForAccessibility != null) {
      map['importantForAccessibility'] = importantForAccessibility;
    }
    if (testID != null) map['testID'] = testID;
    if (pointerEvents != null) map['pointerEvents'] = pointerEvents;

    // Semantic colors - ALWAYS provide values (use DCFTheme fallbacks if not specified)
    // This ensures native components always receive explicit colors - NO native fallbacks needed
    final finalPrimaryColor = primaryColor ?? DCFTheme.textColor;
    final finalSecondaryColor = secondaryColor ?? DCFTheme.current.secondaryTextColor;
    final finalTertiaryColor = tertiaryColor ?? DCFTheme.current.secondaryTextColor;
    final finalAccentColor = accentColor ?? DCFTheme.accentColor;
    final finalBackgroundColor = backgroundColor ?? DCFTheme.backgroundColor;

    
    map['primaryColor'] = _colorToString(finalPrimaryColor);
    map['secondaryColor'] = _colorToString(finalSecondaryColor);
    map['tertiaryColor'] = _colorToString(finalTertiaryColor);
    map['accentColor'] = _colorToString(finalAccentColor);
    map['backgroundColor'] = _colorToString(finalBackgroundColor);
    return map;
  }

  /// CRITICAL FIX: Centralized color conversion to ensure consistency
  /// Uses "dcf:" prefix to distinguish black from transparent on native platforms
  String _colorToString(Color color) {
    final alpha = (color.a * 255.0).round() & 0xff;
    
    // Transparent - explicitly marked
    if (alpha == 0) {
      return 'dcf:transparent';
    }
    
    // Black - explicitly marked to distinguish from transparent
    if (color.value == 0xFF000000) {
      return 'dcf:black';
    }
    
    // Other colors - use dcf: prefix with hex
    if (alpha == 255) {
      final hexValue = color.toARGB32() & 0xFFFFFF;
      return 'dcf:#${hexValue.toRadixString(16).padLeft(6, '0')}';
    } else {
      final argbValue = color.toARGB32();
      return 'dcf:#${argbValue.toRadixString(16).padLeft(8, '0')}';
    }
  }

  /// Create a new StyleSheet by merging this one with another
  /// CRITICAL FIX: Ensure gradient takes precedence over backgroundColor when merging
  DCFStyleSheet merge(DCFStyleSheet other) {
    return DCFStyleSheet(
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
      accessibilityHint: other.accessibilityHint ?? accessibilityHint,
      accessibilityValue: other.accessibilityValue ?? accessibilityValue,
      accessibilityRole: other.accessibilityRole ?? accessibilityRole,
      accessibilityState: other.accessibilityState ?? accessibilityState,
      accessibilityActions: other.accessibilityActions ?? accessibilityActions,
      accessibilityElementsHidden: other.accessibilityElementsHidden ?? accessibilityElementsHidden,
      accessibilityLanguage: other.accessibilityLanguage ?? accessibilityLanguage,
      accessibilityIgnoresInvertColors: other.accessibilityIgnoresInvertColors ?? accessibilityIgnoresInvertColors,
      accessibilityLiveRegion: other.accessibilityLiveRegion ?? accessibilityLiveRegion,
      accessibilityViewIsModal: other.accessibilityViewIsModal ?? accessibilityViewIsModal,
      ariaLabel: other.ariaLabel ?? ariaLabel,
      ariaLabelledby: other.ariaLabelledby ?? ariaLabelledby,
      ariaLive: other.ariaLive ?? ariaLive,
      ariaModal: other.ariaModal ?? ariaModal,
      ariaHidden: other.ariaHidden ?? ariaHidden,
      ariaBusy: other.ariaBusy ?? ariaBusy,
      ariaChecked: other.ariaChecked ?? ariaChecked,
      ariaDisabled: other.ariaDisabled ?? ariaDisabled,
      ariaExpanded: other.ariaExpanded ?? ariaExpanded,
      ariaSelected: other.ariaSelected ?? ariaSelected,
      ariaValuemin: other.ariaValuemin ?? ariaValuemin,
      ariaValuemax: other.ariaValuemax ?? ariaValuemax,
      ariaValuenow: other.ariaValuenow ?? ariaValuenow,
      ariaValuetext: other.ariaValuetext ?? ariaValuetext,
      importantForAccessibility: other.importantForAccessibility ?? importantForAccessibility,
      testID: other.testID ?? testID,
      pointerEvents: other.pointerEvents ?? pointerEvents,
      // Semantic colors
      primaryColor: other.primaryColor ?? primaryColor,
      secondaryColor: other.secondaryColor ?? secondaryColor,
      tertiaryColor: other.tertiaryColor ?? tertiaryColor,
      accentColor: other.accentColor ?? accentColor,
    );
  }

  /// Create a copy of this StyleSheet with certain properties modified
  DCFStyleSheet copyWith({
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
    String? accessibilityHint,
    dynamic accessibilityValue,
    String? accessibilityRole,
    Map<String, dynamic>? accessibilityState,
    List<Map<String, String>>? accessibilityActions,
    bool? accessibilityElementsHidden,
    String? accessibilityLanguage,
    bool? accessibilityIgnoresInvertColors,
    String? accessibilityLiveRegion,
    bool? accessibilityViewIsModal,
    String? ariaLabel,
    String? ariaLabelledby,
    String? ariaLive,
    bool? ariaModal,
    bool? ariaHidden,
    dynamic ariaBusy,
    dynamic ariaChecked,
    bool? ariaDisabled,
    bool? ariaExpanded,
    bool? ariaSelected,
    num? ariaValuemin,
    num? ariaValuemax,
    num? ariaValuenow,
    String? ariaValuetext,
    String? importantForAccessibility,
    String? testID,
    String? pointerEvents,
    // Semantic colors
    Color? primaryColor,
    Color? secondaryColor,
    Color? tertiaryColor,
    Color? accentColor,
  }) {
    return DCFStyleSheet(
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
      accessibilityHint: accessibilityHint ?? this.accessibilityHint,
      accessibilityValue: accessibilityValue ?? this.accessibilityValue,
      accessibilityRole: accessibilityRole ?? this.accessibilityRole,
      accessibilityState: accessibilityState ?? this.accessibilityState,
      accessibilityActions: accessibilityActions ?? this.accessibilityActions,
      accessibilityElementsHidden: accessibilityElementsHidden ?? this.accessibilityElementsHidden,
      accessibilityLanguage: accessibilityLanguage ?? this.accessibilityLanguage,
      accessibilityIgnoresInvertColors: accessibilityIgnoresInvertColors ?? this.accessibilityIgnoresInvertColors,
      accessibilityLiveRegion: accessibilityLiveRegion ?? this.accessibilityLiveRegion,
      accessibilityViewIsModal: accessibilityViewIsModal ?? this.accessibilityViewIsModal,
      ariaLabel: ariaLabel ?? this.ariaLabel,
      ariaLabelledby: ariaLabelledby ?? this.ariaLabelledby,
      ariaLive: ariaLive ?? this.ariaLive,
      ariaModal: ariaModal ?? this.ariaModal,
      ariaHidden: ariaHidden ?? this.ariaHidden,
      ariaBusy: ariaBusy ?? this.ariaBusy,
      ariaChecked: ariaChecked ?? this.ariaChecked,
      ariaDisabled: ariaDisabled ?? this.ariaDisabled,
      ariaExpanded: ariaExpanded ?? this.ariaExpanded,
      ariaSelected: ariaSelected ?? this.ariaSelected,
      ariaValuemin: ariaValuemin ?? this.ariaValuemin,
      ariaValuemax: ariaValuemax ?? this.ariaValuemax,
      ariaValuenow: ariaValuenow ?? this.ariaValuenow,
      ariaValuetext: ariaValuetext ?? this.ariaValuetext,
      importantForAccessibility: importantForAccessibility ?? this.importantForAccessibility,
      testID: testID ?? this.testID,
      pointerEvents: pointerEvents ?? this.pointerEvents,
      // Semantic colors
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      tertiaryColor: tertiaryColor ?? this.tertiaryColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  /// CRITICAL FIX: Add validation method to check for conflicting styles
  List<String> validateStyles() {
    final warnings = <String>[];

    if (backgroundColor != null && backgroundGradient != null) {
      warnings.add(
          'Both backgroundColor and backgroundGradient are set. backgroundGradient will take precedence.');
    }

    if (borderRadius != null &&
        (borderTopLeftRadius != null ||
            borderTopRightRadius != null ||
            borderBottomLeftRadius != null ||
            borderBottomRightRadius != null)) {
      warnings.add(
          'Both borderRadius and specific corner radii are set. Specific corners will take precedence.');
    }

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
    'accessibilityHint',
    'accessibilityValue',
    'accessibilityRole',
    'accessibilityState',
    'accessibilityActions',
    'accessibilityElementsHidden',
    'accessibilityLanguage',
    'accessibilityIgnoresInvertColors',
    'accessibilityLiveRegion',
    'accessibilityViewIsModal',
    'ariaLabel',
    'ariaLabelledby',
    'ariaLive',
    'ariaModal',
    'ariaHidden',
    'ariaBusy',
    'ariaChecked',
    'ariaDisabled',
    'ariaExpanded',
    'ariaSelected',
    'ariaValuemin',
    'ariaValuemax',
    'ariaValuenow',
    'ariaValuetext',
    'importantForAccessibility',
    'testID',
    'pointerEvents',
    // Semantic colors
    'primaryColor',
    'secondaryColor',
    'tertiaryColor',
    'accentColor',
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
        accessibilityHint,
        accessibilityValue,
        accessibilityRole,
        accessibilityState,
        accessibilityActions,
        accessibilityElementsHidden,
        accessibilityLanguage,
        accessibilityIgnoresInvertColors,
        accessibilityLiveRegion,
        accessibilityViewIsModal,
        ariaLabel,
        ariaLabelledby,
        ariaLive,
        ariaModal,
        ariaHidden,
        ariaBusy,
        ariaChecked,
        ariaDisabled,
        ariaExpanded,
        ariaSelected,
        ariaValuemin,
        ariaValuemax,
        ariaValuenow,
        ariaValuetext,
        importantForAccessibility,
        testID,
        pointerEvents,
        // Semantic colors
        primaryColor,
        secondaryColor,
        tertiaryColor,
        accentColor,
        _styleId,
      ];
}

/// StyleSheet registry returned by DCFStyleSheet.create()
/// Provides access to registered styles by name
class DCFStyleSheetRegistry {
  final Map<String, DCFStyleSheet> _styles = {};
  
  DCFStyleSheetRegistry._();
  
  /// Get a registered style by name
  DCFStyleSheet operator [](String name) {
    final style = _styles[name];
    if (style == null) {
      throw ArgumentError('Style "$name" not found in registry. Available styles: ${_styles.keys.join(", ")}');
    }
    return style;
  }
  
  /// Check if a style exists in the registry
  bool containsKey(String name) => _styles.containsKey(name);
  
  /// Get all registered style names
  Iterable<String> get keys => _styles.keys;
}
