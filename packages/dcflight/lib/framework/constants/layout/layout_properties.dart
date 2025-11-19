/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import 'package:equatable/equatable.dart';
import 'package:dcflight/framework/constants/layout/yoga_enums.dart';
import 'package:dcflight/framework/constants/layout/absolute_layout.dart';

/// Layout registry for DCFLayout.create() pattern
/// Caches layouts and assigns IDs for efficient bridge communication
class _DCFLayoutRegistry {
  static final _DCFLayoutRegistry instance = _DCFLayoutRegistry._();
  _DCFLayoutRegistry._();
  
  final Map<String, DCFLayout> _layouts = {}; // Maps ID -> original layout (without ID)
  final Map<DCFLayout, String> _layoutToId = {};
  int _nextId = 1;
  
  /// Register a layout and return its ID
  /// Stores the ORIGINAL layout (without ID) to avoid recursion in toMap()
  String register(String name, DCFLayout layout) {
    // Check if this exact layout instance is already registered
    if (_layoutToId.containsKey(layout)) {
      return _layoutToId[layout]!;
    }
    
    // Generate new ID
    final id = 'dcf_layout_$_nextId';
    _nextId++;
    
    // Store ORIGINAL layout (without ID) to avoid recursion when resolving
    _layouts[id] = layout;
    _layoutToId[layout] = id;
    
    return id;
  }
  
  /// Get layout by ID
  DCFLayout? get(String id) {
    return _layouts[id];
  }
  
  /// Get ID for a layout (if registered)
  String? getId(DCFLayout layout) {
    return _layoutToId[layout];
  }
  
  /// Check if layout is registered
  bool isRegistered(DCFLayout layout) {
    return _layoutToId.containsKey(layout);
  }
  
  /// Clear all registered layouts (for testing/debugging)
  void clear() {
    _layouts.clear();
    _layoutToId.clear();
    _nextId = 1;
  }
}

/// Layout properties for components
class DCFLayout extends Equatable {
  /// Internal layout ID if registered via DCFLayout.create()
  /// Null for non-registered layouts (backward compatibility)
  final String? _layoutId;
  final dynamic width;
  final dynamic height;
  final dynamic minWidth;
  final dynamic maxWidth;
  final dynamic minHeight;
  final dynamic maxHeight;

  final dynamic margin;
  final dynamic marginTop;
  final dynamic marginRight;
  final dynamic marginBottom;
  final dynamic marginLeft;
  final dynamic marginHorizontal;
  final dynamic marginVertical;

  final dynamic padding;
  final dynamic paddingTop;
  final dynamic paddingRight;
  final dynamic paddingBottom;
  final dynamic paddingLeft;
  final dynamic paddingHorizontal;
  final dynamic paddingVertical;

  final DCFPositionType? position;

  final AbsoluteLayout? absoluteLayout;

  final double?
      rotateInDegrees; // Rotation in degrees (more intuitive than radians for most developers)
  final double? scale; // Uniform scale factor for both x and y axes
  final double? scaleX; // Scale factor for x axis only
  final double? scaleY; // Scale factor for y axis only

  final DCFFlexDirection? flexDirection;
  final DCFJustifyContent? justifyContent;
  final DCFAlign? alignItems;
  final DCFAlign? alignSelf;
  final DCFAlign? alignContent;
  final DCFWrap? flexWrap;
  final double? flex;
  final double? flexGrow;
  final double? flexShrink;
  final dynamic flexBasis;

  final DCFDisplay? display;
  final DCFOverflow? overflow;

  final DCFDirection? direction;

  final double? aspectRatio;
  final dynamic gap;
  final dynamic rowGap;
  final dynamic columnGap;

  @Deprecated("Use borderWidth from style instead")
  final dynamic borderWidth;

