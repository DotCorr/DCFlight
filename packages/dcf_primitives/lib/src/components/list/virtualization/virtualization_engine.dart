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
import 'render_scheduler.dart';
import 'performance_monitor.dart';

/// 🚀 CORE VIRTUALIZATION ENGINE - The brain of high-performance list rendering
/// 
/// This engine orchestrates all virtualization subsystems to achieve:
/// - 60+ FPS on all devices
/// - Zero blank spaces during scrolling  
/// - Memory efficient component recycling
/// - Intelligent buffering and pre-rendering
class VirtualizationEngine<T> {
  static const String _logPrefix = '[VirtualizationEngine]';
  
  // Core subsystems
  late final ViewportCalculator _viewportCalculator;
  late final ComponentRecycler<T> _componentRecycler;
  late final LayoutEstimator _layoutEstimator;
  late final RenderScheduler _renderScheduler;
  late final PerformanceMonitor _performanceMonitor;
  
  // Current state
  double _currentScrollOffset = 0;
  double _viewportHeight = 0;
  double _viewportWidth = 0;
  List<T> _data = [];
  bool _isHorizontal = false;
  
  // Active render state
  VirtualizationState<T>? _currentState;
  bool _isInitialized = false;
  
  // Performance configuration
  final VirtualizationConfig _config;
  
  VirtualizationEngine({VirtualizationConfig? config}) 
    : _config = config ?? VirtualizationConfig.defaultConfig() {
    _initializeSubsystems();
  }
  
  void _initializeSubsystems() {
    _viewportCalculator = ViewportCalculator(config: _config);
    _componentRecycler = ComponentRecycler<T>(config: _config);
    _layoutEstimator = LayoutEstimator(config: _config);
    _renderScheduler = RenderScheduler(config: _config);
    _performanceMonitor = PerformanceMonitor(enabled: _config.enablePerformanceMonitoring);
    
    if (_config.debugMode) {
      print('$_logPrefix Initialized with config: ${_config.toString()}');
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
    
    // Initialize layout estimator with data
    _layoutEstimator.initialize(
      itemCount: data.length,
      estimatedItemSize: estimatedItemSize ?? _config.defaultEstimatedItemSize,
      isHorizontal: isHorizontal,
    );
    
    // Configure component recycler for item types
    if (getItemType != null) {
      _componentRecycler.configureItemTypes(data, getItemType);
    }
    
    _isInitialized = true;
    
    if (_config.debugMode) {
      print('$_logPrefix Initialized - Data: ${data.length}, Viewport: ${viewportWidth}x${viewportHeight}');
    }
    
    _performanceMonitor.endFrame();
  }
  
  /// Update scroll position and recalculate visible items
  void updateScrollPosition(double scrollOffset) {
    if (!_isInitialized) return;
    
    _performanceMonitor.startFrame();
    _currentScrollOffset = scrollOffset;
    
    // Calculate new viewport state
    final newState = _calculateVirtualizationState();
    
    // Only update if state changed significantly
    if (_shouldUpdateState(newState)) {
      _currentState = newState;
      
      // Schedule render updates
      _renderScheduler.scheduleUpdate(newState);
      
      if (_config.debugMode) {
        print('$_logPrefix Scroll update - Offset: $scrollOffset, Visible: ${newState.visibleRange}');
      }
    }
    
    _performanceMonitor.endFrame();
  }
  
  /// Build the virtualized children list for rendering
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
    
    final children = <DCFComponentNode>[];
    
    // Add header
    if (header != null) {
      children.add(_wrapWithVirtualization(header, -1, 'header'));
    }
    
    // Build virtualized items
    final state = _currentState ?? _calculateVirtualizationState();
    
    for (int index = state.renderRange.start; index < state.renderRange.end; index++) {
      if (index >= 0 && index < data.length) {
        final item = data[index];
        final itemType = getItemType?.call(item, index) ?? 'default';
        
        // Get or create component from recycler
        final component = _componentRecycler.acquireComponent(
          index: index,
          itemType: itemType,
          builder: () => renderItem(item, index),
          data: item,
        );
        
        children.add(_wrapWithVirtualization(component, index, itemType));
        
        // Add separator
        if (separator != null && index < data.length - 1) {
          children.add(_wrapWithVirtualization(separator, index + 0.5, 'separator'));
        }
      }
    }
    
    // Add footer
    if (footer != null) {
      children.add(_wrapWithVirtualization(footer, data.length, 'footer'));
    }
    
    // Update performance metrics
    _performanceMonitor.recordRenderCount(children.length);
    _performanceMonitor.endFrame();
    
    if (_config.debugMode) {
      print('$_logPrefix Built ${children.length} children (${state.renderRange.end - state.renderRange.start} items)');
    }
    
    return children;
  }
  
