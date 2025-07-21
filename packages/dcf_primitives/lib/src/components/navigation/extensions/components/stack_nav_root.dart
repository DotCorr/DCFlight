/*
 * Fixed DCFStackNavigationRoot - Pure Registration Pattern
 * Just like DCFNestedNavigationRoot but for stack-only apps
 */

import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';

/// A navigation root that provides stack-based navigation through pure screen registration
/// No additional navigator component needed - DCFScreens handle their own navigation
class DCFStackNavigationRoot extends StatelessComponent {
  /// Initial screen name to display first
  final String initialScreen;

  /// Registry of all available screens as DCFScreen objects
  final DCFComponentNode screenRegistryComponents;

  /// Navigation bar configuration (applied to initial screen)
  final DCFNavigationBarStyle? navigationBarStyle;

  /// Whether to hide the navigation bar globally
  final bool hideNavigationBar;

  /// Animation duration for screen transitions
  final double? animationDuration;

  /// Called when navigation changes occur
  final Function(Map<dynamic, dynamic>)? onNavigationChange;

  /// Called when the back button is pressed
  final Function(Map<dynamic, dynamic>)? onBackPressed;

  DCFStackNavigationRoot({
    super.key,
    required this.initialScreen,
    required this.screenRegistryComponents,
    this.navigationBarStyle,
    this.hideNavigationBar = false,
    this.animationDuration,
    this.onNavigationChange,
    this.onBackPressed,
  });

  @override
  DCFComponentNode render() {
    return DCFFragment(
      children: [
        // 🎯 STEP 1: Register all available screens
        screenRegistryComponents,

        // 🎯 STEP 2: Create initial navigation setup
        DCFStackNavigationBootstrapper(
          initialScreen: initialScreen,
          navigationBarStyle: navigationBarStyle,
          hideNavigationBar: hideNavigationBar,
          animationDuration: animationDuration,
          onNavigationChange: onNavigationChange,
          onBackPressed: onBackPressed,
        ),
      ],
    );
  }
}

/// Internal component that sets up the initial navigation controller
/// This just creates the UINavigationController and sets the initial screen
class DCFStackNavigationBootstrapper extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  final String initialScreen;
  final DCFNavigationBarStyle? navigationBarStyle;
  final bool hideNavigationBar;
  final double? animationDuration;
  final Function(Map<dynamic, dynamic>)? onNavigationChange;
  final Function(Map<dynamic, dynamic>)? onBackPressed;

  DCFStackNavigationBootstrapper({
    super.key,
    required this.initialScreen,
    this.navigationBarStyle,
    this.hideNavigationBar = false,
    this.animationDuration,
    this.onNavigationChange,
    this.onBackPressed,
  });

  @override
  DCFComponentNode render() {
    // Build event map
    Map<String, dynamic> eventMap = {};

    if (onNavigationChange != null) {
      eventMap['onNavigationChange'] = onNavigationChange;
    }

    if (onBackPressed != null) {
      eventMap['onBackPressed'] = onBackPressed;
    }

    // Build props map
    Map<String, dynamic> props = {
      'initialScreen': initialScreen,
      'hideNavigationBar': hideNavigationBar,

      // Add navigation bar style if provided
      if (navigationBarStyle != null) ...navigationBarStyle!.toMap(),

      if (animationDuration != null) 'animationDuration': animationDuration,

      ...LayoutProps(padding: 0, margin: 0, flex: 1).toMap(),
      ...eventMap,
    };

    return DCFElement(
      type: 'StackNavigationBootstrapper',
      props: props,
      children: [], // No children - just sets up navigation
    );
  }

  @override
  List<Object?> get props => [
        key,
        initialScreen,
        navigationBarStyle,
        hideNavigationBar,
        animationDuration,
        onNavigationChange,
        onBackPressed,
      ];
}

/// Navigation bar style configuration
class DCFNavigationBarStyle extends Equatable {
  final Color? backgroundColor;
  final Color? titleColor;
  final Color? backButtonColor;
  final bool translucent;
  final String titleDisplayMode; // "automatic", "large", "inline"
  final bool showBackButton;
  final String? backButtonTitle;
  final double? height;
  final bool hideBorder;

  const DCFNavigationBarStyle({
    this.backgroundColor,
    this.titleColor,
    this.backButtonColor,
    this.translucent = true,
    this.titleDisplayMode = "automatic",
    this.showBackButton = true,
    this.backButtonTitle,
    this.height,
    this.hideBorder = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (backgroundColor != null)
        'backgroundColor':
            '#${backgroundColor!.value.toRadixString(16).padLeft(8, '0')}',
      if (titleColor != null)
        'titleColor': '#${titleColor!.value.toRadixString(16).padLeft(8, '0')}',
      if (backButtonColor != null)
        'backButtonColor':
            '#${backButtonColor!.value.toRadixString(16).padLeft(8, '0')}',
      'translucent': translucent,
      'titleDisplayMode': titleDisplayMode,
      'showBackButton': showBackButton,
      if (backButtonTitle != null) 'backButtonTitle': backButtonTitle,
      if (height != null) 'height': height,
      'hideBorder': hideBorder,
    };
  }

  @override
  List<Object?> get props => [
        backgroundColor,
        titleColor,
        backButtonColor,
        translucent,
        titleDisplayMode,
        showBackButton,
        backButtonTitle,
        height,
        hideBorder,
      ];
}
