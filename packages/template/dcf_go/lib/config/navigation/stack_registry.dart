import "package:dcf_go/features/animation_modal.dart";
import "package:dcf_go/features/app.dart";
import "package:dcf_go/main.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class StackScreenRegistry extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final homeNavCommand = useStore(homeRouteNavigationCommand);
    final profileNavCommand = useStore(profileRouteNavigationCommand);
    final settingsNavCommand = useStore(settingsRouteNavigationCommand);
    final animatedModalNavCommand = useStore(animatedModalRouteNavigationCommand);

    return DCFFragment(
      children: [
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
          routeNavigationCommand: homeNavCommand.state,
          navigationStateCleaner: (data) {
            print("🧹 Home navigation cleanup: $data");
          },
          onNavigationEvent: (data) {
            print("🚀 Home navigation event: $data");
            homeRouteNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "anim_action") {
              animatedModalRouteNavigationCommand.setState(
                RouteNavigation.navigateToRoute("home/animated_modal", params: {
                  "title": "Animated Modal",
                  "message": "This is an animated modal screen"
                }),
              );
            }
          },
          onAppear: (data) => print("✅ Home route appeared: $data"),
          builder: () => HomeScreen(),
        ),

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
          routeNavigationCommand: profileNavCommand.state,
          navigationStateCleaner: (data) {
            print("🧹 Profile navigation cleanup: $data");
          },
          onNavigationEvent: (data) {
            print("🚀 Profile navigation event: $data");
            profileRouteNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings_action") {
              settingsRouteNavigationCommand.setState(
                RouteNavigation.navigateToRoute("profile/settings"),
              );
            }
          },
          onAppear: (data) => print("✅ Profile route appeared: $data"),
          builder: () => ProfileScreen(),
        ),

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
          routeNavigationCommand: settingsNavCommand.state,
          navigationStateCleaner: (data) {
            print("🧹 Settings navigation cleanup: $data");
          },
          onNavigationEvent: (data) {
            print("🚀 Settings navigation event: $data");
            settingsRouteNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            print("🎯 Settings header action pressed: $data");
          },
          onAppear: (data) => print("✅ Settings route appeared: $data"),
          builder: () => SettingsScreen(),
        ),

        DCFScreen(
          route: "home/animated_modal",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Animated Modal",
            backButtonTitle: "Home",
          ),
          routeNavigationCommand: animatedModalNavCommand.state,
          navigationStateCleaner: (data) {
            print("🧹 Animated modal navigation cleanup: $data");
          },
          onNavigationEvent: (data) {
            print("🚀 Animated modal navigation event: $data");
            animatedModalRouteNavigationCommand.setState(null);
          },
          onAppear: (data) => print("✅ Animated modal route appeared: $data"),
          onDisappear: (data) => print("❌ Animated modal route disappeared: $data"),
          onActivate: (data) => print("✅ Animated modal route activated: $data"),
          onDeactivate: (data) => print("❌ Animated modal route deactivated: $data"),
          onReceiveParams: (data) => print("📬 Animated modal route received params: $data"),
          builder: () => DCFView(),
        ),
      ],
    );
  }
}