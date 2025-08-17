import "package:dcf_go/features/animation_modal.dart";
import "package:dcf_go/features/app.dart";
import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

class StackScreenRegistry extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // 🎯 SMART NAVIGATION: Each screen checks if it should handle the command
    final globalNavCommand = useStore(globalNavigationCommand);
    final globalNavTarget = useStore(globalNavigationTarget);

    return DCFFragment(
      children: [
        // 🏠 HOME SCREEN - Always active initially
        DCFScreen(
          renderChildren: true,
          route: "home",
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
          routeNavigationCommand: _shouldHandleCommand("home", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Home navigation event: $data");
            // Update active screen based on navigation events
            _handleNavigationEvents("home", data);
            AppNavigation.clearCommand();
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "anim_action") {
              print("🎬 Opening animated modal from home header action");
              AppNavigation.navigateTo("home/animated_modal", 
                params: {
                  "title": "Animated Modal",
                  "message": "This is an animated modal screen"
                },
                fromScreen: "home"
              );
            }
          },
          onAppear: (data) {
            print("✅ Home route appeared: $data");
            activeScreenTracker.setState("home");
          },
          builder: () => HomeScreen(), // Always render home
        ),

        // 👤 PROFILE SCREEN - Suspended until needed
        DCFScreen(
          route: "profile",
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
          routeNavigationCommand: _shouldHandleCommand("profile", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Profile navigation event: $data");
            _handleNavigationEvents("profile", data);
            AppNavigation.clearCommand();
          },
          onHeaderActionPress: (data) {
            if (data['actionId'] == "settings_action") {
              AppNavigation.navigateTo("profile/settings", fromScreen: "profile");
            }
          },
          onAppear: (data) {
            print("✅ Profile route appeared: $data");
            activeScreenTracker.setState("profile");
          },
          builder: () => DCFSuspense(
            shouldRender: _shouldRenderScreen("profile"),
            debugName: "Profile",
            children: () => ProfileScreen(),
            fallback: () => _createPlaceholder("Profile Loading..."),
          ),
        ),

        // ⚙️ SETTINGS SCREEN - Suspended until needed
        DCFScreen(
          route: "profile/settings",
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
          routeNavigationCommand: _shouldHandleCommand("profile/settings", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Settings navigation event: $data");
            _handleNavigationEvents("profile/settings", data);
            AppNavigation.clearCommand();
          },
          onHeaderActionPress: (data) {
            print("🎯 Settings header action pressed: $data");
            if (data['title'] == "Cancel") {
              AppNavigation.goBack(fromScreen: "profile/settings");
            } else if (data['title'] == "Done") {
              AppNavigation.goBack(fromScreen: "profile/settings");
            }
          },
          onAppear: (data) {
            print("✅ Settings route appeared: $data");
            activeScreenTracker.setState("profile/settings");
          },
          builder: () => DCFSuspense(
            shouldRender: _shouldRenderScreen("profile/settings"),
            debugName: "Settings",
            children: () => SettingsScreen(),
            fallback: () => _createPlaceholder("Settings Loading..."),
          ),
        ),

        // 🎬 ANIMATED MODAL SCREEN - Suspended until needed (CRITICAL!)
        DCFScreen(
          route: "home/animated_modal",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Animated Modal",
            backButtonTitle: "Home",
          ),
          routeNavigationCommand: _shouldHandleCommand("home/animated_modal", globalNavTarget.state) 
              ? globalNavCommand.state 
              : null,
          onNavigationEvent: (data) {
            print("🚀 Animated modal navigation event: $data");
            _handleNavigationEvents("home/animated_modal", data);
            AppNavigation.clearCommand();
          },
          onAppear: (data) {
            print("✅ Animated modal appeared: $data");
            activeScreenTracker.setState("home/animated_modal");
          },
          onDisappear: (data) {
            print("❌ Animated modal disappeared: $data");
            // Don't clear active screen here - let the revealed screen set itself
          },
          builder: () => DCFSuspense(
            shouldRender: _shouldRenderScreen("home/animated_modal"),
            debugName: "AnimatedModal",
            children: () => AnimatedModalScreen(), // 🎯 THIS WON'T RUN UNTIL NEEDED!
            fallback: () => _createPlaceholder("Animation Loading..."),
          ),
        ),

        // 🎯 ALTERNATIVE: You can also use DCFLazySuspense for even cleaner syntax
        // DCFScreen(
        //   route: "home/animated_modal",
        //   // ... other config ...
        //   builder: () => DCFLazySuspense(
        //     routeName: "home/animated_modal",
        //     activeScreenStore: activeScreenTracker,
        //     children: () => AnimatedModalScreen(),
        //     fallback: () => _createPlaceholder("Animation Loading..."),
        //   ),
        // ),
      ],
    );
  }

  // 🎯 SCREEN ACTIVATION LOGIC
  bool _shouldRenderScreen(String route) {
    final activeScreen = activeScreenTracker.state;
    final navStack = navigationStackTracker.state;
    
    // Always render if it's the current active screen
    if (activeScreen == route) return true;
    
    // Always render if it's in the navigation stack (for smooth back navigation)
    if (navStack.contains(route)) return true;
    
    // Always render home (it's the root)
    if (route == "home") return true;
    
    return false;
  }

  // 🎯 NAVIGATION EVENT HANDLING
  void _handleNavigationEvents(String screenRoute, Map<dynamic, dynamic> data) {
    final action = data['action'] as String?;
    final targetRoute = data['targetRoute'] as String?;
    
    print("🔍 Navigation event for $screenRoute: action=$action, target=$targetRoute");
    
    // Update active screen and navigation stack based on events
    switch (action) {
      case 'pop':
        if (targetRoute == screenRoute) {
          activeScreenTracker.setState(screenRoute);
          _updateNavStack(targetRoute);
        }
        break;
      case 'popTo':
        if (targetRoute == screenRoute) {
          activeScreenTracker.setState(screenRoute);
          _updateNavStack(targetRoute);
        }
        break;
      case 'popToRoot':
        if (screenRoute == "home") {
          activeScreenTracker.setState("home");
          navigationStackTracker.setState(["home"]);
        }
        break;
    }
  }

  // 🎯 NAVIGATION STACK MANAGEMENT
  void _updateNavStack(String? targetRoute) {
    if (targetRoute == null) return;
    
    final currentStack = List<String>.from(navigationStackTracker.state);
    
    // Simple stack management - you can make this more sophisticated
    if (!currentStack.contains(targetRoute)) {
      currentStack.add(targetRoute);
    }
    
    navigationStackTracker.setState(currentStack);
  }

  // 🎯 PLACEHOLDER COMPONENT
  DCFComponentNode _createPlaceholder(String message) {
    return DCFView(
      layout: LayoutProps(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        padding: 20,
      ),
      children: [
        DCFText(
          content: message,
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.grey,
            textAlign: "center",
          ),
        ),
      ],
    );
  }

  // 🎯 HELPER: Determine if this screen should handle the global navigation command
  bool _shouldHandleCommand(String screenRoute, String? targetRoute) {
    if (targetRoute == null) return true;
    return screenRoute == targetRoute;
  }
}