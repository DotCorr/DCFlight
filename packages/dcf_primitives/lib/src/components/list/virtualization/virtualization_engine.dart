/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'viewport_calculator.dart';
import 'component_recycler.dart';
import 'layout_estimator.dart';
import 'performance_monitor.dart';
import 'types.dart';

/// Current state of the virtualization system
class VirtualizationState<T> {
  final List<T> data;
  final double scrollOffset;
  final IndexRange visibleRange;
  final IndexRange renderRange;
  final IndexRange bufferRange;
  final DateTime timestamp;
  
  const VirtualizationState({
    required this.data,
    required this.scrollOffset,
    required this.visibleRange,
    required this.renderRange,
    required this.bufferRange,
    required this.timestamp,
  });
}

/// 🚀 CORE VIRTUALIZATION ENGINE - Fixed for proper incremental rendering
class VirtualizationEngine<T> {
  static const String _logPrefix = '[VirtualizationEngine]';
  
  // Core subsystems
  late final ViewportCalculator _viewportCalculator;
  late final ComponentRecycler<T> _componentRecycler;
  late final LayoutEstimator _layoutEstimator;
  late final PerformanceMonitor _performanceMonitor;
  
  // Current state
  double _currentScrollOffset = 0;
  double _viewportHeight = 600.0;
  double _viewportWidth = 400.0;
  List<T> _data = [];
  bool _isHorizontal = false;
  
  // Active render state
  VirtualizationState<T>? _currentState;
  bool _isInitialized = false;
  
  // Performance configuration
  final VirtualizationConfig _config;
  
  VirtualizationEngine({VirtualizationConfig? config}) 
    : _config = config ?? VirtualizationConfig() {
    _initializeSubsystems();
  }
  
  void _initializeSubsystems() {
    _viewportCalculator = ViewportCalculator(config: _config);
    _componentRecycler = ComponentRecycler<T>(config: _config);
    _layoutEstimator = LayoutEstimator(
      config: _config,
      estimatedItemSize: _config.defaultEstimatedItemSize,
    );
    _performanceMonitor = PerformanceMonitor(enabled: _config.enablePerformanceMonitoring);
    
    if (_config.debug) {
      print('$_logPrefix Initialized with config: windowSize=${_config.windowSize}, defaultItemSize=${_config.defaultEstimatedItemSize}');
    }
  }
  
  /// Initialize the engine with list configuration
  void initialize({
    required List<T> data,
    required double viewportHeight,
    required double viewportWidth,
    required bool isHorizontal,
    double? estimatedItemSize,
    String Function(T item, int index)? getItemType,
  }) {
    _performanceMonitor.startFrame();
    
    _data = data;
    _viewportHeight = viewportHeight;
    _viewportWidth = viewportWidth;
    _isHorizontal = isHorizontal;
    
    // Configure component recycler for item types
    if (getItemType != null) {
      _componentRecycler.configureItemTypes(data, getItemType);
    }
    
    // Force initial state calculation
    _currentState = _calculateVirtualizationState();
    _isInitialized = true;
    
    if (_config.debug) {
      print('$_logPrefix Initialized - Data: ${data.length}, Viewport: ${viewportWidth}x${viewportHeight}');
      print('$_logPrefix Initial state: ${_currentState?.renderRange}');
    }
    
    _performanceMonitor.endFrame();
  }
  
  /// Update scroll position and recalculate visible items
  void updateScrollPosition(double scrollOffset) {
    if (!_isInitialized) {
      if (_config.debug) {
        print('$_logPrefix Cannot update scroll - not initialized');
      }
      return;
    }
    
    _performanceMonitor.startFrame();
    _currentScrollOffset = scrollOffset;
    
    // Always recalculate state on scroll
    final newState = _calculateVirtualizationState();
    
    // Update if there's any change in render range or if state is null
    if (_shouldUpdateState(newState)) {
      final oldRange = _currentState?.renderRange;
      _currentState = newState;
      
      if (_config.debug) {
        print('$_logPrefix Scroll update - Offset: $scrollOffset');
        print('$_logPrefix Range changed from $oldRange to ${newState.renderRange}');
        print('$_logPrefix Visible: ${newState.visibleRange}, Buffer: ${newState.bufferRange}');
      }
      
      // Release components outside the new buffer range
      _componentRecycler.releaseComponentsOutsideRange(newState.bufferRange);
    }
    
    _performanceMonitor.endFrame();
  }
  
