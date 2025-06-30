/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcf_primitives/src/components/navigation/screen_safe_area.dart';
import 'package:dcflight/dcflight.dart';

enum DCFPresentationStyle {
  tab,
  push,
  modal,
  sheet,
  popover,
  drawer,
  splitView,
}

class DCFTabConfig {
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
}

class DCFModalConfig {
  final List<String>? detents;
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
}

class DCFPushConfig {
  final String? title;
  final bool hideNavigationBar;
  final bool hideBackButton;
  final String? backButtonTitle;
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

class DCFScreen extends StatelessComponent {
  final String name;
  final DCFPresentationStyle presentationStyle;
  final DCFTabConfig? tabConfig;
  final DCFModalConfig? modalConfig;
  final DCFPushConfig? pushConfig;
  final List<DCFComponentNode> children;
  final bool? shouldHideSafeArea;
  final StyleSheet styleSheet;
  final ScreenNavigationCommand? navigationCommand;
  final Map<String, dynamic>? events;
  final Function(Map<dynamic, dynamic>)? onAppear;
  final Function(Map<dynamic, dynamic>)? onDisappear;
  final Function(Map<dynamic, dynamic>)? onActivate;
  final Function(Map<dynamic, dynamic>)? onDeactivate;
  final Function(Map<dynamic, dynamic>)? onNavigationEvent;
  final Function(Map<dynamic, dynamic>)? onReceiveParams;

  DCFScreen({
    this.shouldHideSafeArea,
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

    Map<String, dynamic> props = {
      'name': name,
      'presentationStyle': presentationStyle.name,

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
      children: [
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
      ],
    );
  }
}

class DCFScreenManager {
  static final DCFScreenManager _instance = DCFScreenManager._();
  static DCFScreenManager get instance => _instance;

  DCFScreenManager._();

  final Map<String, bool> _activeScreens = {};
  final Map<String, List<Function()>> _activationCallbacks = {};

  void activateScreen(String screenName) {
    _activeScreens[screenName] = true;
    _notifyActivation(screenName);
  }

  void deactivateScreen(String screenName) {
    _activeScreens[screenName] = false;
    _notifyDeactivation(screenName);
  }

  bool isScreenActive(String screenName) {
    return _activeScreens[screenName] ?? false;
  }

  void onScreenActivated(String screenName, Function() callback) {
    _activationCallbacks.putIfAbsent(screenName, () => []).add(callback);
  }

  void removeActivationCallback(String screenName, Function() callback) {
    _activationCallbacks[screenName]?.remove(callback);
  }

  void _notifyActivation(String screenName) {
    _activationCallbacks[screenName]?.forEach((callback) => callback());
  }

  void _notifyDeactivation(String screenName) {
    // Could add deactivation callbacks in the future
  }

  List<String> get activeScreens {
    return _activeScreens.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}