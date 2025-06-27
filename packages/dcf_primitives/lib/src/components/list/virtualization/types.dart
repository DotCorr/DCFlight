/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Core data structures for the virtualization engine
/// Designed to beat FlashList performance with zero compromises

/// Represents the current state of the viewport and what should be rendered
class VirtualWindow {
  /// First index in the render window (includes buffer)
  final int startIndex;
  
  /// Last index in the render window (includes buffer)  
  final int endIndex;
  
  /// First visible index (no buffer)
  final int visibleStartIndex;
  
  /// Last visible index (no buffer)
  final int visibleEndIndex;
  
  /// Current scroll offset
  final double scrollOffset;
  
  /// Viewport height
  final double viewportHeight;
  
  /// Total content height
  final double totalContentHeight;
  
  const VirtualWindow({
    required this.startIndex,
    required this.endIndex,
    required this.visibleStartIndex,
    required this.visibleEndIndex,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.totalContentHeight,
  });
  
  /// Number of items in render window
  int get renderCount => endIndex - startIndex + 1;
  
  /// Number of visible items
  int get visibleCount => visibleEndIndex - visibleStartIndex + 1;
  
  /// Whether this window contains the given index
  bool contains(int index) => index >= startIndex && index <= endIndex;
  
  /// Whether the given index is visible (not just in buffer)
  bool isVisible(int index) => index >= visibleStartIndex && index <= visibleEndIndex;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VirtualWindow &&
          runtimeType == other.runtimeType &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex &&
          visibleStartIndex == other.visibleStartIndex &&
          visibleEndIndex == other.visibleEndIndex;

  @override
  int get hashCode =>
      startIndex.hashCode ^
      endIndex.hashCode ^
      visibleStartIndex.hashCode ^
      visibleEndIndex.hashCode;
      
  @override
  String toString() => 'VirtualWindow(render: $startIndex-$endIndex, visible: $visibleStartIndex-$visibleEndIndex)';
}

/// Represents a virtualized list item with recycling capability
class VirtualListItem<T> {
  /// Unique identifier for this item instance
  final String id;
  
  /// The data this item represents
  T data;
  
  /// Index in the original data array
  int index;
  
  /// Type of this item (for heterogeneous lists)
  final String itemType;
  
  /// The rendered component
  DCFComponentNode component;
  
  /// Measured height of this item (null if not measured)
  double? measuredHeight;
  
  /// Measured width of this item (null if not measured)
  double? measuredWidth;
  
  /// Whether this item is currently in use
  bool isActive;
  
  /// Last time this item was accessed (for LRU cleanup)
  DateTime lastAccessed;
  
  /// Absolute position from the top of the list
  double absoluteOffset;
  
  VirtualListItem({
    required this.id,
    required this.data,
    required this.index,
    required this.itemType,
    required this.component,
    this.measuredHeight,
    this.measuredWidth,
    this.isActive = true,
    DateTime? lastAccessed,
    this.absoluteOffset = 0.0,
  }) : lastAccessed = lastAccessed ?? DateTime.now();
  
  /// Update this item with new data (for recycling)
  void updateData(T newData, int newIndex, double newOffset) {
    data = newData;
    index = newIndex;
    absoluteOffset = newOffset;
    lastAccessed = DateTime.now();
    isActive = true;
  }
  
  /// Prepare this item for recycling (clear sensitive state)
  void prepareForRecycling() {
    isActive = false;
    // Note: We keep measuredHeight/Width for estimation purposes
  }
  
  /// Mark this item as measured
  void recordMeasurement(double height, [double? width]) {
    measuredHeight = height;
    if (width != null) measuredWidth = width;
    lastAccessed = DateTime.now();
  }
  
  @override
  String toString() => 'VirtualListItem(id: $id, index: $index, type: $itemType, height: $measuredHeight)';
}

/// Configuration for the virtualization engine
class VirtualizationConfig {
  /// Buffer size in terms of viewport heights (default: 10.5 = 21 total window)
  final double windowSize;
  
  /// Initial number of items to render
  final int initialNumToRender;
  
  /// Maximum items to render per batch
  final int maxToRenderPerBatch;
  
  /// Update frequency in milliseconds
  final int updateBatchingPeriod;
  
  /// Whether to enable component recycling
  final bool enableRecycling;
  
  /// Maximum size of component pools
  final int maxPoolSize;
  
  /// Enable performance monitoring
  final bool enablePerformanceMonitoring;
  
  /// Whether to remove clipped subviews (native optimization)
  final bool removeClippedSubviews;
  
  /// Threshold for end reached callback (0.0-1.0)
  final double onEndReachedThreshold;
  
  /// Whether to enable debug mode (shows performance overlay)
  final bool debug;
  
