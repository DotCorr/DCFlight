

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/constants/style/gradient.dart';

class GradientTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final animatedViewCommand = useState<AnimatedViewCommand?>(null);
    final scrollCommand = useState<ScrollViewCommand?>(null);

    return useMemo(() {
      return DCFScrollView(
      // ✅ Command pattern demonstration for ScrollView in gradient test
      command: scrollCommand.state,
      layout: LayoutProps(flex: 1),
      onScroll: (v) {
        if (scrollCommand.state != null) {
          Future.microtask(() => scrollCommand.setState(null));
        }
      },
      children: [
        // Control buttons for command demonstration
        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row,
            height: 60,
            padding: 10,
            gap: 10,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Spin Animation"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.blue, borderRadius: 8),
              onPress: (v) {
                // ✅ Spin animation with rotation
                animatedViewCommand.setState(const AnimateCommand(
                  duration: 2.0,
                  toRotation: 6.28, // 360 degrees (2 * PI)
                  curve: "linear",
                ));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Bounce Scale"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.green, borderRadius: 8),
              onPress: (v) {
                // ✅ Bounce scale animation
                animatedViewCommand.setState(const AnimateCommand(
                  duration: 0.6,
                  toScale: 1.3,
                  curve: "easeOut",
                ));
              },
            ),
          ],
        ),

        // Second row of animation buttons
        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row,
            height: 60,
            padding: 10,
            gap: 10,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Fade Out"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 8),
              onPress: (v) {
                // ✅ Fade out animation
                animatedViewCommand.setState(const AnimateCommand(
                  duration: 1.5,
                  toOpacity: 0.1,
                  curve: "easeIn",
                ));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Complex Move"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.purple, borderRadius: 8),
              onPress: (v) {
                // ✅ Complex animation with multiple properties
                animatedViewCommand.setState(const AnimateCommand(
                  duration: 3.0,
                  toScale: 0.8,
                  toOpacity: 0.6,
                  toTranslateX: 50,
                  toTranslateY: -30,
                  toRotation: 1.57, // 90 degrees
                  curve: "easeInOut",
                ));
              },
            ),
          ],
        ),

        // Reset button
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 10,
            justifyContent: YogaJustifyContent.center,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Reset All Animations"),
              layout: LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.orange, borderRadius: 8),
              onPress: (v) {
                // ✅ Reset all animation properties
                animatedViewCommand.setState(const ResetAnimationCommand(animated: true));
              },
            ),
          ],
        ),

        DCFView(
          styleSheet: StyleSheet(
            backgroundGradient: DCFGradient.linear(
              colors: [Colors.red, Colors.blue],
              startX: 0.0,
              startY: 0.0,
              endX: 1.0,
              endY: 1.0,
            ),
          ),
          layout: LayoutProps(flex: 1),
        ),

        // ✅ Animated view with command pattern
        DCFAnimatedView(
          command: animatedViewCommand.state,
          animation: {}, // Base animation config
          children: [], // No child content needed for this circle
          styleSheet: StyleSheet(
            borderRadius: 100,
            borderWidth: 5,
            backgroundGradient: DCFGradient.radial(
              colors: [Colors.green, Colors.red],
              centerX: 0.5,
              centerY: 0.5,
              radius: 0.5,
            ),
          ),
          layout: LayoutProps(
            height: 200,
            width: 200,
            position: YogaPositionType.absolute,
            absoluteLayout: AbsoluteLayout.centered(),
            alignSelf: YogaAlign.center
          ),
          onAnimationEnd: (v) {
            // Clear command after animation completes
            if (animatedViewCommand.state != null) {
              Future.microtask(() => animatedViewCommand.setState(null));
            }
          },
        ),

        // ScrollView command tests
        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row,
            height: 60,
            padding: 10,
            gap: 10,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Top"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.indigo, borderRadius: 8),
              onPress: (v) {
                // ✅ Scroll to top command
                scrollCommand.setState(ScrollViewCommand(scrollToTop: const ScrollToTopCommand(animated: true)));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Bottom"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.cyan, borderRadius: 8),
              onPress: (v) {
                // ✅ Scroll to bottom command
                scrollCommand.setState(ScrollViewCommand(scrollToBottom: const ScrollToBottomCommand(animated: true)));
              },
            ),
          ],
        ),

        // ScrollView position and flash commands
        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row,
            height: 60,
            padding: 10,
            gap: 10,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Flash Indicators"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.amber, borderRadius: 8),
              onPress: (v) {
                // ✅ Flash scroll indicators
                scrollCommand.setState(const ScrollViewCommand(flashScrollIndicators: true));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Middle"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.teal, borderRadius: 8),
              onPress: (v) {
                // ✅ Scroll to specific position (middle of content)
                scrollCommand.setState(ScrollViewCommand(
                  scrollToPosition: const ScrollToPositionCommand(x: 0, y: 500, animated: true)
                ));
              },
            ),
          ],
        ),

        // Add some spacer content to test scrolling
        ...List.generate(10, (index) => DCFView(
          layout: LayoutProps(
            height: 100,
            margin: 10,
            padding: 20,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.grey.shade200,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: Colors.grey.shade400,
          ),
          children: [
            DCFText(
              content: "Test Content Block ${index + 1}",
              textProps: DCFTextProps(
                fontSize: 18,
                fontWeight: DCFFontWeight.bold,
                color: Colors.black87,
              ),
            ),
            DCFText(
              content: "This is additional content to make the scroll view scrollable and test the scroll commands.",
              textProps: DCFTextProps(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        )),
      ],
    );
    }, [animatedViewCommand.state, scrollCommand.state]);
  }
}
