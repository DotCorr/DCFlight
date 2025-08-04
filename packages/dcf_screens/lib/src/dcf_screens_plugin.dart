/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import 'package:dcflight/dcflight.dart';

/// Plugin for DCFlight primitives
class DcfReanimatedPlugin extends DCFPlugin {
  /// Singleton instance
  static final DcfReanimatedPlugin instance = DcfReanimatedPlugin._();
  
  /// Private constructor for singleton
  DcfReanimatedPlugin._();
  
  @override
  String get name => 'dcf_screens';
  
  @override
  int get priority => 10; // Higher priority than default (100)
  
  @override
  void registerComponents() {
    // StatelessComponent-based primitives don't need explicit registration
    // since they work directly with the reconciler as Component instances.
    //
    // If we need to register factory methods in the future, we can use:
    // ComponentRegistry.instance.registerComponent('ComponentName', factoryFunction);
  }
}