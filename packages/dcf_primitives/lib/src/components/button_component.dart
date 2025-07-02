/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';

/// Button properties
class DCFButtonProps extends Equatable {
  /// The title text of the button
  final String title;
  
  /// Disabled state
  final bool disabled;
  
  /// Whether to use adaptive theming
  final bool adaptive;
  
  /// Create button props
  const DCFButtonProps({
    required this.title,
    this.disabled = false,
    this.adaptive = true,
  });
  
  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'disabled': disabled,
      'adaptive': adaptive,
    };
  }

  @override
  List<Object?> get props => [title, disabled, adaptive];
}

/// A button component implementation using StatelessComponent
class DCFButton extends StatelessComponent with EquatableMixin {
  /// The button properties
  final DCFButtonProps buttonProps;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties
  final StyleSheet styleSheet;
  
  /// Event handlers
  final Map<String, dynamic>? events;
  
  /// Press event handler - receives Map<dynamic, dynamic> with press data
  final Function(Map<dynamic, dynamic>)? onLongPress;

  /// Press event handler - receives Map<dynamic, dynamic> with press data
  final Function(Map<dynamic, dynamic>)? onPress;
  
  /// Create a button component
  DCFButton({
    required this.buttonProps,
       this.layout = const LayoutProps(
    height: 50,width: 200
    ),
    this.styleSheet = const StyleSheet(),
    this.onPress,
    this.onLongPress,
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Create an events map for the onPress handler
    Map<String, dynamic> eventMap = events ?? {};
    
    if (onPress != null) {
      eventMap['onPress'] = onPress;
    }

    if (onLongPress != null) {
      eventMap['onLongPress'] = onLongPress;
    }
    
    // Serialize command if provided
    Map<String, dynamic> props = {
      ...buttonProps.toMap(),
      ...layout.toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'Button',
      props: props,
      children: [],
    );
  }

  @override
  List<Object?> get props => [
        buttonProps,
        layout,
        styleSheet,
        onPress,
        onLongPress,
        events,
        key,
      ];
}
