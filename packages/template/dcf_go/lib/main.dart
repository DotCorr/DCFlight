import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';

// Global state for route navigation commands
final homeRouteNavigationCommand = Store<RouteNavigationCommand?>(null);
final profileRouteNavigationCommand = Store<RouteNavigationCommand?>(null);
final settingsRouteNavigationCommand = Store<RouteNavigationCommand?>(null);
final animatedModalRouteNavigationCommand = Store<RouteNavigationCommand?>(null);

void main() {
  setupDCFReanimated();
  DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home",
      screenRegistryComponents: StackScreenRegistry()
    );
  }
}