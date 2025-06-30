import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class DeepScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final useDeepScreenCommand = useStore(publicDeepScreenCommand);
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
          content: "Deep Screen",
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
          ),
        ),
        DCFText(
          content: "This is deep in the navigation stack",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Pop to Root"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 8),
          onPress: (v) {
            useDeepScreenCommand.setState(
              ScreenNavigationCommand(popToRoot: PopToRootCommand()),
            );
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Pop to Detail"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.cyan, borderRadius: 8),
          onPress: (v) {
            useDeepScreenCommand.setState(
              ScreenNavigationCommand(
                popTo: PopToScreenCommand(screenName: "detail_screen"),
              ),
            );
          },
        ),
      ],
    );
  }
}
