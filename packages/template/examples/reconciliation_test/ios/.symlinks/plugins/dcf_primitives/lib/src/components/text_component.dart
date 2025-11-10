/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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

  /// Convert to string value for native side
  String get value {
    switch (this) {
      case DCFFontWeight.thin:
        return 'thin';
      case DCFFontWeight.ultraLight:
        return 'ultraLight';
      case DCFFontWeight.light:
        return 'light';
      case DCFFontWeight.regular:
        return 'regular';
      case DCFFontWeight.medium:
        return 'medium';
      case DCFFontWeight.semibold:
        return 'semibold';
      case DCFFontWeight.bold:
        return 'bold';
      case DCFFontWeight.heavy:
        return 'heavy';
      case DCFFontWeight.black:
        return 'black';
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
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight!.value,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (isFontAsset) 'isFontAsset': isFontAsset,
      // Color removed - use StyleSheet.primaryColor instead
      if (textAlign != null) 'textAlign': textAlign!.value,
      if (numberOfLines != null) 'numberOfLines': numberOfLines,
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
    Map<String, dynamic> props = {
      'content': content,
      ...textProps.toMap(),
      ...layout.toMap(),
      ...styleSheet.toMap(),
      if (textColor != null) 'textColor': DCFColors.toNativeString(textColor!),
      ...(events ?? {}),
    };

    return DCFElement(
      type: 'Text',
      elementProps: props,
      children: [],
    );
  }
}

