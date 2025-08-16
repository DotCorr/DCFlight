// ============================================================================
// 🎯 ROUTE NAVIGATION COMMANDS - Clean Route Architecture
// ============================================================================

/// Command to navigate to a route
class NavigateToRouteCommand {
  final String route;
  final bool animated;
  final Map<String, dynamic>? params;

  const NavigateToRouteCommand({
    required this.route,
    this.animated = true,
    this.params,
  });

  Map<String, dynamic> toMap() {
    return {
      'route': route,
      'animated': animated,
      if (params != null) 'params': params,
    };
  }
}

/// Command to pop current route from navigation stack
class PopRouteCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const PopRouteCommand({
    this.animated = true,
    this.result,
  });

  Map<String, dynamic> toMap() {
    return {
      'animated': animated,
      if (result != null) 'result': result,
    };
  }
}

/// Command to pop to a specific route in the stack
class PopToRouteCommand {
  final String route;
  final bool animated;

  const PopToRouteCommand({
    required this.route,
    this.animated = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'route': route,
      'animated': animated,
    };
  }
}

/// Command to pop to root route
class PopToRootRouteCommand {
  final bool animated;

  const PopToRootRouteCommand({this.animated = true});

  Map<String, dynamic> toMap() {
    return {
      'animated': animated,
    };
  }
}

/// Command to replace current route with another
class ReplaceWithRouteCommand {
  final String route;
  final bool animated;
  final Map<String, dynamic>? params;

  const ReplaceWithRouteCommand({
    required this.route,
    this.animated = true,
    this.params,
  });

  Map<String, dynamic> toMap() {
    return {
      'route': route,
      'animated': animated,
      if (params != null) 'params': params,
    };
  }
}

/// Command to present route modally
class PresentModalRouteCommand {
  final String route;
  final bool animated;
  final Map<String, dynamic>? params;
  final String? presentationStyle;

  const PresentModalRouteCommand({
    required this.route,
    this.animated = true,
    this.params,
    this.presentationStyle,
  });

  Map<String, dynamic> toMap() {
    return {
      'route': route,
      'animated': animated,
      if (params != null) 'params': params,
      if (presentationStyle != null) 'presentationStyle': presentationStyle,
    };
  }
}

/// Command to dismiss current modal
class DismissModalRouteCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const DismissModalRouteCommand({
    this.animated = true,
    this.result,
  });

  Map<String, dynamic> toMap() {
    return {
      'animated': animated,
      if (result != null) 'result': result,
    };
  }
}

/// Composite command class for all route navigation actions
class RouteNavigationCommand {
  final NavigateToRouteCommand? navigateToRoute;
  final PopRouteCommand? pop;
  final PopToRouteCommand? popToRoute;
  final PopToRootRouteCommand? popToRoot;
  final ReplaceWithRouteCommand? replaceWithRoute;
  final PresentModalRouteCommand? presentModalRoute;
  final DismissModalRouteCommand? dismissModal;

  const RouteNavigationCommand({
    this.navigateToRoute,
    this.pop,
    this.popToRoute,
    this.popToRoot,
    this.replaceWithRoute,
    this.presentModalRoute,
    this.dismissModal,
  });

  /// Convert command to props map for native consumption
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> commandMap = {};

    if (navigateToRoute != null) {
      commandMap['navigateToRoute'] = navigateToRoute!.route;
      commandMap['animated'] = navigateToRoute!.animated;
      if (navigateToRoute!.params != null) {
        commandMap['params'] = navigateToRoute!.params;
      }
    }

    if (pop != null) {
      commandMap['pop'] = pop!.toMap();
    }

    if (popToRoute != null) {
      commandMap['popToRoute'] = popToRoute!.route;
      commandMap['animated'] = popToRoute!.animated;
    }

    if (popToRoot != null) {
      commandMap['popToRoot'] = popToRoot!.toMap();
    }

    if (replaceWithRoute != null) {
      commandMap['replaceWithRoute'] = replaceWithRoute!.toMap();
    }

    if (presentModalRoute != null) {
      commandMap['presentModalRoute'] = presentModalRoute!.toMap();
    }

    if (dismissModal != null) {
      commandMap['dismissModal'] = dismissModal!.toMap();
    }

    return commandMap;
  }

  /// Check if this command has any actions to execute
  bool get hasCommands {
    return navigateToRoute != null ||
        pop != null ||
        popToRoute != null ||
        popToRoot != null ||
        replaceWithRoute != null ||
        presentModalRoute != null ||
        dismissModal != null;
  }
}

// ============================================================================
// 🎯 ROUTE NAVIGATION PRESETS - Clean API
// ============================================================================

/// Route navigation presets for common operations
class RouteNavigation {
  // ROUTE NAVIGATION

  /// Navigate to a route
  static RouteNavigationCommand navigateToRoute(String route,
          {Map<String, dynamic>? params}) =>
      RouteNavigationCommand(
          navigateToRoute: NavigateToRouteCommand(route: route, params: params));

  /// Navigate to a route without animation
  static RouteNavigationCommand navigateToRouteInstant(String route,
          {Map<String, dynamic>? params}) =>
      RouteNavigationCommand(
          navigateToRoute: NavigateToRouteCommand(
              route: route, animated: false, params: params));

  // POP NAVIGATION

  /// Pop current route
  static const RouteNavigationCommand pop =
      RouteNavigationCommand(pop: PopRouteCommand());

  /// Pop current route without animation
  static const RouteNavigationCommand popInstant =
      RouteNavigationCommand(pop: PopRouteCommand(animated: false));

  /// Pop to specific route
  static RouteNavigationCommand popToRoute(String route) =>
      RouteNavigationCommand(popToRoute: PopToRouteCommand(route: route));

  /// Pop to root
  static const RouteNavigationCommand popToRoot =
      RouteNavigationCommand(popToRoot: PopToRootRouteCommand());

  /// Replace current route
  static RouteNavigationCommand replaceWithRoute(String route,
          {Map<String, dynamic>? params}) =>
      RouteNavigationCommand(
          replaceWithRoute:
              ReplaceWithRouteCommand(route: route, params: params));

  // MODAL NAVIGATION

  /// Present modal route
  static RouteNavigationCommand presentModalRoute(String route,
          {Map<String, dynamic>? params, String? style}) =>
      RouteNavigationCommand(
          presentModalRoute: PresentModalRouteCommand(
              route: route,
              params: params,
              presentationStyle: style));

  /// Present full screen modal route
  static RouteNavigationCommand presentFullScreenModalRoute(String route,
          {Map<String, dynamic>? params}) =>
      RouteNavigationCommand(
          presentModalRoute: PresentModalRouteCommand(
              route: route,
              params: params,
              presentationStyle: "fullScreen"));

  /// Present page sheet modal route
  static RouteNavigationCommand presentPageSheetModalRoute(String route,
          {Map<String, dynamic>? params}) =>
      RouteNavigationCommand(
          presentModalRoute: PresentModalRouteCommand(
              route: route,
              params: params,
              presentationStyle: "pageSheet"));

  /// Dismiss modal
  static const RouteNavigationCommand dismissModal =
      RouteNavigationCommand(dismissModal: DismissModalRouteCommand());

  /// Dismiss modal with result
  static RouteNavigationCommand dismissModalWithResult(
          Map<String, dynamic> result) =>
      RouteNavigationCommand(
          dismissModal: DismissModalRouteCommand(result: result));
}