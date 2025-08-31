import 'package:dcflight/dcflight.dart';

void main() async {
  // Enable debug logging to see UseWebDefaults in action
  DCFlight.setLogLevel(DCFLogLevel.debug);

  // Start the app (hot reload listener will be started automatically in debug mode)
  await DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(flex: 1),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.green),
    );
  }

  @override
  List<Object?> get props => [];
}
