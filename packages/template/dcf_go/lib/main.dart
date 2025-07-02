import 'package:dcf_go/app/example/config/stack_registry.dart';
import 'package:dcf_go/app/example/config/tab_registry.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  //? Instantiate registry components once as instance fields.
  // This prevents them from being recreated on every render.
  // Better still use useMemo to create them only once.
  // These react like hooks are deeply integrated into the component lifecycle.
  // And they are made such that flutter developers can use them without thinking much about memorizing hooks.
  // Most of your optimizations are handled by the framework itself and UI modules that follow the framework standards.
  //
  // The hooks are as well made intentionally to be as little as possible to avoid unnecessary complexity.
  final _tabRegistry = TabRegistry();
  final _stackRegistry = StackRegistry();

  @override
  DCFComponentNode render() {
    final currentTab = useState<int>(0);

    return DCFNestedNavigationRoot(
      onTabChange: (data) {
        // The tab navigator itself now handles the state change.
        // We can observe it here if needed.
        print("🔄 Tab changed to index: ${data["selectedIndex"]}");
      },
      tabRoutes: ["test_home", "test_profile", "navigation_demo", "test_gh"],
      tabState: currentTab,
      tabRoutesRegistryComponents: _tabRegistry,
      subRoutesRegistryComponents: _stackRegistry,
    );
  }
}
