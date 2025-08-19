import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  componentDidMount() {}

  @override
  componentWillUnmount() {
    // Cleanup handled automatically by SuperDCFAnimationManager
  }

  @override
  DCFComponentNode render() {
    // ✅ NO MORE MANUAL CONTROLLER IDs!
    // ❌ final animationController = AnimationControllerIds.generate();
    // ❌ final animationController2 = AnimationControllerIds.generate();
    // ❌ final animationController3 = AnimationControllerIds.generate();
    // ❌ final groupCommand = useState<GroupAnimationCommand?>(null, 'groupCommand');

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
            // 🎬 SUPER Animation Manager - Central Sandbox!
            SuperDCFAnimationManager(
              groupId: "modal_animations",
              debugName: "Modal Animation Group",
              autoStart: true,
              onCommand: (cmd) => print("🎮 Executed: ${cmd.type}"),
              builder:
                  (context) => [
                    // 🎯 Box 1 - Auto controller generation!
                    context.animated(
                      name: "box1",
                      children: [
                        DCFText(
                          content: "BOX 1",
                          textProps: DCFTextProps(
                            fontSize: 16,
                            color: Colors.white,
                            textAlign: "center",
                          ),
                        ),
                      ],
                      styleSheet: StyleSheet(backgroundColor: Colors.blue),
                      layout: LayoutProps(
                        height: 100,
                        width: 100,
                        padding: 10,
                        justifyContent: YogaJustifyContent.center,
                        alignItems: YogaAlign.center,
                      ),
                      command: Animations.complex(
                        scale: 1.2,
                        opacity: 0.8,
                        translateX: 50,
                        rotation: 0.5,
                        duration: 2.0,
                        curve: 'easeIn',
                      ),
                    ),

                    // 🎯 Box 2 - Auto controller generation!
                    context.animated(
                      name: "box2",
                      children: [
                        DCFText(
                          content: "BOX 2",
                          textProps: DCFTextProps(
                            fontSize: 16,
                            color: Colors.white,
                            textAlign: "center",
                          ),
                        ),
                      ],
                      styleSheet: StyleSheet(backgroundColor: Colors.red),
                      layout: LayoutProps(
                        height: 100,
                        width: 100,
                        padding: 10,
                        justifyContent: YogaJustifyContent.center,
                        alignItems: YogaAlign.center,
                      ),
                      command: Animations.complex(
                        scale: 1.2,
                        opacity: 0.8,
                        translateX: 50,
                        rotation: 0.5,
                        duration: 2.0,
                        curve: 'easeOut',
                      ),
                    ),

                    // 🎯 Box 3 - Auto controller generation!
                    context.animated(
                      name: "box3",
                      children: [
                        DCFText(
                          content: "BOX 3",
                          textProps: DCFTextProps(
                            fontSize: 16,
                            color: Colors.white,
                            textAlign: "center",
                          ),
                        ),
                      ],
                      styleSheet: StyleSheet(backgroundColor: Colors.green),
                      layout: LayoutProps(
                        height: 100,
                        width: 100,
                        padding: 10,
                        justifyContent: YogaJustifyContent.center,
                        alignItems: YogaAlign.center,
                      ),
                      command: Animations.complex(
                        scale: 1.2,
                        opacity: 0.8,
                        translateX: 50,
                        rotation: 0.5,
                        duration: 2.0,
                        curve: 'easeIn',
                      ),
                    ),

                    // 🎯 Custom animated text
                    context.animated(
                      name: "info_text",
                      command: Animations.fade(opacity: 0.0, duration: 1.0),
                      layout: LayoutProps(
                        height: 100,
                        width: "300",
                        padding: 10,
                        justifyContent: YogaJustifyContent.center,
                        alignItems: YogaAlign.center,
                      ),
                      children: [
                        DCFText(
                          content: "Watch the animated boxes! 🎬",
                          textProps: DCFTextProps(
                            fontSize: 18,
                            color: Colors.black,
                            textAlign: "center",
                          ),
                        ),
                      ],
                    ),

                    // 🎯 Control buttons with context access
                    context.animated(
                      layout: LayoutProps(
                        height: 400,
                        width: 200,
                        marginBottom: 16,
                        justifyContent: YogaJustifyContent.center,
                        alignItems: YogaAlign.center,
                      ),
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.green,
                        borderRadius: 20,
                      ),
                      name: "buttons",
                      command: Animations.rotate(
                        duration: 100,
                        repeat: false,
                        rotation: 10,
                      ),
                      children: [
                        // 🎯 Dismiss with direct context disposal
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
                            print(
                              "Dismissing animated modal - sending dispose command!",
                            );

                            AppNavigation.goBack();
                          },
                        ),

                        // 🎯 Animation control buttons
                        DCFButton(
                          buttonProps: DCFButtonProps(title: "Pause All"),
                          layout: LayoutProps(
                            height: 50,
                            width: 200,
                            marginBottom: 16,
                          ),
                          styleSheet: StyleSheet(
                            backgroundColor: Colors.orange,
                            borderRadius: 25,
                          ),
                          onPress:
                              (v) => context.pauseAll(), // 🎯 Easy control!
                        ),

                        DCFButton(
                          buttonProps: DCFButtonProps(title: "Resume All"),
                          layout: LayoutProps(
                            height: 50,
                            width: 200,
                            marginBottom: 16,
                          ),
                          styleSheet: StyleSheet(
                            backgroundColor: Colors.green,
                            borderRadius: 25,
                          ),
                          onPress:
                              (v) => context.resumeAll(), // 🎯 Easy control!
                        ),

                        DCFButton(
                          buttonProps: DCFButtonProps(title: "Reset All"),
                          layout: LayoutProps(
                            height: 50,
                            width: 200,
                            marginBottom: 16,
                          ),
                          styleSheet: StyleSheet(
                            backgroundColor: Colors.purple,
                            borderRadius: 25,
                          ),
                          onPress:
                              (v) => context.resetAll(
                                animated: true,
                              ), // 🎯 Easy control!
                        ),

                        // Navigation buttons
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
                          onPress: (v) => AppNavigation.navigateTo("profile"),
                        ),

                        DCFButton(
                          buttonProps: DCFButtonProps(title: "Go to Settings"),
                          layout: LayoutProps(height: 50, width: 200),
                          styleSheet: StyleSheet(
                            backgroundColor: Colors.purple,
                            borderRadius: 25,
                          ),
                          onPress:
                              (v) =>
                                  AppNavigation.navigateTo("profile/settings"),
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

