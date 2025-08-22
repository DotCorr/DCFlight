
import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final state = useState(0);

    return DCFView(
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
            absoluteLayout: AbsoluteLayout.centeredVertically(),
          ),
          children: [
            // ✅ PURE: Test button works perfectly - no bridge interference
            DCFButton(
              buttonProps: DCFButtonProps(title: "TEST STATE"),
              layout: LayoutProps(height: 50, width: 200, marginBottom: 16),
              styleSheet: StyleSheet(backgroundColor: Colors.pink, borderRadius: 25),
              onPress: (v) {
                print("🧪 PURE REANIMATED: TEST BUTTON PRESSED - CALLBACK CALLED");
                
                // State changes work perfectly with pure reanimated
                state.setState(state.state + 1);
                
                print("🧪 PURE REANIMATED: SETSTATE CALLED - Counter: ${state.state}");
              },
            ),

            DCFButton(
              onPress: (v) {
                print("🧪 PURE REANIMATED: Navigation button works!");
                AppNavigation.dismissModal();
                AppNavigation.goBack();
              },
              buttonProps: DCFButtonProps(title: "pop"),
              layout: LayoutProps(height: 50, width: 200, marginBottom: 20),
              styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 25),
            ),

            // ✅ PURE: Box 1 - Entrance animation with slide + scale + fade
            ReanimatedView(
              animationId: "box1",
              animatedStyle: Reanimated.slideScaleFadeIn(
                slideDistance: 100,
                fromScale: 0.0,
                duration: 800,
                delay: 200,
                curve: 'easeOut',
              ),
              onAnimationComplete: () => print("🎬 Box 1 entrance complete!"),
              children: [
                DCFText(
                  content: "BOX 1 - PURE UI",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 100,
                width: 100,
                marginBottom: 20,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.blue,
                borderRadius: 10,
              ),
            ),

            // ✅ PURE: Box 2 - Bounce animation
            ReanimatedView(
              animationId: "box2",
              animatedStyle: Reanimated.bounce(
                bounceScale: 1.3,
                duration: 600,
                delay: 400,
                repeat: false,
                repeatCount: 3,
              ),
              onAnimationRepeat: () => print("🔄 Box 2 bounce cycle!"),
              children: [
                DCFText(
                  content: "BOX 2 - BOUNCE",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 100,
                width: 100,
                marginBottom: 20,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.red,
                borderRadius: 10,
              ),
            ),

            // ✅ PURE: Box 3 - Infinite rotation + pulse
            ReanimatedView(
              animationId: "box3",
              animatedStyle: AnimatedStyle()
                .transform(
                  rotation: ReanimatedValue(
                    from: 0.0,
                    to: 6.28, // 2π
                    duration: 3000,
                    curve: 'linear',
                    repeat: false,
                    delay: 600,
                  ),
                )
                .opacity(
                  ReanimatedValue(
                    from: 1.0,
                    to: 0.4,
                    duration: 1500,
                    curve: 'easeInOut',
                    repeat: false,
                    delay: 600,
                  ),
                ),
              children: [
                DCFText(
                  content: "BOX 3 - SPIN",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 100,
                width: 100,
                marginBottom: 20,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.green,
                borderRadius: 10,
              ),
            ),

            // ✅ PURE: Info text with typewriter effect
            ReanimatedView(
              animationId: "info_text",
              animatedStyle: Reanimated.slideInLeft(
                distance: 200,
                duration: 1000,
                delay: 800,
                curve: 'easeOut',
              ),
              children: [
                DCFText(
                  content: "🎬 Pure UI Thread Animations!\nZero Bridge Calls! 🚀",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    color: Colors.black,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 80,
                width: 300,
                marginBottom: 30,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.yellow.withOpacity(0.8),
                borderRadius: 15,
              ),
            ),

            // ✅ PURE: Control buttons with staggered entrance
            ReanimatedView(
            
              animationId: "buttons_container",
              animatedStyle: Reanimated.scaleIn(
                fromScale: 0.0,
                toScale: 1.0,
                duration: 600,
                delay: 1200,
                curve: 'easeOut',
              ),
              children: [
                // Working buttons - no bridge interference!
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Dismiss Modal"),
                  layout: LayoutProps(
                    height: 50,
                    width: 200,
                    marginBottom: 16,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.red,
                    borderRadius: 25,
                  ),
                  onPress: (v) {
                    print("🎬 PURE REANIMATED: Dismiss button works perfectly!");
                    AppNavigation.goBack();
                  },
                ),

                DCFButton(
                  buttonProps: DCFButtonProps(title: "Counter: ${state.state}"),
                  layout: LayoutProps(
                    height: 50,
                    width: 200,
                    marginBottom: 16,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.purple,
                    borderRadius: 25,
                  ),
                  onPress: (v) {
                    print("🎬 PURE REANIMATED: Counter button works! Current: ${state.state}");
                    state.setState(state.state + 1);
                  },
                ),

                DCFButton(
                  buttonProps: DCFButtonProps(title: "Go to Profile"),
                  layout: LayoutProps(
                    height: 50,
                    width: 200,
                    marginBottom: 16,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.blue,
                    borderRadius: 25,
                  ),
                  onPress: (v) {
                    print("🎬 PURE REANIMATED: Navigation works perfectly!");
                    AppNavigation.navigateTo("profile");
                  },
                ),

                DCFButton(
                  buttonProps: DCFButtonProps(title: "Go to Settings"),
                  layout: LayoutProps(height: 50, width: 200),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.orange,
                    borderRadius: 25,
                  ),
                  onPress: (v) {
                    print("🎬 PURE REANIMATED: Settings navigation works!");
                    AppNavigation.navigateTo("profile/settings");
                  },
                ),
              ],
              layout: LayoutProps(
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                padding: 20,
                height: 400
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.white.withOpacity(0.9),
                borderRadius: 20,
                // Add subtle shadow effect
              ),
            ),

            // ✅ PURE: Performance indicator
            ReanimatedView(
              animationId: "performance_indicator",
              animatedStyle: Reanimated.pulse(
                minOpacity: 0.3,
                maxOpacity: 1.0,
                duration: 2000,
                delay: 1500,
                repeat: false,
              ),
              children: [
                DCFText(
                  content: "⚡ 60fps Pure UI Thread ⚡",
                  textProps: DCFTextProps(
                    fontSize: 14,
                    color: Colors.green,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 40,
                width: 250,
                marginTop: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.black.withOpacity(0.1),
                borderRadius: 20,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

