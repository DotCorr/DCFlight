import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Animation value state that drives all animations
    final animationValue = useState<double>(1.0); // Start at full scale (100%)
    
    // Which demo to show: 0 = Transform, 1 = Opacity, 2 = Drawer
    final selectedDemoState = useState<int>(0);

    // Create animated styles for smooth continuous updates (no bouncing)
    final transformStyle = useAnimatedStyle(() {
      // Animate from 0px to ~350px width (full container width minus padding)
      final width = animationValue.state * 350; // 0px → 350px
      return AnimatedStyle()
        .widthValue(width); // Simplified API!
    }, dependencies: [animationValue.state]);

    final opacityStyle = useAnimatedStyle(() {
      // Direct opacity mapping (0.0 → 1.0)
      return AnimatedStyle()
        .opacityValue(animationValue.state); // Simplified API!
    }, dependencies: [animationValue.state]);

    final drawerStyle = useAnimatedStyle(() {
      // Animate drawer from 0px to ~350px width
      final width = animationValue.state * 350; // 0px → 350px
      return AnimatedStyle()
        .widthValue(width); // Simplified API!
    }, dependencies: [animationValue.state]);

    return DCFView(
      layout: LayoutProps(
        padding: 20,
        flex: 1,
        paddingTop: 120,
        gap: 16,
        paddingBottom:120
      ),
      children: [
        // Segmented control to pick demo
        DCFSegmentedControl(
          segmentedControlProps: DCFSegmentedControlProps(
            segments: [
              DCFSegmentItem(title: "Transform"),
              DCFSegmentItem(title: "Opacity"), 
              DCFSegmentItem(title: "Drawer"),
              DCFSegmentItem(title: "Complex"), // NEW: Complex preset animations
            ],
            selectedIndex: selectedDemoState.state,
          ),
          onSelectionChange: (v) {
            try {
              selectedDemoState.setState(v['selectedIndex']);
            } catch (_) {}
          },
        ),

        // Slider that drives a shared animation value used across demos
        DCFView(
          layout: LayoutProps(gap: 8, flex: 1), 
          children: [
            DCFText(content: "Animation value: ${animationValue.state.toStringAsFixed(2)}"),
            DCFSlider(
              value: animationValue.state,
              onValueChange: (v) {
                try {
                  final newValue = v['value'] as double;
                  animationValue.setState(newValue);
                } catch (_) {}
              },
            ),
          ]
        ),

        // Demo area - shows different animated behaviours driven by `sharedValue`.
        DCFScrollView(
          layout: LayoutProps(gap: 5,height:"400"), 
          children: [
            // Transform demo: translateX based on sharedValue
            if (selectedDemoState.state == 0)
              DCFView(
                layout: LayoutProps(width: "100%", height: 140),
                children: [
                  DCFView(
                    layout: LayoutProps(padding: 12),
                    children: [
                      DCFText(
                        content: "Transform demo (width)", 
                        textProps: DCFTextProps(fontSize: 14)
                      ),
                    ],
                  ),
                  // Container with no padding for full width animation
                  DCFView(
                    layout: LayoutProps(paddingLeft: 12, paddingRight: 12),
                    children: [
                      // Pure UI thread animated box using ReanimatedView
                      ReanimatedView(
                        layout: LayoutProps(height: 60), // Width controlled by animation
                        styleSheet: StyleSheet(backgroundColor: Colors.blueAccent),
                        animatedStyle: transformStyle,
                        autoStart: true,
                        children: [
                          DCFText(content: "I animate from 0 to full width!"),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

            // Opacity demo: box fades in/out
            if (selectedDemoState.state == 1)
              DCFView(
                layout: LayoutProps(width: "100%", height: 140, padding: 12),
                children: [
                  DCFText(
                    content: "Opacity demo", 
                    textProps: DCFTextProps(fontSize: 14)
                  ),
                  // Pure UI thread opacity animation using ReanimatedView
                  ReanimatedView(
                    layout: LayoutProps(width: "50%", height: 80),
                    styleSheet: StyleSheet(backgroundColor: Colors.red),
                    animatedStyle: opacityStyle,
                    autoStart: true,
                    children: [],
                  ),
                ],
              ),

            // Drawer demo: a panel whose width is controlled by the slider
            if (selectedDemoState.state == 2)
              DCFView(
                layout: LayoutProps(width: "100%", height: "100%"),
                children: [
                  DCFText(
                    content: "Drawer demo (controlled by slider)", 
                    textProps: DCFTextProps(fontSize: 14)
                  ),
                  // Pure UI thread animated drawer using ReanimatedView
                  ReanimatedView(
                    layout: LayoutProps(
                      position: YogaPositionType.absolute, 
                      absoluteLayout: AbsoluteLayout(left: 0, top: 40), 
                      
                      padding: 12
                    ),
                    styleSheet: StyleSheet(
                      backgroundColor: Colors.white, 
                      borderColor: Colors.grey.shade300, 
                      borderWidth: 1
                    ),
                    animatedStyle: drawerStyle,
                    autoStart: true,
                    children: [
                      DCFText(content: "I am a pure UI thread animated drawer"),
                      DCFButton(
                        buttonProps: DCFButtonProps(title: "Close"),
                        onPress: (v) {
                          try {
                            // Use proper ReanimatedValue for smooth UI thread animation
                            animationValue.setState(0.0);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ],
              ),

            // Complex preset animations demo - showcases ALL DCF Reanimated APIs
            if (selectedDemoState.state == 3)
              DCFScrollView(
                layout: LayoutProps(width: "100%", height: "100%", gap: 16, padding: 12),
                children: [
                  DCFText(
                    content: "Complex Preset Animations - API Showcase", 
                    textProps: DCFTextProps(fontSize: 16, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  // Entrance Animations Section
                  DCFText(
                    content: "🚀 Entrance Animations", 
                    textProps: DCFTextProps(fontSize: 14, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  DCFView(
                    layout: LayoutProps(flexDirection: YogaFlexDirection.row, gap: 8, flexWrap: YogaWrap.wrap),
                    children: [
                      // Fade In
                      ReanimatedView(
                        animationId: "fade-in-demo",
                        animatedStyle: Reanimated.fadeIn(duration: 800, delay: 0),
                        layout: LayoutProps(width: 80, height: 80, marginBottom: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.blue, borderRadius: 8),
                        children: [
                          DCFText(content: "Fade", textProps: DCFTextProps(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                      
                      // Scale In
                      ReanimatedView(
                        animationId: "scale-in-demo", 
                        animatedStyle: Reanimated.scaleIn(fromScale: 0.0, toScale: 1.0, duration: 600, delay: 200),
                        layout: LayoutProps(width: 80, height: 80, marginBottom: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.green, borderRadius: 8),
                        children: [
                          DCFText(content: "Scale", textProps: DCFTextProps(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                      
                      // Slide In Right
                      ReanimatedView(
                        animationId: "slide-right-demo",
                        animatedStyle: Reanimated.slideInRight(distance: 100.0, duration: 700, delay: 400),
                        layout: LayoutProps(width: 80, height: 80, marginBottom: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.purple, borderRadius: 8),
                        children: [
                          DCFText(content: "→ Slide", textProps: DCFTextProps(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                      
                      // Slide In Left  
                      ReanimatedView(
                        animationId: "slide-left-demo",
                        animatedStyle: Reanimated.slideInLeft(distance: 100.0, duration: 700, delay: 600),
                        layout: LayoutProps(width: 80, height: 80, marginBottom: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.orange, borderRadius: 8),
                        children: [
                          DCFText(content: "← Slide", textProps: DCFTextProps(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  
                  // Complex Combined Animation
                  DCFText(
                    content: "✨ Complex Combined Animation", 
                    textProps: DCFTextProps(fontSize: 14, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  ReanimatedView(
                    animationId: "slide-scale-fade-demo",
                    animatedStyle: Reanimated.slideScaleFadeIn(
                      slideDistance: 80.0,
                      fromScale: 0.7,
                      toScale: 1.1, // Overshoot for premium effect
                      duration: 900,
                      delay: 800,
                      curve: 'easeOut',
                    ),
                    layout: LayoutProps(width: "90%", height: 100, alignSelf: YogaAlign.center, padding: 16),
                    styleSheet: StyleSheet(
                      backgroundColor: Colors.indigo,
                      borderRadius: 12,
                    ),
                    children: [
                      DCFText(
                        content: "🎯 Premium Combined Animation", 
                        textProps: DCFTextProps(color: Colors.white, fontSize: 14, fontWeight: DCFFontWeight.bold)
                      ),
                      DCFText(
                        content: "Slide + Scale + Fade with overshoot", 
                        textProps: DCFTextProps(color: Colors.white, fontSize: 12)
                      ),
                    ],
                  ),
                  
                  // Continuous Animations Section
                  DCFText(
                    content: "🔄 Continuous Animations", 
                    textProps: DCFTextProps(fontSize: 14, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  DCFView(
                    layout: LayoutProps(flexDirection: YogaFlexDirection.row, gap: 12, justifyContent: YogaJustifyContent.spaceEvenly),
                    children: [
                      // Rotating Spinner
                      ReanimatedView(
                        animationId: "rotate-demo",
                        animatedStyle: Reanimated.rotate(
                          toRotation: 6.28, // Full 360° rotation
                          duration: 2000,
                          delay: 1000,
                        ),
                        layout: LayoutProps(width: 60, height: 60),
                        styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 30),
                        children: [
                          DCFText(content: "🌀", textProps: DCFTextProps(fontSize: 24)),
                        ],
                      ),
                      
                      // Pulsing Heart
                      ReanimatedView(
                        animationId: "pulse-demo",
                        animatedStyle: Reanimated.pulse(
                          minOpacity: 0.3,
                          maxOpacity: 1.0,
                          duration: 1200,
                          delay: 1200,
                        ),
                        layout: LayoutProps(width: 60, height: 60),
                        styleSheet: StyleSheet(backgroundColor: Colors.pink, borderRadius: 30),
                        children: [
                          DCFText(content: "💖", textProps: DCFTextProps(fontSize: 24)),
                        ],
                      ),
                      
                      // Bouncing Ball
                      ReanimatedView(
                        animationId: "bounce-demo",
                        animatedStyle: Reanimated.bounce(
                          bounceScale: 1.4,
                          duration: 500,
                          delay: 1400,
                          repeatCount: 4,
                        ),
                        layout: LayoutProps(width: 60, height: 60),
                        styleSheet: StyleSheet(backgroundColor: Colors.yellow, borderRadius: 30),
                        children: [
                          DCFText(content: "⚽", textProps: DCFTextProps(fontSize: 24)),
                        ],
                      ),
                    ],
                  ),
                  
                  // Error State Animation
                  DCFText(
                    content: "⚠️ Error State Animation", 
                    textProps: DCFTextProps(fontSize: 14, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  ReanimatedView(
                    animationId: "wiggle-demo",
                    animatedStyle: Reanimated.wiggle(
                      wiggleAngle: 0.15, // ~8 degrees
                      duration: 80,
                      delay: 1800,
                      repeatCount: 6,
                    ),
                    layout: LayoutProps(width: "80%", height: 50, alignSelf: YogaAlign.center, padding: 12),
                    styleSheet: StyleSheet(
                      backgroundColor: Colors.red.shade100,
                      borderColor: Colors.red,
                      borderWidth: 2,
                      borderRadius: 8,
                    ),
                    children: [
                      DCFText(
                        content: "❌ This field has an error - watch me wiggle!", 
                        textProps: DCFTextProps(color: Colors.red, fontSize: 12)
                      ),
                    ],
                  ),
                  
                  // Staggered Animation Sequence
                  DCFText(
                    content: "🎬 Staggered Animation Sequence", 
                    textProps: DCFTextProps(fontSize: 14, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  DCFView(
                    layout: LayoutProps(gap: 4),
                    children: [
                      // Item 1
                      ReanimatedView(
                        animationId: "stagger-1",
                        animatedStyle: Reanimated.slideInLeft(distance: 80, duration: 400, delay: 2200),
                        layout: LayoutProps(height: 40, marginBottom: 4, padding: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.teal.shade100, borderRadius: 4),
                        children: [
                          DCFText(content: "📋 List Item 1", textProps: DCFTextProps(fontSize: 12)),
                        ],
                      ),
                      
                      // Item 2
                      ReanimatedView(
                        animationId: "stagger-2", 
                        animatedStyle: Reanimated.slideInLeft(distance: 80, duration: 400, delay: 2350),
                        layout: LayoutProps(height: 40, marginBottom: 4, padding: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.teal.shade200, borderRadius: 4),
                        children: [
                          DCFText(content: "📋 List Item 2", textProps: DCFTextProps(fontSize: 12)),
                        ],
                      ),
                      
                      // Item 3
                      ReanimatedView(
                        animationId: "stagger-3",
                        animatedStyle: Reanimated.slideInLeft(distance: 80, duration: 400, delay: 2500),
                        layout: LayoutProps(height: 40, marginBottom: 4, padding: 8),
                        styleSheet: StyleSheet(backgroundColor: Colors.teal.shade300, borderRadius: 4),
                        children: [
                          DCFText(content: "📋 List Item 3", textProps: DCFTextProps(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  
                  // Exit Animation Demo
                  DCFText(
                    content: "👋 Exit Animation", 
                    textProps: DCFTextProps(fontSize: 14, fontWeight: DCFFontWeight.bold)
                  ),
                  
                  ReanimatedView(
                    animationId: "fade-out-demo",
                    animatedStyle: Reanimated.fadeOut(duration: 1000, delay: 3000),
                    layout: LayoutProps(width: "70%", height: 60, alignSelf: YogaAlign.center, padding: 12),
                    styleSheet: StyleSheet(backgroundColor: Colors.grey.shade300, borderRadius: 8),
                    onAnimationComplete: () => print("🎉 Exit animation completed!"),
                    children: [
                      DCFText(
                        content: "👻 I will disappear after 3 seconds", 
                        textProps: DCFTextProps(fontSize: 12, textAlign: "center")
                      ),
                    ],
                  ),
                ],
              ),
          ]
        ),

        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row, 
            flexWrap: YogaWrap.wrap,
            gap: 8
          ), 
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Reset"),
              onPress: (v) {
                try {
                  // Use proper ReanimatedValue for smooth UI thread animation
                  animationValue.setState(1.0); // Reset to full scale
                } catch (_) {}
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Close Modal"),
              onPress: (v) {
                AppNavigation.dismissModal();
              },
            ),
          ]
        )
      ],
    );
  }
}