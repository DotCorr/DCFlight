/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Component access tracking for store usage validation
class _ComponentAccess {
  final String componentId;
  final String componentType;
  final bool usedViaHook;
  final DateTime accessTime;
  
  _ComponentAccess({
    required this.componentId,
    required this.componentType,
    required this.usedViaHook,
    required this.accessTime,
  });
}

/// A store for global state management with usage pattern validation
class Store<T> {
  /// The current state
  T _state;

  /// List of listeners to notify on state change
  final List<void Function(T)> _listeners = [];
  
  /// Track component access patterns for validation
  final Map<String, _ComponentAccess> _componentAccess = {};
  
  /// Track if store has been accessed inconsistently
  bool _hasInconsistentUsage = false;

  /// Create a store with initial state
  Store(this._state);

  /// Get the current state (with usage tracking)
  T get state {
    _trackDirectAccess();
    return _state;
  }

  /// Update the state
  void setState(T newState) {
    _trackDirectAccess();
    
    // Skip update if state is identical (for references) or equal (for values)
    if (identical(_state, newState) || _state == newState) {
      return;
    }

    if (kDebugMode) {
      developer.log('Store updated: from $_state to $newState', name: 'Store');
    }

    // Update state
    _state = newState;

    // Notify listeners
    _notifyListeners();
  }

  /// Update the state using a function
  void updateState(T Function(T) updater) {
    _trackDirectAccess();
    setState(updater(_state));
  }

  /// Register a listener (used by hooks)
  void subscribe(void Function(T) listener) {
    // Prevent duplicate listeners for the same function
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      if (kDebugMode) {
        developer.log('Store listener added. Total listeners: ${_listeners.length}', name: 'Store');
      }
    } else {
      if (kDebugMode) {
        developer.log('Duplicate listener prevented', name: 'Store');
      }
    }
  }

  /// Track hook-based access (called from StoreHook)
  void trackHookAccess(String componentId, String componentType) {
    final access = _ComponentAccess(
      componentId: componentId,
      componentType: componentType,
      usedViaHook: true,
      accessTime: DateTime.now(),
    );
    
    final existingAccess = _componentAccess[componentId];
    if (existingAccess != null && !existingAccess.usedViaHook) {
      _warnInconsistentUsage(componentId, componentType, 'switched from direct access to hook');
    }
    
    _componentAccess[componentId] = access;
  }

  /// Track direct access (when .state or .setState is called directly)
  void _trackDirectAccess() {
    if (!kDebugMode) return;
    
    // Get current component from stack trace
    final stackTrace = StackTrace.current;
    final componentInfo = _extractComponentFromStackTrace(stackTrace);
    
    if (componentInfo != null) {
      final (componentId, componentType) = componentInfo;
      
      final access = _ComponentAccess(
        componentId: componentId,
        componentType: componentType,
        usedViaHook: false,
        accessTime: DateTime.now(),
      );
      
      final existingAccess = _componentAccess[componentId];
      if (existingAccess != null && existingAccess.usedViaHook) {
        _warnInconsistentUsage(componentId, componentType, 'switched from hook to direct access');
      }
      
      _componentAccess[componentId] = access;
      
      // Check for mixed usage patterns across components
      _validateUsagePatterns();
    }
  }

  /// Extract component information from stack trace
  (String, String)? _extractComponentFromStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    
    for (final line in lines) {
      // Look for component render methods, build methods, or component class patterns
      if (line.contains('.render') || 
          line.contains('.build') || 
          line.contains('Component.') ||
          line.contains('.setState') ||
          line.contains('.state')) {
        
        // Extract component type from various patterns
        final patterns = [
          RegExp(r'(\w+Component)\.'),  // SomeComponent.method
          RegExp(r'(\w+Component)\s'),  // SomeComponent space
          RegExp(r'/(\w+Component)'),   // /SomeComponent in path
        ];
        
        for (final pattern in patterns) {
          final match = pattern.firstMatch(line);
          if (match != null) {
            final componentType = match.group(1)!;
            // Create a simple ID based on component type and current time
            final componentId = '${componentType}_${_componentIdCounter++}';
            return (componentId, componentType);
          }
        }
      }
    }
    return null;
  }
  
  /// Counter for generating unique component IDs
  static int _componentIdCounter = 0;

  /// Warn about inconsistent usage patterns
  void _warnInconsistentUsage(String componentId, String componentType, String reason) {
    if (_hasInconsistentUsage) return; // Only warn once
    
    _hasInconsistentUsage = true;
    
    developer.log(
      '''
⚠️  STORE USAGE INCONSISTENCY DETECTED ⚠️
Component: $componentType ($componentId)
Issue: $reason

RECOMMENDATION:
Choose ONE consistent pattern for ALL stores in your component:

✅ RECOMMENDED - Use hooks for reactive updates:
  final myStore = useStore(myStoreInstance);
  myStore.state        // Get value
  myStore.setState()   // Update value

❌ AVOID - Direct access (no automatic re-renders):
  myStoreInstance.state        // Get value
  myStoreInstance.setState()   // Update value

Mixed patterns can cause confusing bugs where some UI updates work and others don't.
      ''',
      name: 'StoreUsageValidator'
    );
  }

  /// Validate usage patterns across all components
  void _validateUsagePatterns() {
    final hookComponents = <String>[];
    final directComponents = <String>[];
    
    for (final entry in _componentAccess.entries) {
      if (entry.value.usedViaHook) {
        hookComponents.add(entry.value.componentType);
      } else {
        directComponents.add(entry.value.componentType);
      }
    }
    
    if (hookComponents.isNotEmpty && directComponents.isNotEmpty && !_hasInconsistentUsage) {
      _hasInconsistentUsage = true;
      
      developer.log(
        '''
⚠️  MIXED STORE USAGE PATTERNS DETECTED ⚠️

Components using hooks: ${hookComponents.join(', ')}
Components using direct access: ${directComponents.join(', ')}

RECOMMENDATION:
Use hooks (useStore) in ALL components for consistent reactive behavior.
        ''',
        name: 'StoreUsageValidator'
      );
    }
  }

  /// Unregister a listener
  void unsubscribe(void Function(T) listener) {
    final removed = _listeners.remove(listener);
    if (removed) {
      developer.log('Store listener removed. Total listeners: ${_listeners.length}', name: 'Store');
    }
  }

  /// Notify all listeners of state change
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_state);
    }
  }
}

