import 'package:dcf_go/main.dart';
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

class HomeScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Use global navigation commands
    final profileCommand = useStore(profileRouteNavigationCommand);
    final settingsCommand = useStore(settingsRouteNavigationCommand);
    
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

        // Navigate to profile - FIXED: Use correct route name
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Profile"),
          onPress: (data) {
            print("Navigate to Profile pressed");
            profileCommand.setState(RouteNavigationCommand(
              navigateToRoute: NavigateToRouteCommand(route: "profile") // FIXED: Changed from "profile_screen" to "profile"
            ));
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        // Navigate to settings - FIXED: Use correct route name
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
            print("Navigate to Settings pressed");
            settingsCommand.setState(
              RouteNavigationCommand(
                navigateToRoute: NavigateToRouteCommand(route: "profile/settings") // FIXED: Changed from "settings_screen" to "profile/settings"
              ),
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final settingsCommand = useStore(settingsRouteNavigationCommand);
    final profileCommand = useStore(profileRouteNavigationCommand);

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
          content: "Try the 'Settings' button in the navigation bar!",
          textProps: DCFTextProps(fontSize: 16, textAlign: "center"),
          layout: LayoutProps(marginBottom: 30),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
            settingsCommand.setState(
              RouteNavigationCommand(
                navigateToRoute: NavigateToRouteCommand(route: "profile/settings") // FIXED: Changed from "settings_screen" to "profile/settings"
              ),
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            profileCommand.setState(
              RouteNavigationCommand(
                pop: PopRouteCommand() // FIXED: Use proper pop command instead of navigating to "home_screen"
              ),
            );
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
    final settingsCommand = useStore(settingsRouteNavigationCommand);

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
          ),
          onPress: (data) {
            settingsCommand.setState(
              RouteNavigationCommand(
                popToRoot: PopToRootRouteCommand() // FIXED: Use proper pop to root command
              )
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            settingsCommand.setState(
              RouteNavigationCommand(
                pop: PopRouteCommand() // FIXED: Use proper pop command instead of navigating to "home_screen"
              )
            );
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}