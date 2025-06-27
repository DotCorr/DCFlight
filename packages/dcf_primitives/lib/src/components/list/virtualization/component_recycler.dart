/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:collection';
import 'package:dcflight/dcflight.dart';
import 'types.dart';

/// 🔄 COMPONENT RECYCLER - FlashList-style component reuse system
/// 
/// Provides massive performance gains by:
/// - Reusing existing components instead of creating new ones
/// - Type-based component pools for heterogeneous lists
/// - Intelligent pool management and cleanup
/// - State preservation during recycling
class ComponentRecycler<T> {
  static const String _logPrefix = '[ComponentRecycler]';
  
  final VirtualizationConfig config;
  
  // Component pools organized by type
  final Map<String, Queue<RecyclableComponent<T>>> _componentPools = {};
  final Map<String, int> _poolSizes = {};
  
  // Active components currently being used
  final Map<int, RecyclableComponent<T>> _activeComponents = {};
  
  // Statistics
  int _totalCreated = 0;
  int _totalRecycled = 0;
  int _totalDisposed = 0;
  
  ComponentRecycler({required this.config});
  
  /// Configure item types for heterogeneous lists
  void configureItemTypes<TItem>(
    List<TItem> data, 
    String Function(TItem item, int index) getItemType
  ) {
    final typeSet = <String>{};
    
    // Analyze data to discover all item types
    for (int i = 0; i < data.length; i++) {
      final itemType = getItemType(data[i], i);
      typeSet.add(itemType);
    }
    
    // Initialize pools for each type
    for (final itemType in typeSet) {
      _initializePool(itemType);
    }
    
    final isDebugMode = config.debug;
    if (isDebugMode) {
      print('$_logPrefix Configured ${typeSet.length} item types: $typeSet');
    }
  }
  
  /// Acquire a component for rendering (reuse if available, create if needed)
  DCFComponentNode acquireComponent({
    required int index,
    required String itemType,
    required DCFComponentNode Function() builder,
    required T data,
  }) {
    // Try to get from pool first
    final recycled = _acquireFromPool(itemType);
    
    if (recycled != null) {
      // Reuse existing component
      recycled.updateData(data, index);
      _activeComponents[index] = recycled;
      _totalRecycled++;
      
      if (_config.debugMode) {
        print('$_logPrefix Recycled component for index $index, type: $itemType');
      }
      
      return recycled.component;
    } else {
      // Create new component
      final component = builder();
      final recyclable = RecyclableComponent<T>(
        component: component,
        itemType: itemType,
        data: data,
        index: index,
        createdAt: DateTime.now(),
      );
      
      _activeComponents[index] = recyclable;
      _totalCreated++;
      
      if (_config.debugMode) {
        print('$_logPrefix Created new component for index $index, type: $itemType');
      }
      
      return component;
    }
  }
  
  /// Release component back to pool when no longer needed
  void releaseComponent(int index) {
    final component = _activeComponents.remove(index);
    if (component == null) return;
    
    final pool = _componentPools[component.itemType];
    if (pool == null) {
      _initializePool(component.itemType);
    }
    
    final currentPoolSize = _componentPools[component.itemType]!.length;
          final maxPoolSize = _poolSizes[component.itemType] ?? config.maxPoolSize;
    
    if (currentPoolSize < maxPoolSize) {
      // Prepare component for recycling
      component.prepareForRecycling();
      _componentPools[component.itemType]!.add(component);
      
      final isDebugMode = config.debug;
      if (isDebugMode) {
        print('$_logPrefix Released component index $index to pool (${component.itemType})');
      }
    } else {
      // Pool is full, dispose component
      component.dispose();
      _totalDisposed++;
      
      final isDebugMode2 = config.debug;
      if (isDebugMode2) {
        print('$_logPrefix Disposed component index $index - pool full (${component.itemType})');
      }
    }
  }
  
  /// Release components that are no longer in the render range
  void releaseComponentsOutsideRange(IndexRange renderRange) {
    final indicesToRelease = <int>[];
    
    for (final index in _activeComponents.keys) {
      if (!renderRange.contains(index)) {
        indicesToRelease.add(index);
      }
    }
    
    for (final index in indicesToRelease) {
      releaseComponent(index);
    }
    
    final isDebugMode = config.debug;
    if (isDebugMode && indicesToRelease.isNotEmpty) {
      print('$_logPrefix Released ${indicesToRelease.length} components outside range $renderRange');
    }
  }
  
  /// Get component from pool
  RecyclableComponent<T>? _acquireFromPool(String itemType) {
    final pool = _componentPools[itemType];
    if (pool == null || pool.isEmpty) {
      return null;
    }
    
    return pool.removeFirst();
  }
  
  /// Initialize pool for a specific item type
  void _initializePool(String itemType) {
    if (_componentPools.containsKey(itemType)) return;
    
    _componentPools[itemType] = Queue<RecyclableComponent<T>>();
    _poolSizes[itemType] = config.maxPoolSize;
    
    final isDebugMode = config.debug;
    if (isDebugMode) {
      print('$_logPrefix Initialized pool for type: $itemType');
    }
  }
  
