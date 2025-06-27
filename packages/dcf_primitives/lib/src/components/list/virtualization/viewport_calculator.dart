/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:math' as math;
import 'package:dcf_primitives/src/components/list/virtualization/virtualization_engine.dart';

import 'types.dart' hide IndexRange;

/// 🎯 VIEWPORT CALCULATOR - Intelligent windowing and buffering system
/// 
/// Calculates optimal render windows based on:
/// - Current scroll position and velocity
/// - Item sizes and positions
/// - Buffer requirements for smooth scrolling
/// - Performance constraints
class ViewportCalculator {
  static const String _logPrefix = '[ViewportCalculator]';
  
  final VirtualizationConfig config;
  
  // Scroll velocity tracking for predictive rendering
  double _lastScrollOffset = 0;
  DateTime _lastScrollTime = DateTime.now();
  double _scrollVelocity = 0;
  
  // Cached calculations for performance
  final Map<int, double> _itemPositionCache = {};
  bool _cacheValid = false;
  
  ViewportCalculator({required this.config});
  
  /// Calculate which items are currently visible in the viewport
  IndexRange calculateVisibleRange({
    required double scrollOffset,
    required double viewportSize,
    required List<double> itemSizes,
    required bool isHorizontal,
  }) {
    if (itemSizes.isEmpty || viewportSize <= 0) {
      return const IndexRange(0, 0);
    }
    
    _updateScrollVelocity(scrollOffset);
    _ensurePositionCache(itemSizes);
    
    // Binary search for first visible item
    final startIndex = _findFirstVisibleIndex(
      scrollOffset, 
      itemSizes,
    );
    
    // Find last visible item
    final endIndex = _findLastVisibleIndex(
      scrollOffset + viewportSize,
      itemSizes,
    );
    
    final visibleRange = IndexRange(
      math.max(0, startIndex),
      math.min(itemSizes.length, endIndex + 1),
    );
    
    if (config.debug) {
      print('$_logPrefix Visible range: $visibleRange (scroll: $scrollOffset, viewport: $viewportSize)');
    }
    
    return visibleRange;
  }
  
  /// Calculate render range with intelligent buffering
  IndexRange calculateRenderRange({
    required IndexRange visibleRange,
    required int itemCount,
    required double windowSize,
  }) {
    if (itemCount == 0) return const IndexRange(0, 0);
    
    // Calculate buffer size based on window size and scroll velocity
    final baseBufferSize = ((windowSize - 1) / 2).round();
    final velocityBufferSize = _calculateVelocityBuffer();
    final totalBufferSize = baseBufferSize + velocityBufferSize;
    
    // Expand range with buffer
    final startIndex = math.max(0, visibleRange.start - totalBufferSize);
    final endIndex = math.min(itemCount, visibleRange.end + totalBufferSize);
    
    final renderRange = IndexRange(startIndex, endIndex);
    
    if (config.debug) {
      print('$_logPrefix Render range: $renderRange (buffer: $totalBufferSize, velocity: $_scrollVelocity)');
    }
    
    return renderRange;
  }
  
  /// Calculate buffer range for pre-rendering
  IndexRange calculateBufferRange({
    required IndexRange renderRange,
    required int itemCount,
    required double windowSize,
  }) {
    if (itemCount == 0) return const IndexRange(0, 0);
    
    // Extended buffer for pre-rendering based on scroll direction
    final additionalBuffer = (windowSize * 0.5).round();
    
    int startIndex, endIndex;
    
    if (_scrollVelocity > 50) {
      // Scrolling down/right - extend buffer ahead
      startIndex = renderRange.start;
      endIndex = math.min(itemCount, renderRange.end + additionalBuffer);
    } else if (_scrollVelocity < -50) {
      // Scrolling up/left - extend buffer behind
      startIndex = math.max(0, renderRange.start - additionalBuffer);
      endIndex = renderRange.end;
    } else {
      // Slow scrolling - balanced buffer
      startIndex = math.max(0, renderRange.start - (additionalBuffer ~/ 2));
      endIndex = math.min(itemCount, renderRange.end + (additionalBuffer ~/ 2));
    }
    
    return IndexRange(startIndex, endIndex);
  }
  
  /// Find first visible item using binary search for performance
  int _findFirstVisibleIndex(double scrollOffset, List<double> itemSizes) {
    if (itemSizes.isEmpty) return 0;
    
    int left = 0;
    int right = itemSizes.length - 1;
    
    while (left < right) {
      final mid = (left + right) ~/ 2;
      final position = _getItemPosition(mid);
      
      if (position < scrollOffset) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }
    
    return left;
  }
  
