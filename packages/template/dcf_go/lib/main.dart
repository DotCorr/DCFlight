import 'package:dcf_go/app/example/config/stack_registry.dart';
import 'package:dcf_go/app/example/config/tab_registry.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final currentTab = useState<int>(0);

    return DCFNestedNavigationRoot(
      onTabChange: (data) {
        final newIndex = data["selectedIndex"] as int;

        print("🔄 Tab Comfirm changed to index: $newIndex");
      },
      tabRoutes: ["test_home", "test_profile", "navigation_demo", "test_gh"],
      tabState: currentTab,

      tabRoutesRegistryComponents: TabRegistry(),
      subRoutesRegistryComponents: StackRegistry(),
    );
  }
}
