import "package:dcf_go/main.dart";
import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final modalNavigationCommand = useStore(animatedModalNavigationCommand);
    
    // 🎬 Create animation controllers for different elements
    final titleAnimationController = useAnimationController();
    final descriptionAnimationController = useAnimationController();
    final buttonAnimationController = useAnimationController();
    final backgroundAnimationController = useAnimationController();
    
    return DCFView(
      styleSheet: StyleSheet(backgroundColor: Colors.amber),
      layout: LayoutProps(
        height: "100%",
        width: "100%",
        padding: 16,
        gap: 2,
        alignContent: YogaAlign.center,
        justifyContent: YogaJustifyContent.flexStart,
      ),
      children: [
        // 🎯 Animated Background Container
        DCFAnimatedView(
          nativeAnimationId: backgroundAnimationController,
          command: AnimationPresets.fadeIn, // Entrance animation
          children: [
            DCFView(
              styleSheet: StyleSheet(
                backgroundColor: Colors.black.withOpacity(0.1),
                borderRadius: 16,
              ),
              layout: LayoutProps(
                padding: 20,
                gap: 16,
              ),
              children: [
                // 🎭 Animated Title with Bounce Effect
                DCFAnimatedView(
                  nativeAnimationId: titleAnimationController,
                  command: AnimationPresets.bounceIn, // Complex sequence animation
                  layout: LayoutProps(
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
                      duration: 0.0, // Start invisible
                    ),
                    AnimateCommand(
                      delay: 0.3, // Delay for staggered effect
                      toScale: 1.0,
                      toOpacity: 1.0,
                      duration: 0.4,
                      curve: 'elasticOut',
                    ),
                  ]),
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
                        
                        // Just trigger different animations based on selection
                        // This has nothing to do with navigation!
                        switch (selectedIndex) {
                          case 0:
                            print("🎯 Selected Bounce animation");
                            // Could trigger bounce on other elements here
                            break;
                          case 1:
                            print("🌊 Selected Slide animation"); 
                            // Could trigger slide on other elements here
                            break;
                          case 2:
                            print("🌟 Selected Fade animation");
                            // Could trigger fade on other elements here
                            break;
                        }
                      },
                    ),
                  ],
                ),

                // 🎪 Animated Description with Slide Effect
                DCFAnimatedView(
                  nativeAnimationId: descriptionAnimationController,
                  command: SequenceCommand([
                    AnimateCommand(
                      toTranslateX: -300, // Start off-screen left
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 0.5, // Staggered delay
                      toTranslateX: 0,
                      toOpacity: 1.0,
                      duration: 0.6,
                      curve: 'easeOut',
                    ),
                  ]),
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

                // 🎯 Interactive Animation Buttons
                DCFView(
                  layout: LayoutProps(
                    flexDirection: YogaFlexDirection.row,
                    gap: 12,
                    justifyContent: YogaJustifyContent.spaceEvenly,
                  ),
                  children: [
                    // Pulse Button
                    DCFAnimatedView(
                      nativeAnimationId: useAnimationController(),
                      command: AnimationPresets.pulse, // Continuous pulse
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
                            // Trigger shake animation on description
                            // Note: You'd need to store controller references to trigger this
                            print("🎯 Pulse button pressed!");
                          },
                        ),
                      ],
                    ),

                    // Spin Button
                    DCFAnimatedView(
                      nativeAnimationId: useAnimationController(),
                      command: AnimationPresets.spin, // Continuous spin
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

                // 🎭 Animated Dismiss Button with Hover Effects
                DCFAnimatedView(
                  nativeAnimationId: buttonAnimationController,
                  command: SequenceCommand([
                    AnimateCommand(
                      toTranslateY: 50, // Start below
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 0.8, // Final element appears
                      toTranslateY: 0,
                      toOpacity: 1.0,
                      duration: 0.5,
                      curve: 'bounceOut',
                    ),
                  ]),
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
                        // Create exit animation before dismissing
                        final exitAnimation = ParallelCommand([
                          AnimationPresets.slideOutToBottom, // Slide down
                          AnimationPresets.fadeOut, // Fade out
                          AnimateCommand(
                            toScale: 0.8, // Scale down slightly
                            duration: 0.4,
                            curve: 'easeIn',
                          ),
                        ]);
                        
                        // Trigger exit animations on all controllers
                        // Note: In real implementation, you'd store refs and animate all elements
                        
                        // Dismiss after animation completes
                        Future.delayed(Duration(milliseconds: 400), () {
                          modalNavigationCommand.setState(
                            NavigationPresets.dismissModal,
                          );
                        });
                      },
                    ),
                  ],
                ),

                // 🎪 Performance Info Text
                DCFAnimatedView(
                  nativeAnimationId: useAnimationController(),
                  command: SequenceCommand([
                    AnimateCommand(
                      toScale: 0.0,
                      toOpacity: 0.0,
                      duration: 0.0,
                    ),
                    AnimateCommand(
                      delay: 1.0, // Final reveal
                      toScale: 1.0,
                      toOpacity: 1.0,
                      duration: 0.3,
                      curve: 'elasticOut',
                    ),
                  ]),
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