  /// Internal factory constructor for registered layouts (non-const)
  DCFLayout._withId(
    String layoutId, {
    this.width = '100%',
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.margin,
    this.marginTop,
    this.marginRight,
    this.marginBottom,
    this.marginLeft,
    this.marginHorizontal,
    this.marginVertical,
    this.padding,
    this.paddingTop,
    this.paddingRight,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingHorizontal,
    this.paddingVertical,
    this.position,
    this.absoluteLayout,
    this.rotateInDegrees,
    this.scale,
    this.scaleX,
    this.scaleY,
    this.flexDirection = DCFFlexDirection.column,
    this.justifyContent = DCFJustifyContent.center,
    this.alignItems = DCFAlign.center,
    this.alignSelf,
    this.alignContent,
    this.flexWrap = DCFWrap.nowrap,
    this.flex,
    this.flexGrow,
    this.flexShrink,
    this.flexBasis,
    this.display = DCFDisplay.flex,
    this.overflow,
    this.direction,
    this.aspectRatio,
    this.gap,
    this.rowGap,
    this.columnGap,
    this.borderWidth,
  }) : _layoutId = layoutId;

  /// Create layout props with the specified values
  /// 
  /// @Deprecated Use DCFLayout.create() instead for better performance
  /// This constructor is still supported for backward compatibility but will be removed in a future version.
  @Deprecated('Use DCFLayout.create() instead for better bridge efficiency. Example: final layouts = DCFLayout.create({"container": DCFLayout(flex: 1)});')
  const DCFLayout({
    this.width = '100%', // Default to 100% width for proper nesting
    this.height, // No default height - let flex layout handle it
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.margin,
    this.marginTop,
    this.marginRight,
    this.marginBottom,
    this.marginLeft,
    this.marginHorizontal,
    this.marginVertical,
    this.padding,
    this.paddingTop,
    this.paddingRight,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingHorizontal,
    this.paddingVertical,
    this.position,
    this.absoluteLayout,
    this.rotateInDegrees,
    this.scale,
    this.scaleX,
    this.scaleY,
    this.flexDirection = DCFFlexDirection.column,
    this.justifyContent = DCFJustifyContent.center, // Default to center like iOS
    this.alignItems = DCFAlign.center, // Default to center like iOS 
    this.alignSelf,
    this.alignContent, // No default - let parent control content alignment
    this.flexWrap = DCFWrap.nowrap,
    this.flex,
    this.flexGrow,
    this.flexShrink,
    this.flexBasis,
    this.display = DCFDisplay.flex,
    this.overflow,
    this.direction,
    this.aspectRatio,
    this.gap,
    this.rowGap,
    this.columnGap,
    this.borderWidth,
  }) : _layoutId = null;

