import 'package:dcf_go/main.dart';
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

class HomeScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Use global navigation commands
    final profileCommand = useStore(profileNavigationCommand);
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

