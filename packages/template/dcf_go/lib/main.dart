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
      layout: DCFLayout(flex: 1),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.pink),
      children: [DCFText(content: "Text example"),DCFButton(buttonProps: DCFButtonProps(title: "increment ${count.state}"),onPress: (v){
count.setState(count.state+1);
      })],
    );
  }

  @override
  List<Object?> get props => [];
}
