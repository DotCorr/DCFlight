/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import '../../../dictionary/navigation.dart';

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

  final DCFComponentNode Function()? builder;

  final List<DCFComponentNode>? children;
  final StyleSheet styleSheet;
  final ScreenNavigationCommand? navigationCommand;
  final Map<String, dynamic>? events;
  // This is used to clean up navigation state when the screen is popped or navigated away
  final Function(Map<dynamic, dynamic>)? navigationStateCleaner;
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
    required this.navigationStateCleaner,
    required this.presentationStyle,
    this.tabConfig,
    this.modalConfig,
    this.pushConfig,
    this.popoverConfig,
    this.overlayConfig,
    this.builder,
    this.children,
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
  });

  @override
  DCFComponentNode render() {
    onNavigationEventWithCleanup(data) {
      if (navigationStateCleaner != null) {
        if (data['action'] == 'pop' ||
            data['action'] == 'popToRoot' ||
            data['action'] == 'popTo' ||
            data['action'] == 'replaceWith') {
          navigationStateCleaner!(data);
        }
      }
      onNavigationEvent?.call(data);
    }

    Map<String, dynamic> eventMap = {};
    if (events != null) eventMap.addAll(events!);
    if (onAppear != null) eventMap['onAppear'] = onAppear!;
    if (onDisappear != null) eventMap['onDisappear'] = onDisappear!;
    if (onActivate != null) eventMap['onActivate'] = onActivate!;
    if (onDeactivate != null) eventMap['onDeactivate'] = onDeactivate!;
    if (onNavigationEvent != null) {
      eventMap['onNavigationEvent'] = onNavigationEvent!;
    }
    if (navigationStateCleaner != null) {
      eventMap['onNavigationEvent'] = onNavigationEventWithCleanup;
    }

    if (onReceiveParams != null) eventMap['onReceiveParams'] = onReceiveParams!;
    if (onHeaderActionPress != null) {
      eventMap['onHeaderActionPress'] = onHeaderActionPress!;
    }

    // Build props map (same as before)
    Map<String, dynamic> props = {
      'name': name,
      'presentationStyle': presentationStyle.name,
      if (tabConfig != null) ...tabConfig!.toMap(),
      if (modalConfig != null) ...modalConfig!.toMap(),
      if (pushConfig != null) ...pushConfig!.toMap(),
      if (popoverConfig != null) ...popoverConfig!.toMap(),
      if (overlayConfig != null) ...overlayConfig!.toMap(),
      if (navigationBarConfig != null) ...navigationBarConfig!.toMap(),
      ...LayoutProps(padding: 0, margin: 0, height: "100%", width: "100%")
          .toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    if (navigationCommand != null && navigationCommand!.hasCommands) {
      props['navigationCommand'] = navigationCommand!.toMap();
    }

    List<DCFComponentNode> actualChildren = [];

    if (builder != null) {
      print("🏗️ DCFScreen: Rendering component for screen '$name'");
      actualChildren = [builder!()];
    } else if (children != null) {
      actualChildren = children!;
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
