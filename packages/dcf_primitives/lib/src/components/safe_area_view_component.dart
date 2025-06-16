/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight/dcflight.dart';

/// SafeAreaView component that handles device safe areas using ScreenUtilities
/// This is a pure Dart component that wraps DCFView and applies safe area insets as padding
class DCFSafeAreaView extends StatefulComponent {
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final StyleSheet styleSheet;
  final LayoutProps layout;
  final List<DCFComponentNode> children;
  final Map<String, dynamic>? events;

  DCFSafeAreaView({
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.styleSheet = const StyleSheet(),
    this.layout = const LayoutProps(),
    this.children = const [],
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    
    // Force re-render when screen dimensions change (including orientation changes)
    // Using empty dependencies array - effect runs only once on mount
    useEffect(() {
      void onDimensionChange() {
        // This will trigger a re-render with updated safe area values
        scheduleUpdate();
      }
      
      // Add listener for dimension changes
      screenUtils.addDimensionChangeListener(onDimensionChange);
      
      // Cleanup function
      return () {
        screenUtils.removeDimensionChangeListener(onDimensionChange);
      };
    }, dependencies: []); // Empty dependencies = run once on mount
    
    // Calculate safe area padding (these values will be fresh after orientation change)
    final double topPadding = top ? screenUtils.safeAreaTop : 0.0;
    final double bottomPadding = bottom ? screenUtils.safeAreaBottom : 0.0;
    final double leftPadding = left ? screenUtils.safeAreaLeft : 0.0;
    final double rightPadding = right ? screenUtils.safeAreaRight : 0.0;
    
    // Create enhanced layout with safe area padding
    final enhancedLayout = LayoutProps(
      flex: layout.flex??1,
      width: layout.width,
      height: layout.height,
      margin: layout.margin,
      marginTop: layout.marginTop,
      marginBottom: layout.marginBottom,
      marginLeft: layout.marginLeft,
      marginRight: layout.marginRight,
      marginHorizontal: layout.marginHorizontal,
      marginVertical: layout.marginVertical,
      padding: layout.padding,
      paddingTop: (layout.padding)+(layout.paddingTop ?? 0.0) + (topPadding),
      paddingBottom:(layout.padding)+(layout.paddingBottom ?? 0.0) + (bottomPadding),
      paddingLeft: (layout.padding)+(layout.paddingLeft ?? 0.0) + (leftPadding)??0.0,
      paddingRight: (layout.padding)+(layout.paddingRight ?? 0.0) + (rightPadding),
      paddingHorizontal: layout.paddingHorizontal,
      paddingVertical: layout.paddingVertical,
      flexDirection: layout.flexDirection,
      justifyContent: layout.justifyContent,
      alignItems: layout.alignItems,
      alignSelf: layout.alignSelf,
      position: layout.position,
      absoluteLayout: AbsoluteLayout(
        top: layout.absoluteLayout?.top,
      bottom: layout.absoluteLayout?.bottom,
      left: layout.absoluteLayout?.left,
      right: layout.absoluteLayout?.right,
      )
    );

    return DCFElement(
      type: 'View',
      props: {
        ...enhancedLayout.toMap(),
        ...styleSheet.toMap(),
        ...(events ?? {}),
      },
      children: children,
    );
  }
}
