import "package:dcf_go/features/animation_modal.dart";
import "package:dcf_go/features/app.dart";
import "package:dcf_go/main.dart";
import "package:dcflight/dcflight.dart";

class StackScreenRegistry extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Use global navigation commands
    final homeNavCommand = useStore(homeNavigationCommand);
    final profileNavCommand = useStore(profileNavigationCommand);
    final settingsNavCommand = useStore(settingsNavigationCommand);
    final animatedModalNavCommand = useStore(animatedModalNavigationCommand);

    return DCFFragment(
      children: [
        DCFScreen(
          renderChildren: true,
          name: "home_screen",
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
          navigationCommand: homeNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Home navigation event: $data");
            homeNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "anim_action") {
              // Open drawer navigation
              animatedModalNavCommand.setState(
                NavigationPresets.presentModal("animated_modal_screen"),
              );
            }
          },
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          builder: () => HomeScreen(),
        ),

        // 🎯 Profile screen with edit button
        DCFScreen(
          name: "profile_screen",
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
          navigationCommand: profileNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Profile navigation event: $data");
            profileNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            print("🎯 Profile header action pressed: $data");
          },
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          builder: () => ProfileScreen(),
        ),

        // 🎯 Settings screen with cancel/done pattern
        DCFScreen(
          name: "settings_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Settings",
            backButtonTitle: "Back",
            // Add cancel/done buttons
            prefixActions: [
              DCFPushHeaderActionConfig.withTextOnly(title: "Cancel"),
            ],
            suffixActions: [
              DCFPushHeaderActionConfig.withTextOnly(title: "Done"),
            ],
          ),
          navigationCommand: settingsNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Settings navigation event: $data");
            settingsNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            print("🎯 Settings header action pressed: $data");
          },
          onAppear: (data) => print("✅ Settings screen appeared: $data"),
          builder: () => SettingsScreen(),
        ),

        DCFScreen(
          name: "animated_modal_screen",
          presentationStyle: DCFPresentationStyle.modal,

          navigationCommand: animatedModalNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Detail navigation event: $data");
            print("modal command: ${animatedModalNavigationCommand.state}");
            animatedModalNavigationCommand.setState(null);
          },
          // renderChildren: animatedModalNavigationCommand != null,
          builder: () => AnimatedModalScreen(),
        ),
      ],
    );
  }
}
