/*
 * Example: Drawer with GestureDetector + useState + ReanimatedView
 * 
 * This shows how to build a drawer that slides in/out using gesture-driven animations.
 * This is NOT a layout animation - it's a transform animation driven by user gestures.
 * 
 * Key points:
 * - Use useState to track drawer position (0.0 = closed, 1.0 = open)
 * - Update state in onPanUpdate as user drags
 * - Use translateXValue in ReanimatedView for real-time tracking
 * - Animate to final position in onPanEnd
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';

class DrawerExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // State tracks drawer position (0.0 = closed, 1.0 = open)
    final drawerProgress = useState(0.0);
    final isOpen = useState(false);
    
    // Drawer width (in pixels)
    const drawerWidth = 300.0;
    
    return DCFView(
      layout: DCFLayout(width: '100%', height: '100%'),
      children: [
        // Main content
        DCFView(
          layout: DCFLayout(width: '100%', height: '100%'),
          children: [
            DCFButton(
              onPress: () {
                // Toggle drawer
                isOpen.setState(!isOpen.state);
                drawerProgress.setState(isOpen.state ? 1.0 : 0.0);
              },
              children: [
                DCFText(content: isOpen.state ? 'Close Drawer' : 'Open Drawer'),
              ],
            ),
          ],
        ),
        
        // Drawer overlay (positioned absolutely)
        GestureDetector(
          onPanUpdate: (data) {
            // Update state in real-time as user drags
            // translationX is negative when dragging left (opening), positive when right (closing)
            final currentProgress = drawerProgress.state;
            final delta = -data.translationX / drawerWidth; // Convert pixels to progress (0-1)
            final newProgress = (currentProgress + delta).clamp(0.0, 1.0);
            
            // Update state immediately (triggers rebuild with new translateXValue)
            drawerProgress.setState(newProgress);
          },
          onPanEnd: (data) {
            // When drag ends, determine final position based on:
            // 1. Current position (> 0.5 = open, < 0.5 = closed)
            // 2. Velocity (fast swipe = snap to end)
            final currentProgress = drawerProgress.state;
            final velocity = data.velocityX;
            
            // Determine final state
            final shouldOpen = currentProgress > 0.5 || velocity < -500; // Fast left swipe = open
            
            isOpen.setState(shouldOpen);
            
            // Animate to final position using SharedValue
            final progressValue = useSharedValue(currentProgress);
            final animatedStyle = useAnimatedStyle(() {
              return AnimatedStyle()
                .transform(
                  translateX: progressValue.withTiming(
                    toValue: shouldOpen ? 1.0 : 0.0,
                    duration: 300,
                    curve: AnimationCurve.easeOut,
                  ),
                );
            }, dependencies: [shouldOpen]);
            
            // For now, just set state - the animatedStyle will handle animation
            drawerProgress.setState(shouldOpen ? 1.0 : 0.0);
          },
          children: [
            // Drawer container (slides from left)
            ReanimatedView(
              animatedStyle: useAnimatedStyle(() {
                // Convert progress (0-1) to pixels (-drawerWidth to 0)
                // When progress = 0: translateX = -drawerWidth (hidden off-screen left)
                // When progress = 1: translateX = 0 (fully visible)
                final translateX = (drawerProgress.state - 1.0) * drawerWidth;
                return AnimatedStyle()
                  .transform(
                    translateX: AnimatedStyle().translateXValue(translateX),
                  );
              }, dependencies: [drawerProgress.state]),
              layout: DCFLayout(
                position: DCFPositionType.absolute,
                absoluteLayout: AbsoluteLayout(
                  left: 0,
                  top: 0,
                  width: drawerWidth,
                  height: '100%',
                ),
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.white,
                shadowColor: DCFColors.black,
                shadowOffset: DCFOffset(4, 0),
                shadowOpacity: 0.2,
                shadowRadius: 8,
              ),
              children: [
                // Drawer content
                DCFView(
                  layout: DCFLayout(padding: 20),
                  children: [
                    DCFText(
                      content: 'Drawer Menu',
                      styleSheet: DCFStyleSheet(fontSize: 24, fontWeight: DCFFontWeight.bold),
                    ),
                    // Add menu items here...
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
 * Example: Bottom Sheet with GestureDetector + useState + ReanimatedView
 */
class BottomSheetExample extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final sheetProgress = useState(0.0); // 0 = hidden, 1 = shown
    final isVisible = useState(false);
    
    const sheetHeight = 400.0;
    
    return DCFView(
      layout: DCFLayout(width: '100%', height: '100%'),
      children: [
        // Main content
        DCFView(
          layout: DCFLayout(width: '100%', height: '100%'),
          children: [
            DCFButton(
              onPress: () {
                isVisible.setState(!isVisible.state);
                sheetProgress.setState(isVisible.state ? 1.0 : 0.0);
              },
              children: [
                DCFText(content: isVisible.state ? 'Hide Sheet' : 'Show Sheet'),
              ],
            ),
          ],
        ),
        
        // Bottom sheet (slides from bottom)
        GestureDetector(
          onPanUpdate: (data) {
            // Update based on vertical drag
            final currentProgress = sheetProgress.state;
            final delta = -data.translationY / sheetHeight; // Negative = dragging up (opening)
            final newProgress = (currentProgress + delta).clamp(0.0, 1.0);
            
            sheetProgress.setState(newProgress);
          },
          onPanEnd: (data) {
            final currentProgress = sheetProgress.state;
            final velocity = data.velocityY;
            
            // Fast upward swipe or > 50% visible = show
            final shouldShow = currentProgress > 0.5 || velocity < -500;
            
            isVisible.setState(shouldShow);
            sheetProgress.setState(shouldShow ? 1.0 : 0.0);
          },
          children: [
            ReanimatedView(
              animatedStyle: useAnimatedStyle(() {
                // When progress = 0: translateY = sheetHeight (hidden below)
                // When progress = 1: translateY = 0 (fully visible)
                final translateY = (1.0 - sheetProgress.state) * sheetHeight;
                return AnimatedStyle()
                  .transform(
                    translateY: AnimatedStyle().translateYValue(translateY),
                  );
              }, dependencies: [sheetProgress.state]),
              layout: DCFLayout(
                position: DCFPositionType.absolute,
                absoluteLayout: AbsoluteLayout(
                  left: 0,
                  bottom: 0,
                  width: '100%',
                  height: sheetHeight,
                ),
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.white,
                borderTopLeftRadius: 16,
                borderTopRightRadius: 16,
              ),
              children: [
                // Bottom sheet content
                DCFView(
                  layout: DCFLayout(padding: 20),
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

