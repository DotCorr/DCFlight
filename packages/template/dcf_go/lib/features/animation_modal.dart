import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Animation value state that drives all animations
    final animationValue = useState<double>(0.2);
    
    // Which demo to show: 0 = Transform, 1 = Opacity, 2 = Drawer
    final selectedDemoState = useState<int>(0);

    // Create animated styles for each demo type
    final transformStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .layout(width: ReanimatedValue(
          from: 10,
          to: animationValue.state * 80 + 10,
          duration: 300,
          curve: 'easeOut',
        ));
    }, dependencies: [animationValue.state]);

    final opacityStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .opacity(ReanimatedValue(
          from: 0.1,
          to: animationValue.state,
          duration: 300,
          curve: 'easeInOut',
        ));
    }, dependencies: [animationValue.state]);

    final drawerStyle = useAnimatedStyle(() {
      return AnimatedStyle()
        .layout(width: ReanimatedValue(
          from: 20,
          to: animationValue.state * 70 + 20,
          duration: 300,
          curve: 'easeOut',
        ));
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
          layout: LayoutProps(gap: 12,height:400), 
          children: [
            // Transform demo: translateX based on sharedValue
            if (selectedDemoState.state == 0)
              DCFView(
                layout: LayoutProps(width: "100%", height: 140, padding: 12),
                children: [
                  DCFText(
                    content: "Transform demo (translateX)", 
                    textProps: DCFTextProps(fontSize: 14)
                  ),
                  // Pure UI thread animated box using ReanimatedView
                  ReanimatedView(
                    layout: LayoutProps(height: 60),
                    styleSheet: StyleSheet(backgroundColor: Colors.blueAccent),
                    animatedStyle: transformStyle,
                    autoStart: true,
                    children: [],
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
                layout: LayoutProps(width: "100%", height: 220),
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
                      height: 160, 
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
                            // Animate to closed state
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

        // Helper actions with wrap to prevent overflow
        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.row, 
            flexWrap: YogaWrap.wrap, // This prevents overflow
            gap: 8
          ), 
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Reset"),
              onPress: (v) {
                try {
                  // Reset to initial value
                  animationValue.setState(0.2);
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