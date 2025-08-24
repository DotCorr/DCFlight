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