  /// Find last visible item
  int _findLastVisibleIndex(double maxOffset, List<double> itemSizes) {
    if (itemSizes.isEmpty) return 0;
    
    int left = 0;
    int right = itemSizes.length - 1;
    
    while (left < right) {
      final mid = (left + right + 1) ~/ 2;
      final position = _getItemPosition(mid);
      
      if (position <= maxOffset) {
        left = mid;
      } else {
        right = mid - 1;
      }
    }
    
    return left;
  }
  
  /// Get cached item position
  double _getItemPosition(int index) {
    return _itemPositionCache[index] ?? 0.0;
  }
  
  /// Ensure position cache is valid and up-to-date
  void _ensurePositionCache(List<double> itemSizes) {
    if (_cacheValid && _itemPositionCache.length == itemSizes.length) {
      return;
    }
    
    _itemPositionCache.clear();
    double position = 0;
    
    for (int i = 0; i < itemSizes.length; i++) {
      _itemPositionCache[i] = position;
      position += itemSizes[i];
    }
    
    _cacheValid = true;
  }
  
  /// Update scroll velocity for predictive rendering
  void _updateScrollVelocity(double scrollOffset) {
    final now = DateTime.now();
    final deltaTime = now.difference(_lastScrollTime).inMilliseconds;
    
    if (deltaTime > 0) {
      final deltaOffset = scrollOffset - _lastScrollOffset;
      _scrollVelocity = (deltaOffset / deltaTime) * 1000; // pixels per second
      
      // Apply smoothing to reduce jitter
      _scrollVelocity = _scrollVelocity * 0.3 + _scrollVelocity * 0.7;
    }
    
    _lastScrollOffset = scrollOffset;
    _lastScrollTime = now;
  }
  
  /// Calculate additional buffer based on scroll velocity
  int _calculateVelocityBuffer() {
    final absVelocity = _scrollVelocity.abs();
    
    if (absVelocity < 100) {
      return 0; // Slow scrolling - no additional buffer
    } else if (absVelocity < 500) {
      return 1; // Medium scrolling - small buffer
    } else if (absVelocity < 1000) {
      return 2; // Fast scrolling - medium buffer
    } else {
      return 3; // Very fast scrolling - large buffer
    }
  }
  
  /// Calculate optimal item position based on scroll offset and item sizes
  double calculateItemOffset(int index, List<double> itemSizes) {
    _ensurePositionCache(itemSizes);
    return _getItemPosition(index);
  }
  
  /// Get total content size
  double calculateTotalContentSize(List<double> itemSizes) {
    if (itemSizes.isEmpty) return 0;
    return itemSizes.reduce((a, b) => a + b);
  }
  
  /// Check if index is in visible viewport
  bool isIndexVisible({
    required int index,
    required double scrollOffset,
    required double viewportSize,
    required List<double> itemSizes,
  }) {
    if (index < 0 || index >= itemSizes.length) return false;
    
    _ensurePositionCache(itemSizes);
    final itemStart = _getItemPosition(index);
    final itemEnd = itemStart + itemSizes[index];
    
    final viewportStart = scrollOffset;
    final viewportEnd = scrollOffset + viewportSize;
    
    return itemEnd > viewportStart && itemStart < viewportEnd;
  }
  
  /// Get viewport intersection ratio for an item (0.0 to 1.0)
  double getViewportIntersectionRatio({
    required int index,
    required double scrollOffset,
    required double viewportSize,
    required List<double> itemSizes,
  }) {
    if (index < 0 || index >= itemSizes.length) return 0.0;
    
    _ensurePositionCache(itemSizes);
    final itemStart = _getItemPosition(index);
    final itemEnd = itemStart + itemSizes[index];
    final itemSize = itemSizes[index];
    
    final viewportStart = scrollOffset;
    final viewportEnd = scrollOffset + viewportSize;
    
    if (itemEnd <= viewportStart || itemStart >= viewportEnd) {
      return 0.0; // No intersection
    }
    
    final intersectionStart = math.max(itemStart, viewportStart);
    final intersectionEnd = math.min(itemEnd, viewportEnd);
    final intersectionSize = intersectionEnd - intersectionStart;
    
    return intersectionSize / itemSize;
  }
  
  /// Reset cache when item sizes change
  void invalidateCache() {
    _itemPositionCache.clear();
    _cacheValid = false;
    
    if (config.debug) {
      print('$_logPrefix Position cache invalidated');
    }
  }
  
  /// Get current scroll velocity
  double get scrollVelocity => _scrollVelocity;
  
  /// Get performance stats
  Map<String, dynamic> getStats() {
    return {
      'scrollVelocity': _scrollVelocity,
      'cacheSize': _itemPositionCache.length,
      'cacheValid': _cacheValid,
    };
  }
}