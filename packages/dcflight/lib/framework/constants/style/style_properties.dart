/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'gradient.dart';
export 'gradient.dart'; // Export DCFGradient for use in examples
import 'hit_slop.dart';
import 'style_processors.dart';
export 'style_flatten.dart'; // Export flattenStyle for public API
export 'style_processors.dart' show processColor, processTransform, processShadow, processAspectRatio, normalizeColor;
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
/// Style registry for StyleSheet.create() pattern.
///
/// Caches styles and assigns numeric IDs for efficient bridge communication.
/// Registered styles can be referenced by ID instead of sending full objects.
///
/// Usage:
/// ```dart
/// final styles = DCFStyleSheet.create({
///   'container': DCFStyleSheet(backgroundColor: Colors.blue),
/// });
/// // styles.container has an internal numeric ID
/// ```
class _DCFStyleRegistry {
  static final _DCFStyleRegistry instance = _DCFStyleRegistry._();
  _DCFStyleRegistry._();

  /// Maps numeric ID -> original style object (without ID)
  final Map<int, DCFStyleSheet> _styles = {};
  
  /// Maps style object -> numeric ID (for deduplication)
  final Map<DCFStyleSheet, int> _styleToId = {};
  
  /// Next available numeric ID
  int _nextId = 1;

  /// Register a style and return its numeric ID.
  ///
  /// If the same style instance is already registered, returns the existing ID.
  /// This enables style deduplication and reduces memory usage.
  ///
  /// The original style (without ID) is stored to avoid recursion in toMap().
  int register(String name, DCFStyleSheet style) {
    // Check if this exact style instance is already registered
    if (_styleToId.containsKey(style)) {
      return _styleToId[style]!;
    }

    // Generate new numeric ID
    final id = _nextId;
    _nextId++;

    // Store ORIGINAL style (without ID) to avoid recursion when resolving
    _styles[id] = style;
    _styleToId[style] = id;

    return id;
  }

  /// Get style by numeric ID.
  ///
  /// Returns null if ID is not found in registry.
  DCFStyleSheet? get(int id) {
    return _styles[id];
  }

  /// Get numeric ID for a style (if registered).
  ///
  /// Returns null if style is not registered.
  int? getId(DCFStyleSheet style) {
    return _styleToId[style];
  }

  /// Check if style is registered in the registry.
  bool isRegistered(DCFStyleSheet style) {
    return _styleToId.containsKey(style);
  }

  /// Clear all registered styles (for testing/debugging).
  void clear() {
    _styles.clear();
    _styleToId.clear();
    _nextId = 1;
  }
}

/// StyleSheet defines visual styling properties for components.
///
/// StyleSheet provides a type-safe way to define styles that are processed
/// and sent to native platforms for rendering. Styles can be registered
/// via `DCFStyleSheet.create()` for better performance, or used inline.
///
/// **Basic Usage:**
/// ```dart
/// // Inline style
/// DCFView(
///   style: DCFStyleSheet(
///     backgroundColor: Colors.blue,
///     borderRadius: 8,
///     padding: EdgeInsets.all(16),
///   ),
/// )
/// ```
///
/// **Registered Styles (Recommended):**
/// ```dart
/// final styles = DCFStyleSheet.create({
///   'container': DCFStyleSheet(
///     backgroundColor: Colors.white,
///     borderRadius: 12,
///   ),
///   'button': DCFStyleSheet(
///     backgroundColor: Colors.blue,
///     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
///   ),
/// });
///
/// // Use registered styles
/// DCFView(style: styles.container)
/// DCFButton(style: styles.button)
/// ```
///
/// **Merging Styles:**
/// ```dart
/// final base = DCFStyleSheet(backgroundColor: Colors.white);
/// final override = DCFStyleSheet(backgroundColor: Colors.blue);
/// final merged = base.merge(override); // backgroundColor is blue
/// ```
///
/// **Style Arrays (Flattening):**
/// ```dart
/// final flattened = flattenStyle([
///   DCFStyleSheet(backgroundColor: Colors.white),
///   DCFStyleSheet(backgroundColor: Colors.blue), // Overrides white
/// ]);
/// ```
///
/// **Semantic Colors:**
/// Use semantic colors for theme-aware styling:
/// ```dart
/// DCFStyleSheet(
///   primaryColor: DCFTheme.textColor,      // Main text color
///   secondaryColor: DCFTheme.secondaryTextColor,  // Secondary text
///   backgroundColor: DCFTheme.surfaceColor,
/// )
/// ```
class DCFStyleSheet extends Equatable {
  /// Internal numeric style ID if registered via StyleSheet.create().
  ///
  /// Null for non-registered styles (backward compatibility).
  /// Registered styles can be referenced by ID to reduce bridge traffic.
  final int? _styleId;