  /// Build the virtualized children list for rendering - FIXED VERSION
  List<DCFComponentNode> buildVirtualizedChildren<TItem>({
    required List<TItem> data,
    required DCFComponentNode Function(TItem item, int index) renderItem,
    String Function(TItem item, int index)? getItemType,
    DCFComponentNode? header,
    DCFComponentNode? footer,
    DCFComponentNode? separator,
    DCFComponentNode? empty,
  }) {
    _performanceMonitor.startFrame();
    
    if (!_isInitialized || data.isEmpty) {
      _performanceMonitor.endFrame();
      return _buildEmptyState(empty);
    }
    
    final state = _currentState ?? _calculateVirtualizationState();
    final children = <DCFComponentNode>[];
    
    if (_config.debug) {
      print('$_logPrefix Building children for range ${state.renderRange} (${state.renderRange.length} items)');
    }
    
    // Add header if present and we're at the top
    if (header != null && state.renderRange.start == 0) {
      children.add(_wrapWithVirtualization(header, -1, 'header'));
    }
    
    // Build virtualized items within the render range
    int renderedCount = 0;
    for (int index = state.renderRange.start; index < state.renderRange.end; index++) {
      if (index >= 0 && index < data.length) {
        final item = data[index];
        final itemType = getItemType?.call(item, index) ?? 'default';
        
        try {
          // Get or create component from recycler
          final component = _componentRecycler.acquireComponent(
            index: index,
            itemType: itemType,
            builder: () => renderItem(item, index),
            data: item as T, // Safe cast since TItem extends T in this context
          );
          
          children.add(_wrapWithVirtualization(component, index, itemType));
          renderedCount++;
          
          // Add separator between items (not after last item)
          if (separator != null && index < data.length - 1 && index < state.renderRange.end - 1) {
            children.add(_wrapWithVirtualization(separator, index + 0.5, 'separator'));
          }
          
        } catch (e) {
          if (_config.debug) {
            print('$_logPrefix Error rendering item $index: $e');
          }
        }
      }
    }
    
    // Add footer if present and we're at the bottom
    if (footer != null && state.renderRange.end >= data.length) {
      children.add(_wrapWithVirtualization(footer, data.length, 'footer'));
    }
    
    // Update performance metrics
    _performanceMonitor.recordRenderCount(renderedCount);
    _performanceMonitor.endFrame();
    
    if (_config.debug) {
      print('$_logPrefix Built ${children.length} children (${renderedCount} items rendered)');
    }
    
    return children;
  }
  
  /// Calculate current virtualization state - IMPROVED VERSION
  VirtualizationState<T> _calculateVirtualizationState() {
    if (_data.isEmpty) {
      return VirtualizationState<T>(
        data: _data,
        scrollOffset: _currentScrollOffset,
        visibleRange: const IndexRange(0, 0),
        renderRange: const IndexRange(0, 0),
        bufferRange: const IndexRange(0, 0),
        timestamp: DateTime.now(),
      );
    }
    
    // Get item sizes from layout estimator
    final itemSizes = List.generate(_data.length, (index) => 
      _layoutEstimator.getItemSize(index)
    );
    
    // Calculate visible range
    final visibleRange = _viewportCalculator.calculateVisibleRange(
      scrollOffset: _currentScrollOffset,
      viewportSize: _isHorizontal ? _viewportWidth : _viewportHeight,
      itemSizes: itemSizes,
      isHorizontal: _isHorizontal,
    );
    
    // Calculate render range with buffer
    final renderRange = _viewportCalculator.calculateRenderRange(
      visibleRange: visibleRange,
      itemCount: _data.length,
      windowSize: _config.windowSize,
    );
    
    // Calculate extended buffer range
    final bufferRange = _viewportCalculator.calculateBufferRange(
      renderRange: renderRange,
      itemCount: _data.length,
      windowSize: _config.windowSize,
    );
    
    return VirtualizationState<T>(
      data: _data,
      scrollOffset: _currentScrollOffset,
      visibleRange: visibleRange,
      renderRange: renderRange,
      bufferRange: bufferRange,
      timestamp: DateTime.now(),
    );
  }
  
