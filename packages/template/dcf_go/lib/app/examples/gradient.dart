

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/constants/style/gradient.dart';

class GradientTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final animatedViewCommand = useState<AnimatedViewCommand?>(null);
    final scrollCommand = useState<ScrollViewCommand?>(null);

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
              buttonProps: DCFButtonProps(title: "Animate Circle"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.blue, borderRadius: 8),
              onPress: (v) {
                // ✅ Using AnimatedView command pattern
                animatedViewCommand.setState(const AnimateCommand(
                  duration: 2.0,
                  toOpacity: 0.3,
                  toScale: 1.2,
                  toRotation: 3.14, // 180 degrees in radians
                ));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Reset Animation"),
              layout: LayoutProps(flex: 1, height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.orange, borderRadius: 8),
              onPress: (v) {
                // ✅ Reset animation using command pattern
                animatedViewCommand.setState(const AnimateCommand(
                  duration: 1.0,
                  toOpacity: 1.0,
                  toScale: 1.0,
                  toRotation: 0.0,
                ));
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

        // Add a button to test scroll commands
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 10,
            justifyContent: YogaJustifyContent.center,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Top"),
              layout: LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.purple, borderRadius: 8),
              onPress: (v) {
                // ✅ Scroll command demonstration
                scrollCommand.setState(ScrollViewCommand(scrollToTop: const ScrollToTopCommand(animated: true)));
              },
            ),
          ],
        ),
      ],
    );
  }
}