  /// Create a Layout registry (React Native StyleSheet.create() pattern for layouts)
  /// 
  /// This optimizes bridge communication by caching layouts and sending IDs instead of full objects.
  /// 
  /// Example:
  /// ```dart
  /// final layouts = DCFLayout.create({
  ///   'container': DCFLayout(flex: 1, padding: 20),
  ///   'row': DCFLayout(flexDirection: DCFFlexDirection.row),
  /// });
  /// 
  /// // Use with ID reference
  /// DCFView(layout: layouts.container)
  /// ```
  /// 
  /// Benefits:
  /// - Bridge efficiency: Sends layout IDs instead of full objects
  /// - Memory optimization: Layouts cached and reused
  /// - Early validation: Catches layout errors at creation time
  static DCFLayoutRegistry create(Map<String, DCFLayout> layouts) {
    final registry = DCFLayoutRegistry._();
    for (final entry in layouts.entries) {
      final id = _DCFLayoutRegistry.instance.register(entry.key, entry.value);
      // Create registered layout with ID using internal factory
      registry._layouts[entry.key] = DCFLayout._withId(
        id,
        width: entry.value.width,
        height: entry.value.height,
        minWidth: entry.value.minWidth,
        maxWidth: entry.value.maxWidth,
        minHeight: entry.value.minHeight,
        maxHeight: entry.value.maxHeight,
        margin: entry.value.margin,
        marginTop: entry.value.marginTop,
        marginRight: entry.value.marginRight,
        marginBottom: entry.value.marginBottom,
        marginLeft: entry.value.marginLeft,
        marginHorizontal: entry.value.marginHorizontal,
        marginVertical: entry.value.marginVertical,
        padding: entry.value.padding,
        paddingTop: entry.value.paddingTop,
        paddingRight: entry.value.paddingRight,
        paddingBottom: entry.value.paddingBottom,
        paddingLeft: entry.value.paddingLeft,
        paddingHorizontal: entry.value.paddingHorizontal,
        paddingVertical: entry.value.paddingVertical,
        position: entry.value.position,
        absoluteLayout: entry.value.absoluteLayout,
        rotateInDegrees: entry.value.rotateInDegrees,
        scale: entry.value.scale,
        scaleX: entry.value.scaleX,
        scaleY: entry.value.scaleY,
        flexDirection: entry.value.flexDirection,
        justifyContent: entry.value.justifyContent,
        alignItems: entry.value.alignItems,
        alignSelf: entry.value.alignSelf,
        alignContent: entry.value.alignContent,
        flexWrap: entry.value.flexWrap,
        flex: entry.value.flex,
        flexGrow: entry.value.flexGrow,
        flexShrink: entry.value.flexShrink,
        flexBasis: entry.value.flexBasis,
        display: entry.value.display,
        overflow: entry.value.overflow,
        direction: entry.value.direction,
        aspectRatio: entry.value.aspectRatio,
        gap: entry.value.gap,
        rowGap: entry.value.rowGap,
        columnGap: entry.value.columnGap,
        borderWidth: entry.value.borderWidth,
      );
    }
    return registry;
  }

  /// Check if there are any layout properties set
  bool get isNotEmpty {
    return width != null ||
        height != null ||
        minWidth != null ||
        maxWidth != null ||
        minHeight != null ||
        maxHeight != null ||
        margin != null ||
        marginTop != null ||
        marginRight != null ||
        marginBottom != null ||
        marginLeft != null ||
        marginHorizontal != null ||
        marginVertical != null ||
        padding != null ||
        paddingTop != null ||
        paddingRight != null ||
        paddingBottom != null ||
        paddingLeft != null ||
        paddingHorizontal != null ||
        paddingVertical != null ||
        position != null ||
        absoluteLayout?.isNotEmpty == true ||
        rotateInDegrees != null ||
        scale != null ||
        scaleX != null ||
        scaleY != null ||
        flexDirection != null ||
        justifyContent != null ||
        alignItems != null ||
        alignSelf != null ||
        alignContent != null ||
        flexWrap != null ||
        flex != null ||
        flexGrow != null ||
        flexShrink != null ||
        flexBasis != null ||
        display != null ||
        overflow != null ||
        direction != null ||
        aspectRatio != null ||
        gap != null ||
        rowGap != null ||
        columnGap != null ||
        borderWidth != null;
  }

