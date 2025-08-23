/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import "package:dcf_screens/dcf_screens.dart";
import "package:dcflight/dcflight.dart";

/// 🎯 DCFEasyScreen - Simple wrapper that reduces boilerplate 
/// while keeping your existing working pattern
class DCFEasyScreen extends StatefulComponent with EquatableMixin {
  final String route;
  final DCFPresentationStyle? presentationStyle;
  final DCFComponentNode Function() builder;
  final DCFPushConfig? pushConfig;
  final DCFTabConfig? tabConfig;
  final DCFModalConfig? modalConfig;
  final DCFPopoverConfig? popoverConfig;
  final DCFOverlayConfig? overlayConfig;
  final DCFNavigationBarConfig? navigationBarConfig;
  final StyleSheet styleSheet;
  
  /// Whether to always render (skip suspense)
  final bool alwaysRender;
  
  /// Custom placeholder when suspended
  final DCFComponentNode Function()? placeholder;
  
  /// Optional user event handlers
  final Function(Map<dynamic, dynamic>)? onAppear;
  final Function(Map<dynamic, dynamic>)? onDisappear;
  final Function(Map<dynamic, dynamic>)? onActivate;
  final Function(Map<dynamic, dynamic>)? onDeactivate;
  final Function(Map<dynamic, dynamic>)? onNavigationEvent;
  final Function(Map<dynamic, dynamic>)? onReceiveParams;
  final Function(Map<dynamic, dynamic>)? onHeaderActionPress;
  final Map<String, dynamic>? customEvents;

   DCFEasyScreen({
    super.key,
    required this.route,
     this.presentationStyle,
    required this.builder,
    this.pushConfig,
    this.tabConfig,
    this.modalConfig,
    this.popoverConfig,
    this.overlayConfig,
    this.navigationBarConfig,
    this.styleSheet = const StyleSheet(),
    this.alwaysRender = false,
    this.placeholder,
    this.onAppear,
    this.onDisappear,
    this.onActivate,
    this.onDeactivate,
    this.onNavigationEvent,
    this.onReceiveParams,
    this.onHeaderActionPress,
    this.customEvents,
  });

  @override
  DCFComponentNode render() {
    // Use the existing stores
    final globalNavCommand = useStore(globalNavigationCommand);
    final globalNavTarget = useStore(globalNavigationTarget);
    final activeScreen = useStore(activeScreenTracker);
    final navStack = useStore(navigationStackTracker);

    return DCFScreen(
      route: route,
      presentationStyle: presentationStyle ?? DCFPresentationStyle.push,
      pushConfig: pushConfig,
      tabConfig: tabConfig,
      modalConfig: modalConfig,
      popoverConfig: popoverConfig,
      overlayConfig: overlayConfig,
      navigationBarConfig: navigationBarConfig,
      styleSheet: styleSheet,
      
      // 🎯 AUTOMATIC: Command routing
      routeNavigationCommand: _shouldHandleCommand(route, globalNavTarget.state) 
          ? globalNavCommand.state 
          : null,
      
      // 🎯 AUTOMATIC: Event handling with automatic state updates
      onAppear: (data) {
        print("✅ $route route appeared: $data");
        activeScreenTracker.setState(route);
        
        // Call user handler if provided
        if (onAppear != null) onAppear!(data);
      },
      
      onDisappear: (data) {
        print("❌ $route route disappeared: $data");
        if (onDisappear != null) onDisappear!(data);
      },
      
      onActivate: (data) {
        print("✅ $route route activated: $data");
        if (onActivate != null) onActivate!(data);
      },
      
      onDeactivate: (data) {
        print("❌ $route route deactivated: $data");
        if (onDeactivate != null) onDeactivate!(data);
      },
      
      onNavigationEvent: (data) {
        print("🚀 $route navigation event: $data");
        _handleNavigationEvents(route, data);
        AppNavigation.clearCommand();
        
        // Call user handler if provided
        if (onNavigationEvent != null) onNavigationEvent!(data);
      },
      
      onReceiveParams: (data) {
        print("📬 $route received params: $data");
        if (onReceiveParams != null) onReceiveParams!(data);
      },
      
      onHeaderActionPress: (data) {
        print("🎯 $route header action pressed: $data");
        if (onHeaderActionPress != null) onHeaderActionPress!(data);
      },
      
      events: customEvents,
      
      // 🎯 AUTOMATIC: Suspense wrapper
      builder: () {
        if (alwaysRender) {
          return builder();
        }
        
        return DCFSuspense(
          shouldRender: _shouldRenderScreen(route, activeScreen.state, navStack.state),
          debugName: route,
          children: builder,
          fallback: placeholder != null 
              ? placeholder! 
              : () => _createDefaultPlaceholder(route),
        );
      },
    );
  }

  // 🎯 Helper methods (same logic as your working version)
  bool _shouldHandleCommand(String screenRoute, String? targetRoute) {
    if (targetRoute == null) return true;
    return screenRoute == targetRoute;
  }

  bool _shouldRenderScreen(String route, String? activeScreen, List<String> navStack) {
    // Always render if it's the current active screen
    if (activeScreen == route) return true;
    
    // Always render if it's in the navigation stack (for back navigation)
    if (navStack.contains(route)) return true;
    
    // Always render home (it's the root)
    if (route == "home") return true;
    
    return false;
  }

  void _handleNavigationEvents(String screenRoute, Map<dynamic, dynamic> data) {
    final action = data['action'] as String?;
    final targetRoute = data['targetRoute'] as String?;
    
    print("🔍 Navigation event for $screenRoute: action=$action, target=$targetRoute");
    
    // Update active screen and navigation stack based on events
    switch (action) {
      case 'pop':
        if (targetRoute == screenRoute) {
          activeScreenTracker.setState(screenRoute);
        }
        break;
      case 'popTo':
        if (targetRoute == screenRoute) {
          activeScreenTracker.setState(screenRoute);
        }
        break;
      case 'popToRoot':
        if (screenRoute == "home") {
          activeScreenTracker.setState("home");
          navigationStackTracker.setState(["home"]);
        }
        break;
    }
  }

  DCFComponentNode _createDefaultPlaceholder(String route) {
    return DCFView(
      layout: LayoutProps(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        padding: 20,
      ),
      children: [
        DCFText(
          content: "Loading $route...",
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.grey,
            textAlign: "center",
          ),
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [
        key, route, presentationStyle, builder, pushConfig, tabConfig, modalConfig,
        popoverConfig, overlayConfig, navigationBarConfig, styleSheet, alwaysRender,
        placeholder, onAppear, onDisappear, onActivate, onDeactivate, onNavigationEvent,
        onReceiveParams, onHeaderActionPress, customEvents,
      ];
}

