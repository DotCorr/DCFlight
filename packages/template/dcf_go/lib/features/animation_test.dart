import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcflight/dcflight.dart";

class AnimationTestScreen extends DCFStatefulComponent {
  AnimationTestScreen({super.key});

  @override
  List<Object?> get props => [];

  @override
  DCFComponentNode render() {
    final selectedDemo = useState<int>(0);
    final animationValue = useState<double>(1.0);

    final transformStyle = useAnimatedStyle(() {
      return AnimatedStyle().widthValue(animationValue.state * 300);
    }, dependencies: [animationValue.state]);

    final opacityStyle = useAnimatedStyle(() {
      return AnimatedStyle().opacityValue(animationValue.state);
    }, dependencies: [animationValue.state]);

    return DCFScrollView(
      layout: DCFLayout(flex: 1, gap: 16, padding: 20),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.green.shade100),
      children: [
        DCFText(
          content: "🧪 Animation Reconciliation Test",
          textProps: DCFTextProps(fontSize: 18, fontWeight: DCFFontWeight.bold),
        ),

        DCFText(
          content:
              "This tests if animation state transfers incorrectly between different component types.",
          textProps: DCFTextProps(fontSize: 14),
        ),

        // Segmented control
        DCFSegmentedControl(
          segmentedControlProps: DCFSegmentedControlProps(
            segments: [
              DCFSegmentItem(title: "Transform"),
              DCFSegmentItem(title: "Opacity"),
            ],
            selectedIndex: selectedDemo.state,
          ),
          onSelectionChange: (v) {
            selectedDemo.setState(v['selectedIndex']);
          },
        ),

        // Animation value slider
        DCFView(
          layout: DCFLayout(gap: 8),
          children: [
            DCFText(
              content:
                  "Animation Value: ${animationValue.state.toStringAsFixed(2)}",
            ),
            DCFSlider(
              value: animationValue.state,
              onValueChange: (v) {
                animationValue.setState(v['value'] as double);
              },
            ),
          ],
        ),

        // Demo content area
        DCFView(
          layout: DCFLayout(height: 200, width: "100%", padding: 16),
          styleSheet: DCFStyleSheet(
            backgroundColor: Colors.white,
            borderRadius: 8,
          ),
          children: [
            // Transform demo - should NOT inherit opacity animation state
            if (selectedDemo.state == 0)
              DCFView(
                layout: DCFLayout(gap: 8),
                children: [
                  DCFText(
                    content: "🟢 Transform Demo",
                    textProps: DCFTextProps(fontWeight: DCFFontWeight.bold),
                  ),
                  ReanimatedView(
                    layout: DCFLayout(height: 60),
                    styleSheet: DCFStyleSheet(backgroundColor: Colors.blue),
                    animatedStyle: transformStyle,
                    children: [
                      DCFText(
                        content: "Width animates",
                        textProps: DCFTextProps(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),

            // Opacity demo - should NOT inherit transform animation state
            if (selectedDemo.state == 1)
              DCFView(
                layout: DCFLayout(gap: 8),
                children: [
                  DCFText(
                    content: "🔴 Opacity Demo",
                    textProps: DCFTextProps(fontWeight: DCFFontWeight.bold),
                  ),
                  ReanimatedView(
                    layout: DCFLayout(width: 200, height: 60),
                    styleSheet: DCFStyleSheet(backgroundColor: Colors.red),
                    animatedStyle: opacityStyle,
                    children: [
                      DCFText(
                        content: "Opacity animates",
                        textProps: DCFTextProps(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Reset Animation"),
          onPress: (v) {
            animationValue.setState(1.0);
          },
        ),

        DCFText(
          content:
              "✅ Expected: Switching demos should show clean animations\n❌ Bug: Animation state transfers between different components",
          textProps: DCFTextProps(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
