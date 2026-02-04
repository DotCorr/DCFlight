/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Extension Registry (stub) — kept for API compatibility, no-op in pure signals engine.
 */

import '../../../src/components/component.dart';
import '../../hooks/state_hook.dart';

/// Stub registry for extension points. No-op in pure signals engine (no VDOM prop diffing).
/// Kept for backward compatibility with dcf_reanimated and other packages.
class VDomExtensionRegistry {
  static final VDomExtensionRegistry _instance = VDomExtensionRegistry._();
  static VDomExtensionRegistry get instance => _instance;
  VDomExtensionRegistry._();

  /// Register a prop diff interceptor (no-op, prop diffing removed).
  void registerPropDiffInterceptor(dynamic interceptor) {
    // No-op: pure signals engine doesn't diff props
  }

  /// Get hook factory by name (no-op, custom hooks not supported).
  dynamic getHookFactory(String hookName) => null;

  /// Register a hook factory (no-op).
  void registerHookFactory(String hookName, dynamic factory) {
    // No-op: use built-in hooks (useState, useEffect, etc)
  }
}

/// Hook factory interface (stub)
abstract class HookFactory {
  Hook createHook(DCFStatefulComponent component, List<dynamic> args);
}
