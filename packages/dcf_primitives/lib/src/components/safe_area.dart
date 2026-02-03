/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcf_primitives/dcf_primitives.dart';
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
    final lastPaddingState = useState<Map<String, double>>({});

    useEffect(() {
      void onDimensionChange() {
        final newTopPadding = top ? screenUtils.safeAreaTop : 0.0;
        final newBottomPadding = bottom ? screenUtils.safeAreaBottom : 0.0;
        final newLeftPadding = left ? screenUtils.safeAreaLeft : 0.0;
        final newRightPadding = right ? screenUtils.safeAreaRight : 0.0;
        
        final newPaddingState = {
          'top': newTopPadding,
          'bottom': newBottomPadding,
          'left': newLeftPadding,
          'right': newRightPadding,
        };
        
        // Only trigger re-render if padding actually changed (with tolerance for floating point)
        // This prevents unnecessary re-renders that can corrupt event handlers
        final lastState = lastPaddingState.state;
        const tolerance = 0.01; // 0.01 pixel tolerance for floating point comparison
        final hasChanged = lastState.isEmpty || 
            ((lastState['top'] as double? ?? 0.0) - newTopPadding).abs() > tolerance ||
            ((lastState['bottom'] as double? ?? 0.0) - newBottomPadding).abs() > tolerance ||
            ((lastState['left'] as double? ?? 0.0) - newLeftPadding).abs() > tolerance ||
            ((lastState['right'] as double? ?? 0.0) - newRightPadding).abs() > tolerance;
        
        if (hasChanged) {
          lastPaddingState.setState(newPaddingState);
          orientationFlag.setState(orientationFlag.state + 1);
        }
      }

      screenUtils.addDimensionChangeListener(onDimensionChange);

      return () {
        screenUtils.removeDimensionChangeListener(onDimensionChange);
      };
    }, dependencies: []); // Empty dependencies = run once on mount

    final double topPadding = top ? screenUtils.safeAreaTop : 0.0;
    final double bottomPadding = bottom ? screenUtils.safeAreaBottom : 0.0;
    final double leftPadding = left ? screenUtils.safeAreaLeft : 0.0;
    final double rightPadding = right ? screenUtils.safeAreaRight : 0.0;

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

    return DCFView(
      key: 'safe_area_view', // CRITICAL: Stable key prevents view replacement on re-render
      layout: enhancedLayout,
      styleSheet: styleSheet,
      children: children,
      events: events,
    );
  }
}
