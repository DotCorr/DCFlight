
import 'package:dcflight/dcflight.dart';

class DCFNestedNavigationRoot extends StatelessComponent {
  final StateHook tabState;
  final double? animationDuration;
  final DCFTabBarStyle? tabBarStyle;
  final Function(dynamic)? onTabChange;
  final Function(dynamic)? onTabPress;
  // List of tab routes (screen names)
  final List<String> tabRoutes;
  // Registry of tab routes as DCFScreen objects
  // Assign a route to a corresponding tab Component
  final DCFComponentNode tabRoutesRegistryComponents;
  final DCFComponentNode subRoutesRegistryComponents;

  DCFNestedNavigationRoot(
      {super.key,
      required this.tabState,
      this.animationDuration,
      this.tabBarStyle =
          const DCFTabBarStyle(selectedTintColor: Colors.blueAccent),
      this.onTabChange,
      this.onTabPress,
      required this.tabRoutes,
      required this.tabRoutesRegistryComponents,
      required this.subRoutesRegistryComponents});

  @override
  DCFComponentNode render() {
    return DCFFragment(children: [
      tabRoutesRegistryComponents,
      subRoutesRegistryComponents,
      DCFTabNavigator(
        animationDuration: animationDuration,
        lazyLoad: true,
        screens: tabRoutes,
        selectedIndex: tabState.state,
        tabBarStyle: tabBarStyle,
        onTabChange:  (data) {
            final newIndex = data["selectedIndex"] as int;
            tabState.setState(newIndex);
            print("🔄 Tab changed to index: $newIndex");
            onTabChange?.call(data);
          },
        onTabPress: onTabPress,
      ),
    ]);
  }
}
