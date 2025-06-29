/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcf_primitives/src/components/navigation/screen_safe_area.dart';
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

  /// Drawer presentation - screen appears as a side drawer
  drawer,

  /// Split view presentation - screen appears in split view
  splitView,
}

/// Configuration for tab presentation
class DCFTabConfig {
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
}

/// Configuration for modal presentation
class DCFModalConfig {
  /// Modal detents (height sizes)
  final List<String>? detents;

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
}

/// Configuration for push presentation
class DCFPushConfig {
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
}

/// A screen component that provides navigation context and lifecycle
class DCFScreen extends StatelessComponent {
  /// Unique screen name/identifier
  final String name;

  /// How this screen should be presented
  final DCFPresentationStyle presentationStyle;

  /// Whether the screen is currently visible
  final bool visible;

  /// Configuration for tab presentation
  final DCFTabConfig? tabConfig;

  /// Configuration for modal presentation
  final DCFModalConfig? modalConfig;

  /// Configuration for push presentation
  final DCFPushConfig? pushConfig;

  /// Screen content
  final List<DCFComponentNode> children;
  final bool? shouldHideSafeArea;

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
    this.shouldHideSafeArea,
    super.key,
    required this.name,
    required this.presentationStyle,
    required this.visible,
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
      'visible': visible,

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

    // Add navigation command props if command has actions
    if (navigationCommand != null && navigationCommand!.hasCommands) {
      props['navigationCommand'] = navigationCommand!.toMap();
    }

    // Handle visibility - but always render children for tab screens
    if (!visible) {
      // For non-tab screens (push/modal), we can safely hide them
      if (presentationStyle != DCFPresentationStyle.tab) {
        props['display'] = 'none';
        props['opacity'] = 0.0;
        props['userInteractionEnabled'] = false;
      } else {
        // For tab screens, use visibility but keep them rendered
        props['opacity'] = 0.0;
        props['userInteractionEnabled'] = false;
      }
    } else {
      props['display'] = 'flex';
      props['opacity'] = 1.0;
      props['userInteractionEnabled'] = true;
    }

    // Always render children for tab screens, conditionally for others
    final shouldRenderChildren = visible || presentationStyle == DCFPresentationStyle.tab;

    return DCFElement(
      type: 'Screen',
      props: props,
      children: shouldRenderChildren ? [
        ScreenForceSafeAreaChildrenDirtier(
          bottom: shouldHideSafeArea == true ? false : true,
          top: shouldHideSafeArea == true ? false : true,
          layout: LayoutProps(
            flex: 1,
            padding: 0,
            margin: 0,
          ),
          children: children,
        ),
      ] : [], // Empty children only for non-tab invisible screens
    );
  }
}

/// Screen manager for coordinating screen lifecycle
class DCFScreenManager {
  static final DCFScreenManager _instance = DCFScreenManager._();
  static DCFScreenManager get instance => _instance;

  DCFScreenManager._();

  /// Currently active screens by name
  final Map<String, bool> _activeScreens = {};

  /// Screen activation callbacks
  final Map<String, List<Function()>> _activationCallbacks = {};

  /// Register a screen as active
  void activateScreen(String screenName) {
    _activeScreens[screenName] = true;
    _notifyActivation(screenName);
  }

  /// Register a screen as inactive
  void deactivateScreen(String screenName) {
    _activeScreens[screenName] = false;
    _notifyDeactivation(screenName);
  }

  /// Check if a screen is active
  bool isScreenActive(String screenName) {
    return _activeScreens[screenName] ?? false;
  }

  /// Register callback for screen activation
  void onScreenActivated(String screenName, Function() callback) {
    _activationCallbacks.putIfAbsent(screenName, () => []).add(callback);
  }

  /// Remove activation callback
  void removeActivationCallback(String screenName, Function() callback) {
    _activationCallbacks[screenName]?.remove(callback);
  }

  void _notifyActivation(String screenName) {
    _activationCallbacks[screenName]?.forEach((callback) => callback());
  }

  void _notifyDeactivation(String screenName) {
    // Could add deactivation callbacks in the future
  }

  /// Get all active screens
  List<String> get activeScreens {
    return _activeScreens.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}