import 'package:dcflight/dcflight.dart';

void main() async {
  // Enable debug logging to see UseWebDefaults in action
  DCFlight.setLogLevel(DCFLogLevel.debug);

  // Start the app (hot reload listener will be started automatically in debug mode)
  await DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState(0);
    return DCFView(
      layout: DCFLayout(flex: 1,alignItems: YogaAlign.center,justifyContent: YogaJustifyContent.center,paddingTop: 120),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.red.shade100),
      children: [
        DCFText(content: "Text example ${count.state}",textProps: DCFTextProps(fontSize: 20,color: Colors.indigo)),
        DCFButton(
          buttonProps: DCFButtonProps(title: "increment counter"),
          onPress: (v) {
            count.setState(count.state + 1);
          },
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}
