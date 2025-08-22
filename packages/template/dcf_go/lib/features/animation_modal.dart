import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // State for testing
    final counter = useState(0);
    final isPressed = useState(false);
    final showLoader = useState(true);
    final pulseActive = useState(true);
    final bounceActive = useState(true);
    
    // 🎯 SHARED VALUES for interactive animations
    final buttonScale = useSharedValue(1.0);
    final cardOpacity = useSharedValue(1.0);
    final rotationAngle = useSharedValue(0.0);
    final slidePosition = useSharedValue(0.0);
    
    // 🎨 ANIMATED STYLES using shared values
    final interactiveButtonStyle = useAnimatedStyle(() {
      return AnimatedStyle().transform(
        scale: buttonScale.withTiming(
          toValue: isPressed.state ? 0.9 : 1.0,
          duration: 150,
          curve: 'easeOut',
        ),
      );
    }, dependencies: [isPressed.state]);
    
    final interactiveCardStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .opacity(cardOpacity.withTiming(
          toValue: counter.state % 2 == 0 ? 1.0 : 0.7,
          duration: 300,
          curve: 'easeInOut',
        ))
        .transform(
          rotation: rotationAngle.withTiming(
            toValue: (counter.state * 0.1) % 6.28, // Rotate based on counter
            duration: 500,
            curve: 'easeOut',
          ),
        );
    }, dependencies: [counter.state]);
    
    final slidingElementStyle = useAnimatedStyle(() {
      return AnimatedStyle().transform(
        translateX: slidePosition.withSpring(
          toValue: isPressed.state ? 50.0 : -50.0,
          damping: 10,
          stiffness: 100,
        ),
      );
    }, dependencies: [isPressed.state]);

    return DCFView(
      children: [
        // Background image
        DCFImage(
          imageProps: DCFImageProps(
            source: "https://images.pexels.com/photos/2832382/pexels-photo-2832382.jpeg?_gl=1*18awrhp*_ga*MTE2MzEwOTgwOS4xNzUzMjYyOTQ5*_ga_8JE65Q40S6*czE3NTMyNjI5NDkkbzEkZzEkdDE3NTMyNjI5NzkkajMwJGwwJGgw",
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
           gap:100,
            padding: 20,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
            position: YogaPositionType.absolute,
            absoluteLayout: AbsoluteLayout.centeredVertically(),
          ),
          children: [
          
            // 🎬 TITLE with entrance animation
            ReanimatedView(
              animationId: "title",
              animatedStyle: Reanimated.slideScaleFadeIn(
                slideDistance: 200,
                fromScale: 0.0,
                duration: 1000,
                delay: 100,
                curve: 'easeOut',
              ),
              onAnimationComplete: () => print("🎬 Title animation complete!"),
              children: [
                DCFText(
                  content: "🎯 DCF REANIMATED\nFULL FEATURE TEST",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 120,
                width: 350,
                marginBottom: 30,
                padding: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.black.withOpacity(0.7),
                borderRadius: 20,
              ),
            ),

            // 🔄 INFINITE ROTATION TEST (Testing repeat: true)
            ReanimatedView(
              animationId: "infinite_spinner",
              animatedStyle: AnimatedStyle().transform(
                rotation: ReanimatedValue(
                  from: 0.0,
                  to: 6.28, // 2π
                  duration: 2000,
                  curve: 'linear',
                  repeat: true, // 🧪 TESTING INFINITE REPEAT
                  // No repeatCount = infinite
                ),
              ),
              children: [
                DCFText(
                  content: "⚙️",
                  textProps: DCFTextProps(
                    fontSize: 40,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 80,
                width: 80,
                marginBottom: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.blue.withOpacity(0.8),
                borderRadius: 40,
              ),
            ),

            // 🏃 FINITE REPEAT TEST (Testing repeatCount)
            ReanimatedView(
              animationId: "bounce_test",
              animatedStyle: AnimatedStyle().transform(
                scale: ReanimatedValue(
                  from: 1.0,
                  to: 1.5,
                  duration: 400,
                  curve: 'easeInOut',
                  repeat: true,
                  repeatCount: 6, // 🧪 TESTING FINITE REPEAT
                ),
              ),
              autoStart: bounceActive.state,
              onAnimationRepeat: () => print("🔄 Bounce repeat #${DateTime.now().millisecondsSinceEpoch}"),
              onAnimationComplete: () {
                print("✅ Bounce sequence complete!");
                bounceActive.setState(false);
              },
              children: [
                DCFText(
                  content: "🏀",
                  textProps: DCFTextProps(
                    fontSize: 30,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 80,
                width: 80,
                marginBottom: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.orange.withOpacity(0.8),
                borderRadius: 40,
              ),
            ),

            // 💓 PULSE TEST (Testing repeat with ping-pong)
            if (pulseActive.state)
              ReanimatedView(
                animationId: "pulse_test",
                animatedStyle: AnimatedStyle().opacity(
                  ReanimatedValue(
                    from: 1.0,
                    to: 0.3,
                    duration: 800,
                    curve: 'easeInOut',
                    repeat: true,
                    repeatCount: 8, // 🧪 TESTING PULSE REPEAT
                  ),
                ),
                onAnimationRepeat: () => print("💓 Pulse beat #${DateTime.now().millisecondsSinceEpoch}"),
                onAnimationComplete: () {
                  print("✅ Pulse sequence complete!");
                  pulseActive.setState(false);
                },
                children: [
                  DCFText(
                    content: "💓",
                    textProps: DCFTextProps(
                      fontSize: 40,
                      color: Colors.red,
                      textAlign: "center",
                    ),
                  ),
                ],
                layout: LayoutProps(
                  height: 80,
                  width: 80,
                  marginBottom: 20,
                  justifyContent: YogaJustifyContent.center,
                  alignItems: YogaAlign.center,
                ),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  borderRadius: 40,
                ),
              ),

            // 🎯 INTERACTIVE BUTTON using SharedValue
            ReanimatedView(
              animationId: "interactive_button",
              animatedStyle: interactiveButtonStyle,
              children: [
                DCFButton(
                  buttonProps: DCFButtonProps(title: "PRESS ME! (${counter.state})"),
                  layout: LayoutProps(
                    height: 60,
                    width: 250,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: isPressed.state ? Colors.purple : Colors.pink,
                    borderRadius: 30,
                  ),
                  onPress: (v) {
                    print("🎯 Interactive button pressed! Counter: ${counter.state}");
                    isPressed.setState(true);
                    counter.setState(counter.state + 1);
                    
                    // Reset pressed state after 150ms
                    Future.delayed(Duration(milliseconds: 150), () {
                      isPressed.setState(false);
                    });
                  },
                ),
              ],
              layout: LayoutProps(
                height: 60,
                width: "250",
                marginBottom: 20,
              ),
            ),

            // 🔄 INTERACTIVE CARD using SharedValue
            ReanimatedView(
              animationId: "interactive_card",
              animatedStyle: interactiveCardStyle,
              children: [
                DCFText(
                  content: "🔄 INTERACTIVE CARD\nCounter: ${counter.state}\nRotation: ${(counter.state * 0.1 % 6.28).toStringAsFixed(2)}",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 120,
                width: 200,
                marginBottom: 20,
                padding: 15,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.blue.withOpacity(0.8),
                borderRadius: 15,
              ),
            ),

            // 🏃 SLIDING ELEMENT using SharedValue with Spring
            ReanimatedView(
              animationId: "sliding_element",
              animatedStyle: slidingElementStyle,
              children: [
                DCFText(
                  content: "🏃",
                  textProps: DCFTextProps(
                    fontSize: 30,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 60,
                width: 60,
                marginBottom: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.green.withOpacity(0.8),
                borderRadius: 30,
              ),
            ),

            // 🎨 COLOR ANIMATION TEST
            ReanimatedView(
              animationId: "color_test",
              animatedStyle: AnimatedStyle().backgroundColor(
                ReanimatedValue(
                  from: 0.0,
                  to: 1.0,
                  duration: 3000,
                  curve: 'linear',
                  repeat: true,
                  delay: 500,
                ),
              ),
              children: [
                DCFText(
                  content: "🌈 COLOR CYCLE",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 80,
                width: 200,
                marginBottom: 20,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                borderRadius: 15,
              ),
            ),

            // 📏 LAYOUT ANIMATION TEST
            ReanimatedView(
              animationId: "layout_test",
              animatedStyle: AnimatedStyle().layout(
                width: ReanimatedValue(
                  from: 100,
                  to: 250,
                  duration: 2000,
                  curve: 'easeInOut',
                  repeat: true,
                  repeatCount: 4,
                ),
                height: ReanimatedValue(
                  from: 50,
                  to: 100,
                  duration: 2000,
                  curve: 'easeInOut',
                  repeat: true,
                  repeatCount: 4,
                ),
              ),
              onAnimationRepeat: () => print("📏 Layout animation repeat"),
              children: [
                DCFText(
                  content: "📏 LAYOUT",
                  textProps: DCFTextProps(
                    fontSize: 14,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 100, // Explicit height for container
                width: 250,  // Explicit width for container
                marginBottom: 30,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.purple.withOpacity(0.8),
                borderRadius: 10,
              ),
            ),

            // 🎭 COMPLEX SEQUENCE TEST
            ReanimatedView(
              animationId: "complex_sequence",
              animatedStyle: AnimatedStyle()
                .transform(
                  scale: ReanimatedValue(
                    from: 0.5,
                    to: 1.2,
                    duration: 1000,
                    curve: 'easeOut',
                    delay: 1000,
                  ),
                  rotation: ReanimatedValue(
                    from: 0.0,
                    to: 3.14, // π (half rotation)
                    duration: 1500,
                    curve: 'easeInOut',
                    delay: 1200,
                  ),
                  translateY: ReanimatedValue(
                    from: 50,
                    to: -20,
                    duration: 800,
                    curve: 'spring',
                    delay: 1400,
                  ),
                )
                .opacity(
                  ReanimatedValue(
                    from: 0.0,
                    to: 1.0,
                    duration: 600,
                    curve: 'easeIn',
                    delay: 1000,
                  ),
                ),
              onAnimationStart: () => print("🎭 Complex sequence started"),
              onAnimationComplete: () => print("🎭 Complex sequence complete"),
              children: [
                DCFText(
                  content: "🎭\nCOMPLEX\nSEQUENCE",
                  textProps: DCFTextProps(
                    fontSize: 14,
                    color: Colors.white,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 100,
                width: 100,
                marginBottom: 30,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.indigo.withOpacity(0.8),
                borderRadius: 15,
              ),
            ),

            // 🎛️ CONTROL PANEL
            ReanimatedView(
              animationId: "control_panel",
              animatedStyle: Reanimated.slideInLeft(
                distance: 300,
                duration: 800,
                delay: 2000,
                curve: 'easeOut',
              ),
              children: [
                DCFView(
                  layout: LayoutProps(
                    height: 400, // Explicit height for control panel content
                    width: 280,  // Explicit width for control panel content
                    justifyContent: YogaJustifyContent.center,
                    alignItems: YogaAlign.center,
                  ),
                  children: [
                    DCFText(
                      content: "🎛️ CONTROL PANEL",
                      textProps: DCFTextProps(
                        fontSize: 18,
                        color: Colors.black,
                        textAlign: "center",
                      ),
                      layout: LayoutProps(
                        height: 40,
                        width: 250,
                        marginBottom: 15,
                      ),
                    ),
                    
                    // Restart bounce button
                    DCFButton(
                      buttonProps: DCFButtonProps(title: "🔄 Restart Bounce"),
                      layout: LayoutProps(
                        height: 50,
                        width: 200,
                        marginBottom: 10,
                      ),
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.orange,
                        borderRadius: 25,
                      ),
                      onPress: (v) {
                        print("🔄 Restarting bounce animation");
                        bounceActive.setState(true);
                      },
                    ),
                    
                    // Restart pulse button
                    DCFButton(
                      buttonProps: DCFButtonProps(title: "💓 Restart Pulse"),
                      layout: LayoutProps(
                        height: 50,
                        width: 200,
                        marginBottom: 10,
                      ),
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.red,
                        borderRadius: 25,
                      ),
                      onPress: (v) {
                        print("💓 Restarting pulse animation");
                        pulseActive.setState(true);
                      },
                    ),
                    
                    // Reset counter
                    DCFButton(
                      buttonProps: DCFButtonProps(title: "🔄 Reset Counter"),
                      layout: LayoutProps(
                        height: 50,
                        width: 200,
                        marginBottom: 10,
                      ),
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.blue,
                        borderRadius: 25,
                      ),
                      onPress: (v) {
                        print("🔄 Resetting counter");
                        counter.setState(0);
                      },
                    ),
                    
                    // Navigation buttons
                    DCFButton(
                      buttonProps: DCFButtonProps(title: "← Back"),
                      layout: LayoutProps(
                        height: 50,
                        width: 200,
                        marginBottom: 10,
                      ),
                      styleSheet: StyleSheet(
                        backgroundColor: Colors.grey,
                        borderRadius: 25,
                      ),
                      onPress: (v) {
                        print("🚀 Going back...");
                        AppNavigation.goBack();
                      },
                    ),
                  ],
                ),
              ],
              layout: LayoutProps(
                height: 450, // Explicit height for ReanimatedView container
                width: 320,  // Explicit width for ReanimatedView container
                padding: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.white.withOpacity(0.95),
                borderRadius: 20,
              ),
            ),

            // 📊 PERFORMANCE INDICATOR
            ReanimatedView(
              animationId: "performance_indicator",
              animatedStyle: Reanimated.pulse(
                minOpacity: 0.4,
                maxOpacity: 1.0,
                duration: 1500,
                delay: 2500,
                repeat: true,
              ),
              children: [
                DCFText(
                  content: "⚡ 60fps Pure UI Thread ⚡\n🎯 Zero Bridge Calls During Animation 🎯\n🚀 ${counter.state} Interactions Completed 🚀",
                  textProps: DCFTextProps(
                    fontSize: 12,
                    color: Colors.green,
                    textAlign: "center",
                  ),
                ),
              ],
              layout: LayoutProps(
                height: 80,
                width: 320,
                marginTop: 20,
                padding: 10,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.black.withOpacity(0.8),
                borderRadius: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }
}