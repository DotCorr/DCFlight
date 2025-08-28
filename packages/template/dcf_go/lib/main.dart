import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcf_screens/dcf_screens.dart';
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
    return DCFStackNavigationRoot(
      initialScreen: "home",
      screenRegistryComponents: StackScreenRegistry(),
    );
  }

  @override
  List<Object?> get props => [];
}



