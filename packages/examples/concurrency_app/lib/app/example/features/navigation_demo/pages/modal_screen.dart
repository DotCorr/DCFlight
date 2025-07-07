import 'package:concurrency_app/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class ModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // use one command state instance if you want to stack multiple modals
    // or use a different command state instance for each modal screen
    final navigator = useStore(publicModalScreenCommand);

    return DCFView(
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        gap: 20,
      ),
      children: [
        DCFText(
          content: "Modal Screen",
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
          ),
        ),
        DCFText(
          content: "This screen was presented modally",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Dismiss Modal"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 8),
          onPress: (v) {
            navigator.setState(
               NavigationPresets.dismissModal
            );
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Stack Another Modal"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(
            backgroundColor: Colors.amber,
            borderRadius: 8,
          ),
          onPress: (v) {
            navigator.setState(
              NavigationPresets.presentModal("deep_screen_in_modal",)
            );
          },
        ),
      ],
    );
  }
}
