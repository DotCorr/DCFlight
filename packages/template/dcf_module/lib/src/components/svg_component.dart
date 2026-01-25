/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';

/// SVG properties
class DCFSVGProps {
  /// The SVG source (asset or URL)
  final String source;

  /// Whether the source is an asset
  final bool isAsset;

  /// The width of the SVG
  final double? width;

  /// The height of the SVG
  final double? height;


  /// Create SVG props
  const DCFSVGProps({
    required this.source,
    this.isAsset = false,
    this.width,
    this.height,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'isAsset': isAsset,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
  }
}

/// An SVG component implementation using StatelessComponent
class DCFSVG extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.normal;

  /// The SVG properties
  final DCFSVGProps svgProps;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Explicit color override: tintColor (overrides StyleSheet.primaryColor)
  /// If provided, this will override the semantic primaryColor for SVG tint
  final Color? tintColor;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Create an SVG component
  DCFSVG({
    required this.svgProps,
    this.layout = const DCFLayout(height: 20, width: 20),
    this.styleSheet = const DCFStyleSheet(),
    this.tintColor,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'Svg',
      elementProps: {
        ...svgProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        if (tintColor != null) 'tintColor': DCFColors.toNativeString(tintColor!),
        ...(events ?? {}),
      },
      children: [],
    );
  }
}
