import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class DeepScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    print("DeepScreen render called");
    final useDeepScreenCommand = useStore(publicDeepScreenCommand);
    final useDeepScreenInModalCommand = useStore(
      publicModalScreenInModalCommand,
    );

    final slidedState = useState<double>(0.5);
    final scale = useState<double>(0.2);

    return DCFScrollView(
      styleSheet: StyleSheet(backgroundColor: Colors.amber),
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        gap: 20,
      ),
      children: [
        DCFView(
          layout: LayoutProps(
            height: 120,
            width: 120,
            alignItems: YogaAlign.center,
          ),
          children: [
            DCFText(
              content: "❤",

              layout: LayoutProps(
                height: 100,
                width: "100%",
                alignItems: YogaAlign.center,
                justifyContent: YogaJustifyContent.center,
                scale: scale.state,
              ),
              textProps: DCFTextProps(
                fontSize: slidedState.state * 100,
                fontWeight: DCFFontWeight.bold,
                color: Colors.black,
                textAlign: 'center',
              ),
            ),
          ],
        ),

        DCFView(
          styleSheet: cardStyle,

          layout: cardLayout,
          children: [
            DCFText(
              content: "Slider Value: ${slidedState.state.toStringAsFixed(2)}",
              textProps: DCFTextProps(
                fontSize: 16,
                fontWeight: DCFFontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            DCFSlider(
              value: slidedState.state,
              onValueChange: (v) {
                print("Slider value changed: ${v['value']} ");
                slidedState.setState(v['value']);
              },
            ),
          ],
        ),

        DCFView(
          styleSheet: cardStyle,
          layout: cardLayout,
          children: [
            DCFText(
              content: "Scale Value: ${scale.state}",
              textProps: DCFTextProps(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            DCFSlider(
              value: scale.state,
              onValueChange: (v) {
                print("Scale value changed: ${v['value']}");
                scale.setState(v['value']);
              },
            ),
          ],
        ),

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
           if(useDeepScreenInModalCommand.state ==
                ScreenNavigationCommand().popToRoot) {
              useDeepScreenInModalCommand.setState(
                NavigationPresets.dismissModal,
              );
            } else {
              useDeepScreenCommand.setState(
                NavigationPresets.popToRoot,
              );
            }
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Pop to Detail"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.cyan, borderRadius: 8),
          onPress: (v) {
            if (publicModalScreenInModalCommand.state ==
                ScreenNavigationCommand().dismissModal) {
              useDeepScreenInModalCommand.setState(
                NavigationPresets.dismissModal,
              );
            } else {
              useDeepScreenCommand.setState(
                NavigationPresets.popTo("detail_screen"),
              );
            }
          },
        ),
      ],
    );
  }
}

final cardStyle = StyleSheet(
  backgroundColor: Colors.white30,
  borderRadius: 8,

  shadowColor: Colors.black.withOpacity(0.1),
  shadowRadius: 10,
  shadowOffsetX: 0,
  shadowOffsetY: 2,
  shadowOpacity: 0.5,
);

final cardLayout = LayoutProps(
  flexDirection: YogaFlexDirection.column,
  height: 100,
  width: "100%",
  padding: 10,
  gap: 2,
  alignItems: YogaAlign.center,
);
