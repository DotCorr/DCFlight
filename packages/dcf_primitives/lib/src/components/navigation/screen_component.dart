// File: screen_component.dart
// UPDATED: DCFScreen with lazy loading support

/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

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
  
  // 🎯 NEW: Lazy loading support
  @Deprecated('Use builder instead of children')
  final DCFComponentNode Function()? builder;
  final List<DCFComponentNode>? children; // Keep for backward compatibility
  
  final StyleSheet styleSheet;
  final ScreenNavigationCommand? navigationCommand;
  final Map<String, dynamic>? events;
  final Function(Map<dynamic, dynamic>)? onAppear;
  final Function(Map<dynamic, dynamic>)? onDisappear;
  final Function(Map<dynamic, dynamic>)? onActivate;
  final Function(Map<dynamic, dynamic>)? onDeactivate;
  final Function(Map<dynamic, dynamic>)? onNavigationEvent;
  final Function(Map<dynamic, dynamic>)? onReceiveParams;
  final Function(Map<dynamic, dynamic>)? onHeaderActionPress;
  final DCFNavigationBarConfig? navigationBarConfig;

  DCFScreen({
    super.key,
    required this.name,
    required this.presentationStyle,
    this.tabConfig,
    this.modalConfig,
    this.pushConfig,
    this.popoverConfig,
    this.overlayConfig,
    
    // 🎯 NEW: Choose between builder (lazy) or children (eager)
    this.builder, // Use this for lazy loading

    this.children, // Keep for backward compatibility
    
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
    this.navigationBarConfig,
  }) : assert(
         builder != null || children != null,
         'Either builder or children must be provided'
       );

  @override
  DCFComponentNode render() {
    // Create a proper event map that includes ALL event handlers
    Map<String, dynamic> eventMap = {};

    // Add custom events passed in
    if (events != null) {
      eventMap.addAll(events!);
    }

    // Add ALL event handlers to the props map
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

      if (navigationBarConfig != null) ...navigationBarConfig!.toMap(),

      // Layout and style props
      ...LayoutProps(
        padding: 0,
        margin: 0,
        height: "100%",
        width: "100%",
      ).toMap(),
      ...styleSheet.toMap(),

      ...eventMap,
    };

    // Add navigation command if present
    if (navigationCommand != null && navigationCommand!.hasCommands) {
      props['navigationCommand'] = navigationCommand!.toMap();
    }

    // 🎯 NEW: Determine children - use builder if provided, fallback to children
    List<DCFComponentNode> actualChildren;
    
    if (builder != null) {
      // 🚀 LAZY LOADING: Create component only when screen is rendered
      print("🏗️ DCFScreen: Lazy loading component for screen '$name'");
      actualChildren = [builder!()];
    } else {
      // 🔄 BACKWARD COMPATIBILITY: Use provided children
      actualChildren = children ?? [];
    }

    return DCFElement(
      type: 'Screen',
      props: props,
      children: actualChildren,
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
        builder,
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
        navigationBarConfig,
      ];
}

/// Configuration for navigation bar appearance and behavior (for tab screens)
class DCFNavigationBarConfig extends Equatable {
  /// Navigation bar title (overrides tab title for navigation bar)
  final String? title;

  /// Whether to show large title
  final bool largeTitleDisplayMode;

  /// Whether to hide the navigation bar
  final bool hideNavigationBar;

  /// Whether to hide the back button (for pushed screens)
  final bool hideBackButton;

  /// Custom back button title
  final String? backButtonTitle;

  /// Left navigation bar actions
  final List<DCFPushHeaderActionConfig>? prefixActions;

  /// Right navigation bar actions
  final List<DCFPushHeaderActionConfig>? suffixActions;

  const DCFNavigationBarConfig({
    this.title,
    this.largeTitleDisplayMode = false,
    this.hideNavigationBar = false,
    this.hideBackButton = false,
    this.backButtonTitle,
    this.prefixActions,
    this.suffixActions,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'navigationBarTitle': title,
      'largeTitleDisplayMode': largeTitleDisplayMode,
      'hideNavigationBar': hideNavigationBar,
      'hideBackButton': hideBackButton,
      if (backButtonTitle != null) 'backButtonTitle': backButtonTitle,
      if (prefixActions != null && prefixActions!.isNotEmpty)
        'prefixActions':
            prefixActions!.map((action) => action.toMap()).toList(),
      if (suffixActions != null && suffixActions!.isNotEmpty)
        'suffixActions':
            suffixActions!.map((action) => action.toMap()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        title,
        largeTitleDisplayMode,
        hideNavigationBar,
        hideBackButton,
        backButtonTitle,
        prefixActions,
        suffixActions,
      ];
}