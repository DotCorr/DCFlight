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
      ),
      children: [
        // Segmented-like row to pick demo (keeps API surface minimal and only uses DCFButton)
  DCFView(
    layout: LayoutProps(flexDirection: YogaFlexDirection.row, gap: 8),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Transform"),
              onPress: (v) {
                // update state to switch demo
                try {
      selectedDemoState.setState(0);
                } catch (_) {}
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Opacity"),
              onPress: (v) {
                try {
      selectedDemoState.setState(1);
                } catch (_) {}
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Drawer"),
              onPress: (v) {
                try {
      selectedDemoState.setState(2);
                } catch (_) {}
              },
            ),
          ],
        ),

        // Slider that drives a "shared" animation value used across demos.
        // NOTE: many dcf_reanimated APIs expose a SharedValue - here we keep a plain double
        // so the example compiles without requiring direct Reanimated bindings. Replace
        // `sharedValue` updates with your SharedValue.set(...) when wiring Reanimated.
        DCFView(layout: LayoutProps(gap: 8,flex:1), children: [
          DCFText(content: "Shared value: ${shared.state.toStringAsFixed(2)}"),
          DCFSlider(
            value: shared.state,
            onValueChange: (v) {
              try {
                shared.setState(v['value']);
              } catch (_) {}
            },
          ),
        ]),

        // Demo area - shows different animated behaviours driven by `sharedValue`.
        DCFView(layout: LayoutProps(gap: 12), children: [
          // Transform demo: translateX based on sharedValue
      if (selectedDemoState.state == 0)
            DCFView(
              layout: LayoutProps(width: "100%", height: 140, padding: 12),
              children: [
        DCFText(content: "Transform demo (translateX)", textProps: DCFTextProps(fontSize: 14)),
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
                DCFText(content: "Opacity demo", textProps: DCFTextProps(fontSize: 14)),
                DCFView(
                  layout: LayoutProps(width: "50%", height: 80),
                  styleSheet: StyleSheet(backgroundColor: Colors.red.withOpacity(shared.state)),
                ),
              ],
            ),

          // Drawer demo: a panel whose width is controlled by the slider (no gesture detector)
          if (selectedDemoState.state == 2)
            DCFView(
              layout: LayoutProps(width: "100%", height: 220),
              children: [
                DCFText(content: "Drawer demo (controlled by slider)", textProps: DCFTextProps(fontSize: 14)),
                // Drawer container uses absolute positioning to emulate an overlay drawer
                DCFView(
                  layout: LayoutProps(position: YogaPositionType.absolute, absoluteLayout: AbsoluteLayout(left: 0, top: 40), width: drawerPercent, height: 160, padding: 12),
                  styleSheet: StyleSheet(backgroundColor: Colors.white, borderColor: Colors.grey.shade300, borderWidth: 1),
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
        ]),

        // Helper actions
  DCFView(layout: LayoutProps(flexDirection: YogaFlexDirection.row, gap: 8), children: [
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
        ])
      ],
    );
  }
}