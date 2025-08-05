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
        // 🎯 HOME SCREEN - Always active (initial screen)
        DCFScreen(
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
              // 🔧 FIX: Activate the screen BEFORE navigation
              print("🎭 Activating animated modal screen...");
              DCFSuspensionManager.activate("animated_modal_screen", 
                reason: "Navigation triggered from home");
              
              // Small delay to ensure activation completes
              Future.delayed(Duration(milliseconds: 100), () {
                animatedModalNavCommand.setState(
                  NavigationPresets.pushTo("animated_modal_screen", params: {
                    "title": "Animated Modal",
                    "message": "This is an animated modal screen"
                  }),
                );
              });
            }
          },
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          builder: () => HomeScreen(),
        ),

        // 🎯 PROFILE SCREEN - TRUE SUSPENSION
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
            
            if (data['action'] == 'pop') {
              DCFSuspensionManager.suspend("profile_screen", 
                reason: "User navigated away");
            }
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings_action") {
              DCFSuspensionManager.activate("settings_screen", 
                reason: "Settings button pressed");
              
              Future.delayed(Duration(milliseconds: 50), () {
                settingsNavigationCommand.setState(
                  NavigationPresets.pushTo("settings_screen")
                );
              });
            }
          },
          onAppear: (data) {
            print("✅ Profile screen appeared: $data");
            DCFSuspensionManager.activate("profile_screen", 
              reason: "Screen appeared");
          },
          // 🔧 KEY FIX: TRUE SUSPENSION - Don't render children when suspended
          builder: () {
            final isSuspended = DCFSuspensionManager.isSuspended("profile_screen");
            if (isSuspended) {
              print("⏸️ Profile screen is suspended - not rendering children");
              return DCFView(
                children: [], // TRULY EMPTY - no ProfileScreen() creation
              );
            }
            print("🏗️ Profile screen is active - rendering children");
            return ProfileScreen(); // Only create when active
          },
        ),

        // 🎯 SETTINGS SCREEN - TRUE SUSPENSION
        DCFScreen(
          name: "settings_screen",
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
          navigationCommand: settingsNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Settings navigation event: $data");
            settingsNavigationCommand.setState(null);
            
            if (data['action'] == 'pop') {
              DCFSuspensionManager.suspend("settings_screen", 
                reason: "User left settings");
            }
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "Cancel" || data['actionId'] == "Done") {
              settingsNavigationCommand.setState(NavigationPresets.pop);
            }
          },
          onAppear: (data) {
            print("✅ Settings screen appeared: $data");
            DCFSuspensionManager.activate("settings_screen", 
              reason: "Screen appeared");
          },
          // 🔧 KEY FIX: TRUE SUSPENSION - Don't render children when suspended
          builder: () {
            final isSuspended = DCFSuspensionManager.isSuspended("settings_screen");
            if (isSuspended) {
              print("⏸️ Settings screen is suspended - not rendering children");
              return DCFView(
                children: [], // TRULY EMPTY
              );
            }
            print("🏗️ Settings screen is active - rendering children");
            return SettingsScreen();
          },
        ),

        // 🎯 ANIMATED MODAL SCREEN - THE MOST IMPORTANT FIX
        DCFScreen(
          name: "animated_modal_screen",
          presentationStyle: DCFPresentationStyle.push,
          navigationCommand: animatedModalNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Animated modal navigation event: $data");
            animatedModalNavigationCommand.setState(null);
            
            if (data['action'] == 'pop') {
              // Suspend immediately after navigation
              DCFSuspensionManager.suspend("animated_modal_screen", 
                reason: "Heavy animation screen cleanup");
            }
          },
          onAppear: (data) {
            print("✅ Animated modal screen appeared: $data");
            DCFSuspensionManager.activate("animated_modal_screen", 
              reason: "Screen appeared");
          },
          onDisappear: (data) => print("❌ Animated modal screen disappeared: $data"),
          onActivate: (data) => print("✅ Animated modal screen activated: $data"),
          onDeactivate: (data) => print("❌ Animated modal screen deactivated: $data"),
          onReceiveParams: (data) => print("📬 Animated modal screen received params: $data"),
          
          // 🔧 CRITICAL FIX: TRUE SUSPENSION - AnimatedModalScreen only created when active
          builder: () {
            final isSuspended = DCFSuspensionManager.isSuspended("animated_modal_screen");
            if (isSuspended) {
              print("⏸️ Animated modal screen is SUSPENDED - NO ANIMATION CONTROLLERS CREATED");
              return DCFView(
                children: [], // COMPLETELY EMPTY - NO AnimatedModalScreen() CONSTRUCTOR CALLED
              );
            }
            print("🏗️ Animated modal screen is ACTIVE - creating animation controllers");
            return AnimatedModalScreen(); // Only create (and thus animation controllers) when active
          },
        ),
      ],
    );
  }
}

// 🎯 SMART NAVIGATION HELPERS
class SmartNavigationHelpers {
  /// Navigate to profile with smart activation
  static void navigateToProfile() {
    print("Navigate to Profile pressed");
    
    DCFSuspensionManager.activate("profile_screen", 
      reason: "User navigation request");
    
    Future.delayed(Duration(milliseconds: 50), () {
      profileNavigationCommand.setState(
        NavigationPresets.pushTo("profile_screen")
      );
    });
  }
  
  /// Navigate to settings with smart activation
  static void navigateToSettings() {
    print("Navigate to Settings pressed");
    
    DCFSuspensionManager.activate("settings_screen", 
      reason: "User navigation request");
    
    Future.delayed(Duration(milliseconds: 50), () {
      settingsNavigationCommand.setState(
        NavigationPresets.pushTo("settings_screen")
      );
    });
  }
  
  /// Navigate to animated modal with proper activation
  static void navigateToAnimatedModal() {
    print("Navigate to Animated Modal pressed");
    
    DCFSuspensionManager.activate("animated_modal_screen", 
      reason: "Animation screen requested");
    
    Future.delayed(Duration(milliseconds: 100), () {
      animatedModalNavigationCommand.setState(
        NavigationPresets.pushTo("animated_modal_screen")
      );
    });
  }
  
  /// Print suspension statistics for debugging
  static void printStats() {
    final stats = DCFSuspensionManager.getStats();
    print("🎭 Suspension Stats: ${stats['suspendedCount']} suspended, ${stats['activeCount']} active");
    print("   Suspended: ${stats['suspended']}");
    print("   Active: ${stats['active']}");
  }
}