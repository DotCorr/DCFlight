import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {

  @override
  componentDidMount() {}

  @override
  componentWillUnmount() {
    // No setState - that doesn't exist! 
    // We need to use hooks properly
  }

  @override
  DCFComponentNode render() {
    // 🎬 Animation controllers - generate unique IDs (no hooks needed!)
    final animationController = AnimationControllerIds.generate();
    final animationController2 = AnimationControllerIds.generate();
    final animationController3 = AnimationControllerIds.generate();

    // Use hook for disposal command
    final groupCommand = useState<GroupAnimationCommand?>(null, 'groupCommand');

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
            absoluteLayout: AbsoluteLayout.centeredVertically(),
          ),
          children: [
            // 🎬 Animation Manager - Controls all animations as a group!
            DCFAnimationManager(
              groupId: "modal_animations",
              debugName: "Modal Animation Group",
              autoStart: true,
              command: groupCommand.state, // Use hook state for command
              children: [
                // 🎯 Animated box 1
                DCFAnimatedView(
                  nativeAnimationId: animationController,
                  groupId: "modal_animations", // Register with the group
                  command: AnimateCommand(
                    toScale: 1.2,
                    toOpacity: 0.8,
                    toTranslateX: 50,
                    toRotation: 0.5,
                    duration: 2.0,
                    curve: 'easeIn',
                    repeat: true,
                  ),
                  layout: LayoutProps(height: 65, width: 150, marginBottom: 30),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.blue,
                    borderRadius: 20,
                  ),
                  onAnimationStart: (data) {
                    print("🚀 Box 1 Animation STARTED!");
                  },
                  onAnimationEnd: (data) {
                    print("🎉 Box 1 Animation ENDED!");
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

                // 🎯 Animated box 2
                DCFAnimatedView(
                  nativeAnimationId: animationController2,
                  groupId: "modal_animations", // Register with the group
                  command: AnimateCommand(
                    toScale: 1.2,
                    toOpacity: 0.8,
                    toTranslateX: 50,
                    toRotation: -20,
                    duration: 2.0,
                    curve: 'easeInOut',
                    repeat: true,
                  ),
                  layout: LayoutProps(height: 65, width: 150, marginBottom: 30),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.pink,
                    borderRadius: 20,
                  ),
                  onAnimationStart: (data) {
                    print("🚀 Box 2 Animation STARTED!");
                  },
                  onAnimationEnd: (data) {
                    print("🎉 Box 2 Animation ENDED!");
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

                // 🎯 Animated box 3
                DCFAnimatedView(
                  nativeAnimationId: animationController3,
                  groupId: "modal_animations", // Register with the group
                  command: AnimateCommand(
                    toScale: 1.2,
                    toOpacity: 0.8,
                    toTranslateX: 50,
                    toRotation: 0.5,
                    duration: 2.0,
                    curve: 'easeOut',
                    repeat: true,
                  ),
                  layout: LayoutProps(height: 65, width: 150, marginBottom: 30),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.green,
                    borderRadius: 20,
                  ),
                  onAnimationStart: (data) {
                    print("🚀 Box 3 Animation STARTED!");
                  },
                  onAnimationEnd: (data) {
                    print("🎉 Box 3 Animation ENDED!");
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
              ],
            ),

            // Info text
            DCFText(
              content: "Watch the animated boxes! 🎬",
              textProps: DCFTextProps(
                fontSize: 18,
                color: Colors.black,
                textAlign: "center",
              ),
              layout: LayoutProps(marginBottom: 30),
            ),

            // 🎯 UPDATED: Use AppNavigation helper for dismiss button
            DCFButton(
              buttonProps: DCFButtonProps(title: "Dismiss Modal"),
              layout: LayoutProps(height: 50, width: 200, marginBottom: 16),
              styleSheet: StyleSheet(
                backgroundColor: Colors.red,
                borderRadius: 25,
              ),
              onPress: (v) {
                
                print("Dismissing animated modal - sending dispose command!");
                groupCommand.setState(GroupAnimationCommand.dispose);
                // AppNavigation.goBack();
              },
            ),

            // 🎯 NEW: Additional navigation buttons for testing
            DCFButton(
              buttonProps: DCFButtonProps(title: "Go to Profile"),
              layout: LayoutProps(height: 50, width: 200, marginBottom: 16),
              styleSheet: StyleSheet(
                backgroundColor: Colors.blue,
                borderRadius: 25,
              ),
              onPress: (v) {
                AppNavigation.navigateTo("profile");
              },
            ),

            DCFButton(
              buttonProps: DCFButtonProps(title: "Go to Settings"),
              layout: LayoutProps(height: 50, width: 200),
              styleSheet: StyleSheet(
                backgroundColor: Colors.purple,
                borderRadius: 25,
              ),
              onPress: (v) {
                AppNavigation.navigateTo("profile/settings");
              },
            ),
          ],
        ),
      ],
    );
  }
}

