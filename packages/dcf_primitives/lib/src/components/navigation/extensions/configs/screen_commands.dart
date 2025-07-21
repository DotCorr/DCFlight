// ============================================================================
// 🎯 NAVIGATION COMMANDS - Standard Architecture
// ============================================================================

/// Command to push a screen onto the navigation stack
class PushToCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;

  const PushToCommand({
    required this.screenName,
    this.animated = true,
    this.params,
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
      if (params != null) 'params': params,
    };
  }
}

/// Command to pop current screen from navigation stack
class PopCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const PopCommand({
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

/// Command to pop to a specific screen in the stack
class PopToCommand {
  final String screenName;
  final bool animated;

  const PopToCommand({
    required this.screenName,
    this.animated = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
    };
  }
}

/// Command to pop to root screen
class PopToRootCommand {
  final bool animated;

  const PopToRootCommand({this.animated = true});

  Map<String, dynamic> toMap() {
    return {
      'animated': animated,
    };
  }
}

/// Command to replace current screen with another
class ReplaceWithCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;

  const ReplaceWithCommand({
    required this.screenName,
    this.animated = true,
    this.params,
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
      if (params != null) 'params': params,
    };
  }
}

/// Command to present screen modally
class PresentModalCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;
  final String? presentationStyle;

  const PresentModalCommand({
    required this.screenName,
    this.animated = true,
    this.params,
    this.presentationStyle,
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
      if (params != null) 'params': params,
      if (presentationStyle != null) 'presentationStyle': presentationStyle,
    };
  }
}

