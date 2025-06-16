/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcf_primitives/src/components/text_component.dart';
import 'package:dcflight/dcflight.dart';

/// An animated text component implementation using StatelessComponent
class DCFAnimatedText extends StatelessComponent {
  /// The text content to display
  final String content;
  
  /// The text properties
  final DCFTextProps textProps;
  
  /// The layout properties
  final LayoutProps layout;
  
  /// The style properties
  final StyleSheet styleSheet;
  
  /// The animation configuration
  final Map<String, dynamic> animation;
  
  /// Event handlers
  final Map<String, dynamic>? events;
  
  /// Animation end event handler - receives Map<dynamic, dynamic> with animation data
  final Function(Map<dynamic, dynamic>)? onAnimationEnd;
  
  /// Create an animated text component
  DCFAnimatedText({
    required this.content,
    required this.animation,
    this.textProps = const DCFTextProps(),
       this.layout = const LayoutProps(
      height: 50,width: 200
    ),
    this.styleSheet = const StyleSheet(),
    this.onAnimationEnd,
    this.events,
    super.key,
  });
  
  @override
  DCFComponentNode render() {
    // Create an events map for callbacks
    Map<String, dynamic> eventMap = events ?? {};
    
    if (onAnimationEnd != null) {
      eventMap['onAnimationEnd'] = onAnimationEnd;
    }
    
    return DCFElement(
      type: 'AnimatedText',
      props: {
        'content': content,
        'animation': animation,
        ...textProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: [],
    );
  }
}
