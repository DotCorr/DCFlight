/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Commands for screen-level navigation operations
/// These commands can be used from any screen to navigate to other screens

/// Command to push a screen onto the navigation stack
class PushToScreenCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params; // Optional parameters to pass
  
  const PushToScreenCommand({
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
class PopScreenCommand {
  final bool animated;
  final Map<String, dynamic>? result; // Optional result to pass back
  
  const PopScreenCommand({
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
class PopToScreenCommand {
  final String screenName;
  final bool animated;
  
  const PopToScreenCommand({
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
class ReplaceWithScreenCommand {
  final String screenName;
  final bool animated;
  final Map<String, dynamic>? params;
  
  const ReplaceWithScreenCommand({
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
  final String? presentationStyle; // "fullScreen", "pageSheet", etc.
  
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

/// Composite command class for all screen navigation actions
class ScreenNavigationCommand {
  final PushToScreenCommand? pushTo;
  final PopScreenCommand? pop;
  final PopToScreenCommand? popTo;
  final PopToRootCommand? popToRoot;
  final ReplaceWithScreenCommand? replaceWith;
  final PresentModalCommand? presentModal;
  final DismissModalCommand? dismissModal;
  
  const ScreenNavigationCommand({
    this.pushTo,
    this.pop,
    this.popTo,
    this.popToRoot,
    this.replaceWith,
    this.presentModal,
    this.dismissModal,
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
           dismissModal != null;
  }
}

/// Navigation presets for common operations
class NavigationPresets {
  /// Push to a screen
  static ScreenNavigationCommand pushTo(String screenName, {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(pushTo: PushToScreenCommand(screenName: screenName, params: params));
  
  /// Pop current screen
  static const ScreenNavigationCommand pop = ScreenNavigationCommand(pop: PopScreenCommand());
  
  /// Pop to specific screen
  static ScreenNavigationCommand popTo(String screenName) =>
      ScreenNavigationCommand(popTo: PopToScreenCommand(screenName: screenName));
  
  /// Pop to root
  static const ScreenNavigationCommand popToRoot = ScreenNavigationCommand(popToRoot: PopToRootCommand());
  
  /// Replace current screen
  static ScreenNavigationCommand replaceWith(String screenName, {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(replaceWith: ReplaceWithScreenCommand(screenName: screenName, params: params));
  
  /// Present modal
  static ScreenNavigationCommand presentModal(String screenName, {Map<String, dynamic>? params, String? style}) =>
      ScreenNavigationCommand(presentModal: PresentModalCommand(screenName: screenName, params: params, presentationStyle: style));
  
  /// Dismiss modal
  static const ScreenNavigationCommand dismissModal = ScreenNavigationCommand(dismissModal: DismissModalCommand());
  
  /// Push without animation
  static ScreenNavigationCommand pushToInstant(String screenName, {Map<String, dynamic>? params}) =>
      ScreenNavigationCommand(pushTo: PushToScreenCommand(screenName: screenName, animated: false, params: params));
  
  /// Pop without animation
  static const ScreenNavigationCommand popInstant = ScreenNavigationCommand(pop: PopScreenCommand(animated: false));
}