import "package:equatable/equatable.dart";
import "package:flutter/material.dart";

class DCFPushHeaderActionConfig extends Equatable {
  final String title;
  final dynamic icon;
  final String? actionId;
  final bool enabled;

  const DCFPushHeaderActionConfig({
    required this.title,
    required this.icon,
    this.actionId,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'icon': icon,
      if (actionId != null) 'actionId': actionId,
      'enabled': enabled,
    };
  }

  @override
  List<Object?> get props => [title, icon, actionId, enabled];

  // STATIC FACTORY METHODS - This is the correct way!

  /// Create SF Symbol icon config
  static DCFPushHeaderActionConfig withSFSymbol({
    required String title,
    required String symbolName,
    String? actionId,
    bool enabled = true,
    double? size,
  }) {
    return DCFPushHeaderActionConfig(
      title: title,
      icon: {
        'type': 'sf',
        'name': symbolName,
        if (size != null) 'size': size,
      },
      actionId: actionId,
      enabled: enabled,
    );
  }

  /// Create SVG icon from app bundle config
  static DCFPushHeaderActionConfig withSVGAsset({
    required String title,
    required String assetPath,
    String? actionId,
    bool enabled = true,
    double? size,
    Color? tintColor,
  }) {
    return DCFPushHeaderActionConfig(
      title: title,
      icon: {
        'type': 'svg',
        'assetPath': assetPath,
        if (size != null) 'size': size,
        if (tintColor != null)
          'tintColor': '#${tintColor.value.toRadixString(16).padLeft(8, '0')}',
      },
      actionId: actionId,
      enabled: enabled,
    );
  }

  /// Create SVG icon from package bundle config
  static DCFPushHeaderActionConfig withSVGPackage({
    required String title,
    required String package,
    required String iconName,
    String? actionId,
    bool enabled = true,
    double? size,
    Color? tintColor,
  }) {
    return DCFPushHeaderActionConfig(
      title: title,
      icon: {
        'type': 'package',
        'package': package,
        'name': iconName,
        if (size != null) 'size': size,
        if (tintColor != null)
          'tintColor': '#${tintColor.value.toRadixString(16).padLeft(8, '0')}',
      },
      actionId: actionId,
      enabled: enabled,
    );
  }

  /// Create text-only button (no icon)
  static DCFPushHeaderActionConfig withTextOnly({
    required String title,
    String? actionId,
    bool enabled = true,
  }) {
    return DCFPushHeaderActionConfig(
      title: title,
      icon: {
        'type': 'text',
      },
      actionId: actionId,
      enabled: enabled,
    );
  }

  /// Create icon-only button (no text)
  static DCFPushHeaderActionConfig withIconOnly({
    required String package,
    required String iconName,
    String? actionId,
    bool enabled = true,
    double? size,
    Color? tintColor,
  }) {
    return DCFPushHeaderActionConfig(
      title: "", // Empty title for icon-only
      icon: {
        'type': 'package',
        'package': package,
        'name': iconName,
        if (size != null) 'size': size,
        if (tintColor != null)
          'tintColor': '#${tintColor.value.toRadixString(16).padLeft(8, '0')}',
      },
      actionId: actionId,
      enabled: enabled,
    );
  }

  /// Create SF Symbol icon-only button
  static DCFPushHeaderActionConfig withSFSymbolOnly({
    required String symbolName,
    String? actionId,
    bool enabled = true,
    double? size,
    Color? tintColor,
  }) {
    return DCFPushHeaderActionConfig(
      title: "", // Empty title for icon-only
      icon: {
        'type': 'sf',
        'name': symbolName,
        if (size != null) 'size': size,
        if (tintColor != null)
          'tintColor': '#${tintColor.value.toRadixString(16).padLeft(8, '0')}',
      },
      actionId: actionId,
      enabled: enabled,
    );
  }
}

class DCFPushConfig extends Equatable {
  final String? title;
  final bool hideNavigationBar;
  final bool hideBackButton;
  final String? backButtonTitle;
  final bool largeTitleDisplayMode;

  // NEW: Navigation bar button support
  final List<DCFPushHeaderActionConfig>? prefixActions;
  final List<DCFPushHeaderActionConfig>? suffixActions;

  const DCFPushConfig({
    this.title,
    this.hideNavigationBar = false,
    this.hideBackButton = false,
    this.backButtonTitle,
    this.largeTitleDisplayMode = false,
    this.prefixActions,
    this.suffixActions,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      'hideNavigationBar': hideNavigationBar,
      'hideBackButton': hideBackButton,
      if (backButtonTitle != null) 'backButtonTitle': backButtonTitle,
      'largeTitleDisplayMode': largeTitleDisplayMode,
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
        hideNavigationBar,
        hideBackButton,
        backButtonTitle,
        largeTitleDisplayMode,
        prefixActions,
        suffixActions,
      ];
}
