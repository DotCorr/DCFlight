import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/constants/style/gradient.dart';

class DeepScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // print("DeepScreen render called");
    final useDeepScreenCommand = useStore(publicDeepScreenCommand);

    final slidedState = useState<double>(0.5);
    final scale = useState<double>(1);
    final raceTrack = useState<double>(0.12);

    return DCFScrollView(
      styleSheet: StyleSheet(
        backgroundGradient: DCFGradient.linear(
          colors: [Colors.red, Colors.blue, Colors.green],
        ),
      ),
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        gap: 20,
      ),
      children: [
        DCFView(
          styleSheet: cardStyle,
          layout: LayoutProps(
            height: 120,
            width: raceTrack.state > 0.12 ? "100%" : 120,
            paddingRight: raceTrack.state * 100,
            alignItems: YogaAlign.center,
          ),
          children: [
            DCFText(
              content: "🏎️",
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
              content:
                  "Race Track Value: ${raceTrack.state.toStringAsFixed(2)}",
              textProps: DCFTextProps(
                fontSize: 16,
                fontWeight: DCFFontWeight.bold,
                color: Colors.amber.shade600,
              ),
            ),
            DCFSlider(
              value: raceTrack.state,
              onValueChange: (v) {
                raceTrack.setState(v['value']);
              },
            ),
          ],
        ),

        DCFView(
          styleSheet: cardStyle,
          layout: cardLayout,
          children: [
            DCFText(
              content: "Scale Value: ${scale.state.toStringAsFixed(1)}}",
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
            // won't dismis for modals as they dont share same command state instance. ou can handle that with if statements
            // But this test involved using this same deep screen componet accross stack and modal. In real life you are most likely not doing this but if you do, hey; use if statements to see where the command is from and take the appropriate action
            useDeepScreenCommand.setState(NavigationPresets.popToRoot);
          },
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Pop to Detail"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.cyan, borderRadius: 8),
          onPress: (v) {
            useDeepScreenCommand.setState(
              NavigationPresets.popTo("detail_screen"),
            );
          },
        ),
      ],
    );
  }
}

final cardStyle = StyleSheet(
  backgroundColor: Colors.grey.shade100,
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
