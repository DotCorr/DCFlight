import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcflight/dcflight.dart';

// Global state for navigation commands
final homeNavigationCommand = Store<ScreenNavigationCommand?>(null);
final profileNavigationCommand = Store<ScreenNavigationCommand?>(null);
final settingsNavigationCommand = Store<ScreenNavigationCommand?>(null);
final detailNavigationCommand = Store<ScreenNavigationCommand?>(null);
final drawerNavigationCommand = Store<ScreenNavigationCommand?>(null);


void main() {
  DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home_screen",
      // 🎯 FIXED: Create screen registry component that renders screens FIRST
      screenRegistryComponents: StackScreenRegistry(),
      navigationBarStyle: const DCFNavigationBarStyle(
        backgroundColor: Colors.amber,
        titleColor: Colors.black,
        backButtonColor: Colors.red,
        titleDisplayMode: "large",
        showBackButton: true,
        hideBorder: false,
      ),
      hideNavigationBar: false,
      // animationDuration: 0.3,
      onNavigationChange: (data) {
        print("🧭 Navigation changed: $data");
      },
      onBackPressed: (data) {
        print("◀️ Back pressed: $data");
      },
    );
  }
}
