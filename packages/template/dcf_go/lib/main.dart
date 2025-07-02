import 'package:dcf_go/app/example/config/stack_registry.dart';
import 'package:dcf_go/app/example/config/tab_registry.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  // keep outside of the render method to avoid re-instantiation(to be safe)
  // if this was inside the render method if the main component was stateful, useMemo could have been used in the render method
  final tabReg = TabRegistry();
  final subRoutesReg = StackRegistry();

  @override
  DCFComponentNode render() {
    final selectedIndex = useState<int>(0);
    return DCFNestedNavigationRoot(
      onTabChange: (data) {
        print("🔄 Tab changed to index: ${data["selectedIndex"]}");
selectedIndex.setState(data["selectedIndex"]);
      },
      tabRoutes: const [
        "test_home",
        "test_profile",
        "navigation_demo",
        "test_gh",
      ],
      //sub-routes don't have to be registered in the same order as the tabs
      // fun fact: sub routes can push to the same screen as the tab routes
      selectedIndex: selectedIndex.state,
      tabRoutesRegistryComponents: tabReg,
      subRoutesRegistryComponents: subRoutesReg,
    );
  }
}