  final dynamic borderRadius;
  final dynamic borderTopLeftRadius;
  final dynamic borderTopRightRadius;
  final dynamic borderBottomLeftRadius;
  final dynamic borderBottomRightRadius;
  
  final Color? borderColor;
  final Color? borderTopColor;
  final Color? borderRightColor;
  final Color? borderBottomColor;
  final Color? borderLeftColor;
  
  final dynamic borderWidth;
  final dynamic borderTopWidth;
  final dynamic borderRightWidth;
  final dynamic borderBottomWidth;
  final dynamic borderLeftWidth;
  
  /// Border style: 'solid', 'dotted', or 'dashed'.
  ///
  /// Controls how borders are rendered:
  /// - 'solid': Continuous line (default)
  /// - 'dotted': Dotted line
  /// - 'dashed': Dashed line
  ///
  /// Example:
  /// ```dart
  /// DCFStyleSheet(
  ///   borderWidth: 2,
  ///   borderColor: Colors.black,
  ///   borderStyle: 'dashed',
  /// )
  /// ```
  final String? borderStyle;

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

  /// Internal factory constructor for registered styles (non-const).
  ///
  /// Used by StyleSheet.create() to create styles with numeric IDs.
  /// This allows native platforms to cache styles and reference them by ID.
  DCFStyleSheet._withId(
    int styleId, {
    this.borderRadius,
    this.borderTopLeftRadius,
    this.borderTopRightRadius,
    this.borderBottomLeftRadius,
    this.borderBottomRightRadius,
    this.borderColor,
    this.borderTopColor,
    this.borderRightColor,
    this.borderBottomColor,
    this.borderLeftColor,
    this.borderWidth,
    this.borderTopWidth,
    this.borderRightWidth,
    this.borderBottomWidth,
    this.borderLeftWidth,
    this.borderStyle,
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
  // @Deprecated('Use DCFStyleSheet.create() instead for better bridge efficiency. Example: final styles = DCFStyleSheet.create({"container": DCFStyleSheet(backgroundColor: Colors.blue)});')
  const DCFStyleSheet({
    this.borderRadius,
    this.borderTopLeftRadius,
    this.borderTopRightRadius,
    this.borderBottomLeftRadius,
    this.borderBottomRightRadius,
    this.borderColor,
    this.borderTopColor,
    this.borderRightColor,
    this.borderBottomColor,
    this.borderLeftColor,
    this.borderWidth,
    this.borderTopWidth,
    this.borderRightWidth,
    this.borderBottomWidth,
    this.borderLeftWidth,
    this.borderStyle,
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

  /// Create a StyleSheet registry for efficient style management.
  ///
  /// This optimizes bridge communication by caching styles and assigning numeric IDs.
  /// Registered styles can be referenced by ID, reducing serialization overhead.
  ///
  /// **Basic Usage:**
  /// ```dart
  /// final styles = DCFStyleSheet.create({
  ///   'container': DCFStyleSheet(backgroundColor: Colors.blue),
  ///   'text': DCFStyleSheet(primaryColor: Colors.black),
  /// });
  ///
  /// // Use registered styles
  /// DCFView(style: styles.container)
  /// DCFText(style: styles.text)
  /// ```
  ///
  /// **Type-Safe Pattern:**
  /// ```dart
  /// class AppStyles {
  ///   static final container = DCFStyleSheet(backgroundColor: Colors.blue);
  ///   static final text = DCFStyleSheet(primaryColor: Colors.black);
  /// }
  ///
  /// final styles = DCFStyleSheet.create({
  ///   'container': AppStyles.container,
  ///   'text': AppStyles.text,
  /// });
  /// ```
  ///
  /// **Benefits:**
  /// - **Performance**: Styles are cached and referenced by numeric ID
  /// - **Memory**: Duplicate styles are deduplicated automatically
  /// - **Validation**: Style errors are caught at creation time
  /// - **Type Safety**: Full IDE autocomplete and type checking
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
        borderTopColor: entry.value.borderTopColor,
        borderRightColor: entry.value.borderRightColor,
        borderBottomColor: entry.value.borderBottomColor,
        borderLeftColor: entry.value.borderLeftColor,
        borderWidth: entry.value.borderWidth,
        borderTopWidth: entry.value.borderTopWidth,
        borderRightWidth: entry.value.borderRightWidth,
        borderBottomWidth: entry.value.borderBottomWidth,
        borderLeftWidth: entry.value.borderLeftWidth,
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
        accessibilityIgnoresInvertColors:
            entry.value.accessibilityIgnoresInvertColors,
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

  /// Create a StyleSheet registry from a class with static final properties (type-safe registration)
  ///
  /// This allows type-safe registration and access without string keys.
  ///
  /// Example:
  /// ```dart
  /// class AppStyles {
  ///   static final container = DCFStyleSheet(backgroundColor: Colors.blue);
  ///   static final text = DCFStyleSheet(primaryColor: Colors.black);
  /// }
  ///
  /// final styles = DCFStyleSheet.createFrom({
  ///   'container': AppStyles.container,
  ///   'text': AppStyles.text,
  /// });
  /// // Or use the builder pattern:
  /// final styles = DCFStyleSheet.createFromClass(() => AppStyles());
  /// ```
  ///
  /// For even simpler usage, define styles as a class and use create() with a helper:
  /// ```dart
  /// class Styles {
  ///   static final root = DCFStyleSheet(backgroundColor: Colors.black);
  ///   static final button = DCFStyleSheet(primaryColor: Colors.white);
  /// }
  ///
  /// final _styles = DCFStyleSheet.create({
  ///   'root': Styles.root,
  ///   'button': Styles.button,
  /// });
  /// // Use: _styles.root, _styles.button (type-safe access)
  /// ```
  static DCFStyleSheetRegistry createFrom(Map<String, DCFStyleSheet> styles) {
    // Alias for create() - same functionality, clearer name for type-safe usage
    return create(styles);
  }

  /// Convert style properties to a map for serialization to native platforms.
  ///
  /// Processes all style values through style processors (colors, transforms, etc.)
  /// and returns a map ready for native consumption.
  ///
  /// **Precedence Rules:**
  /// - backgroundGradient overrides backgroundColor
  /// - Specific border properties override general ones (borderTopWidth overrides borderWidth)
  /// - Specific corner radii override general borderRadius
  ///
  /// **Semantic Colors:**
  /// Semantic colors are always included with theme fallbacks to ensure
  /// native components always receive explicit color values.
  ///
  /// **Style IDs:**
  /// If this style is registered via StyleSheet.create(), the method can send
  /// either the style ID or the full style object. When `sendId: true`, only
  /// the numeric ID is sent, allowing native platforms to cache and reuse styles.
  ///
  /// Example:
  /// ```dart
  /// final style = DCFStyleSheet(
  ///   backgroundColor: Colors.blue,
  ///   borderRadius: 8,
  /// );
  /// final map = style.toMap();
  /// // Returns: {'backgroundColor': 'dcf:#0000ff', 'borderRadius': 8}
  ///
  /// // For registered styles:
  /// final registeredStyle = DCFStyleSheet.create({'container': style}).container;
  /// final mapWithId = registeredStyle.toMap(sendId: true);
  /// // Returns: {'styleId': 1} (native resolves to full style)
  /// ```
  Map<String, dynamic> toMap({bool sendId = false}) {
    // If registered and sendId is true, send only the numeric ID
    // Native platforms will resolve it to the full style object
    if (_styleId != null && sendId) {
      return {'styleId': _styleId};
    }
    
    // If registered but sendId is false, resolve numeric ID to full style object
    // This is the default behavior for backward compatibility
    if (_styleId != null && !sendId) {
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
    // Process border colors through color processor
    if (borderColor != null) {
      final processedColor = processColor(borderColor);
      if (processedColor != null) {
        map['borderColor'] = _intColorToString(processedColor);
      }
    }
    if (borderTopColor != null) {
      final processedColor = processColor(borderTopColor);
      if (processedColor != null) {
        map['borderTopColor'] = _intColorToString(processedColor);
      }
    }
    if (borderRightColor != null) {
      final processedColor = processColor(borderRightColor);
      if (processedColor != null) {
        map['borderRightColor'] = _intColorToString(processedColor);
      }
    }
    if (borderBottomColor != null) {
      final processedColor = processColor(borderBottomColor);
      if (processedColor != null) {
        map['borderBottomColor'] = _intColorToString(processedColor);
      }
    }
    if (borderLeftColor != null) {
      final processedColor = processColor(borderLeftColor);
      if (processedColor != null) {
        map['borderLeftColor'] = _intColorToString(processedColor);
      }
    }
    if (borderWidth != null) map['borderWidth'] = borderWidth;
    if (borderTopWidth != null) map['borderTopWidth'] = borderTopWidth;
    if (borderRightWidth != null) map['borderRightWidth'] = borderRightWidth;
    if (borderBottomWidth != null) map['borderBottomWidth'] = borderBottomWidth;
    if (borderLeftWidth != null) map['borderLeftWidth'] = borderLeftWidth;
    if (borderStyle != null) map['borderStyle'] = borderStyle;

    // Process backgroundColor through color processor
    // Note: backgroundGradient takes precedence if both are set
    if (backgroundColor != null && backgroundGradient == null) {
      final processedColor = processColor(backgroundColor);
      if (processedColor != null) {
        map['backgroundColor'] = _intColorToString(processedColor);
      }
    }

    if (backgroundGradient != null) {
      map['backgroundGradient'] = backgroundGradient!.toMap();
    }

    if (opacity != null) map['opacity'] = opacity;

    // Process shadow color through color processor
    if (shadowColor != null) {
      final processedColor = processColor(shadowColor);
      if (processedColor != null) {
        map['shadowColor'] = _intColorToString(processedColor);
      }
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
      map['accessibilityIgnoresInvertColors'] =
          accessibilityIgnoresInvertColors;
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
    // Process semantic colors through color processor
    final finalPrimaryColor = primaryColor ?? DCFTheme.textColor;
    final finalSecondaryColor =
        secondaryColor ?? DCFTheme.current.secondaryTextColor;
    final finalTertiaryColor =
        tertiaryColor ?? DCFTheme.current.secondaryTextColor;
    final finalAccentColor = accentColor ?? DCFTheme.accentColor;
    final finalBackgroundColor = backgroundColor ?? DCFTheme.backgroundColor;

    final processedPrimary = processColor(finalPrimaryColor);
    if (processedPrimary != null) {
      map['primaryColor'] = _intColorToString(processedPrimary);
    }
    final processedSecondary = processColor(finalSecondaryColor);
    if (processedSecondary != null) {
      map['secondaryColor'] = _intColorToString(processedSecondary);
    }
    final processedTertiary = processColor(finalTertiaryColor);
    if (processedTertiary != null) {
      map['tertiaryColor'] = _intColorToString(processedTertiary);
    }
    final processedAccent = processColor(finalAccentColor);
    if (processedAccent != null) {
      map['accentColor'] = _intColorToString(processedAccent);
    }
    final processedBg = processColor(finalBackgroundColor);
    if (processedBg != null) {
      map['backgroundColor'] = _intColorToString(processedBg);
    }
    return map;
  }

  /// Converts processed color integers (ARGB format) to platform-specific color strings.
  ///
  /// Uses "dcf:" prefix format to distinguish special cases (transparent, black)
  /// and ensure consistent parsing on native platforms.
  ///
  /// **Format:**
  /// - Transparent: `'dcf:transparent'`
  /// - Black: `'dcf:black'`
  /// - Opaque colors: `'dcf:#RRGGBB'` (6-digit hex)
  /// - Colors with alpha: `'dcf:#AARRGGBB'` (8-digit hex, ARGB format)
  ///
  /// Native platforms parse this format and convert to platform-specific color types.
  ///
  /// Example:
  /// ```dart
  /// _intColorToString(0x00000000)  // 'dcf:transparent'
  /// _intColorToString(0xFF000000)  // 'dcf:black'
  /// _intColorToString(0xFF0000FF)  // 'dcf:#0000ff'
  /// _intColorToString(0x800000FF)  // 'dcf:#800000ff'
  /// ```
  String _intColorToString(int colorValue) {
    final alpha = (colorValue >> 24) & 0xFF;
    final rgb = colorValue & 0xFFFFFF;

    // Transparent - explicitly marked
    if (alpha == 0) {
      return 'dcf:transparent';
    }

    // Black - explicitly marked to distinguish from transparent
    if (colorValue == 0xFF000000) {
      return 'dcf:black';
    }

    // Other colors - use dcf: prefix with hex
    if (alpha == 255) {
      return 'dcf:#${rgb.toRadixString(16).padLeft(6, '0')}';
    } else {
      return 'dcf:#${colorValue.toRadixString(16).padLeft(8, '0')}';
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
      borderTopColor: other.borderTopColor ?? borderTopColor,
      borderRightColor: other.borderRightColor ?? borderRightColor,
      borderBottomColor: other.borderBottomColor ?? borderBottomColor,
      borderLeftColor: other.borderLeftColor ?? borderLeftColor,
      borderWidth: other.borderWidth ?? borderWidth,
      borderTopWidth: other.borderTopWidth ?? borderTopWidth,
      borderRightWidth: other.borderRightWidth ?? borderRightWidth,
      borderBottomWidth: other.borderBottomWidth ?? borderBottomWidth,
      borderLeftWidth: other.borderLeftWidth ?? borderLeftWidth,
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
      accessibilityElementsHidden:
          other.accessibilityElementsHidden ?? accessibilityElementsHidden,
      accessibilityLanguage:
          other.accessibilityLanguage ?? accessibilityLanguage,
      accessibilityIgnoresInvertColors:
          other.accessibilityIgnoresInvertColors ??
              accessibilityIgnoresInvertColors,
      accessibilityLiveRegion:
          other.accessibilityLiveRegion ?? accessibilityLiveRegion,
      accessibilityViewIsModal:
          other.accessibilityViewIsModal ?? accessibilityViewIsModal,
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
      importantForAccessibility:
          other.importantForAccessibility ?? importantForAccessibility,
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
    Color? borderTopColor,
    Color? borderRightColor,
    Color? borderBottomColor,
    Color? borderLeftColor,
    dynamic borderWidth,
    dynamic borderTopWidth,
    dynamic borderRightWidth,
    dynamic borderBottomWidth,
    dynamic borderLeftWidth,
    String? borderStyle,
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
      borderTopColor: borderTopColor ?? this.borderTopColor,
      borderRightColor: borderRightColor ?? this.borderRightColor,
      borderBottomColor: borderBottomColor ?? this.borderBottomColor,
      borderLeftColor: borderLeftColor ?? this.borderLeftColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderTopWidth: borderTopWidth ?? this.borderTopWidth,
      borderRightWidth: borderRightWidth ?? this.borderRightWidth,
      borderBottomWidth: borderBottomWidth ?? this.borderBottomWidth,
      borderLeftWidth: borderLeftWidth ?? this.borderLeftWidth,
      borderStyle: borderStyle ?? this.borderStyle,
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
      accessibilityElementsHidden:
          accessibilityElementsHidden ?? this.accessibilityElementsHidden,
      accessibilityLanguage:
          accessibilityLanguage ?? this.accessibilityLanguage,
      accessibilityIgnoresInvertColors: accessibilityIgnoresInvertColors ??
          this.accessibilityIgnoresInvertColors,
      accessibilityLiveRegion:
          accessibilityLiveRegion ?? this.accessibilityLiveRegion,
      accessibilityViewIsModal:
          accessibilityViewIsModal ?? this.accessibilityViewIsModal,
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
      importantForAccessibility:
          importantForAccessibility ?? this.importantForAccessibility,
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
    'borderTopColor',
    'borderRightColor',
    'borderBottomColor',
    'borderLeftColor',
    'borderWidth',
    'borderTopWidth',
    'borderRightWidth',
    'borderBottomWidth',
    'borderLeftWidth',
    'borderStyle',
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
        borderTopColor,
        borderRightColor,
        borderBottomColor,
        borderLeftColor,
        borderWidth,
        borderTopWidth,
        borderRightWidth,
        borderBottomWidth,
        borderLeftWidth,
        borderStyle,
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
/// Provides type-safe access to registered styles by name
///
/// Supports both bracket notation and dot notation:
/// ```dart
/// _styles['buttonText']  // Bracket notation
/// _styles.buttonText     // Dot notation (works via noSuchMethod)
/// ```
class DCFStyleSheetRegistry {
  final Map<String, DCFStyleSheet> _styles = {};

  DCFStyleSheetRegistry._();

  /// Get a registered style by name (bracket notation)
  DCFStyleSheet operator [](String name) {
    final style = _styles[name];
    if (style == null) {
      throw ArgumentError(
          'Style "$name" not found in registry. Available styles: ${_styles.keys.join(", ")}');
    }
    return style;
  }

  /// Type-safe dot notation access (e.g., _styles.buttonText)
  /// Uses noSuchMethod to provide dynamic property access
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final name = invocation.memberName
          .toString()
          .replaceFirst(RegExp(r'^Symbol\("'), '')
          .replaceFirst(RegExp(r'"\)$'), '');
      if (_styles.containsKey(name)) {
        return _styles[name] as DCFStyleSheet;
      }
      throw ArgumentError(
          'Style "$name" not found in registry. Available styles: ${_styles.keys.join(", ")}');
    }
    return super.noSuchMethod(invocation);
  }

  /// Check if a style exists in the registry
  bool containsKey(String name) => _styles.containsKey(name);

  /// Get all registered style names
  Iterable<String> get keys => _styles.keys;
}