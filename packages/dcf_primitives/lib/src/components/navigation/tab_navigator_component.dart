/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

import 'managers/screen_manager.dart';

/// Tab bar style configuration
class DCFTabBarStyle extends Equatable {
  /// Background color of tab bar
  final Color? backgroundColor;

  /// Selected tab tint color
  final Color? selectedTintColor;

  /// Unselected tab tint color
  final Color? unselectedTintColor;

  /// Whether tab bar is translucent
  final bool translucent;

  /// Tab bar position
  final String position; // "top" or "bottom"

  /// Whether to show tab labels
  final bool showLabels;

  /// Whether to show tab icons
  final bool showIcons;

  /// Tab bar height
  final double? height;

  const DCFTabBarStyle({
    this.backgroundColor,
    this.selectedTintColor,
    this.unselectedTintColor,
    this.translucent = true,
    this.position = "bottom",
    this.showLabels = true,
    this.showIcons = true,
    this.height,
  });

  Map<String, dynamic> toMap() {
    return {
      if (backgroundColor != null)
        'backgroundColor':
            '#${backgroundColor!.value.toRadixString(16).padLeft(8, '0')}',
      if (selectedTintColor != null)
        'selectedTintColor':
            '#${selectedTintColor!.value.toRadixString(16).padLeft(8, '0')}',
      if (unselectedTintColor != null)
        'unselectedTintColor':
            '#${unselectedTintColor!.value.toRadixString(16).padLeft(8, '0')}',
      'translucent': translucent,
      'position': position,
      'showLabels': showLabels,
      'showIcons': showIcons,
      if (height != null) 'height': height,
    };
  }

  @override
  List<Object?> get props => [
        backgroundColor,
        selectedTintColor,
        unselectedTintColor,
        translucent,
        position,
        showLabels,
        showIcons,
        height,
      ];
}

/// Tab navigator that coordinates multiple screens in a tab interface
class DCFTabNavigator extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// List of screen names to include in tab navigation
  final List<String> screens;

  /// Currently selected tab index
  final int selectedIndex;

  /// Tab bar style configuration
  final DCFTabBarStyle? tabBarStyle;

  /// Whether tab bar is hidden
  final bool isHidden;

  /// Whether to lazy load tab content
  final bool lazyLoad;

  /// Animation duration for tab switches
  final double? animationDuration;

  /// Style properties
  final StyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Called when tab selection changes
  final Function(Map<dynamic, dynamic>)? onTabChange;

  /// Called when tab is pressed
  final Function(Map<dynamic, dynamic>)? onTabPress;

  DCFTabNavigator({
    super.key,
    required this.screens,
    this.selectedIndex = 0,
    this.tabBarStyle,
    this.isHidden = false,
    this.lazyLoad = true,
    this.animationDuration,
    this.styleSheet = const StyleSheet(),
    this.events,
    this.onTabChange,
    this.onTabPress,
  });

  @override
  DCFComponentNode render() {
    // Build event map
    Map<String, dynamic> eventMap = events ?? {};

    if (onTabChange != null) {
      eventMap['onTabChange'] = onTabChange;
    }

    if (onTabPress != null) {
      eventMap['onTabPress'] = onTabPress;
    }

    // Build props map
    Map<String, dynamic> props = {
      'screens': screens,
      'selectedIndex': selectedIndex,
      'isHidden': isHidden,
      'lazyLoad': lazyLoad,

      // Add tab bar style if provided
      if (tabBarStyle != null) ...tabBarStyle!.toMap(),

      if (animationDuration != null) 'animationDuration': animationDuration,

      ...LayoutProps(padding: 0, margin: 0, flex: 1).toMap(),
      ...styleSheet.toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'TabNavigator',
      props: props,
      children: [], // Tab navigator doesn't have direct children - it coordinates screens
    );
  }

  @override
  List<Object?> get props => [
        key,
        screens,
        selectedIndex,
        tabBarStyle,
        isHidden,
        lazyLoad,
        animationDuration,
        styleSheet,
        events,
        onTabChange,
        onTabPress,
      ];
}

/// Tab bar controller for managing tab state and coordination
class DCFTabController {
  /// Tab navigator instance identifier
  final String navigatorId;

  /// Currently selected tab index
  int _selectedIndex = 0;

  /// List of screen names
  List<String> _screens = [];

  /// Tab change callbacks
  final List<Function(int)> _tabChangeCallbacks = [];

  DCFTabController(this.navigatorId);

  /// Get current selected tab index
  int get selectedIndex => _selectedIndex;

  /// Get list of screens
  List<String> get screens => List.unmodifiable(_screens);

  /// Set screens for this tab navigator
  void setScreens(List<String> screens) {
    _screens = List.from(screens);
  }

  /// Select a tab by index
  void selectTab(int index) {
    if (index >= 0 && index < _screens.length && index != _selectedIndex) {
      final previousIndex = _selectedIndex;
      _selectedIndex = index;

      // Notify screen manager about activation changes
      if (previousIndex < _screens.length) {
        DCFScreenManager.instance.deactivateScreen(_screens[previousIndex]);
      }
      DCFScreenManager.instance.activateScreen(_screens[index]);

      // Notify callbacks
      _notifyTabChange(index);
    }
  }

  /// Select a tab by screen name
  void selectTabByScreen(String screenName) {
    final index = _screens.indexOf(screenName);
    if (index != -1) {
      selectTab(index);
    }
  }

  /// Add a tab change callback
  void onTabChanged(Function(int) callback) {
    _tabChangeCallbacks.add(callback);
  }

  /// Remove a tab change callback
  void removeTabChangeCallback(Function(int) callback) {
    _tabChangeCallbacks.remove(callback);
  }

  /// Add a new tab screen
  void addTab(String screenName, {int? index}) {
    if (index != null && index >= 0 && index <= _screens.length) {
      _screens.insert(index, screenName);
    } else {
      _screens.add(screenName);
    }
  }

  /// Remove a tab screen
  void removeTab(String screenName) {
    final index = _screens.indexOf(screenName);
    if (index != -1) {
      _screens.removeAt(index);

      // Adjust selected index if needed
      if (_selectedIndex >= _screens.length && _screens.isNotEmpty) {
        selectTab(_screens.length - 1);
      } else if (_screens.isEmpty) {
        _selectedIndex = 0;
      }
    }
  }

  /// Get current active screen name
  String? get currentScreen {
    if (_selectedIndex >= 0 && _selectedIndex < _screens.length) {
      return _screens[_selectedIndex];
    }
    return null;
  }

  void _notifyTabChange(int newIndex) {
    for (final callback in _tabChangeCallbacks) {
      callback(newIndex);
    }
  }
}

/// Global tab controller registry
class DCFTabControllerRegistry {
  static final DCFTabControllerRegistry _instance =
      DCFTabControllerRegistry._();
  static DCFTabControllerRegistry get instance => _instance;

  DCFTabControllerRegistry._();

  /// Map of navigator IDs to tab controllers
  final Map<String, DCFTabController> _controllers = {};

  /// Get or create a tab controller for a navigator
  DCFTabController getController(String navigatorId) {
    return _controllers.putIfAbsent(
        navigatorId, () => DCFTabController(navigatorId));
  }

  /// Remove a tab controller
  void removeController(String navigatorId) {
    _controllers.remove(navigatorId);
  }

  /// Get all registered controllers
  Map<String, DCFTabController> get controllers =>
      Map.unmodifiable(_controllers);
}
