import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/framework/renderer/engine/component/hooks/store.dart';


final globalNavigationCommand = Store<RouteNavigationCommand?>(null);

final globalNavigationTarget = Store<String?>(null);

class AppNavigation {
  // ============================================================================
  // 🎯 ROUTE NAVIGATION
  // ============================================================================
  
  /// Navigate to a route from a specific screen
  static void navigateTo(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.navigateToRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  /// Navigate to a route without animation
  static void navigateToInstant(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.navigateToRouteInstant(route, params: params),
      fromScreen: fromScreen
    );
  }

  // ============================================================================
  // 🎯 POP NAVIGATION
  // ============================================================================
  
  /// Pop current route
  static void goBack({String? fromScreen}) {
    _executeGlobalCommand(RouteNavigation.pop, fromScreen: fromScreen);
  }
  
  /// Pop current route without animation
  static void goBackInstant({String? fromScreen}) {
    _executeGlobalCommand(RouteNavigation.popInstant, fromScreen: fromScreen);
  }
  
  /// Pop current route with result data
  static void goBackWithResult(Map<String, dynamic> result, {String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigationCommand(pop: PopRouteCommand(result: result)),
      fromScreen: fromScreen
    );
  }
  
  /// Pop to a specific route in the stack
  static void popToRoute(String route, {String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.popToRoute(route),
      fromScreen: fromScreen
    );
  }
  
  /// Pop to root route
  static void goToRoot({String? fromScreen}) {
    _executeGlobalCommand(RouteNavigation.popToRoot, fromScreen: fromScreen);
  }
  
  /// Pop to root route without animation
  static void goToRootInstant({String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigationCommand(popToRoot: PopToRootRouteCommand(animated: false)),
      fromScreen: fromScreen
    );
  }

  // ============================================================================
  // 🎯 REPLACE NAVIGATION
  // ============================================================================
  
  /// Replace current route with another
  static void replace(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.replaceWithRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  /// Replace current route without animation
  static void replaceInstant(String route, {Map<String, dynamic>? params, String? fromScreen}) {
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
  
  /// Present modal route (default style)
  static void presentModal(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.presentModalRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  /// Present full screen modal
  static void presentFullScreenModal(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.presentFullScreenModalRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  /// Present page sheet modal
  static void presentPageSheetModal(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.presentPageSheetModalRoute(route, params: params),
      fromScreen: fromScreen
    );
  }
  
  /// Present modal with custom style
  static void presentModalWithStyle(
    String route, 
    String style, 
    {Map<String, dynamic>? params, String? fromScreen}
  ) {
    _executeGlobalCommand(
      RouteNavigation.presentModalRoute(route, params: params, style: style),
      fromScreen: fromScreen
    );
  }
  
  /// Present modal without animation
  static void presentModalInstant(String route, {Map<String, dynamic>? params, String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigationCommand(
        presentModalRoute: PresentModalRouteCommand(
          route: route,
          animated: false,
          params: params
        )
      ),
      fromScreen: fromScreen
    );
  }
  
  /// Dismiss current modal
  static void dismissModal({String? fromScreen}) {
    _executeGlobalCommand(RouteNavigation.dismissModal, fromScreen: fromScreen);
  }
  
  /// Dismiss modal with result
  static void dismissModalWithResult(Map<String, dynamic> result, {String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigation.dismissModalWithResult(result),
      fromScreen: fromScreen
    );
  }
  
  /// Dismiss modal without animation
  static void dismissModalInstant({String? fromScreen}) {
    _executeGlobalCommand(
      RouteNavigationCommand(dismissModal: DismissModalRouteCommand(animated: false)),
      fromScreen: fromScreen
    );
  }

  // ============================================================================
  // 🎯 UTILITY METHODS
  // ============================================================================
  
  /// Clear navigation command (call after navigation completes)
  static void clearCommand() {
    globalNavigationCommand.setState(null);
    globalNavigationTarget.setState(null);
  }
  
  /// Check if there's a pending navigation command
  static bool hasPendingCommand() {
    return globalNavigationCommand.state != null;
  }
  
  /// Get current navigation command
  static RouteNavigationCommand? getCurrentCommand() {
    return globalNavigationCommand.state;
  }
  
  /// Get current navigation target
  static String? getCurrentTarget() {
    return globalNavigationTarget.state;
  }

  // ============================================================================
  // 🎯 CONVENIENCE METHODS
  // ============================================================================
  
  /// Navigate with custom RouteNavigationCommand
  static void executeCommand(RouteNavigationCommand command, {String? fromScreen}) {
    _executeGlobalCommand(command, fromScreen: fromScreen);
  }
  
  /// Batch multiple navigation commands (execute one after another)
  static void executeSequence(List<RouteNavigationCommand> commands, {String? fromScreen}) {
    if (commands.isEmpty) return;
    
    // Execute first command immediately
    _executeGlobalCommand(commands.first, fromScreen: fromScreen);
    
    // Schedule remaining commands with delays
    for (int i = 1; i < commands.length; i++) {
      Future.delayed(Duration(milliseconds: 300 * i), () {
        _executeGlobalCommand(commands[i], fromScreen: fromScreen);
      });
    }
  }

  // ============================================================================
  // 🎯 PRIVATE HELPER
  // ============================================================================
  
  /// Execute a global command with optional targeting
  static void _executeGlobalCommand(RouteNavigationCommand command, {String? fromScreen}) {
    // Set the target screen if specified
    if (fromScreen != null) {
      globalNavigationTarget.setState(fromScreen);
    } else {
      globalNavigationTarget.setState(null); // Let any screen handle it
    }
    
    // Set the command
    globalNavigationCommand.setState(command);
    
    print("🧭 GLOBAL NAV: ${command.toMap()} ${fromScreen != null ? 'from $fromScreen' : 'from any screen'}");
  }
}