  /// Convert layout props to a map for serialization
  /// 
  /// If layout is registered via DCFLayout.create(), resolves ID to full object for native compatibility
  Map<String, dynamic> toMap() {
    // If registered, resolve ID to full layout object (native side doesn't support IDs yet)
    if (_layoutId != null) {
      final resolvedLayout = _DCFLayoutRegistry.instance.get(_layoutId);
      if (resolvedLayout != null) {
        // Return the resolved layout's full map
        return resolvedLayout.toMap();
      }
      // Fallback: if ID not found, continue with current layout
    }
    
    // Serialize full layout object
    final map = <String, dynamic>{};

    map['width'] = width;
    map['height'] = height;

    if (minWidth != null) map['minWidth'] = minWidth;
    if (maxWidth != null) map['maxWidth'] = maxWidth;
    if (minHeight != null) map['minHeight'] = minHeight;
    if (maxHeight != null) map['maxHeight'] = maxHeight;

    if (margin != null) map['margin'] = margin;
    if (marginTop != null) map['marginTop'] = marginTop;
    if (marginRight != null) map['marginRight'] = marginRight;
    if (marginBottom != null) map['marginBottom'] = marginBottom;
    if (marginLeft != null) map['marginLeft'] = marginLeft;
    if (marginHorizontal != null) {
      map['marginLeft'] = marginHorizontal;
      map['marginRight'] = marginHorizontal;
    }
    if (marginVertical != null) {
      map['marginTop'] = marginVertical;
      map['marginBottom'] = marginVertical;
    }

    if (padding != null) map['padding'] = padding;
    if (paddingTop != null) map['paddingTop'] = paddingTop;
    if (paddingRight != null) map['paddingRight'] = paddingRight;
    if (paddingBottom != null) map['paddingBottom'] = paddingBottom;
    if (paddingLeft != null) map['paddingLeft'] = paddingLeft;
    if (paddingHorizontal != null) {
      map['paddingLeft'] = paddingHorizontal;
      map['paddingRight'] = paddingHorizontal;
    }
    if (paddingVertical != null) {
      map['paddingTop'] = paddingVertical;
      map['paddingBottom'] = paddingVertical;
    }

    if (position != null) map['position'] = position.toString().split('.').last;

    if (absoluteLayout != null) {
      map.addAll(absoluteLayout!.toMap());
    }

    if (rotateInDegrees != null) map['rotateInDegrees'] = rotateInDegrees;
    if (scale != null) map['scale'] = scale;
    if (scaleX != null) map['scaleX'] = scaleX;
    if (scaleY != null) map['scaleY'] = scaleY;

    if (flexDirection != null) {
      map['flexDirection'] = flexDirection.toString().split('.').last;
    }
    if (justifyContent != null) {
      map['justifyContent'] = justifyContent.toString().split('.').last;
    }
    if (alignItems != null) {
      map['alignItems'] = alignItems.toString().split('.').last;
    }
    if (alignSelf != null) {
      map['alignSelf'] = alignSelf.toString().split('.').last;
    }
    if (alignContent != null) {
      map['alignContent'] = alignContent.toString().split('.').last;
    }
    if (flexWrap != null) map['flexWrap'] = flexWrap.toString().split('.').last;
    if (flex != null) map['flex'] = flex;
    if (flexGrow != null) map['flexGrow'] = flexGrow;
    if (flexShrink != null) map['flexShrink'] = flexShrink;
    if (flexBasis != null) map['flexBasis'] = flexBasis;

    if (display != null) map['display'] = display.toString().split('.').last;
    if (overflow != null) map['overflow'] = overflow.toString().split('.').last;

    if (direction != null) {
      map['direction'] = direction.toString().split('.').last;
    }

    if (aspectRatio != null) map['aspectRatio'] = aspectRatio;
    if (gap != null) map['gap'] = gap;
    if (rowGap != null) map['rowGap'] = rowGap;
    if (columnGap != null) map['columnGap'] = columnGap;

    if (borderWidth != null) map['borderWidth'] = borderWidth;

    return map;
  }

