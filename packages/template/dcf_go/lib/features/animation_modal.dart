import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Shared interactive value (use hook so component re-renders)
    final shared = useState<double>(0.2);

    // Which demo to show: 0 = Transform, 1 = Opacity, 2 = Drawer
    final selectedDemoState = useState<int>(0);

    // Drawer width expressed as percent string so the Yoga layout can handle it
    final drawerPercent = "${(shared.state * 70 + 20).toStringAsFixed(0)}%"; // range 20%..90%

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

        // Slider that drives a "shared" animation value used across demos.
        DCFView(
          layout: LayoutProps(gap: 8, flex: 1), 
          children: [
            DCFText(content: "Shared value: ${shared.state.toStringAsFixed(2)}"),
            DCFSlider(
              value: shared.state,
              onValueChange: (v) {
                try {
                  shared.setState(v['value']);
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
                  // A simple colored box whose left offset is driven by sharedValue percentage
                  DCFView(
                    layout: LayoutProps(
                      width: "${(shared.state * 80 + 10).toStringAsFixed(0)}%",
                      height: 60,
                    ),
                    styleSheet: StyleSheet(backgroundColor: Colors.blueAccent),
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
                  DCFView(
                    layout: LayoutProps(width: "50%", height: 80),
                    styleSheet: StyleSheet(
                      backgroundColor: Colors.red.withOpacity(shared.state)
                    ),
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
                  // Drawer container uses absolute positioning to emulate an overlay drawer
                  DCFView(
                    layout: LayoutProps(
                      position: YogaPositionType.absolute, 
                      absoluteLayout: AbsoluteLayout(left: 0, top: 40), 
                      width: drawerPercent, 
                      height: 160, 
                      padding: 12
                    ),
                    styleSheet: StyleSheet(
                      backgroundColor: Colors.white, 
                      borderColor: Colors.grey.shade300, 
                      borderWidth: 1
                    ),
                    children: [
                      DCFText(content: "I am a drawer — width = $drawerPercent"),
                      DCFButton(
                        buttonProps: DCFButtonProps(title: "Close"),
                        onPress: (v) {
                          try {
                            shared.setState(0.0); // animate closed via slider programmatically
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
                  shared.setState(0.2);
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