/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// 🚀 DCF Modal Header Component
/// 
/// A header component specifically designed for modals.
/// Provides title, close button, and custom action buttons.
class DCFModalHeader extends StatelessComponent {
  /// Title text to display in the header
  final String? title;
  
  /// Whether to show the close button
  final bool showCloseButton;
  
  /// Close button icon name
  final String closeButtonIcon;
  
  /// Close button position (left, right)
  final String closeButtonPosition;
  
  /// Called when close button is pressed
  final Function(Map<dynamic, dynamic>)? onClose;
  
  /// Additional action buttons to display
  final List<DCFComponentNode>? actions;
  
  /// Style preset for the header
  final String style;
  
  /// Background color of the header
  final Color? backgroundColor;
  
  /// Text color for the title
  final Color? textColor;
  
  /// Border configuration
  final bool showBorder;
  
  /// Border color
  final Color? borderColor;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties  
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;

  DCFModalHeader({
    super.key,
    this.title,
    this.showCloseButton = true,
    this.closeButtonIcon = 'xmark',
    this.closeButtonPosition = 'right',
    this.onClose,
    this.actions,
    this.style = 'default',
    this.backgroundColor,
    this.textColor,
    this.showBorder = true,
    this.borderColor,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.events,
  });

  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};
    
    if (onClose != null) {
      eventMap['onClose'] = onClose;
    }
    
    Map<String, dynamic> props = {
      'title': title,
      'showCloseButton': showCloseButton,
      'closeButtonIcon': closeButtonIcon,
      'closeButtonPosition': closeButtonPosition,
      'style': style,
      'showBorder': showBorder,
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };
    
    // Add color properties if provided
    if (backgroundColor != null) {
      props['backgroundColor'] = '#${backgroundColor!.value.toRadixString(16).padLeft(8, '0')}';
    }
    
    if (textColor != null) {
      props['textColor'] = '#${textColor!.value.toRadixString(16).padLeft(8, '0')}';
    }
    
    if (borderColor != null) {
      props['borderColor'] = '#${borderColor!.value.toRadixString(16).padLeft(8, '0')}';
    }
    
    return DCFElement(
      type: 'ModalHeader',
      props: props,
      children: actions ?? [],
    );
  }

  /// Helper method to create a simple header with just title and close button
  static DCFModalHeader simple({
    required String title,
    Function(Map<dynamic, dynamic>)? onClose,
    String closeButtonPosition = 'right',
  }) {
    return DCFModalHeader(
      title: title,
      onClose: onClose,
      closeButtonPosition: closeButtonPosition,
      style: DCFModalHeaderStyle.defaultStyle,
    );
  }

  /// Helper method to create a minimal header without border
  static DCFModalHeader minimal({
    String? title,
    Function(Map<dynamic, dynamic>)? onClose,
    bool showCloseButton = true,
  }) {
    return DCFModalHeader(
      title: title,
      onClose: onClose,
      showCloseButton: showCloseButton,
      showBorder: false,
      style: DCFModalHeaderStyle.minimal,
    );
  }

  /// Helper method to create an elevated header with shadow
  static DCFModalHeader elevated({
    required String title,
    Function(Map<dynamic, dynamic>)? onClose,
    List<DCFComponentNode>? actions,
  }) {
    return DCFModalHeader(
      title: title,
      onClose: onClose,
      actions: actions,
      style: DCFModalHeaderStyle.elevated,
    );
  }
}

/// Modal header style constants
class DCFModalHeaderStyle {
  static const String defaultStyle = 'default';
  static const String minimal = 'minimal';
  static const String elevated = 'elevated';
  static const String borderless = 'borderless';
}

/// Close button position constants
class DCFModalHeaderPosition {
  static const String left = 'left';
  static const String right = 'right';
}