  /// Create a new LayoutProps object by merging this one with another
  DCFLayout merge(DCFLayout other) {
    return DCFLayout(
      width: other.width ?? width,
      height: other.height ?? height,
      minWidth: other.minWidth ?? minWidth,
      maxWidth: other.maxWidth ?? maxWidth,
      minHeight: other.minHeight ?? minHeight,
      maxHeight: other.maxHeight ?? maxHeight,
      margin: other.margin ?? margin,
      marginTop: other.marginTop ?? marginTop,
      marginRight: other.marginRight ?? marginRight,
      marginBottom: other.marginBottom ?? marginBottom,
      marginLeft: other.marginLeft ?? marginLeft,
      marginHorizontal: other.marginHorizontal ?? marginHorizontal,
      marginVertical: other.marginVertical ?? marginVertical,
      padding: other.padding ?? padding,
      paddingTop: other.paddingTop ?? paddingTop,
      paddingRight: other.paddingRight ?? paddingRight,
      paddingBottom: other.paddingBottom ?? paddingBottom,
      paddingLeft: other.paddingLeft ?? paddingLeft,
      paddingHorizontal: other.paddingHorizontal ?? paddingHorizontal,
      paddingVertical: other.paddingVertical ?? paddingVertical,
      position: other.position ?? position,
      absoluteLayout: other.absoluteLayout ?? absoluteLayout,
      rotateInDegrees: other.rotateInDegrees ?? rotateInDegrees,
      scale: other.scale ?? scale,
      scaleX: other.scaleX ?? scaleX,
      scaleY: other.scaleY ?? scaleY,
      flexDirection: other.flexDirection ?? flexDirection,
      justifyContent: other.justifyContent ?? justifyContent,
      alignItems: other.alignItems ?? alignItems,
      alignSelf: other.alignSelf ?? alignSelf,
      alignContent: other.alignContent ?? alignContent,
      flexWrap: other.flexWrap ?? flexWrap,
      flex: other.flex ?? flex,
      flexGrow: other.flexGrow ?? flexGrow,
      flexShrink: other.flexShrink ?? flexShrink,
      flexBasis: other.flexBasis ?? flexBasis,
      display: other.display ?? display,
      overflow: other.overflow ?? overflow,
      direction: other.direction ?? direction,
      aspectRatio: other.aspectRatio ?? aspectRatio,
      gap: other.gap ?? gap,
      rowGap: other.rowGap ?? rowGap,
      columnGap: other.columnGap ?? columnGap,
      borderWidth: other.borderWidth ?? borderWidth,
    );
  }

