import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  componentDidMount() {
    // Start animations after component mounts
    Future.delayed(Duration(milliseconds: 100), () {
      // Access context and start individual animations via tunnel
      final context = _getAnimationContext();
      if (context != null) {
        context.startAnimation("box1", Animations.complex(
          scale: 1.2,
          opacity: 0.8,
          translateX: 100,
          rotation: 0.5,
          duration: 2.0,
          curve: 'easeIn',
          repeat: false
        ));
        
        context.startAnimation("box2", Animations.complex(
          scale: 1.2,
          opacity: 0.8,
          translateX: 120,
          rotation: 0.5,
          duration: 2.0,
          curve: 'easeOut',
          repeat: false,
        ));
        
        context.startAnimation("box3", Animations.complex(
          scale: 1.2,
          opacity: 0.8,
          translateX: 50,
          rotation: 0.5,
          duration: 2.0,
          curve: 'easeIn',
          repeat: false,
        ));
        
        context.startAnimation("info_text", Animations.fade(opacity: 0.0, duration: 1.0));
        
        context.startAnimation("buttons", Animations.rotate(
          duration: 100,
          repeat: false,
          rotation: 10,
        ));
      }
    });
  }

  @override
  componentWillUnmount() {
    // Cleanup handled automatically by SuperDCFAnimationManager
  }

  // Store context reference for button callbacks
  AnimationBuilderContext? _animationContext;
  
  AnimationBuilderContext? _getAnimationContext() => _animationContext;

  @override
  DCFComponentNode render() {
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
            // Animation Manager - tunnel-based, no command props
            SuperDCFAnimationManager(
              groupId: "modal_animations",
              debugName: "Modal Animation Group",
              autoStart: true,
              builder: (context) {
                // Store context reference for button callbacks
                _animationContext = context;
                
                return [
                  // Box 1 - no command prop, animations started via tunnel
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
                  ),

                  // Box 2 - no command prop
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
                  ),

                  // Box 3 - no command prop
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
                  ),

                  // Custom animated text - no command prop
                  context.animated(
                    name: "info_text",
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

                  // Control buttons - no command prop
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
                    children: [
                      // Dismiss with context disposal
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
                          print("Dismissing animated modal - sending dispose command!");
                          context.dispose();
                          AppNavigation.goBack();
                        },
                      ),

                      // Animation control buttons using tunnel methods
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
                        onPress: (v) => context.pauseAll(),
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
                        onPress: (v) => context.resumeAll(),
                      ),

                      DCFButton(
                        buttonProps: DCFButtonProps(title: "Reset Box 1"),
                        layout: LayoutProps(
                          height: 50,
                          width: 200,
                          marginBottom: 16,
                        ),
                        styleSheet: StyleSheet(
                          backgroundColor: Colors.purple,
                          borderRadius: 25,
                        ),
                        onPress: (v) => context.resetAnimation("box1"),
                      ),

                      DCFButton(
                        buttonProps: DCFButtonProps(title: "Restart All"),
                        layout: LayoutProps(
                          height: 50,
                          width: 200,
                          marginBottom: 16,
                        ),
                        styleSheet: StyleSheet(
                          backgroundColor: Colors.teal,
                          borderRadius: 25,
                        ),
                        onPress: (v) {
                          // Restart animations via tunnel
                          context.startAnimation("box1", Animations.bounce());
                          context.startAnimation("box2", Animations.slide());
                          context.startAnimation("box3", Animations.rotate());
                        },
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
                        onPress: (v) => AppNavigation.navigateTo("profile/settings"),
                      ),
                    ],
                  ),
                ];
              },
            ),
          ],
        ),
      ],
    );
  }
}

