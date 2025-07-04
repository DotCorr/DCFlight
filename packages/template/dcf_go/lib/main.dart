import 'package:dcf_go/app/example/config/stack_registry.dart';
import 'package:dcf_go/app/example/config/tab_registry.dart';
import 'package:dcflight/dcflight.dart';

void main() {

  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  // keep outside of the render method to avoid re-instantiation(to be safe)
  // if you where to access state or context in the render method, you can use useMemo to access them safely
  final tabReg = TabRegistry();
  final subRoutesReg = StackRegistry();

  @override
  DCFComponentNode render() {
    return DCFNestedNavigationRoot(
      tabRoutes: const [
        "test_home",
        "test_profile",
        "navigation_demo",
        "test_gh",
      ],
      //sub-routes don't have to be registered in the same order as the tabs
      // fun fact: sub routes can push to the same screen as the tab routes
      selectedIndex: 0,
      tabRoutesRegistryComponents: tabReg,
      subRoutesRegistryComponents: subRoutesReg,
    );
  }
}
