import 'package:dcf_primitives/dcf_primitives.dart';
import "package:dcf_go/features/animation_modal.dart";
import "package:dcf_go/features/animation_test.dart";
import "package:dcf_go/features/app.dart";
import "package:dcf_go/features/hot_reload_test.dart";
import "package:dcf_go/features/website_screen.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class StackScreenRegistry extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFFragment(
      children: [
        // 🏠 HOME SCREEN - Always rendered, automatic handling
        DCFEasyScreen(
          route: "home",
          alwaysRender: true, // Skip suspense for home
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
          onHeaderActionPress: (data) {
            if (data['actionId'] == "anim_action") {
              print("🎬 Opening animated modal from home header action");
              AppNavigation.navigateTo(
                "home/animated_modal",
                params: {
                  "title": "Animated Modal",
                  "message": "This is an animated modal screen",
                },
                fromScreen: "home",
              );
            }
          },
          builder: () => HomeScreen(),
        ),

        // 👤 PROFILE SCREEN - Automatic suspense!
        DCFEasyScreen(
          route: "profile",
          // presentationStyle: DCFPresentationStyle.push,
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
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings_action") {
              AppNavigation.navigateTo(
                "profile/settings",
                fromScreen: "profile",
              );
            }
          },
          builder: () => ProfileScreen(),
        ),

        // ⚙️ SETTINGS SCREEN - Automatic suspense!
        DCFEasyScreen(
          route: "profile/settings",
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
          onHeaderActionPress: (data) {
            print("🎯 Settings header action pressed: $data");
            if (data['title'] == "Cancel") {
              AppNavigation.goBack(fromScreen: "profile/settings");
            } else if (data['title'] == "Done") {
              AppNavigation.goBack(fromScreen: "profile/settings");
            }
          },
          builder: () => SettingsScreen(),
        ),

        DCFEasyScreen(
          route: "home/animated_modal",
          pushConfig: DCFPushConfig(
            title: "Animated Modal",
            backButtonTitle: "Home",
          ),
          builder:
              () =>
                  AnimatedModalScreen(), // Only creates when actually navigated to!
        ),

        DCFEasyScreen(
          route: "home/website",
          modalConfig: DCFModalConfig(
            allowsBackgroundDismiss: true,
            detents: [DCFModalDetent.large, DCFModalDetent.medium],
            selectedDetentIndex: 0,
            showDragIndicator: true,
          ),
          builder: () => WebsiteScreen(),
        ),

        // 🧪 ANIMATION TEST - Test reconciliation fix
        DCFEasyScreen(
          route: "home/animation_test",
          modalConfig: DCFModalConfig(
            allowsBackgroundDismiss: true,
            detents: [DCFModalDetent.large],
            selectedDetentIndex: 0,
            showDragIndicator: true,
          ),
          builder: () => AnimationTestScreen(),
        ),

        // 🔥 HOT RELOAD TEST - Test hot reload functionality
        DCFEasyScreen(
          route: "home/hot_reload_test",
          pushConfig: DCFPushConfig(
            title: "Hot Reload Test",
            backButtonTitle: "Home",
          ),
          builder: () => HotReloadTestScreen(),
        ),
      ],
    );
  }
  
  @override
  List<Object?> get props => [];
}

