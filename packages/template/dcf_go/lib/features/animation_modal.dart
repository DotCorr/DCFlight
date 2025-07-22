import "package:dcf_go/main.dart";
import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final modalNavigationCommand = useStore(animatedModalNavigationCommand);
    


    // 🎬 Create animation controllers
    final titleAnimationController = useAnimationController();
    final descriptionAnimationController = useAnimationController();
    final buttonAnimationController = useAnimationController();
    final backgroundAnimationController = useAnimationController();

    return DCFView(
      styleSheet: StyleSheet(backgroundColor: Colors.amber),
      layout: LayoutProps(
        height: "100%",
        width: "100%",
   
        alignContent: YogaAlign.center,
        justifyContent: YogaJustifyContent.flexStart,
      ),
      children: [
        // 🎯 Animated Background Container
        DCFAnimatedView(
          nativeAnimationId: backgroundAnimationController,
          command: AnimationPresets.fadeIn,
          layout: LayoutProps(
            height: "100%", 
            width: "100%",
          ),
          children: [
            DCFView(
              styleSheet: StyleSheet(
                backgroundColor: Colors.black.withOpacity(0.1),
                borderRadius: 16,
              ),
              layout: LayoutProps(
                height: "100%",
                width: "100%",
                padding: 20,
                gap: 16,
              ),
              children: [
                // 🎭 Animated Title
                DCFAnimatedView(
                  nativeAnimationId: titleAnimationController,
                  command: AnimationPresets.elastic,
                  layout: LayoutProps(
                    height: "80%", 
                    padding: 16,
                    marginBottom: 20,
                    width: "100%",
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    borderRadius: 12,
                  ),
                  onAnimationEnd: (data) {
                    print("🎉 Title animation completed!");
                  },
                  onAnimationStart: (data) {
                    print("🚀 Title animation started!");
                  },
                  children: [
                    DCFText(
                      content: "🎬 Animated Modal",
                      textProps: DCFTextProps(
                        fontSize: 28,
                        fontWeight: DCFFontWeight.bold,
                        color: Colors.white,
                        textAlign: "center",
                      ),
                    ),
                  ],
                ),

                // 🎮 Animated Segmented Control
                DCFAnimatedView(
                  nativeAnimationId: useAnimationController(),
                  command: SequenceCommand([
                    AnimateCommand(
                      toScale: 0.8,
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 0.3,
                      toScale: 1.0,
                      toOpacity: 1.0,
                      duration: 0.4,
                      curve: 'elasticOut',
                    ),
                  ]),
                  layout: LayoutProps(
                    height: 60, // 👈 Added height for consistent spacing
                  ),
                  children: [
                    DCFSegmentedControl(
                      segmentedControlProps: DCFSegmentedControlProps(
                        segments: [
                          DCFSegmentItem(title: "🎯 Bounce"),
                          DCFSegmentItem(title: "🌊 Slide"),
                          DCFSegmentItem(title: "🌟 Fade"),
                        ],
                        selectedIndex: 0,
                      ),
                      onSelectionChange: (data) {
                        final selectedIndex = data['selectedIndex'] ?? 0;
                        switch (selectedIndex) {
                          case 0:
                            print("🎯 Selected Bounce animation");
                            break;
                          case 1:
                            print("🌊 Selected Slide animation");
                            break;
                          case 2:
                            print("🌟 Selected Fade animation");
                            break;
                        }
                      },
                    ),
                  ],
                ),

                // 🎪 Animated Description
                DCFAnimatedView(
                  nativeAnimationId: descriptionAnimationController,
                  command: SequenceCommand([
                    AnimateCommand(
                      toTranslateX: -300,
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 0.5,
                      toTranslateX: 0,
                      toOpacity: 1.0,
                      duration: 0.6,
                      curve: 'easeOut',
                    ),
                  ]),
                  layout: LayoutProps(height: 120), // 👈 Explicit height added
                  children: [
                    DCFView(
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        borderRadius: 12,
                      ),
                      layout: LayoutProps(padding: 16),
                      children: [
                        DCFText(
                          content: "🚀 Pure UI Thread Animation",
                          textProps: DCFTextProps(
                            fontSize: 18,
                            fontWeight: DCFFontWeight.semibold,
                            color: Colors.black87,
                          ),
                        ),
                        DCFText(
                          content: "This modal uses DCFAnimatedView with native UI thread animation - no bridge latency, silky smooth 60fps performance!",
                          textProps: DCFTextProps(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          layout: LayoutProps(marginTop: 8),
                        ),
                      ],
                    ),
                  ],
                ),

                // 🎯 Interactive Buttons
                DCFView(
                  layout: LayoutProps(
                    flexDirection: YogaFlexDirection.row,
                    gap: 12,
                    justifyContent: YogaJustifyContent.spaceEvenly,
                  ),
                  children: [
                    DCFAnimatedView(
                      nativeAnimationId: useAnimationController(),
                      command: AnimationPresets.pulse,
                      layout: LayoutProps(
                        height: 50,
                        width: 100,
                      ),
                      styleSheet: StyleSheet(
                        borderRadius: 25,
                        backgroundColor: Colors.purple.withOpacity(0.8),
                      ),
                      children: [
                        DCFButton(
                          buttonProps: DCFButtonProps(title: "✨ Pulse"),
                          layout: LayoutProps(height: 40, width: 80),
                          styleSheet: StyleSheet(
                            backgroundColor: Colors.transparent,
                            borderRadius: 20,
                          ),
                          onPress: (v) {
                            print("🎯 Pulse button pressed!");
                          },
                        ),
                      ],
                    ),
                    DCFAnimatedView(
                      nativeAnimationId: useAnimationController(),
                      command: AnimationPresets.spin,
                      layout: LayoutProps(
                        height: 50,
                        width: 100,
                      ),
                      styleSheet: StyleSheet(
                        borderRadius: 25,
                        backgroundColor: Colors.blue.withOpacity(0.8),
                      ),
                      children: [
                        DCFButton(
                          buttonProps: DCFButtonProps(title: "🌀 Spin"),
                          layout: LayoutProps(height: 40, width: 80),
                          styleSheet: StyleSheet(
                            backgroundColor: Colors.transparent,
                            borderRadius: 20,
                          ),
                          onPress: (v) {
                            print("🌀 Spin button pressed!");
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // 🎭 Animated Dismiss Button
                DCFAnimatedView(
                  nativeAnimationId: buttonAnimationController,
                  command: SequenceCommand([
                    AnimateCommand(
                      toTranslateY: 50,
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 0.8,
                      toTranslateY: 0,
                      toOpacity: 1.0,
                      duration: 0.5,
                      curve: 'bounceOut',
                    ),
                  ]),
                  layout: LayoutProps(height: 60), // 👈 Added height
                  onAnimationEnd: (data) {
                    print("🎯 Dismiss button ready!");
                  },
                  children: [
                    DCFButton(
                      buttonProps: DCFButtonProps(
                        title: "🚪 Dismiss with Style",
                      ),
                      layout: LayoutProps(height: 50, width: 200),
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.red,
                        borderRadius: 25,
                      ),
                      onPress: (v) {
                        final exitAnimation = ParallelCommand([
                          AnimationPresets.slideOutToBottom,
                          AnimationPresets.fadeOut,
                          AnimateCommand(
                            toScale: 0.8,
                            duration: 0.4,
                            curve: 'easeIn',
                          ),
                        ]);
                        // Simulate exit
                        Future.delayed(Duration(milliseconds: 400), () {
                          modalNavigationCommand.setState(
                            NavigationPresets.dismissModal,
                          );
                        });
                      },
                    ),
                  ],
                ),

                // 🎪 Final Info Text
                DCFAnimatedView(
                  nativeAnimationId: useAnimationController(),
                  command: SequenceCommand([
                    AnimateCommand(
                      toScale: 0.0,
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 1.0,
                      toScale: 1.0,
                      toOpacity: 1.0,
                      duration: 0.3,
                      curve: 'elasticOut',
                    ),
                  ]),
                  layout: LayoutProps(height: 80), // 👈 Explicit height
                  children: [
                    DCFView(
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        borderRadius: 8,
                      ),
                      layout: LayoutProps(padding: 12),
                      children: [
                        DCFText(
                          content: "⚡ Native UI Thread Animation",
                          textProps: DCFTextProps(
                            fontSize: 12,
                            fontWeight: DCFFontWeight.medium,
                            color: Colors.green.shade700,
                            textAlign: "center",
                          ),
                        ),
                        DCFText(
                          content: "60fps • No Bridge Latency • Pure Performance",
                          textProps: DCFTextProps(
                            fontSize: 10,
                            color: Colors.green.shade600,
                            textAlign: "center",
                          ),
                        ),
                      ],
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
