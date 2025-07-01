import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class ModalScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final useModalScreenCommand = useStore(publicModalScreenCommand);
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
            useModalScreenCommand.setState(
              ScreenNavigationCommand(
                dismissModal: DismissModalCommand(
                  result: {
                    "dismissed": true,
                    "timestamp": DateTime.now().toString(),
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
