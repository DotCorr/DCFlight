import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcflight/dcflight.dart';

// Global state for navigation commands
final homeNavigationCommand = Store<ScreenNavigationCommand?>(null);
final profileNavigationCommand = Store<ScreenNavigationCommand?>(null);
final settingsNavigationCommand = Store<ScreenNavigationCommand?>(null);
final animatedModalNavigationCommand = Store<ScreenNavigationCommand?>(null);


void main() {
  DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home_screen",
      screenRegistryComponents: StackScreenRegistry()
    );
  }
}
