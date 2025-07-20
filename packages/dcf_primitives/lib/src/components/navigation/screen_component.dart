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

  /// Overlay presentation - screen appears as a custom overlay
  overlay,

  /// Drawer presentation - screen appears as a side drawer
  drawer,

  /// Split view presentation - screen appears in split view
  splitView,
}

/// Configuration for tab presentation
class DCFTabConfig extends Equatable {
  final String title;
  final dynamic icon;
  final int index;
  final String? badge;
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
  final List<DCFModalDetent>? detents;
  final int? selectedDetentIndex;
  final bool showDragIndicator;
  final double? cornerRadius;
  final bool isDismissible;
  final bool allowsBackgroundDismiss;
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

/// Configuration for popover presentation
class DCFPopoverConfig extends Equatable {
  final String? title;
  final double? preferredWidth;
  final double? preferredHeight;
  final List<String>? permittedArrowDirections;
  final bool dismissOnOutsideTap;

  const DCFPopoverConfig({
    this.title,
    this.preferredWidth,
    this.preferredHeight,
    this.permittedArrowDirections,
    this.dismissOnOutsideTap = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (preferredWidth != null) 'preferredWidth': preferredWidth,
      if (preferredHeight != null) 'preferredHeight': preferredHeight,
      if (permittedArrowDirections != null)
        'permittedArrowDirections': permittedArrowDirections,
      'dismissOnOutsideTap': dismissOnOutsideTap,
    };
  }

  @override
  List<Object?> get props => [
        title,
        preferredWidth,
        preferredHeight,
        permittedArrowDirections,
        dismissOnOutsideTap,
      ];
}

/// Configuration for overlay presentation
class DCFOverlayConfig extends Equatable {
  final String? title;
  final Color? overlayBackgroundColor;
  final bool dismissOnTap;
  final double? animationDuration;
  final bool blocksInteraction;

  const DCFOverlayConfig({
    this.title,
    this.overlayBackgroundColor,
    this.dismissOnTap = true,
    this.animationDuration,
    this.blocksInteraction = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (overlayBackgroundColor != null)
        'overlayBackgroundColor':
            '#${overlayBackgroundColor!.value.toRadixString(16).padLeft(8, '0')}',
      'dismissOnTap': dismissOnTap,
      if (animationDuration != null) 'animationDuration': animationDuration,
      'blocksInteraction': blocksInteraction,
    };
  }

  @override
  List<Object?> get props => [
        title,
        overlayBackgroundColor,
        dismissOnTap,
        animationDuration,
        blocksInteraction,
      ];
}

/// A screen component that provides navigation context and lifecycle
class DCFScreen extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  final String name;
  final DCFPresentationStyle presentationStyle;
  final DCFTabConfig? tabConfig;
  final DCFModalConfig? modalConfig;
  final DCFPushConfig? pushConfig;
  final DCFPopoverConfig? popoverConfig;
  final DCFOverlayConfig? overlayConfig;
  final List<DCFComponentNode> children;
  final StyleSheet styleSheet;
  final ScreenNavigationCommand? navigationCommand;
  final Map<String, dynamic>? events;
  final Function(Map<dynamic, dynamic>)? onAppear;
  final Function(Map<dynamic, dynamic>)? onDisappear;
  final Function(Map<dynamic, dynamic>)? onActivate;
  final Function(Map<dynamic, dynamic>)? onDeactivate;
  final Function(Map<dynamic, dynamic>)? onNavigationEvent;
  final Function(Map<dynamic, dynamic>)? onReceiveParams;

  // Header action event handler
  final Function(Map<dynamic, dynamic>)? onHeaderActionPress;

  DCFScreen({
    super.key,
    required this.name,
    required this.presentationStyle,
    this.tabConfig,
    this.modalConfig,
    this.pushConfig,
    this.popoverConfig,
    this.overlayConfig,
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
    this.onHeaderActionPress,
  });

  @override
  DCFComponentNode render() {
    // 🎯 FIXED: Create a proper event map that includes ALL event handlers
    Map<String, dynamic> eventMap = {};

    // Add custom events passed in
    if (events != null) {
      eventMap.addAll(events!);
    }

    // 🎯 CRITICAL FIX: Add ALL event handlers to the props map
    // This ensures they are registered with the native event system
    if (onAppear != null) {
      eventMap['onAppear'] = onAppear!;
    }

    if (onDisappear != null) {
      eventMap['onDisappear'] = onDisappear!;
    }

    if (onActivate != null) {
      eventMap['onActivate'] = onActivate!;
    }

    if (onDeactivate != null) {
      eventMap['onDeactivate'] = onDeactivate!;
    }

    if (onNavigationEvent != null) {
      eventMap['onNavigationEvent'] = onNavigationEvent!;
    }

    if (onReceiveParams != null) {
      eventMap['onReceiveParams'] = onReceiveParams!;
    }

    // 🎯 MOST IMPORTANT FIX: Add header action handler to event map
    if (onHeaderActionPress != null) {
      eventMap['onHeaderActionPress'] = onHeaderActionPress!;
    }

    // Build props map
    Map<String, dynamic> props = {
      'name': name,
      'presentationStyle': presentationStyle.name,

      // Add configuration based on presentation style
      if (tabConfig != null) ...tabConfig!.toMap(),
      if (modalConfig != null) ...modalConfig!.toMap(),
      if (pushConfig != null) ...pushConfig!.toMap(),
      if (popoverConfig != null) ...popoverConfig!.toMap(),
      if (overlayConfig != null) ...overlayConfig!.toMap(),

      // Layout and style props
      ...LayoutProps(
        padding: 0,
        margin: 0,
        height: "100%",
        width: "100%",
      ).toMap(),
      ...styleSheet.toMap(),

      // 🎯 CRITICAL: Add event handlers to props (like DCFWebView does)
      ...eventMap,
    };

    // Add navigation command if present
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
        popoverConfig,
        overlayConfig,
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
        onHeaderActionPress,
      ];
}

enum DCFModalPresentationStyle {
  pageSheet,
  fullScreen,
  overCurrentContext,
}

enum DCFModalDetent {
  medium,
  large,
}

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
        dismissOverlay != null;
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
}
