import 'package:dcf_primitives/src/components/navigation/extensions/components/tab_navigator_component.dart';
import 'package:dcflight/dcflight.dart';

class DCFNestedNavigationRoot extends StatelessComponent {
  final double? animationDuration;
  final int selectedIndex; // Default selected index, can be overridden
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
      this.animationDuration,
      this.tabBarStyle =
          const DCFTabBarStyle(selectedTintColor: Colors.blueAccent),
      this.onTabChange,
      this.onTabPress,
      required this.selectedIndex,
      required this.tabRoutes,
      required this.tabRoutesRegistryComponents,
      required this.subRoutesRegistryComponents});

  @override
  DCFComponentNode render() {
    return DCFFragment(children: [
      // These components are not actually children of the tab navigator component
      // It just preloads the tab routes registry components and sub routes registry components
      tabRoutesRegistryComponents,
      subRoutesRegistryComponents,
      DCFTabNavigator(
        animationDuration: animationDuration,
        // Todo: lazy load at abstraction as well (this means that the tab routes registry components and sub routes registry components will be loaded lazily by using if statements. This is not advisable but just providing that option)
        lazyLoad: true,
        screens: tabRoutes,
        selectedIndex: selectedIndex,
        tabBarStyle: tabBarStyle,
        onTabChange: onTabChange,
        onTabPress: onTabPress,
      ),
    ]);
  }
}
