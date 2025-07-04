import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class NavigationDemo extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final detailsCommand = useStore(publicDetailScreenCommand);
    final modalCommand = useStore(publicModalScreenCommand);
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
          content: "Navigation Demo",
          textProps: DCFTextProps(
            fontSize: 28,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
          ),
        ),
        DCFText(
          content: "Test push navigation with screen commands:",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Push to Detail Screen"),
          layout: LayoutProps(height: 50, width: 250),
          styleSheet: StyleSheet(backgroundColor: Colors.blue, borderRadius: 8),
          onPress: (v) {
            detailsCommand.setState(
             NavigationPresets.pushTo(
                "detail_screen",
                params: {"source": "navigation_demo"},
              )
            );
          },
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Present Modal Screen"),
          layout: LayoutProps(height: 50, width: 250),
          styleSheet: StyleSheet(
            backgroundColor: Colors.green,
            borderRadius: 8,
          ),
          onPress: (v) {
            modalCommand.setState(
             NavigationPresets.presentModal("modal_screen")
            );
          },
        ),
      ],
    );
  }
}
