/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import 'package:dcflight/dcflight.dart';

/// Plugin for DCFlight module.
/// 
/// Register your module components here if needed.
class DcfModulePlugin extends DCFPlugin {
  /// Singleton instance
  static final DcfModulePlugin instance = DcfModulePlugin._();
  
  /// Private constructor for singleton
  DcfModulePlugin._();
  
  @override
  String get name => 'dcf_module';
  
  @override
  int get priority => 10;
  
  @override
  void registerComponents() {
    // Register your module components here if needed.
    // StatelessComponent-based components don't need explicit registration
    // since they work directly with the reconciler as Component instances.
    //
    // If you need to register factory methods, use:
    // ComponentRegistry.instance.registerComponent('ComponentName', factoryFunction);
  }
}