  /// Check if state update is necessary - IMPROVED VERSION
  bool _shouldUpdateState(VirtualizationState<T> newState) {
    if (_currentState == null) return true;
    
    // Always update if visible range changed
    if (_currentState!.visibleRange != newState.visibleRange) {
      return true;
    }
    
    // Update if render range changed significantly
    final currentRange = _currentState!.renderRange;
    final newRange = newState.renderRange;
    
    // Use smaller threshold for more responsive updates
    const threshold = 1; // Update even with small changes
    
    return (newRange.start - currentRange.start).abs() > threshold ||
           (newRange.end - currentRange.end).abs() > threshold;
  }
  
  /// Wrap component with virtualization metadata
  DCFComponentNode _wrapWithVirtualization(
    DCFComponentNode component, 
    dynamic index, 
    String itemType
  ) {
    // Store virtualization metadata directly on the component
    if (component is DCFElement) {
      component.props['_virtualIndex'] = index;
      component.props['_itemType'] = itemType;
      component.props['_recycled'] = _componentRecycler.isRecycled(index);
      
      if (_config.debug) {
        component.props['_debugInfo'] = {
          'renderTime': DateTime.now().millisecondsSinceEpoch,
          'scrollOffset': _currentScrollOffset,
        };
      }
    }
    
    return component;
  }
  
  /// Build empty state
  List<DCFComponentNode> _buildEmptyState(DCFComponentNode? empty) {
    if (empty != null) {
      return [_wrapWithVirtualization(empty, -1, 'empty')];
    }
    return [];
  }
  
  /// Record item measurement for layout estimation
  void recordItemMeasurement(int index, double size, [String? itemType]) {
    _layoutEstimator.recordMeasurement(index, size, itemType: itemType);
    
    if (_config.debug) {
      print('$_logPrefix Recorded measurement - Index: $index, Size: $size, Type: $itemType');
    }
    
    // Trigger re-calculation if this affects visible items
    if (_currentState != null && _currentState!.visibleRange.contains(index)) {
      final newState = _calculateVirtualizationState();
      if (_shouldUpdateState(newState)) {
        _currentState = newState;
      }
    }
  }
  
  /// Get performance metrics
  PerformanceMetrics getPerformanceMetrics() {
    return _performanceMonitor.getMetrics();
  }
  
  /// Get current state for debugging
  VirtualizationState<T>? get currentState => _currentState;
  
  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'scrollOffset': _currentScrollOffset,
      'viewportSize': {'width': _viewportWidth, 'height': _viewportHeight},
      'dataLength': _data.length,
      'currentState': _currentState != null ? {
        'visibleRange': _currentState!.visibleRange.toString(),
        'renderRange': _currentState!.renderRange.toString(),
        'bufferRange': _currentState!.bufferRange.toString(),
      } : null,
      'config': {
        'windowSize': _config.windowSize,
        'defaultItemSize': _config.defaultEstimatedItemSize,
        'debug': _config.debug,
      }
    };
  }
  
  /// Dispose resources
  void dispose() {
    _componentRecycler.dispose();
    _performanceMonitor.dispose();
    _currentState = null;
    _isInitialized = false;
    
    if (_config.debug) {
      print('$_logPrefix Disposed');
    }
  }
}