  const VirtualizationConfig({
    this.windowSize = 10.5, // 21 total window size (10.5 above + visible + 10.5 below)
    this.initialNumToRender = 10,
    this.maxToRenderPerBatch = 10,
    this.updateBatchingPeriod = 50,
    this.enableRecycling = true,
    this.maxPoolSize = 15,
    this.enablePerformanceMonitoring = false,
    this.removeClippedSubviews = true,
    this.onEndReachedThreshold = 0.1,
    this.debug = false,
  });
  
  /// High performance config (more aggressive)
  static const VirtualizationConfig highPerformance = VirtualizationConfig(
    windowSize: 5.0,  // Smaller window for memory efficiency
    maxToRenderPerBatch: 15,
    updateBatchingPeriod: 33, // ~30fps updates
    maxPoolSize: 20,
  );
  
  /// Memory optimized config
  static const VirtualizationConfig memoryOptimized = VirtualizationConfig(
    windowSize: 3.0,  // Very small window
    maxToRenderPerBatch: 5,
    maxPoolSize: 10,
    removeClippedSubviews: true,
  );
  
  /// Debug config (shows performance metrics)
  static const VirtualizationConfig debugMode = VirtualizationConfig(
    enablePerformanceMonitoring: true,
    debug: true,
    windowSize: 10.5,
  );
}

/// Performance metrics for monitoring
class VirtualizationMetrics {
  /// Current FPS
  final double fps;
  
  /// JavaScript thread usage percentage
  final double jsThreadUsage;
  
  /// Number of components in memory
  final int componentsInMemory;
  
  /// Number of items being rendered
  final int itemsRendered;
  
  /// Number of blank spaces visible
  final int blankSpaces;
  
  /// Memory usage in MB
  final double memoryUsage;
  
  /// Average render time per item in ms
  final double avgRenderTime;
  
  /// Number of recycled components used this frame
  final int recycledComponents;
  
  /// Current scroll velocity
  final double scrollVelocity;
  
  const VirtualizationMetrics({
    required this.fps,
    required this.jsThreadUsage,
    required this.componentsInMemory,
    required this.itemsRendered,
    required this.blankSpaces,
    required this.memoryUsage,
    required this.avgRenderTime,
    required this.recycledComponents,
    required this.scrollVelocity,
  });
  
  /// Whether performance is good
  bool get isPerformanceGood => fps >= 55 && jsThreadUsage < 70 && blankSpaces == 0;
  
  @override
  String toString() => 'VirtualizationMetrics(fps: ${fps.toStringAsFixed(1)}, '
      'js: ${jsThreadUsage.toStringAsFixed(1)}%, items: $itemsRendered, blanks: $blankSpaces)';
}

/// Render task for batched rendering
class RenderTask {
  /// Index to render
  final int index;
  
  /// Whether this is high priority (visible items)
  final bool isHighPriority;
  
  /// Task creation time
  final DateTime createdAt;
  
  /// Associated item type
  final String? itemType;
  
  RenderTask(this.index, this.isHighPriority, {this.itemType}) 
    : createdAt = DateTime.now();
    
  /// Age of this task in milliseconds
  int get ageMs => DateTime.now().difference(createdAt).inMilliseconds;
  
  @override
  String toString() => 'RenderTask(index: $index, priority: ${isHighPriority ? 'HIGH' : 'LOW'}, age: ${ageMs}ms)';
}

/// Scroll direction for optimization
enum ScrollDirection {
  up,
  down,
  idle,
}

/// Item size estimation data
class ItemSizeEstimate {
  /// Estimated height
  final double height;
  
  /// Estimated width
  final double width;
  
  /// Confidence level (0.0-1.0)
  final double confidence;
  
  /// Number of measurements this is based on
  final int sampleSize;
  
  const ItemSizeEstimate({
    required this.height,
    required this.width,
    this.confidence = 1.0,
    this.sampleSize = 1,
  });
  
  /// Combine with another estimate (weighted average)
  ItemSizeEstimate combineWith(ItemSizeEstimate other) {
    final totalSamples = sampleSize + other.sampleSize;
    final weight1 = sampleSize / totalSamples;
    final weight2 = other.sampleSize / totalSamples;
    
    return ItemSizeEstimate(
      height: (height * weight1) + (other.height * weight2),
      width: (width * weight1) + (other.width * weight2),
      confidence: ((confidence * weight1) + (other.confidence * weight2)).clamp(0.0, 1.0),
      sampleSize: totalSamples,
    );
  }
  
  @override
  String toString() => 'ItemSizeEstimate(h: ${height.toStringAsFixed(1)}, '
      'w: ${width.toStringAsFixed(1)}, conf: ${(confidence * 100).toStringAsFixed(0)}%)';
}