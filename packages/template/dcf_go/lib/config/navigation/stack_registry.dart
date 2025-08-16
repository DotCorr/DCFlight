import "package:dcf_go/features/app.dart";
import "package:dcf_go/main.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class StackScreenRegistry extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // 🎯 SMART NAVIGATION: Each screen checks if it should handle the command
    final globalNavCommand = useStore(globalNavigationCommand);
    final globalNavTarget = useStore(globalNavigationTarget);

    return DCFFragment(
      children: [
        // 🏠 HOME SCREEN
        DCFScreen(
          renderChildren: true,
          route: "home",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Home",
            prefixActions: [
              DCFPushHeaderActionConfig.withSVGPackage(
                title: "Animation",
                package: dcfP,
                iconName: DCFIcons.rabbit,
                actionId: "anim_action",
              ),
            ],
          ),
          // 🎯 SMART: Only handle command if targeted to this screen or no target specified
          routeNavigationCommand: _shouldHandleCommand("home", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Home navigation event: $data");
            AppNavigation.clearCommand();
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "anim_action") {
              print("🎬 Opening animated modal from home header action");
              // 🎯 SPECIFY FROM SCREEN to prevent conflicts
              AppNavigation.navigateTo("home/animated_modal", 
                params: {
                  "title": "Animated Modal",
                  "message": "This is an animated modal screen"
                },
                fromScreen: "home"
              );
            }
          },
          onAppear: (data) => print("✅ Home route appeared: $data"),
          builder: () => HomeScreen(),
        ),

        // 👤 PROFILE SCREEN
        DCFScreen(
          route: "profile",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Profile",
            backButtonTitle: "Home",
            suffixActions: [
              DCFPushHeaderActionConfig.withSVGPackage(
                title: "Settings",
                package: "dcf_primitives",
                iconName: DCFIcons.settings,
                actionId: "settings_action",
              ),
            ],
          ),
          // 🎯 SMART: Only handle command if targeted to this screen or no target specified
          routeNavigationCommand: _shouldHandleCommand("profile", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Profile navigation event: $data");
            AppNavigation.clearCommand();
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings_action") {
              AppNavigation.navigateTo("profile/settings", fromScreen: "profile");
            }
          },
          onAppear: (data) => print("✅ Profile route appeared: $data"),
          builder: () => ProfileScreen(),
        ),

        // ⚙️ SETTINGS SCREEN
        DCFScreen(
          route: "profile/settings",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Settings",
            backButtonTitle: "Back",
            prefixActions: [
              DCFPushHeaderActionConfig.withTextOnly(title: "Cancel"),
            ],
            suffixActions: [
              DCFPushHeaderActionConfig.withTextOnly(title: "Done"),
            ],
          ),
          // 🎯 SMART: Only handle command if targeted to this screen or no target specified
          routeNavigationCommand: _shouldHandleCommand("profile/settings", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Settings navigation event: $data");
            AppNavigation.clearCommand();
          },
          onHeaderActionPress: (data) {
            print("🎯 Settings header action pressed: $data");
            // Handle Cancel/Done buttons
            if (data['title'] == "Cancel") {
              AppNavigation.goBack(fromScreen: "profile/settings");
            } else if (data['title'] == "Done") {
              // Save settings and go back
              AppNavigation.goBack(fromScreen: "profile/settings");
            }
          },
          onAppear: (data) => print("✅ Settings route appeared: $data"),
          builder: () => SettingsScreen(),
        ),

        // 🎬 ANIMATED MODAL SCREEN
        DCFScreen(
          route: "home/animated_modal",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Animated Modal",
            backButtonTitle: "Home",
          ),
          // 🎯 SMART: Only handle command if targeted to this screen or no target specified
          routeNavigationCommand: _shouldHandleCommand("home/animated_modal", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Animated modal navigation event: $data");
            AppNavigation.clearCommand();
          },
          onAppear: (data) => print("✅ Animated modal appeared: $data"),
          builder: () => DCFView(
            layout: LayoutProps(
              flex: 1,
              padding: 20,
              justifyContent: YogaJustifyContent.center,
              alignItems: YogaAlign.center,
            ),
            styleSheet: StyleSheet(
              backgroundColor: Colors.amber,
              borderRadius: 20,
            ),
          ),
        ),
      ],
    );
  }

  // 🎯 HELPER: Determine if this screen should handle the global navigation command
  bool _shouldHandleCommand(String screenRoute, String? targetRoute) {
    // If no target specified, any screen can handle (for backwards compatibility)
    if (targetRoute == null) return true;

    return screenRoute == targetRoute;
  }
}