/// Store registry for managing global stores
class StoreRegistry {
  /// Singleton instance
  static final StoreRegistry instance = StoreRegistry._();

  /// Private constructor for singleton
  StoreRegistry._();

  /// Map of stores by ID
  final Map<String, Store<dynamic>> _stores = {};

  /// Register a store with a unique ID
  void registerStore<T>(String id, Store<T> store) {
    if (_stores.containsKey(id)) {
      developer.log('Store with ID $id already exists, replacing', name: 'StoreRegistry');
    }
    _stores[id] = store;
  }

  /// Get a store by ID
  Store<T>? getStore<T>(String id) {
    final store = _stores[id];
    if (store == null) {
      return null;
    }
    
    if (store is Store<T>) {
      return store;
    } else {
      developer.log('Store with ID $id is not of type Store<$T>', name: 'StoreRegistry');
      return null;
    }
  }

  /// Remove a store
  void removeStore(String id) {
    _stores.remove(id);
  }

  /// Create and register a store in one step
  Store<T> createStore<T>(String id, T initialState) {
    final store = Store<T>(initialState);
    registerStore(id, store);
    return store;
  }
}

/// Helper functions for working with stores
class StoreHelpers {
  /// Create a new store
  static Store<T> createStore<T>(T initialState) {
    return Store<T>(initialState);
  }
  
  /// Create and register a global store
  static Store<T> createGlobalStore<T>(String id, T initialState) {
    return StoreRegistry.instance.createStore(id, initialState);
  }
  
  /// Get a global store by ID
  static Store<T>? getGlobalStore<T>(String id) {
    return StoreRegistry.instance.getStore<T>(id);
  }
}