/// Command to dismiss current modal
class DismissModalCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const DismissModalCommand({
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

/// Command to present screen as popover
class PresentPopoverCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;
  final String? sourceViewId;

  const PresentPopoverCommand({
    required this.screenName,
    this.animated = true,
    this.params,
    this.sourceViewId,
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
      if (params != null) 'params': params,
      if (sourceViewId != null) 'sourceViewId': sourceViewId,
    };
  }
}

/// Command to dismiss current popover
class DismissPopoverCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const DismissPopoverCommand({
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

/// Command to present screen as overlay
class PresentOverlayCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;

  const PresentOverlayCommand({
    required this.screenName,
    this.animated = true,
    this.params,
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
      if (params != null) 'params': params,
    };
  }
}

/// Command to dismiss current overlay
class DismissOverlayCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const DismissOverlayCommand({
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

class PresentDrawerCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;
  final String? direction; // "left", "right", "top", "bottom"

  const PresentDrawerCommand({
    required this.screenName,
    this.animated = true,
    this.params,
    this.direction = "left",
  });

  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'animated': animated,
      if (params != null) 'params': params,
      if (direction != null) 'direction': direction,
    };
  }
}

/// Command to dismiss current drawer
class DismissDrawerCommand {
  final bool animated;
  final Map<String, dynamic>? result;

  const DismissDrawerCommand({
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

/// Composite command class for all screen navigation actions
class ScreenNavigationCommand {
  final PushToCommand? pushTo;
  final PopCommand? pop;
  final PopToCommand? popTo;
  final PopToRootCommand? popToRoot;
  final ReplaceWithCommand? replaceWith;
  final PresentModalCommand? presentModal;
  final DismissModalCommand? dismissModal;
  final PresentPopoverCommand? presentPopover;
  final DismissPopoverCommand? dismissPopover;
  final PresentOverlayCommand? presentOverlay;
  final DismissOverlayCommand? dismissOverlay;
  // 🎯 NEW: Drawer navigation commands
  final PresentDrawerCommand? presentDrawer;
  final DismissDrawerCommand? dismissDrawer;

  const ScreenNavigationCommand({
    this.pushTo,
    this.pop,
    this.popTo,
    this.popToRoot,
    this.replaceWith,
    this.presentModal,
    this.dismissModal,
    this.presentPopover,
    this.dismissPopover,
    this.presentOverlay,
    this.dismissOverlay,
    this.presentDrawer, // 🎯 NEW
    this.dismissDrawer, // 🎯 NEW
  });

  /// Convert command to props map for native consumption
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> commandMap = {};

    if (pushTo != null) {
      commandMap['pushTo'] = pushTo!.toMap();
    }

    if (pop != null) {
      commandMap['pop'] = pop!.toMap();
    }

    if (popTo != null) {
      commandMap['popTo'] = popTo!.toMap();
    }

    if (popToRoot != null) {
      commandMap['popToRoot'] = popToRoot!.toMap();
    }

    if (replaceWith != null) {
      commandMap['replaceWith'] = replaceWith!.toMap();
    }

    if (presentModal != null) {
      commandMap['presentModal'] = presentModal!.toMap();
    }

    if (dismissModal != null) {
      commandMap['dismissModal'] = dismissModal!.toMap();
    }

    if (presentPopover != null) {
      commandMap['presentPopover'] = presentPopover!.toMap();
    }

    if (dismissPopover != null) {
      commandMap['dismissPopover'] = dismissPopover!.toMap();
    }

    if (presentOverlay != null) {
      commandMap['presentOverlay'] = presentOverlay!.toMap();
    }

    if (dismissOverlay != null) {
      commandMap['dismissOverlay'] = dismissOverlay!.toMap();
    }

    // 🎯 NEW: Add drawer commands
    if (presentDrawer != null) {
      commandMap['presentDrawer'] = presentDrawer!.toMap();
    }

    if (dismissDrawer != null) {
      commandMap['dismissDrawer'] = dismissDrawer!.toMap();
    }

    return commandMap;
  }

  /// Check if this command has any actions to execute
  bool get hasCommands {
    return pushTo != null ||
        pop != null ||
        popTo != null ||
        popToRoot != null ||
        replaceWith != null ||
        presentModal != null ||
        dismissModal != null ||
        presentPopover != null ||
        dismissPopover != null ||
        presentOverlay != null ||
        dismissOverlay != null ||
        presentDrawer != null ||
        dismissDrawer != null;
  }
}

// ============================================================================
// 🎯 NAVIGATION PRESETS - Clean API as Default
// ============================================================================

/// Navigation presets for common operations - USE THESE AS DEFAULT
class NavigationPresets {
  // PUSH NAVIGATION

  /// Push to a screen
  static ScreenNavigationCommand pushTo(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          pushTo: PushToCommand(screenName: screenName, params: params));

  /// Push to a screen without animation
  static ScreenNavigationCommand pushToInstant(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          pushTo: PushToCommand(
              screenName: screenName, animated: false, params: params));

  // POP NAVIGATION

  /// Pop current screen
  static const ScreenNavigationCommand pop =
      ScreenNavigationCommand(pop: PopCommand());

  /// Pop current screen without animation
  static const ScreenNavigationCommand popInstant =
      ScreenNavigationCommand(pop: PopCommand(animated: false));

  /// Pop to specific screen
  static ScreenNavigationCommand popTo(String screenName) =>
      ScreenNavigationCommand(popTo: PopToCommand(screenName: screenName));

  /// Pop to root
  static const ScreenNavigationCommand popToRoot =
      ScreenNavigationCommand(popToRoot: PopToRootCommand());

  /// Replace current screen
  static ScreenNavigationCommand replaceWith(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          replaceWith:
              ReplaceWithCommand(screenName: screenName, params: params));

  // MODAL NAVIGATION

  /// Present modal
  static ScreenNavigationCommand presentModal(String screenName,
          {Map<String, dynamic>? params, String? style}) =>
      ScreenNavigationCommand(
          presentModal: PresentModalCommand(
              screenName: screenName,
              params: params,
              presentationStyle: style));

  /// Present full screen modal
  static ScreenNavigationCommand presentFullScreenModal(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentModal: PresentModalCommand(
              screenName: screenName,
              params: params,
              presentationStyle: "fullScreen"));

  /// Present page sheet modal
  static ScreenNavigationCommand presentPageSheetModal(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentModal: PresentModalCommand(
              screenName: screenName,
              params: params,
              presentationStyle: "pageSheet"));

  /// Dismiss modal
  static const ScreenNavigationCommand dismissModal =
      ScreenNavigationCommand(dismissModal: DismissModalCommand());

  /// Dismiss modal with result
  static ScreenNavigationCommand dismissModalWithResult(
          Map<String, dynamic> result) =>
      ScreenNavigationCommand(
          dismissModal: DismissModalCommand(result: result));

  // POPOVER NAVIGATION

  /// Present popover
  static ScreenNavigationCommand presentPopover(String screenName,
          {Map<String, dynamic>? params, String? sourceViewId}) =>
      ScreenNavigationCommand(
          presentPopover: PresentPopoverCommand(
              screenName: screenName,
              params: params,
              sourceViewId: sourceViewId));

  /// Dismiss popover
  static const ScreenNavigationCommand dismissPopover =
      ScreenNavigationCommand(dismissPopover: DismissPopoverCommand());

  // OVERLAY NAVIGATION

  /// Present overlay
  static ScreenNavigationCommand presentOverlay(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentOverlay:
              PresentOverlayCommand(screenName: screenName, params: params));

  /// Dismiss overlay
  static const ScreenNavigationCommand dismissOverlay =
      ScreenNavigationCommand(dismissOverlay: DismissOverlayCommand());

  /// Dismiss overlay with result
  static ScreenNavigationCommand dismissOverlayWithResult(
          Map<String, dynamic> result) =>
      ScreenNavigationCommand(
          dismissOverlay: DismissOverlayCommand(result: result));

  // 🎯 NEW: DRAWER NAVIGATION

  /// Present drawer from left side
  static ScreenNavigationCommand presentDrawer(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentDrawer: PresentDrawerCommand(
              screenName: screenName, params: params, direction: "left"));

  /// Present drawer from right side
  static ScreenNavigationCommand presentRightDrawer(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentDrawer: PresentDrawerCommand(
              screenName: screenName, params: params, direction: "right"));

  /// Present drawer from top
  static ScreenNavigationCommand presentTopDrawer(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentDrawer: PresentDrawerCommand(
              screenName: screenName, params: params, direction: "top"));

  /// Present drawer from bottom
  static ScreenNavigationCommand presentBottomDrawer(String screenName,
          {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(
          presentDrawer: PresentDrawerCommand(
              screenName: screenName, params: params, direction: "bottom"));

  /// Dismiss drawer
  static const ScreenNavigationCommand dismissDrawer =
      ScreenNavigationCommand(dismissDrawer: DismissDrawerCommand());

  /// Dismiss drawer with result
  static ScreenNavigationCommand dismissDrawerWithResult(
          Map<String, dynamic> result) =>
      ScreenNavigationCommand(
          dismissDrawer: DismissDrawerCommand(result: result));
}
