/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/components/component.dart';
import 'package:dcflight/framework/components/component_node.dart';
import 'package:dcflight/framework/context/context.dart';
import 'package:dcflight/framework/context/context_provider.dart';
import 'package:dcflight/framework/hooks/state_hook.dart';

/// Hook for consuming a context value
class ContextHook<T> extends Hook {
  /// The context to consume
  final DCFContext<T> context;
  
  /// The current value from the context
  T? _value;
  
  /// Whether we found a provider
  bool _hasProvider = false;
  
  /// Create a context hook
  ContextHook(this.context, DCFStatefulComponent component) {
    _findContextValue(component);
  }
  
  /// Find the context value by walking up the tree
  void _findContextValue(DCFStatefulComponent component) {
    // Start from the component's parent and walk up the tree
    DCFComponentNode? current = component.parent;
    
    while (current != null) {
      // Check if current node is a context provider component
      if (current is DCFContextProvider) {
        final provider = current;
        if (provider.context == context) {
          _value = provider.value as T;
          _hasProvider = true;
          return;
        }
      }
      
      // Walk up the tree
      current = current.parent;
    }
    
    // No provider found, use default value
    _value = context.defaultValue;
    _hasProvider = false;
  }
  
  /// Get the current context value
  T get value {
    if (!_hasProvider && context.defaultValue == null) {
      throw Exception(
        'No provider found for context ${context}. '
        'Make sure ${context} is provided by a DCFContextProvider ancestor, '
        'or provide a defaultValue when creating the context.'
      );
    }
    return _value as T;
  }
  
  @override
  void dispose() {
    // Context hooks don't need cleanup
  }
}


