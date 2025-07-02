import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class Details extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final useDetailScreenCommand = useStore(publicDetailScreenCommand);
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
            content: "Detail Screen",
            textProps: DCFTextProps(
              fontSize: 24,
              fontWeight: DCFFontWeight.bold,
              color: Colors.black,
            ),
          ),
          DCFText(
            content: "This screen was pushed using ScreenNavigationCommand",
            textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
          ),

          DCFButton(
            buttonProps: DCFButtonProps(title: "Push Another Screen"),
            layout: LayoutProps(height: 50, width: 200),
            styleSheet: StyleSheet(
              backgroundColor: Colors.purple,
              borderRadius: 8,
            ),
            onPress: (v) {
              useDetailScreenCommand.setState(
                ScreenNavigationCommand(
                  pushTo: PushToScreenCommand(
                    screenName: "deep_screen",
                    params: {"level": "deep", "source": "detail_screen"},
                  ),
                ),
              );
            },
          ),

          DCFButton(
            buttonProps: DCFButtonProps(title: "Pop Back"),
            layout: LayoutProps(height: 50, width: 200),
            styleSheet: StyleSheet(
              backgroundColor: Colors.red,
              borderRadius: 8,
            ),
            onPress: (v) {
              useDetailScreenCommand.setState(
                ScreenNavigationCommand(
                  pop: PopScreenCommand(
                    result: {"message": "Returned from detail screen"},
                  ),
                ),
              );
            },
          ),
        ],
     
    );
  }
}
