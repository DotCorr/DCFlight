/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */



/// Base class for DCFlight plugins
abstract class DCFPlugin {
  /// The name of the plugin
  String get name;
  
  /// Priority for initialization order (lower numbers initialize first)
  int get priority => 100; // Default priority
  
  /// Initialize the plugin
  void initialize() {
    registerComponents();
  }
  
  /// Register components provided by this plugin
  void registerComponents();
}

/// Registry for plugins
class PluginRegistry {
  /// Singleton instance
  static final PluginRegistry instance = PluginRegistry._();
  
  /// Private constructor for singleton
  PluginRegistry._();
  
  /// Map of registered plugins
  final Map<String, DCFPlugin> _plugins = {};
  
  /// Register a plugin
  void registerPlugin(DCFPlugin plugin) {
    _plugins[plugin.name] = plugin;
    
    plugin.initialize();
  }
  
  /// Get a plugin by name
  T? getPlugin<T extends DCFPlugin>(String name) {
    final plugin = _plugins[name];
    if (plugin is T) {
      return plugin;
    }
    return null;
  }
  
  /// Check if a plugin is registered
  bool hasPlugin(String name) {
    return _plugins.containsKey(name);
  }
  
  /// Get all registered plugins
  List<DCFPlugin> get plugins => _plugins.values.toList();
}

/// Core plugin that provides basic components
class CorePlugin extends DCFPlugin {
  /// Singleton instance
  static final CorePlugin instance = CorePlugin._();
  
  /// Private constructor for singleton
  CorePlugin._();
  
  @override
  String get name => 'core';
  
  @override
  int get priority => 0; // Highest priority
  
  @override
  void registerComponents() {
  }
}