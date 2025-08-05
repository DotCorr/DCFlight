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
              // 🎭 ACTIVATE the animated modal screen before navigation
              DCFSuspensionManager.activate("animated_modal_screen", 
                reason: "Navigation triggered from home");
              
              animatedModalNavCommand.setState(
                NavigationPresets.pushTo("animated_modal_screen", params: {
                  "title": "Animated Modal",
                  "message": "This is an animated modal screen"
                }),
              );
            }
          },
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          builder: () => HomeScreen(),
        ),

        // 🎯 PROFILE SCREEN - Smart suspended
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
            
            // 🎭 SUSPEND after navigation completes
            if (data['action'] == 'pop') {
              DCFSuspensionManager.suspend("profile_screen", 
                reason: "User navigated away");
            }
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings_action") {
              // 🎭 ACTIVATE settings before navigation
              DCFSuspensionManager.activate("settings_screen", 
                reason: "Settings button pressed");
              
              settingsNavigationCommand.setState(
                NavigationPresets.pushTo("settings_screen")
              );
            }
          },
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          
          // 🎭 SMART SUSPENSION: Use suspension view with memory mode
          builder: () => DCFSuspensionManager.getStore("profile_screen").suspensionView(
            mode: DCFSuspensionMode.memory, // Pre-rendered but suspended
            reason: "Profile screen lazy loading",
            children: [ProfileScreen()],
          ),
        ),

        // 🎯 SETTINGS SCREEN - Smart suspended with placeholder
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
            
            // 🎭 SUSPEND after navigation
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
          onAppear: (data) => print("✅ Settings screen appeared: $data"),
          
          // 🎭 SMART SUSPENSION: Use placeholder mode for smoother UX
          builder: () => DCFSuspensionManager.getStore("settings_screen").suspensionView(
            mode: DCFSuspensionMode.placeholder,
            reason: "Settings screen with placeholder",
            placeholder: DCFView(
              layout: LayoutProps(
                flex: 1,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              children: [
                DCFText(
                  content: "Loading Settings...",
                  textProps: DCFTextProps(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            children: [SettingsScreen()],
          ),
        ),

        // 🎯 ANIMATED MODAL SCREEN - Full suspension for heavy animations
        DCFScreen(
          name: "animated_modal_screen",
          presentationStyle: DCFPresentationStyle.push,
          navigationCommand: animatedModalNavCommand.state,
          onNavigationEvent: (data) {
            print("🚀 Animated modal navigation event: $data");
            animatedModalNavigationCommand.setState(null);
            
            // 🎭 SUSPEND after navigation (heavy animations)
            if (data['action'] == 'pop') {
              DCFSuspensionManager.suspend("animated_modal_screen", 
                reason: "Heavy animation screen cleanup");
            }
          },
          onAppear: (data) => print("✅ Animated modal screen appeared: $data"),
          onDisappear: (data) => print("❌ Animated modal screen disappeared: $data"),
          onActivate: (data) => print("✅ Animated modal screen activated: $data"),
          onDeactivate: (data) => print("❌ Animated modal screen deactivated: $data"),
          onReceiveParams: (data) => print("📬 Animated modal screen received params: $data"),
          
          // 🎭 SMART SUSPENSION: Full suspension for performance
          builder: () => DCFSuspensionManager.getStore("animated_modal_screen").suspensionView(
            mode: DCFSuspensionMode.full, // Completely suspended when not needed
            reason: "Heavy animation performance optimization",
           
            children: [AnimatedModalScreen()],
          ),
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
    
    // 🎭 ACTIVATE before navigation
    DCFSuspensionManager.activate("profile_screen", 
      reason: "User navigation request");
    
    profileNavigationCommand.setState(
      NavigationPresets.pushTo("profile_screen")
    );
  }
  
  /// Navigate to settings with smart activation
  static void navigateToSettings() {
    print("Navigate to Settings pressed");
    
    // 🎭 ACTIVATE before navigation
    DCFSuspensionManager.activate("settings_screen", 
      reason: "User navigation request");
    
    settingsNavigationCommand.setState(
      NavigationPresets.pushTo("settings_screen")
    );
  }
  
  /// Smart memory management - suspend all except active
  static void optimizeMemory(String activeScreen) {
    DCFSuspensionManager.suspendAllExcept(activeScreen);
  }
  
  /// Print suspension statistics for debugging
  static void printStats() {
    final stats = DCFSuspensionManager.getStats();
    print("🎭 Suspension Stats: ${stats['suspendedCount']} suspended, ${stats['activeCount']} active");
    print("   Suspended: ${stats['suspended']}");
    print("   Active: ${stats['active']}");
  }
}