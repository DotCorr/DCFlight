/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// Text style properties
class DCFTextProps {
  /// Font size
  final double? fontSize;
  
  /// Font weight
  final String? fontWeight;
  
  /// Font family
  final String? fontFamily;
  
  /// Whether the font family refers to an asset path
  final bool isFontAsset;
  
  /// Text color
  final Color? color;
  
  /// Text alignment
  final String? textAlign;
  
  /// Number of lines (0 for unlimited)
  final int? numberOfLines;
  
  /// Create text props
  const DCFTextProps({
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.isFontAsset = false,
    this.color,
    this.textAlign,
    this.numberOfLines,
  });
  
  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (isFontAsset) 'isFontAsset': isFontAsset,
      if (color != null) 'color': '#${color!.value.toRadixString(16).padLeft(8, '0')}',
      if (textAlign != null) 'textAlign': textAlign,
      if (numberOfLines != null) 'numberOfLines': numberOfLines,
    };
  }
}

/// A text component implementation using StatelessComponent
class DCFText extends StatelessComponent {
  /// The text content to display
  final String content;
  
  /// The text properties
  final DCFTextProps textProps;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;
  
  /// Create a text component
  DCFText({
    required this.content,
    this.textProps = const DCFTextProps(),
       this.layout = const LayoutProps(
        
      height: 50,width: 200
    ),
    this.styleSheet = const StyleSheet(),
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'Text',
      props: {
        'content': content,
        ...textProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...(events ?? {}),
      },
      children: [],
    );
  }
}
