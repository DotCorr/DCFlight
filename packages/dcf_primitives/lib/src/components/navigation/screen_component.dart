/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';

/// Presentation styles for screens
enum DCFPresentationStyle {
  /// Tab presentation - screen appears as a tab in tab bar
  tab,

  /// Push presentation - screen appears pushed onto navigation stack
  push,

  /// Modal presentation - screen appears as a modal overlay
  modal,

  /// Sheet presentation - screen appears as a bottom sheet
  sheet,

  /// Popover presentation - screen appears as a popover (iPad)
  popover,

  /// Drawer presentation - screen appears as a side drawer
  drawer,

  /// Split view presentation - screen appears in split view
  splitView,
}

/// Configuration for tab presentation
class DCFTabConfig extends Equatable {
  /// Tab title
  final String title;

  /// Tab icon - can be String (SF Symbol) or Map (SVG config)
  final dynamic icon;

  /// Tab index in tab bar
  final int index;

  /// Tab badge text
  final String? badge;

  /// Whether tab is enabled
  final bool enabled;

  const DCFTabConfig({
    required this.title,
    required this.icon,
    required this.index,
    this.badge,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'icon': icon,
      'index': index,
      if (badge != null) 'badge': badge,
      'enabled': enabled,
    };
  }

  @override
  List<Object?> get props => [title, icon, index, badge, enabled];
}

/// Configuration for modal presentation
class DCFModalConfig extends Equatable {
  /// Modal detents (height sizes)
  final List<DCFModalDetent>? detents;

  /// Selected detent index
  final int? selectedDetentIndex;

  /// Whether to show drag indicator
  final bool showDragIndicator;

  /// Corner radius
  final double? cornerRadius;

  /// Whether modal is dismissible
  final bool isDismissible;

  /// Whether background tap dismisses modal
  final bool allowsBackgroundDismiss;

  /// Transition style
  final String? transitionStyle;

  const DCFModalConfig({
    this.detents,
    this.selectedDetentIndex,
    this.showDragIndicator = true,
    this.cornerRadius,
    this.isDismissible = true,
    this.allowsBackgroundDismiss = true,
    this.transitionStyle,
  });

  Map<String, dynamic> toMap() {
    return {
      if (detents != null) 'detents': detents,
      if (selectedDetentIndex != null)
        'selectedDetentIndex': selectedDetentIndex,
      'showDragIndicator': showDragIndicator,
      if (cornerRadius != null) 'cornerRadius': cornerRadius,
      'isDismissible': isDismissible,
      'allowsBackgroundDismiss': allowsBackgroundDismiss,
      if (transitionStyle != null) 'transitionStyle': transitionStyle,
    };
  }

  @override
  List<Object?> get props => [
        detents,
        selectedDetentIndex,
        showDragIndicator,
        cornerRadius,
        isDismissible,
        allowsBackgroundDismiss,
        transitionStyle,
      ];
}

/// Configuration for push presentation
class DCFPushConfig extends Equatable {
  /// Navigation bar title
  final String? title;

  /// Whether navigation bar is hidden
  final bool hideNavigationBar;

  /// Whether back button is hidden
  final bool hideBackButton;

  /// Custom back button title
  final String? backButtonTitle;

  /// Whether large titles are enabled
  final bool largeTitleDisplayMode;

  const DCFPushConfig({
    this.title,
    this.hideNavigationBar = false,
    this.hideBackButton = false,
    this.backButtonTitle,
    this.largeTitleDisplayMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      'hideNavigationBar': hideNavigationBar,
      'hideBackButton': hideBackButton,
      if (backButtonTitle != null) 'backButtonTitle': backButtonTitle,
      'largeTitleDisplayMode': largeTitleDisplayMode,
    };
  }

  @override
  List<Object?> get props => [
        title,
        hideNavigationBar,
        hideBackButton,
        backButtonTitle,
        largeTitleDisplayMode,
      ];
}

/// A screen component that provides navigation context and lifecycle
class DCFScreen extends StatelessComponent with EquatableMixin {
  /// Unique screen name/identifier
  final String name;

