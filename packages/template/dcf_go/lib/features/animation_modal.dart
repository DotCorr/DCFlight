import "package:dcf_go/main.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
  final modalNavigationCommand = useStore(animatedModalNavigationCommand);

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
        DCFSegmentedControl(
          
          segmentedControlProps: DCFSegmentedControlProps(
            segments: [
              DCFSegmentItem(title: "Anim 1"),
              DCFSegmentItem(title: "Anim 2"),
              DCFSegmentItem(title: "Anim 3"),
            ],
            selectedIndex: 0,
          ),
          onSelectionChange: (index) {
            // Handle segmented control value change
          },
        ),
        DCFText(
          content: "Animated Modal Screen",
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
          ),
        ),
        DCFText(
          styleSheet: StyleSheet(
            backgroundColor: Colors.white,
            borderRadius: 8,
          ),
          content: "This screen was presented modally with an animation",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),

        DCFText(
          content: "This screen was presented modally with an animation",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),

        DCFButton(buttonProps: DCFButtonProps(title: "Dismiss Modal"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 8),
          onPress: (v) {
            // Use the command to dismiss the modal
            modalNavigationCommand.setState(
              NavigationPresets.dismissModal,
            );
          },
        ),
      ],
    );
  }
}
