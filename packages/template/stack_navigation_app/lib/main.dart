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
  // Registry containing all available screens
  final subRoutesReg = SimpleStackRegistry();

  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home_screen", // Start with this screen
      screenRegistryComponents: subRoutesReg,
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

// Example screen registry for stack navigation
class SimpleStackRegistry extends StatefulComponent {
  final _homeScreen = HomeScreen();
  final _profileScreen = ProfileScreen();
  final _settingsScreen = SettingsScreen();

  @override
  DCFComponentNode render() {
    // Use global navigation commands
    final homeNavCommand = useStore(homeNavigationCommand);
    final profileNavCommand = useStore(profileNavigationCommand);
    final settingsNavCommand = useStore(settingsNavigationCommand);
    final detailNavCommand = useStore(detailNavigationCommand);

    return DCFFragment(
      children: [
        // Home screen - initial screen
        DCFScreen(
          name: "home_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: const DCFPushConfig(
            title: "Home",
            largeTitleDisplayMode: true,
          ),
          navigationCommand: homeNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Home navigation event: $data");
            homeNavCommand.setState(null);
          },
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          children: [_homeScreen],
        ),

        // Profile screen
        DCFScreen(
          name: "profile_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: const DCFPushConfig(
            title: "Profile",
            backButtonTitle: "Home",
          ),
          navigationCommand: profileNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Profile navigation event: $data");
            profileNavCommand.setState(null);
          },
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          children: [_profileScreen],
        ),

        // Settings screen
        DCFScreen(
          name: "settings_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: const DCFPushConfig(
            title: "Settings",
            backButtonTitle: "Back",
          ),
          navigationCommand: settingsNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Settings navigation event: $data");
            settingsNavCommand.setState(null);
          },
          onAppear: (data) => print("✅ Settings screen appeared: $data"),
          children: [_settingsScreen],
        ),

        // Detail screen that can be pushed from any screen
        DCFScreen(
          name: "detail_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: const DCFPushConfig(
            title: "Detail",
            backButtonTitle: "Back",
          ),
          navigationCommand: detailNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Detail navigation event: $data");
            detailNavCommand.setState(null);
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

        // Navigate to profile
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Profile"),
          onPress: (data) {
            profileCommand.setState(NavigationPresets.pushTo("profile_screen"));
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        // Navigate to settings
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
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

        DCFButton(
          buttonProps: DCFButtonProps(title: "Pop to Root"),
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
          content: "This screen can be reached from any other screen",
          textProps: DCFTextProps(fontSize: 16),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            detailCommand.setState(NavigationPresets.pop);
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}