  /// Calculate current virtualization state
  VirtualizationState<T> _calculateVirtualizationState() {
    final visibleRange = _viewportCalculator.calculateVisibleRange(
      scrollOffset: _currentScrollOffset,
      viewportSize: _isHorizontal ? _viewportWidth : _viewportHeight,
      itemSizes: _layoutEstimator.getAllItemSizes(),
      isHorizontal: _isHorizontal,
    );
    
    final renderRange = _viewportCalculator.calculateRenderRange(
      visibleRange: visibleRange,
      itemCount: _data.length,
      windowSize: _config.windowSize,
    );
    
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
  
  /// Check if state update is necessary
  bool _shouldUpdateState(VirtualizationState<T> newState) {
    if (_currentState == null) return true;
    
    // Update if render range changed significantly
    final currentRange = _currentState!.renderRange;
    final newRange = newState.renderRange;
    
    return (newRange.start - currentRange.start).abs() > _config.renderThreshold ||
           (newRange.end - currentRange.end).abs() > _config.renderThreshold;
  }
  
  /// Wrap component with virtualization metadata
  DCFComponentNode _wrapWithVirtualization(
    DCFComponentNode component, 
    dynamic index, 
    String itemType
  ) {
    // Add virtualization metadata for debugging and optimization
    return DCFElement(
      type: 'VirtualizedItem',
      props: {
        'virtualIndex': index,
        'itemType': itemType,
        'recycled': _componentRecycler.isRecycled(index),
        if (_config.debugMode) 'debugInfo': {
          'renderTime': DateTime.now().millisecondsSinceEpoch,
          'scrollOffset': _currentScrollOffset,
        },
      },
      children: [component],
    );
  }
  
  /// Build empty state
  List<DCFComponentNode> _buildEmptyState(DCFComponentNode? empty) {
    if (empty != null) {
      return [_wrapWithVirtualization(empty, -1, 'empty')];
    }
    return [];
  }
  
  /// Record item measurement for layout estimation
  void recordItemMeasurement(int index, double size, String? itemType) {
    _layoutEstimator.recordMeasurement(index, size, itemType);
    
    if (_config.debugMode) {
      print('$_logPrefix Recorded measurement - Index: $index, Size: $size, Type: $itemType');
    }
  }
  
  /// Get performance metrics
  PerformanceMetrics getPerformanceMetrics() {
    return _performanceMonitor.getMetrics();
  }
  
  /// Dispose resources
  void dispose() {
    _componentRecycler.dispose();
    _performanceMonitor.dispose();
    _currentState = null;
    _isInitialized = false;
    
    if (_config.debugMode) {
      print('$_logPrefix Disposed');
    }
  }
}

/// Configuration for virtualization behavior
class VirtualizationConfig {
  final double windowSize;
  final int renderThreshold;
  final double defaultEstimatedItemSize;
  final int maxComponentPoolSize;
  final bool enablePerformanceMonitoring;
  final bool debugMode;
  final Duration frameBudget;
  final int maxRenderBatchSize;
  
  const VirtualizationConfig({
    this.windowSize = 21.0,
    this.renderThreshold = 2,
    this.defaultEstimatedItemSize = 50.0,
    this.maxComponentPoolSize = 20,
    this.enablePerformanceMonitoring = false,
    this.debugMode = false,
    this.frameBudget = const Duration(milliseconds: 8),
    this.maxRenderBatchSize = 10,
  });
  
  factory VirtualizationConfig.defaultConfig() => const VirtualizationConfig();
  
  factory VirtualizationConfig.highPerformance() => const VirtualizationConfig(
    windowSize: 15.0,
    renderThreshold: 1,
    maxComponentPoolSize: 30,
    frameBudget: Duration(milliseconds: 6),
    maxRenderBatchSize: 15,
  );
  
  factory VirtualizationConfig.debug() => const VirtualizationConfig(
    enablePerformanceMonitoring: true,
    debugMode: true,
  );
  
  @override
  String toString() {
    return 'VirtualizationConfig(windowSize: $windowSize, renderThreshold: $renderThreshold, '
           'estimatedItemSize: $defaultEstimatedItemSize, debugMode: $debugMode)';
  }
}

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

/// Range of indices
class IndexRange {
  final int start;
  final int end;
  
  const IndexRange(this.start, this.end);
  
  int get length => end - start;
  bool get isEmpty => start >= end;
  
  bool contains(int index) => index >= start && index < end;
  
  @override
  String toString() => '[$start..$end]';
  
  @override
  bool operator ==(Object other) {
    return other is IndexRange && other.start == start && other.end == end;
  }
  
  @override
  int get hashCode => Object.hash(start, end);
}