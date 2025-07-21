import "package:dcf_go/app.dart";
import "package:dcf_go/main.dart";
import "package:dcflight/dcflight.dart";

class StackScreenRegistry extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Use global navigation commands
    final homeNavCommand = useStore(homeNavigationCommand);
    final profileNavCommand = useStore(profileNavigationCommand);
    final settingsNavCommand = useStore(settingsNavigationCommand);
    final detailNavCommand = useStore(detailNavigationCommand);

    return DCFFragment(
      children: [
        DCFScreen(
          name: "home_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Home",

            prefixActions: [
              DCFPushHeaderActionConfig.withSVGPackage(
                title: "Menu",
                package: dcfP,
                iconName: DCFIcons.menu,
                actionId: "menu_action",
              ),
            ],
          ),
          navigationCommand: homeNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Home navigation event: $data");
            homeNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            print("🎯 Home header action pressed: $data");
            if (data['actionId'] == "menu_action") {
              // Open drawer navigation
              detailNavCommand.setState(
                NavigationPresets.pushTo("detail_screen"),
              );
            }
          },
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          children: [HomeScreen()],
        ),

        // 🎯 Profile screen with edit button
        DCFScreen(
          name: "profile_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Profile",
            backButtonTitle: "Home",
            // Add edit button
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
          children: [ProfileScreen()],
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
          children: [SettingsScreen()],
        ),

        DCFScreen(
          name: "detail_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Detail",
            backButtonTitle: "Back",
            // Add multiple actions
            suffixActions: [
              DCFPushHeaderActionConfig.withSFSymbol(
                title: "Share",
                symbolName: "square.and.arrow.up",
              ),
              DCFPushHeaderActionConfig.withSFSymbolOnly(
                symbolName: "ellipsis",
              ),
            ],
          ),
          navigationCommand: detailNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Detail navigation event: $data");
            detailNavigationCommand.setState(null);
          },
          onHeaderActionPress: (data) {
            print("🎯 Detail header action pressed: $data");
          },
          onReceiveParams: (data) => print("📨 Detail received params: $data"),
          onAppear: (data) => print("✅ Detail screen appeared: $data"),
          children: [DetailScreen()],
        ),
      ],
    );
  }
}
