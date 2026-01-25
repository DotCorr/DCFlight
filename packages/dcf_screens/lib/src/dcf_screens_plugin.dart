/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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