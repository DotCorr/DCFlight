import 'package:flutter/foundation.dart';

import '../packages/vdom/vdom_node.dart';
import '../packages/vdom/vdom_element.dart';
import '../constants/layout_properties.dart';
import '../constants/style_properties.dart';
import 'comp_props/view_props.dart';
import 'comp_props/text_props.dart';
import 'comp_props/button_props.dart';
import 'comp_props/image_props.dart';
import 'comp_props/scroll_view_props.dart';

/// Factory for creating UI components with unified styling approach
class DC {
  /// Create a View component
  static VDomElement View({
    required LayoutProps layout,
    StyleSheet? style,
    ViewProps? viewProps,
    List<VDomNode> children = const [],
    String? key,
    // Add an optional events map parameter
    Map<String, dynamic>? events,
  }) {
    // Merge props from both layout and style
    final propsMap = <String, dynamic>{};

    // Add layout props
    propsMap.addAll(layout.toMap());

    // Add style props if available
    if (style != null) {
      propsMap.addAll(style.toMap());
    }

    // Add component-specific props
    if (viewProps != null) {
      propsMap.addAll(viewProps.toMap());
    }

    return VDomElement(
      type: 'View',
      key: key,
      props: propsMap,
      children: children,
      events: events, // Pass the events map
    );
  }

  /// Create a Text component
  static VDomElement Text({
    required String content,
    LayoutProps? layout,
    StyleSheet? style,
    TextProps? textProps,
    String? key,
    // Add an optional events map parameter
    Map<String, dynamic>? events,
  }) {
    // Merge props from layout, style, and text-specific props
    final propsMap = <String, dynamic>{};

    // Add content
    propsMap['content'] = content;

    // Add layout props if available
    if (layout != null) {
      propsMap.addAll(layout.toMap());
    } else {
      propsMap.addAll(LayoutProps(height: 20, width: 100).toMap());
    }

    // Add style props if available
    if (style != null) {
      propsMap.addAll(style.toMap());
    }

    // Add component-specific props
    if (textProps != null) {
      propsMap.addAll(textProps.toMap());
    }

    return VDomElement(
      type: 'Text',
      key: key,
      props: propsMap,
      events: events, // Pass the events map
    );
  }

  /// Create a Button component
  static VDomElement Button({
    required LayoutProps layout,
    StyleSheet? style,
    ButtonProps? buttonProps,
    String? key,
    Function? onPress,
  }) {
    // Merge props from both layout and style
    final propsMap = <String, dynamic>{};
    // Create events map specifically for event handling
    final eventsMap = <String, dynamic>{};

    // Add layout props
    propsMap.addAll(layout.toMap());

    // Add style props if available
    if (style != null) {
      propsMap.addAll(style.toMap());
    }

    // Add component-specific props
    if (buttonProps != null) {
      propsMap.addAll(
        buttonProps.toMap(),
      );
    }

    // Add onPress event handler if provided
    if (onPress != null) {
      eventsMap['onPress'] = onPress;

      // DEBUG: Add logging for event registration
      debugPrint("Button created with onPress handler: $onPress");
      debugPrint("Event map: $eventsMap");
    }

    // CRITICAL FIX: Always return the VDomElement with events map
    return VDomElement(
      type: 'Button',
      key: key,
      props: propsMap,
      events: eventsMap.isNotEmpty ? eventsMap : null,
    );
  }

  /// Create an Image component
  static VDomElement Image({
    required LayoutProps layout,
    StyleSheet? style,
    ImageProps? imageProps,
    String? key,
    Function? onLoad,
    Function? onError,
  }) {
    // Merge props from both layout and style
    final propsMap = <String, dynamic>{};

    // Add layout props
    propsMap.addAll(layout.toMap());

    // Add style props if available
    if (style != null) {
      propsMap.addAll(style.toMap());
    }

    // Add component-specific props
    if (imageProps != null) {
      propsMap.addAll(imageProps.toMap());
    }

    // CRITICAL FIX: Add event handlers directly to props for consistent handling
    if (onLoad != null) {
      propsMap['onLoad'] = onLoad;
    }

    if (onError != null) {
      propsMap['onError'] = onError;
    }

    return VDomElement(
      type: 'Image',
      key: key,
      props: propsMap,
    );
  }

  /// Create a ScrollView component
  static VDomElement ScrollView({
    required LayoutProps layout,
    StyleSheet? style,
    ScrollViewProps? scrollViewProps,
    List<VDomNode> children = const [],
    String? key,

  }) {
    // Merge props from both layout and style
    final propsMap = <String, dynamic>{};

    // Add layout props
    propsMap.addAll(layout.toMap());

    // Add style props if available
    if (style != null) {
      propsMap.addAll(style.toMap());
    }

    // Add component-specific props
    if (scrollViewProps != null) {
      propsMap.addAll(scrollViewProps.toMap());
    }


    return VDomElement(
      type: 'ScrollView',
      key: key,
      props: propsMap,
      children: children,
    );
  }
}