  /// Create a copy of this LayoutProps with certain properties modified
  DCFLayout copyWith({
    dynamic width,
    dynamic height,
    dynamic minWidth,
    dynamic maxWidth,
    dynamic minHeight,
    dynamic maxHeight,
    dynamic margin,
    dynamic marginTop,
    dynamic marginRight,
    dynamic marginBottom,
    dynamic marginLeft,
    dynamic marginHorizontal,
    dynamic marginVertical,
    dynamic padding,
    dynamic paddingTop,
    dynamic paddingRight,
    dynamic paddingBottom,
    dynamic paddingLeft,
    dynamic paddingHorizontal,
    dynamic paddingVertical,
    DCFPositionType? position,
    AbsoluteLayout? absoluteLayout,
    double? rotateInDegrees,
    double? scale,
    double? scaleX,
    double? scaleY,
    DCFFlexDirection? flexDirection,
    DCFJustifyContent? justifyContent,
    DCFAlign? alignItems,
    DCFAlign? alignSelf,
    DCFAlign? alignContent,
    DCFWrap? flexWrap,
    double? flex,
    double? flexGrow,
    double? flexShrink,
    dynamic flexBasis,
    DCFDisplay? display,
    DCFOverflow? overflow,
    DCFDirection? direction,
    double? aspectRatio,
    dynamic gap,
    dynamic rowGap,
    dynamic columnGap,
    dynamic borderWidth,
  }) {
    return DCFLayout(
      width: width ?? this.width,
      height: height ?? this.height,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
      margin: margin ?? this.margin,
      marginTop: marginTop ?? this.marginTop,
      marginRight: marginRight ?? this.marginRight,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginHorizontal: marginHorizontal ?? this.marginHorizontal,
      marginVertical: marginVertical ?? this.marginVertical,
      padding: padding ?? this.padding,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingRight: paddingRight ?? this.paddingRight,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      paddingVertical: paddingVertical ?? this.paddingVertical,
      position: position ?? this.position,
      absoluteLayout: absoluteLayout ?? this.absoluteLayout,
      rotateInDegrees: rotateInDegrees ?? this.rotateInDegrees,
      scale: scale ?? this.scale,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      flexDirection: flexDirection ?? this.flexDirection,
      justifyContent: justifyContent ?? this.justifyContent,
      alignItems: alignItems ?? this.alignItems,
      alignSelf: alignSelf ?? this.alignSelf,
      alignContent: alignContent ?? this.alignContent,
      flexWrap: flexWrap ?? this.flexWrap,
      flex: flex ?? this.flex,
      flexGrow: flexGrow ?? this.flexGrow,
      flexShrink: flexShrink ?? this.flexShrink,
      flexBasis: flexBasis ?? this.flexBasis,
      display: display ?? this.display,
      overflow: overflow ?? this.overflow,
      direction: direction ?? this.direction,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      gap: gap ?? this.gap,
      rowGap: rowGap ?? this.rowGap,
      columnGap: columnGap ?? this.columnGap,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  /// List of all layout property names for easy identification
  static const List<String> all = [
    'width',
    'height',
    'minWidth',
    'maxWidth',
    'minHeight',
    'maxHeight',
    'margin',
    'marginTop',
    'marginRight',
    'marginBottom',
    'marginLeft',
    'marginHorizontal',
    'marginVertical',
    'padding',
    'paddingTop',
    'paddingRight',
    'paddingBottom',
    'paddingLeft',
    'paddingHorizontal',
    'paddingVertical',
    'position',
    'absoluteLayout', // Note: absolute positioning properties are now grouped in AbsoluteLayout
    'rotateInDegrees',
    'scale',
    'scaleX',
    'scaleY',
    'flexDirection',
    'justifyContent',
    'alignItems',
    'alignSelf',
    'alignContent',
    'flexWrap',
    'flex',
    'flexGrow',
    'flexShrink',
    'flexBasis',
    'display',
    'overflow',
    'direction',
    'aspectRatio',
    'gap',
    'rowGap',
    'columnGap',
    'borderWidth',
  ];

  /// Parse a dimension value that could be a number or percentage string
  static dynamic parseDimensionValue(dynamic value) {
    if (value == null) return null;

    if (value is num) return value.toDouble();

    if (value is String && value.endsWith('%')) {
      return value; // Keep percentage strings as-is for native handling
    }

    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Convert dimension to percentage string
  static String toPercentage(double value) {
    return '${value.toString()}%';
  }

  /// Check if dimension is percentage
  static bool isPercentage(dynamic value) {
    return value is String && value.endsWith('%');
  }

  @override
  List<Object?> get props => [
        width,
        height,
        minWidth,
        maxWidth,
        minHeight,
        maxHeight,
        margin,
        marginTop,
        marginRight,
        marginBottom,
        marginLeft,
        marginHorizontal,
        marginVertical,
        padding,
        paddingTop,
        paddingRight,
        paddingBottom,
        paddingLeft,
        paddingHorizontal,
        paddingVertical,
        position,
        absoluteLayout,
        rotateInDegrees,
        scale,
        scaleX,
        scaleY,
        flexDirection,
        justifyContent,
        alignItems,
        alignSelf,
        alignContent,
        flexWrap,
        flex,
        flexGrow,
        flexShrink,
        flexBasis,
        display,
        overflow,
        direction,
        aspectRatio,
        gap,
        rowGap,
        columnGap,
        borderWidth,
        _layoutId,
      ];
}

/// Layout registry returned by DCFLayout.create()
/// Provides access to registered layouts by name
class DCFLayoutRegistry {
  final Map<String, DCFLayout> _layouts = {};
  
  DCFLayoutRegistry._();
  
  /// Get a registered layout by name
  DCFLayout operator [](String name) {
    final layout = _layouts[name];
    if (layout == null) {
      throw ArgumentError('Layout "$name" not found in registry. Available layouts: ${_layouts.keys.join(", ")}');
    }
    return layout;
  }
  
  /// Check if a layout exists in the registry
  bool containsKey(String name) => _layouts.containsKey(name);
  
  /// Get all registered layout names
  Iterable<String> get keys => _layouts.keys;
}
