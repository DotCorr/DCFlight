import "package:dcf_go/main.dart";
import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final modalNavigationCommand = useStore(animatedModalNavigationCommand);

    // 🎬 ONE animation controller only
    final animationController = useAnimationController();
    final animationController2 = useAnimationController();
    final animationController3 = useAnimationController();

    return DCFFragment(
      children: [
        DCFImage(
          imageProps: DCFImageProps(
            source:
                "https://images.pexels.com/photos/2832382/pexels-photo-2832382.jpeg?_gl=1*18awrhp*_ga*MTE2MzEwOTgwOS4xNzUzMjYyOTQ5*_ga_8JE65Q40S6*czE3NTMyNjI5NDkkbzEkZzEkdDE3NTMyNjI5NzkkajMwJGwwJGgw",
          ),
          layout: LayoutProps(
            flex: 1,
            padding: 20,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
        ),

        DCFScrollView(
          styleSheet: StyleSheet(backgroundColor: Colors.transparent),
          layout: LayoutProps(
            height: "100%",
            width: "100%",
            padding: 20,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
            position: YogaPositionType.absolute,
          absoluteLayout: AbsoluteLayout.centeredVertically()),
          children: [
            // 🎯 Simple animated box
            DCFAnimatedView(
              nativeAnimationId: animationController,
              command: AnimateCommand(
                toScale: 1.2, // Scale UP by 20%
                toOpacity: 0.8, // Fade to 80% opacity
                toTranslateX: 50, // Move 50px to the right
                toRotation: 0.5, // Rotate slightly
                duration: 2.0, // 2 second animation
                curve: 'easeIn', // Smooth curve
                repeat: true, // Keep repeating
              ),
              layout: LayoutProps(height: 65, width: 150, marginBottom: 30),
              styleSheet: StyleSheet(
                backgroundColor: Colors.blue,
                borderRadius: 20,
              ),
              onAnimationStart: (data) {
                print("🚀 Animation STARTED!");
              },
              onAnimationEnd: (data) {
                print("🎉 Animation ENDED!");
              },
              children: [
                DCFText(
                  content: "BOX 1",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
            ),

            DCFAnimatedView(
              nativeAnimationId: animationController2,
              command: AnimateCommand(
                toScale: 1.2, // Scale UP by 20%
                toOpacity: 0.8, // Fade to 80% opacity
                toTranslateX: 50, // Move 50px to the right
                toRotation: -20, // Rotate slightly
                duration: 2.0, // 2 second animation
                curve: 'easeInOut', // Smooth curve
                repeat: true, // Keep repeating
              ),
              layout: LayoutProps(height: 65, width: 150, marginBottom: 30),
              styleSheet: StyleSheet(
                backgroundColor: Colors.pink,
                borderRadius: 20,
              ),
              onAnimationStart: (data) {
                print("🚀 Animation STARTED!");
              },
              onAnimationEnd: (data) {
                print("🎉 Animation ENDED!");
              },
              children: [
                DCFText(
                  content: "BOX 2",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
            ),
            DCFAnimatedView(
              nativeAnimationId: animationController3,
              command: AnimateCommand(
                toScale: 1.2, // Scale UP by 20%
                toOpacity: 0.8, // Fade to 80% opacity
                toTranslateX: 50, // Move 50px to the right
                toRotation: 0.5, // Rotate slightly
                duration: 2.0, // 2 second animation
                curve: 'easeOut', // Smooth curve
                repeat: true, // Keep repeating
              ),
              layout: LayoutProps(height: 65, width: 150, marginBottom: 30),
              styleSheet: StyleSheet(
                backgroundColor: Colors.green,
                borderRadius: 20,
              ),
              onAnimationStart: (data) {
                print("🚀 Animation STARTED!");
              },
              onAnimationEnd: (data) {
                print("🎉 Animation ENDED!");
              },
              children: [
                DCFText(
                  content: "BOX 3",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
            ),
            // Simple text (NOT animated)
            DCFText(
              content: "Watch the blue box animate!",
              textProps: DCFTextProps(
                fontSize: 18,
                color: Colors.black,
                textAlign: "center",
              ),
              layout: LayoutProps(marginBottom: 30),
            ),

            // Non-animated dismiss button
            DCFButton(
              buttonProps: DCFButtonProps(title: "Dismiss Modal"),
              layout: LayoutProps(height: 50, width: 200),
              styleSheet: StyleSheet(
                backgroundColor: Colors.red,
                borderRadius: 25,
              ),
              onPress: (v) {
                modalNavigationCommand.setState(NavigationPresets.dismissModal);
              },
            ),
          ],
        ),
      ],
    );
  }
}
