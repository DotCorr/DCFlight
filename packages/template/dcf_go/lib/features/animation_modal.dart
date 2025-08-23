import "package:dcf_reanimated/dcf_reanimated.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
   return DCFView(layout: LayoutProps(
    padding:20,
    paddingTop:120,
    gap:20
   ),
    children: [
      DCFTextInput(
        placeholder: "Type something...",
        styleSheet: StyleSheet(backgroundColor: Colors.grey.shade100,borderColor: Colors.blueAccent)
      ),
      DCFButton(
        layout: LayoutProps(
          width: "100%",
        height: 50
        ),
        buttonProps: DCFButtonProps(
        title: "Close Modal",
      
      ),
        onPress: (v) {
          AppNavigation.goBack();
          AppNavigation.dismissModal();
        },
      ),
      DCFSpinner(),
    DCFText(content: "Hello from Animated Modal!", styleSheet: StyleSheet(backgroundColor: Colors.amber)),
   ]);
  }
}