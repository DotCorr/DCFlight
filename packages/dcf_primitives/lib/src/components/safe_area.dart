/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Improved SafeAreaView component that properly handles orientation changes
class DCFSafeArea extends DCFStatefulComponent {
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final DCFStyleSheet styleSheet;
  final DCFLayout layout;
  final List<DCFComponentNode> children;
  final Map<String, dynamic>? events;

  @override
  List<Object?> get props => [
        top,
        bottom,
        left,
        right,
        styleSheet,
        layout,
        children,
        events,
      ];

  @Deprecated(
      "This View would be removed in the major release. A native primitve would be made as a replacement.")
  DCFSafeArea({
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.styleSheet = const DCFStyleSheet(),
    this.layout = const DCFLayout(),
    this.children = const [],
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    final orientationFlag = useState<int>(0);

    // CRITICAL FIX: Use a more reliable orientation change detection
    useEffect(() {
      void onDimensionChange() {
        // Force re-render with a flag increment to ensure proper layout recalculation
        orientationFlag.setState(orientationFlag.state + 1);

        // Additional delay to ensure native layout completion
        Future.delayed(Duration(milliseconds: 100), () {
          scheduleUpdate();
        });
      }

      // Add listener for dimension changes
      screenUtils.addDimensionChangeListener(onDimensionChange);

      // Cleanup function
      return () {
        screenUtils.removeDimensionChangeListener(onDimensionChange);
      };
    }, dependencies: []); // Empty dependencies = run once on mount

    // CRITICAL FIX: Calculate safe area with orientation consideration
    final double topPadding = top ? screenUtils.safeAreaTop : 0.0;
    final double bottomPadding = bottom ? screenUtils.safeAreaBottom : 0.0;
    final double leftPadding = left ? screenUtils.safeAreaLeft : 0.0;
    final double rightPadding = right ? screenUtils.safeAreaRight : 0.0;

    // CRITICAL FIX: Create layout that forces proper bounds
    final enhancedLayout = DCFLayout(
        flex: layout.flex ?? 1,
        width: layout.width ?? "100%",
        height: layout.height ?? "100%",
        margin: layout.margin,
        marginTop: layout.marginTop,
        marginBottom: layout.marginBottom,
        marginLeft: layout.marginLeft,
        marginRight: layout.marginRight,
        marginHorizontal: layout.marginHorizontal,
        marginVertical: layout.marginVertical,
        padding: layout.padding,
        paddingTop:
            (layout.padding ?? 0) + (layout.paddingTop ?? 0.0) + topPadding,
        paddingBottom: (layout.padding ?? 0) +
            (layout.paddingBottom ?? 0.0) +
            bottomPadding,
        paddingLeft:
            (layout.padding ?? 0) + (layout.paddingLeft ?? 0.0) + leftPadding,
        paddingRight:
            (layout.padding ?? 0) + (layout.paddingRight ?? 0.0) + rightPadding,
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
        ));

    return DCFElement(
      type: 'View',
      elementProps: {
        ...enhancedLayout.toMap(),
        ...styleSheet.toMap(),
        ...(events ?? {}),
      },
      children: children,
    );
  }
}
