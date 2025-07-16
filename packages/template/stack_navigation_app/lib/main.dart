import 'package:dcflight/dcflight.dart';

// Global state for navigation commands
final homeNavigationCommand = Store<ScreenNavigationCommand?>(null);
final profileNavigationCommand = Store<ScreenNavigationCommand?>(null);
final settingsNavigationCommand = Store<ScreenNavigationCommand?>(null);
final detailNavigationCommand = Store<ScreenNavigationCommand?>(null);

void main() {
  DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home_screen",
      // 🎯 FIXED: Create screen registry component that renders screens FIRST
      screenRegistryComponents: StackScreenRegistry(),
      navigationBarStyle: const DCFNavigationBarStyle(
        backgroundColor: Colors.white,
        titleColor: Colors.black,
        backButtonColor: Colors.blue,
        titleDisplayMode: "large",
        showBackButton: true,
        hideBorder: false,
      ),
      hideNavigationBar: false,
      animationDuration: 0.3,
      onNavigationChange: (data) {
        print("🧭 Navigation changed: $data");
      },
      onBackPressed: (data) {
        print("◀️ Back pressed: $data");
      },
    );
  }
}

// 🎯 FIXED: Separate registry component that ensures screens are rendered
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
        // 🎯 Home screen - initial screen with header actions
        DCFScreen(
          name: "home_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Home",
            largeTitleDisplayMode: true,
            suffixActions: [
              DCFPushHeaderActionConfig.withSVGPackage(
                title: "Settings",
                package: "dcf_primitives",
                iconName: DCFIcons.search,
                actionId: "settings_action",
              ),
              DCFPushHeaderActionConfig.withSFSymbolOnly(
                symbolName: "magnifyingglass",
                actionId: "search_action",
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
                iconName: "settings",
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

        // 🎯 Detail screen with share and more options
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

// Example home screen with navigation actions
class HomeScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Use global navigation commands
    final profileCommand = useStore(profileNavigationCommand);
    final settingsCommand = useStore(settingsNavigationCommand);
    final detailCommand = useStore(detailNavigationCommand);

    return DCFView(
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      children: [
        DCFText(
          content: "Welcome to Stack Navigation!",
          textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFText(
          content:
              "Header actions are working! Try the buttons in the navigation bar.",
          textProps: DCFTextProps(fontSize: 16, textAlign: "center"),
          layout: LayoutProps(marginBottom: 30),
        ),

        // Navigate to profile
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Profile"),
          onPress: (data) {
            print("Navigate to Profile pressed");
            profileCommand.setState(NavigationPresets.pushTo("profile_screen"));
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        // Navigate to settings
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
            print("Navigate to Settings pressed");
            settingsCommand.setState(
              NavigationPresets.pushTo("settings_screen"),
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        // Navigate to detail
        DCFButton(
          buttonProps: DCFButtonProps(title: "View Detail"),
          onPress: (data) {
            print("Navigate to Detail pressed");
            detailCommand.setState(
              NavigationPresets.pushTo(
                "detail_screen",
                params: {"from": "home"},
              ),
            );
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final settingsCommand = useStore(settingsNavigationCommand);
    final profileCommand = useStore(profileNavigationCommand);

    return DCFView(
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      children: [
        DCFText(
          content: "Profile Screen",
          textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFText(
          content: "Try the 'Edit' button in the navigation bar!",
          textProps: DCFTextProps(fontSize: 16, textAlign: "center"),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
            settingsCommand.setState(
              NavigationPresets.pushTo("settings_screen"),
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            profileCommand.setState(NavigationPresets.pop);
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final settingsCommand = useStore(settingsNavigationCommand);

    return DCFView(
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      children: [
        DCFText(
          content: "Settings Screen",
          textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFText(
          content: "Try the 'Cancel' and 'Done' buttons in the navigation bar!",
          textProps: DCFTextProps(fontSize: 16, textAlign: "center"),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(
            title: "Pop to Root",
            // color: Colors.red,
            // textColor: Colors.white,
          ),
          onPress: (data) {
            settingsCommand.setState(NavigationPresets.popToRoot);
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            settingsCommand.setState(NavigationPresets.pop);
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}

class DetailScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final detailCommand = useStore(detailNavigationCommand);

    return DCFView(
      layout: LayoutProps(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      children: [
        DCFText(
          content: "Detail Screen",
          textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFText(
          content:
              "This screen can be reached from any other screen. Try the 'Share' and 'More' buttons in the navigation bar!",
          textProps: DCFTextProps(fontSize: 16, textAlign: "center"),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(
            title: "Go Back",
            // backgroundColor: Colors.grey,
            // textColor: Colors.white,
          ),
          onPress: (data) {
            detailCommand.setState(NavigationPresets.pop);
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}