  /// Check if component at index is recycled
  bool isRecycled(dynamic index) {
    if (index is! int) return false;
    final component = _activeComponents[index];
    return component?.isRecycled ?? false;
  }
  
  /// Force cleanup of unused components
  void cleanup() {
    int cleanedCount = 0;
    
    for (final pool in _componentPools.values) {
      while (pool.isNotEmpty) {
        final component = pool.removeFirst();
        component.dispose();
        cleanedCount++;
      }
    }
    
    _totalDisposed += cleanedCount;
    
    final isDebugMode = config.debug;
    if (isDebugMode) {
      print('$_logPrefix Cleaned up $cleanedCount components');
    }
  }
  
  /// Optimize pools by adjusting sizes based on usage patterns
  void optimizePools() {
    for (final entry in _componentPools.entries) {
      final itemType = entry.key;
      final pool = entry.value;
      
      // Analyze usage patterns
      final currentSize = pool.length;
      final maxSize = _poolSizes[itemType] ?? _config.maxPoolSize;
      
      // If pool is consistently empty, reduce max size
      if (currentSize == 0 && maxSize > 5) {
        _poolSizes[itemType] = (maxSize * 0.8).round();
      }
      // If pool is consistently full, increase max size (within limits)
      else if (currentSize == maxSize && maxSize < config.maxPoolSize * 2) {
        _poolSizes[itemType] = (maxSize * 1.2).round();
      }
    }
    
    final isDebugMode = config.debug;
    if (isDebugMode) {
      print('$_logPrefix Optimized pools - sizes: $_poolSizes');
    }
  }
  
  /// Get memory usage statistics
  ComponentRecyclerStats getStats() {
    final poolSizes = <String, int>{};
    final activeByType = <String, int>{};
    
    for (final entry in _componentPools.entries) {
      poolSizes[entry.key] = entry.value.length;
    }
    
    for (final component in _activeComponents.values) {
      final type = component.itemType;
      activeByType[type] = (activeByType[type] ?? 0) + 1;
    }
    
    return ComponentRecyclerStats(
      totalCreated: _totalCreated,
      totalRecycled: _totalRecycled,
      totalDisposed: _totalDisposed,
      activeComponents: _activeComponents.length,
      poolSizes: poolSizes,
      activeByType: activeByType,
      recycleRatio: _totalRecycled / (_totalCreated + _totalRecycled),
    );
  }
  
  /// Dispose all resources
  void dispose() {
    // Dispose all active components
    for (final component in _activeComponents.values) {
      component.dispose();
    }
    _activeComponents.clear();
    
    // Dispose all pooled components
    for (final pool in _componentPools.values) {
      while (pool.isNotEmpty) {
        pool.removeFirst().dispose();
      }
    }
    _componentPools.clear();
    _poolSizes.clear();
    
    final isDebugMode = config.debug;
    if (isDebugMode) {
      print('$_logPrefix Disposed all components - Stats: ${getStats()}');
    }
  }
}

/// Wrapper for recyclable components
class RecyclableComponent<T> {
  DCFComponentNode component;
  final String itemType;
  T data;
  int index;
  final DateTime createdAt;
  DateTime? lastRecycledAt;
  bool _isDisposed = false;
  
  RecyclableComponent({
    required this.component,
    required this.itemType,
    required this.data,
    required this.index,
    required this.createdAt,
  });
  
  /// Update component data during recycling
  void updateData(T newData, int newIndex) {
    if (_isDisposed) return;
    
    data = newData;
    index = newIndex;
    lastRecycledAt = DateTime.now();
  }
  
  /// Prepare component for recycling (clear sensitive state)
  void prepareForRecycling() {
    if (_isDisposed) return;
    
    // Mark as recycled
    lastRecycledAt = DateTime.now();
    
    // TODO: Reset any component-specific state if needed
    // This is where you would clear animations, focus state, etc.
  }
  
  /// Check if this component has been recycled
  bool get isRecycled => lastRecycledAt != null;
  
  /// Get age of component
  Duration get age => DateTime.now().difference(createdAt);
  
  /// Get time since last recycle
  Duration? get timeSinceRecycle {
    final recycleTime = lastRecycledAt;
    return recycleTime != null ? DateTime.now().difference(recycleTime) : null;
  }
  
  /// Dispose component resources
  void dispose() {
    _isDisposed = true;
    // Component disposal is handled by the framework
  }
}

/// Statistics for component recycling performance
class ComponentRecyclerStats {
  final int totalCreated;
  final int totalRecycled;
  final int totalDisposed;
  final int activeComponents;
  final Map<String, int> poolSizes;
  final Map<String, int> activeByType;
  final double recycleRatio;
  
  const ComponentRecyclerStats({
    required this.totalCreated,
    required this.totalRecycled,
    required this.totalDisposed,
    required this.activeComponents,
    required this.poolSizes,
    required this.activeByType,
    required this.recycleRatio,
  });
  
  @override
  String toString() {
    return 'ComponentRecyclerStats('
           'created: $totalCreated, '
           'recycled: $totalRecycled, '
           'disposed: $totalDisposed, '
           'active: $activeComponents, '
           'recycleRatio: ${(recycleRatio * 100).toStringAsFixed(1)}%, '
           'pools: $poolSizes)';
  }
}