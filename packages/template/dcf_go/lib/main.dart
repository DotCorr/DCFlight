import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  await DCFlight.go(app: MyApp());
}

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home",
      screenRegistryComponents: StackScreenRegistry(),
      navigationBarStyle: DCFNavigationBarStyle(
        backgroundColor: Colors.orange.shade400,
        titleColor: Colors.blueAccent,
        backButtonColor: Colors.pink,
      ),
      onNavigationChange: (data) {
        print("🧭 Navigation changed: $data");
      },
      onBackPressed: (data) {
        print("⬅️ Back button pressed: $data");
      },
    );
  }

  @override
  List<Object?> get props => [];
}

