/*
 * Example: Drawer with DCFGestureDetector + useState + ReanimatedView
 *
 * Shows how to build a drawer that slides in/out using gesture-driven animations.
 * This is NOT a layout animation — it's a transform animation driven by user gestures.
 *
 * Key points:
 * - Use useState to track drawer position (0.0 = closed, 1.0 = open)
 * - Update state in onPanUpdate as user drags
 * - Use translateXValue in ReanimatedView for real-time tracking
 * - Snap to final position in onPanEnd
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';

class DrawerExample extends DCFStatefulComponent {
  DrawerExample({super.key});

  @override
  DCFComponentNode render() {
    final drawerProgress = useState(0.0);
    final isOpen = useState(false);

    const drawerWidth = 300.0;

    return DCFView(
      layout: const DCFLayout(width: '100%', height: '100%'),
      children: [
        DCFView(
          layout: const DCFLayout(width: '100%', height: '100%'),
          children: [
            DCFButton(
              onPress: (_) {
                isOpen.setState(!isOpen.state);
                drawerProgress.setState(isOpen.state ? 1.0 : 0.0);
              },
              children: [
                DCFText(content: isOpen.state ? 'Close Drawer' : 'Open Drawer'),
              ],
            ),
          ],
        ),
        DCFGestureDetector(
          layout: const DCFLayout(width: '100%', height: '100%'),
          onPanUpdate: (DCFGesturePanData data) {
            final currentProgress = drawerProgress.state;
            final delta = -data.translationX / drawerWidth;
            final newProgress = (currentProgress + delta).clamp(0.0, 1.0);
            drawerProgress.setState(newProgress);
          },
          onPanEnd: (DCFGesturePanData data) {
            final currentProgress = drawerProgress.state;
            final velocity = data.velocityX;
            final shouldOpen =
                currentProgress > 0.5 || velocity < -500;
            isOpen.setState(shouldOpen);
            drawerProgress.setState(shouldOpen ? 1.0 : 0.0);
          },
          children: [
            ReanimatedView(
              animatedStyle: useAnimatedStyle(
                () {
                  final translateX =
                      (drawerProgress.state - 1.0) * drawerWidth;
                  return AnimatedStyle().translateXValue(translateX);
                },
                dependencies: [drawerProgress.state],
              ),
              layout: DCFLayout(
                position: DCFPositionType.absolute,
                width: drawerWidth,
                height: '100%',
                absoluteLayout: const AbsoluteLayout(left: 0, top: 0),
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.white,
                shadowColor: DCFColors.black,
                shadowOffsetX: 4,
                shadowOffsetY: 0,
                shadowOpacity: 0.2,
                shadowRadius: 8,
              ),
              children: [
                DCFView(
                  layout: const DCFLayout(padding: 20),
                  children: [
                    DCFText(
                      content: 'Drawer Menu',
                      textProps: const DCFTextProps(
                        fontSize: 24,
                        fontWeight: DCFFontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/*
 * Example: Bottom Sheet with DCFGestureDetector + useState + ReanimatedView
 */
class BottomSheetExample extends DCFStatefulComponent {
  BottomSheetExample({super.key});

  @override
  DCFComponentNode render() {
    final sheetProgress = useState(0.0);
    final isVisible = useState(false);

    const sheetHeight = 400.0;

    return DCFView(
      layout: const DCFLayout(width: '100%', height: '100%'),
      children: [
        DCFView(
          layout: const DCFLayout(width: '100%', height: '100%'),
          children: [
            DCFButton(
              onPress: (_) {
                isVisible.setState(!isVisible.state);
                sheetProgress.setState(isVisible.state ? 1.0 : 0.0);
              },
              children: [
                DCFText(
                    content: isVisible.state ? 'Hide Sheet' : 'Show Sheet'),
              ],
            ),
          ],
        ),
        DCFGestureDetector(
          layout: const DCFLayout(width: '100%', height: '100%'),
          onPanUpdate: (DCFGesturePanData data) {
            final currentProgress = sheetProgress.state;
            final delta = -data.translationY / sheetHeight;
            final newProgress = (currentProgress + delta).clamp(0.0, 1.0);
            sheetProgress.setState(newProgress);
          },
          onPanEnd: (DCFGesturePanData data) {
            final currentProgress = sheetProgress.state;
            final velocity = data.velocityY;
            final shouldShow =
                currentProgress > 0.5 || velocity < -500;
            isVisible.setState(shouldShow);
            sheetProgress.setState(shouldShow ? 1.0 : 0.0);
          },
          children: [
            ReanimatedView(
              animatedStyle: useAnimatedStyle(
                () {
                  final translateY =
                      (1.0 - sheetProgress.state) * sheetHeight;
                  return AnimatedStyle().translateYValue(translateY);
                },
                dependencies: [sheetProgress.state],
              ),
              layout: DCFLayout(
                position: DCFPositionType.absolute,
                width: '100%',
                height: sheetHeight,
                absoluteLayout: const AbsoluteLayout(left: 0, bottom: 0),
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.white,
                borderTopLeftRadius: 16,
                borderTopRightRadius: 16,
              ),
              children: [
                DCFView(
                  layout: const DCFLayout(padding: 20),
                  children: [
                    DCFText(content: 'Bottom Sheet Content'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
