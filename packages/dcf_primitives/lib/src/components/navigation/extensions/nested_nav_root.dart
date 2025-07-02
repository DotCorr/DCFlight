
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
      tabRoutesRegistryComponents,
      subRoutesRegistryComponents,
      DCFTabNavigator(
        animationDuration: animationDuration,
        lazyLoad: true,
        screens: tabRoutes,
        selectedIndex: selectedIndex,
        tabBarStyle: tabBarStyle,
        onTabChange:  onTabChange,
        onTabPress: onTabPress,
      ),
    ]);
  }
}
