
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

class HomeScreen extends StatelessComponent {
  @override
  DCFComponentNode render() {
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

        // 🎯 TARGETED NAVIGATION: Specify fromScreen to prevent conflicts
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Profile"),
          onPress: (data) {
            print("Navigate to Profile pressed");
            AppNavigation.navigateTo("profile", fromScreen: "home");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Website"),
          onPress: (data) {
            print("Navigate to Website pressed");
            AppNavigation.presentModal("home/website", fromScreen: "home");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
            print("Navigate to Settings pressed");
            AppNavigation.navigateTo("profile/settings", fromScreen: "home");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Open Animation Modal"),
          onPress: (data) {
            print("Navigate to Animation Modal pressed");
            AppNavigation.navigateTo("home/animated_modal", 
              params: {
                "title": "Animated Modal from Button",
                "message": "This modal was opened from a button!"
              },
              fromScreen: "home"
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        // 🎯 FIXED: Present modal with proper targeting
        DCFButton(
          buttonProps: DCFButtonProps(title: "Present Modal"),
          onPress: (data) {
            AppNavigation.presentModal("home/animated_modal", 
              params: {
                "title": "Presented as Modal",
                "message": "This was presented modally!"
              },
              fromScreen: "home"
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),
      ],
    );
  }
  
  @override
  List<Object?> get props => [];
}

class ProfileScreen extends StatefulComponent {
  @override
  DCFComponentNode render() {
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

        // 🎯 TARGETED NAVIGATION
        DCFButton(
          buttonProps: DCFButtonProps(title: "Go to Settings"),
          onPress: (data) {
            AppNavigation.navigateTo("profile/settings", fromScreen: "profile");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            AppNavigation.goBack(fromScreen: "profile");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Animation Modal from Profile"),
          onPress: (data) {
            AppNavigation.navigateTo("home/animated_modal", 
              params: {
                "title": "Modal from Profile",
                "message": "This works from any screen now!"
              },
              fromScreen: "profile"
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Replace with Settings"),
          onPress: (data) {
            AppNavigation.replace("profile/settings", 
              params: {
                "replaced": true,
                "message": "This screen was replaced!"
              },
              fromScreen: "profile"
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

        // 🎯 TARGETED NAVIGATION
        DCFButton(
          buttonProps: DCFButtonProps(
            title: "Pop to Root",
          ),
          onPress: (data) {
            AppNavigation.goToRoot(fromScreen: "profile/settings");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back"),
          onPress: (data) {
            AppNavigation.goBack(fromScreen: "profile/settings");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        // 🎯 FIXED: This was the problematic case!
        DCFButton(
          buttonProps: DCFButtonProps(title: "Animation Modal from Settings"),
          onPress: (data) {
            AppNavigation.navigateTo("home/animated_modal", 
              params: {
                "title": "Modal from Settings",
                "message": "This was the problematic case - now fixed!"
              },
              fromScreen: "profile/settings"
            );
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Go Back with Result"),
          onPress: (data) {
            AppNavigation.goBackWithResult({
              "settingsSaved": true,
              "timestamp": DateTime.now().toIso8601String(),
              "changes": ["theme", "notifications", "privacy"]
            }, fromScreen: "profile/settings");
          },
          layout: LayoutProps(marginBottom: 16, width: "80%"),
        ),

        DCFButton(
          buttonProps: DCFButtonProps(title: "Pop to Profile"),
          onPress: (data) {
            AppNavigation.popToRoute("profile", fromScreen: "profile/settings");
          },
          layout: LayoutProps(width: "80%"),
        ),
      ],
    );
  }
}

