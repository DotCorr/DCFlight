import "package:dcf_go/features/animation_modal.dart";
import "package:dcf_go/features/app.dart";
import "package:dcf_go/main.dart";
import "package:dcf_screens/dcf_screens.dart";
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
          name: "home_screen",
          presentationStyle: DCFPresentationStyle.push,
          navigationStateCleaner: (v) {
            print("🧹 Cleaning up home navigation state: $v");
            homeNavigationCommand.setState(null);
          },
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

          onHeaderActionPress: (data) {
            if (data['actionId'] == "anim_action") {
              // Open drawer navigation
              animatedModalNavCommand.setState(
                NavigationPresets.pushTo(
                  "animated_modal_screen",
                  params: {
                    "title": "Animated Modal",
                    "message": "This is an animated modal screen",
                  },
                ),
              );
            }
          },
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          builder: () {
            final isSuspended = homeNavCommand.state == null;
            if (isSuspended) {
              print("⏸️ Home screen is suspended - not rendering children");
              return DCFFragment(children: []); // TRULY EMPTY
            }
            print("🏗️ Home screen is active - rendering children");
            return HomeScreen();
          },
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
          navigationStateCleaner: (v) {
            print("🧹 Cleaning up profile navigation state: $v");
            profileNavigationCommand.setState(null);
          },
          onNavigationEvent: (data) {
            print("🚀 Profile navigation event: $data");
          },
          onHeaderActionPress: (data) {
            print("🎯 Profile header action pressed: $data");
          },
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          builder: () {
            final isSuspended = profileNavCommand.state == null;
            if (isSuspended) {
              print("⏸️ Profile screen is suspended - not rendering children");
              return DCFFragment(children: []); // TRULY EMPTY
            }
            print("🏗️ Profile screen is active - rendering children");
            return ProfileScreen();
          },
        ),

        // 🎯 Settings screen with cancel/done pattern
        DCFScreen(
          navigationStateCleaner: (v) {
            settingsNavigationCommand.setState(null);
          },
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

          onHeaderActionPress: (data) {
            print("🎯 Settings header action pressed: $data");
          },
          onAppear: (data) => print("✅ Settings screen appeared: $data"),

          builder: () {
            final isSuspended = settingsNavCommand.state == null;
            if (isSuspended) {
              print("⏸️ Settings screen is suspended - not rendering children");
              return DCFFragment(
                children: [], // TRULY EMPTY
              );
            }
            print("🏗️ Settings screen is active - rendering children");
            return SettingsScreen();
          },
        ),

        DCFScreen(
          name: "animated_modal_screen",
          presentationStyle: DCFPresentationStyle.push,

          navigationCommand: animatedModalNavCommand.state,
          navigationStateCleaner: (v) {
            print("🧹 Cleaning up animated modal navigation state: $v");
            animatedModalNavigationCommand.setState(null);
          },

          builder: () {
            final isSuspended = animatedModalNavCommand.state == null;
            if (isSuspended) {
              print(
                "⏸️ Animated modal screen is suspended - not rendering children",
              );
              return DCFFragment(children: []);
            }

            return AnimatedModalScreen();
          },
        ),
      ],
    );
  }
}
