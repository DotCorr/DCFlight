import 'package:dcflight/dcflight.dart';

/// Configuration for tab presentation
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

extension DCFTabConfigSVG on DCFTabConfig {
  /// Create SF Symbol icon config
  static DCFTabConfig withSFSymbol({
    required String title,
    required String symbolName,
    required int index,
    String? badge,
    bool enabled = true,
    double? size,
  }) {
    return DCFTabConfig(
      title: title,
      icon: {
        'type': 'sf',
        'name': symbolName,
        if (size != null) 'size': size,
      },
      index: index,
      badge: badge,
      enabled: enabled,
    );
  }
  
  /// Create SVG icon from app bundle config
  static DCFTabConfig withSVGAsset({
    required String title,
    required String assetPath,
    required int index,
    String? badge,
    bool enabled = true,
    double? size,
    Color? tintColor,
    Color? selectedTintColor,
  }) {
    return DCFTabConfig(
      title: title,
      icon: {
        'type': 'svg',
        'assetPath': assetPath,
        if (size != null) 'size': size,
        if (tintColor != null) 'tintColor': '#${tintColor.value.toRadixString(16).padLeft(8, '0')}',
        if (selectedTintColor != null) 'selectedTintColor': '#${selectedTintColor.value.toRadixString(16).padLeft(8, '0')}',
      },
      index: index,
      badge: badge,
      enabled: enabled,
    );
  }
  
  /// Create SVG icon from package bundle config
  static DCFTabConfig withSVGPackage({
    required String title,
    required String package,
    required String iconName,
    required int index,
    String? badge,
    bool enabled = true,
    double? size,
    Color? tintColor,
    Color? selectedTintColor,
  }) {
    return DCFTabConfig(
      title: title,
      icon: {
        'type': 'package',
        'package': package,
        'name': iconName,
        if (size != null) 'size': size,
        if (tintColor != null) 'tintColor': '#${tintColor.value.toRadixString(16).padLeft(8, '0')}',
        if (selectedTintColor != null) 'selectedTintColor': '#${selectedTintColor.value.toRadixString(16).padLeft(8, '0')}',
      },
      index: index,
      badge: badge,
      enabled: enabled,
    );
  }
}