/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';

/// Font weight options for text components
enum DCFFontWeight {
  thin,
  ultraLight,
  light,
  regular,
  medium,
  semibold,
  bold,
  heavy,
  black;

  /// Convert to numeric weight (100-900) for native side
  /// Both iOS and Android use numeric weights directly
  int get numericWeight {
    switch (this) {
      case DCFFontWeight.thin:
        return 100;
      case DCFFontWeight.ultraLight:
        return 200;
      case DCFFontWeight.light:
        return 300;
      case DCFFontWeight.regular:
        return 400;
      case DCFFontWeight.medium:
        return 500;
      case DCFFontWeight.semibold:
        return 600;
      case DCFFontWeight.bold:
        return 700;
      case DCFFontWeight.heavy:
        return 800;
      case DCFFontWeight.black:
        return 900;
    }
  }
}

/// Text alignment options for text components  
enum DCFTextAlign {
  left,
  center,
  right,
  justify;

  /// Convert to string value for native side
  String get value {
    switch (this) {
      case DCFTextAlign.left:
        return 'left';
      case DCFTextAlign.center:
        return 'center';
      case DCFTextAlign.right:
        return 'right';
      case DCFTextAlign.justify:
        return 'justify';
    }
  }
}

/// Text style properties
class DCFTextProps {
  /// Font size
  final double? fontSize;

  /// Font weight
  final DCFFontWeight? fontWeight;

  /// Font family
  final String? fontFamily;

  /// Whether the font family refers to an asset path
  final bool isFontAsset;

  /// Text alignment
  final DCFTextAlign? textAlign;
  
  /// NOTE: Color is now handled via StyleSheet.primaryColor
  /// Use DCFStyleSheet(primaryColor: ...) instead of textProps.color

  /// Number of lines (0 for unlimited)
  final int? numberOfLines;

  /// Letter spacing (character spacing)
  final double? letterSpacing;

  /// Line height (line spacing multiplier or absolute value)
  final double? lineHeight;

  /// Whether to automatically adjust font size to fit within bounds
  final bool? adjustsFontSizeToFit;

  /// Minimum font scale when adjustsFontSizeToFit is enabled (0.0 to 1.0)
  final double? minimumFontScale;

  /// Create text props
  /// 
  /// NOTE: Use StyleSheet.primaryColor for text color instead of color prop
  const DCFTextProps({
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.isFontAsset = false,
    this.textAlign =  DCFTextAlign.center,
    this.numberOfLines,
    this.letterSpacing,
    this.lineHeight,
    this.adjustsFontSizeToFit,
    this.minimumFontScale,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight!.numericWeight,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (isFontAsset) 'isFontAsset': isFontAsset,
      // Color removed - use StyleSheet.primaryColor instead
      if (textAlign != null) 'textAlign': textAlign!.value,
      if (numberOfLines != null) 'numberOfLines': numberOfLines,
      if (letterSpacing != null) 'letterSpacing': letterSpacing,
      if (lineHeight != null) 'lineHeight': lineHeight,
      if (adjustsFontSizeToFit != null) 'adjustsFontSizeToFit': adjustsFontSizeToFit,
      if (minimumFontScale != null) 'minimumFontScale': minimumFontScale,
    };
  }
}

/// A text component implementation using StatelessComponent
class DCFText extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// The text content to display
  final String content;

  /// The text properties
  final DCFTextProps textProps;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Explicit color override: textColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for text
  final Color? textColor;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Create a text component
  DCFText({
    required this.content,
    this.textProps = const DCFTextProps(),
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    this.textColor,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Merge user-provided styleSheet with default (transparent background)
    final defaultTextStyleSheet = const DCFStyleSheet(backgroundColor: DCFColors.transparent);
    final mergedStyleSheet = defaultTextStyleSheet.merge(styleSheet);
    
    // CRITICAL: Apply default layout constraints to prevent text overflow on small devices
    // These defaults ensure text can shrink and wrap properly, especially on Android
    // User-provided layout values will override these defaults (via merge)
    const defaultTextLayout = DCFLayout(
      flexShrink: 1, // Allow text to shrink when space is limited
      minWidth: 0, // CRITICAL: Allow shrinking below content size to prevent overflow
    );
    final mergedLayout = defaultTextLayout.merge(layout);
    
    Map<String, dynamic> props = {
      'content': content,
      ...textProps.toMap(),
      ...mergedLayout.toMap(), // Use merged layout with overflow-prevention defaults
      ...mergedStyleSheet.toMap(),
      if (textColor != null) 'textColor': DCFColors.toNativeString(textColor!),
      // Include system state version to trigger updates on system changes
      // (font scale, language, theme, etc.) even when props don't change
      // This ensures reconciliation detects system changes and updates native views
      '_systemVersion': SystemStateManager.version,
      ...(events ?? {}),
    };

    return DCFElement(
      type: 'Text',
      elementProps: props,
      children: [],
    );
  }
}