  /// How this screen should be presented
  final DCFPresentationStyle presentationStyle;

  /// Configuration for tab presentation
  final DCFTabConfig? tabConfig;

  /// Configuration for modal presentation
  final DCFModalConfig? modalConfig;

  /// Configuration for push presentation
  final DCFPushConfig? pushConfig;

  /// Screen content
  final List<DCFComponentNode> children;

  /// Style properties
  final StyleSheet styleSheet;

  /// Command for screen navigation operations
  final ScreenNavigationCommand? navigationCommand;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Called when screen appears
  final Function(Map<dynamic, dynamic>)? onAppear;

  /// Called when screen disappears
  final Function(Map<dynamic, dynamic>)? onDisappear;

  /// Called when screen is activated (becomes current)
  final Function(Map<dynamic, dynamic>)? onActivate;

  /// Called when screen is deactivated (no longer current)
  final Function(Map<dynamic, dynamic>)? onDeactivate;

  /// Called when navigation occurs from this screen
  final Function(Map<dynamic, dynamic>)? onNavigationEvent;

  /// Called when this screen receives parameters from navigation
  final Function(Map<dynamic, dynamic>)? onReceiveParams;

  DCFScreen({
    super.key,
    required this.name,
    required this.presentationStyle,
    this.tabConfig,
    this.modalConfig,
    this.pushConfig,
    this.children = const [],
    this.styleSheet = const StyleSheet(),
    this.navigationCommand,
    this.events,
    this.onAppear,
    this.onDisappear,
    this.onActivate,
    this.onDeactivate,
    this.onNavigationEvent,
    this.onReceiveParams,
  });

  @override
  DCFComponentNode render() {
    // Build event map
    Map<String, dynamic> eventMap = events ?? {};

    if (onAppear != null) {
      eventMap['onAppear'] = onAppear;
    }

    if (onDisappear != null) {
      eventMap['onDisappear'] = onDisappear;
    }

    if (onActivate != null) {
      eventMap['onActivate'] = onActivate;
    }

    if (onDeactivate != null) {
      eventMap['onDeactivate'] = onDeactivate;
    }

    if (onNavigationEvent != null) {
      eventMap['onNavigationEvent'] = onNavigationEvent;
    }

    if (onReceiveParams != null) {
      eventMap['onReceiveParams'] = onReceiveParams;
    }

    // Build props map
    Map<String, dynamic> props = {
      // CRITICAL FIX: Always include name and presentationStyle as the first props
      'name': name,
      'presentationStyle': presentationStyle.name,

      // Add configuration based on presentation style
      if (tabConfig != null) ...tabConfig!.toMap(),
      if (modalConfig != null) ...modalConfig!.toMap(),
      if (pushConfig != null) ...pushConfig!.toMap(),

      ...LayoutProps(
        padding: 0,
        margin: 0,
        height: "100%",
        width: "100%",
      ).toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };
    
    if (navigationCommand != null && navigationCommand!.hasCommands) {
      props['navigationCommand'] = navigationCommand!.toMap();
    }

    return DCFElement(
      type: 'Screen',
      props: props,
      children: children,
    );
  }

  @override
  List<Object?> get props => [
        key,
        name,
        presentationStyle,
        tabConfig,
        modalConfig,
        pushConfig,
        children,
        styleSheet,
        navigationCommand,
        events,
        onAppear,
        onDisappear,
        onActivate,
        onDeactivate,
        onNavigationEvent,
        onReceiveParams,
      ];
}




enum DCFModalPresentationStyle {
  /// A standard page sheet presentation that can be resized.
  pageSheet,

  /// A full-screen presentation.
  fullScreen,

  /// A presentation that covers the content below it.
  overCurrentContext,
}

/// Defines the detents for a resizable modal sheet.
enum DCFModalDetent {
  /// A detent that resizes to a medium height.
  medium,

  /// A detent that resizes to the full height of the screen.
  large,
}


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