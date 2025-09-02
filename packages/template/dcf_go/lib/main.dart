import 'package:dcflight/dcflight.dart';

void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);

  await DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState(0);
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        alignItems: YogaAlign.center,
        justifyContent: YogaJustifyContent.center,
        alignContent: YogaAlign.center,
        paddingTop: 120,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.yellow.shade100),
      children: [
        DCFText(
          content: "Text example ${count.state}",
          textProps: DCFTextProps(
            fontSize: 20,
            color: Colors.red,
            textAlign: 'center',
          ),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "increment counter"),
          onPress: (v) {
            print("Button pressed");
            print("Current count: ${count.state}");
            count.setState(count.state + 1);
            print("New count: ${count.state}");
          },
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}
