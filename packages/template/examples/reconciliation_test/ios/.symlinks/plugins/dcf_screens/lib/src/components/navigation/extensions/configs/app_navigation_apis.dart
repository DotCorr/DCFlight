import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/framework/renderer/engine/component/hooks/store.dart';


final globalNavigationCommand = Store<RouteNavigationCommand?>(null);

final globalNavigationTarget = Store<String?>(null);
// 🎯 SUSPENSE TRACKING STORES
final activeScreenTracker = Store<String?>("home"); // Start with home active
final navigationStackTracker = Store<List<String>>(["home"]); // Start with home in stack

class AppNavigation {
  // ============================================================================
  // 🎯 ROUTE NAVIGATION WITH SUSPENSE AWARENESS
  // ============================================================================
  
  static void navigateTo(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    // Update suspense state immediately for UI responsiveness
    activeScreenTracker.setState(route);
    _updateNavigationStack(route);
    
    _executeGlobalCommand(
      RouteNavigation.navigateToRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  static void navigateToInstant(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    activeScreenTracker.setState(route);
    _updateNavigationStack(route);
    
    _executeGlobalCommand(
      RouteNavigation.navigateToRouteInstant(route, params: params),
      fromScreen: fromScreen
    );
  }

  // ============================================================================
  // 🎯 POP NAVIGATION WITH SUSPENSE AWARENESS
  // ============================================================================
  
  static void goBack({String? fromScreen}) {
    // Predict which screen will be revealed
    final currentStack = List<String>.from(navigationStackTracker.state);
    if (currentStack.length > 1) {
      currentStack.removeLast();
      final revealedScreen = currentStack.last;
      activeScreenTracker.setState(revealedScreen);
      navigationStackTracker.setState(currentStack);
    }
    
    _executeGlobalCommand(RouteNavigation.pop, fromScreen: fromScreen);
  }
  
  static void goBackInstant({String? fromScreen}) {
    final currentStack = List<String>.from(navigationStackTracker.state);
    if (currentStack.length > 1) {
      currentStack.removeLast();
      final revealedScreen = currentStack.last;
      activeScreenTracker.setState(revealedScreen);
      navigationStackTracker.setState(currentStack);
    }
    
    _executeGlobalCommand(RouteNavigation.popInstant, fromScreen: fromScreen);
  }
  
  static void goBackWithResult(Map<String, dynamic> result, {String? fromScreen}) {
    final currentStack = List<String>.from(navigationStackTracker.state);
    if (currentStack.length > 1) {
      currentStack.removeLast();
      final revealedScreen = currentStack.last;
      activeScreenTracker.setState(revealedScreen);
      navigationStackTracker.setState(currentStack);
    }
    
    _executeGlobalCommand(
      RouteNavigationCommand(pop: PopRouteCommand(result: result)),
      fromScreen: fromScreen
    );
  }
  
  static void popToRoute(String route, {String? fromScreen}) {
    activeScreenTracker.setState(route);
    _popStackToRoute(route);
    
    _executeGlobalCommand(
      RouteNavigation.popToRoute(route),
      fromScreen: fromScreen
    );
  }
  
  static void goToRoot({String? fromScreen}) {
    activeScreenTracker.setState("home");
    navigationStackTracker.setState(["home"]);
    
    _executeGlobalCommand(RouteNavigation.popToRoot, fromScreen: fromScreen);
  }
  
  static void goToRootInstant({String? fromScreen}) {
    activeScreenTracker.setState("home");
    navigationStackTracker.setState(["home"]);
    
    _executeGlobalCommand(
      RouteNavigationCommand(popToRoot: PopToRootRouteCommand(animated: false)),
      fromScreen: fromScreen
    );
  }

  // ============================================================================
  // 🎯 REPLACE NAVIGATION
  // ============================================================================
  
  static void replace(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    activeScreenTracker.setState(route);
    _replaceTopOfStack(route);
    
    _executeGlobalCommand(
      RouteNavigation.replaceWithRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  static void replaceInstant(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    activeScreenTracker.setState(route);
    _replaceTopOfStack(route);
    
    _executeGlobalCommand(
      RouteNavigationCommand(
        replaceWithRoute: ReplaceWithRouteCommand(
          route: route, 
          animated: false, 
          params: params
        )
      ),
      fromScreen: fromScreen
    );
  }

  // ============================================================================
  // 🎯 MODAL NAVIGATION
  // ============================================================================
  
  static void presentModal(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    activeScreenTracker.setState(route);
    _updateNavigationStack(route);
    
    _executeGlobalCommand(
      RouteNavigation.presentModalRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  static void dismissModal({String? fromScreen}) {
    final currentStack = List<String>.from(navigationStackTracker.state);
    if (currentStack.length > 1) {
      currentStack.removeLast();
      final revealedScreen = currentStack.last;
      activeScreenTracker.setState(revealedScreen);
      navigationStackTracker.setState(currentStack);
    }
    
    _executeGlobalCommand(RouteNavigation.dismissModal, fromScreen: fromScreen);
  }

  // ============================================================================
  // 🎯 UTILITY METHODS
  // ============================================================================
  
  static void clearCommand() {
    globalNavigationCommand.setState(null);
    globalNavigationTarget.setState(null);
  }
  
  static bool hasPendingCommand() {
    return globalNavigationCommand.state != null;
  }
  
  static RouteNavigationCommand? getCurrentCommand() {
    return globalNavigationCommand.state;
  }
  
  static String? getCurrentTarget() {
    return globalNavigationTarget.state;
  }

  // ============================================================================
  // 🎯 SUSPENSE STATE HELPERS
  // ============================================================================
  
  /// Get the currently active screen for suspense logic
  static String? getActiveScreen() {
    return activeScreenTracker.state;
  }
  
  /// Get the current navigation stack for suspense logic
  static List<String> getNavigationStack() {
    return List<String>.from(navigationStackTracker.state);
  }
  
  /// Check if a screen should be rendered (for suspense logic)
  static bool shouldRenderScreen(String route) {
    final activeScreen = activeScreenTracker.state;
    final navStack = navigationStackTracker.state;
    
    // Always render current active screen
    if (activeScreen == route) return true;
    
    // Always render screens in navigation stack
    if (navStack.contains(route)) return true;
    
    // Always render home
    if (route == "home") return true;
    
    return false;
  }
  
  /// Reset suspense state (for debugging)
  static void resetSuspenseState() {
    activeScreenTracker.setState("home");
    navigationStackTracker.setState(["home"]);
    clearCommand();
    print("🔄 Suspense state reset to home");
  }

  // ============================================================================
  // 🎯 PRIVATE HELPERS
  // ============================================================================
  
  static void _updateNavigationStack(String route) {
    final currentStack = List<String>.from(navigationStackTracker.state);
    
    // Handle nested routes properly
    if (route.contains("/")) {
      final routeParts = route.split("/");
      final parentRoute = routeParts[0];
      
      // Add parent if not already in stack
      if (!currentStack.contains(parentRoute)) {
        currentStack.add(parentRoute);
      }
    }
    
    // Add the route if not already in stack
    if (!currentStack.contains(route)) {
      currentStack.add(route);
    }
    
    navigationStackTracker.setState(currentStack);
    print("📚 Navigation stack updated: $currentStack");
  }
  
  static void _popStackToRoute(String route) {
    final currentStack = List<String>.from(navigationStackTracker.state);
    final targetIndex = currentStack.lastIndexOf(route);
    
    if (targetIndex != -1) {
      final newStack = currentStack.sublist(0, targetIndex + 1);
      navigationStackTracker.setState(newStack);
    }
  }
  
  static void _replaceTopOfStack(String route) {
    final currentStack = List<String>.from(navigationStackTracker.state);
    if (currentStack.isNotEmpty) {
      currentStack[currentStack.length - 1] = route;
      navigationStackTracker.setState(currentStack);
    }
  }
  
  static void _executeGlobalCommand(RouteNavigationCommand command, {String? fromScreen}) {
    if (fromScreen != null) {
      globalNavigationTarget.setState(fromScreen);
    } else {
      globalNavigationTarget.setState(null);
    }
    
    globalNavigationCommand.setState(command);
    
    print("🧭 GLOBAL NAV: ${command.toMap()} ${fromScreen != null ? 'from $fromScreen' : 'from any screen'}");
  }
}