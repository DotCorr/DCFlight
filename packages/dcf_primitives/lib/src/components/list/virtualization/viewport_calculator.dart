/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:math' as math;
import 'types.dart';

/// 🎯 VIEWPORT CALCULATOR - Fixed for proper incremental rendering
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
  
  /// Calculate which items are currently visible in the viewport - FIXED VERSION
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
    
    // Find first visible item using binary search
    final startIndex = _findFirstVisibleIndex(scrollOffset, itemSizes);
    
    // Find last visible item
    final endIndex = _findLastVisibleIndex(scrollOffset + viewportSize, itemSizes);
    
    final visibleRange = IndexRange(
      math.max(0, startIndex),
      math.min(itemSizes.length, endIndex + 1),
    );
    
    if (config.debug) {
      print('$_logPrefix Visible range: $visibleRange (scroll: ${scrollOffset.toStringAsFixed(1)}, viewport: ${viewportSize.toStringAsFixed(1)})');
    }
    
    return visibleRange;
  }
  
  /// Calculate render range with intelligent buffering - IMPROVED VERSION
  IndexRange calculateRenderRange({
    required IndexRange visibleRange,
    required int itemCount,
    required double windowSize,
  }) {
    if (itemCount == 0) return const IndexRange(0, 0);
    
    // Calculate buffer size based on window size and scroll velocity
    final baseBufferSize = math.max(5, (windowSize / 2).round()); // Minimum 5 items buffer
    final velocityBufferSize = _calculateVelocityBuffer();
    final totalBufferSize = baseBufferSize + velocityBufferSize;
    
    // Expand range with buffer, ensuring we don't go negative or exceed bounds
    final startIndex = math.max(0, visibleRange.start - totalBufferSize);
    final endIndex = math.min(itemCount, visibleRange.end + totalBufferSize);
    
    // Ensure minimum render count for smooth scrolling
    final minRenderCount = math.max(config.initialNumToRender, 10);
    final currentRenderCount = endIndex - startIndex;
    
    IndexRange renderRange;
    if (currentRenderCount < minRenderCount) {
      // Expand range to meet minimum render count
      final additionalItems = minRenderCount - currentRenderCount;
      final expandStart = math.max(0, startIndex - (additionalItems ~/ 2));
      final expandEnd = math.min(itemCount, endIndex + (additionalItems ~/ 2));
      renderRange = IndexRange(expandStart, expandEnd);
    } else {
      renderRange = IndexRange(startIndex, endIndex);
    }
    
    if (config.debug) {
      print('$_logPrefix Render range: $renderRange (buffer: $totalBufferSize, velocity: ${_scrollVelocity.toStringAsFixed(1)})');
    }
    
    return renderRange;
  }
  
  /// Calculate buffer range for pre-rendering - IMPROVED VERSION
  IndexRange calculateBufferRange({
    required IndexRange renderRange,
    required int itemCount,
    required double windowSize,
  }) {
    if (itemCount == 0) return const IndexRange(0, 0);
    
    // Extended buffer for pre-rendering based on scroll direction
    final additionalBuffer = math.max(3, (windowSize * 0.3).round());
    
    int startIndex, endIndex;
    
    if (_scrollVelocity > 100) {
      // Scrolling down/right - extend buffer ahead more aggressively
      startIndex = renderRange.start;
      endIndex = math.min(itemCount, renderRange.end + (additionalBuffer * 2));
    } else if (_scrollVelocity < -100) {
      // Scrolling up/left - extend buffer behind more aggressively
      startIndex = math.max(0, renderRange.start - (additionalBuffer * 2));
      endIndex = renderRange.end;
    } else {
      // Slow scrolling or stationary - balanced buffer
      startIndex = math.max(0, renderRange.start - additionalBuffer);
      endIndex = math.min(itemCount, renderRange.end + additionalBuffer);
    }
    
    return IndexRange(startIndex, endIndex);
  }
  
  /// Find first visible item using optimized binary search
  int _findFirstVisibleIndex(double scrollOffset, List<double> itemSizes) {
    if (itemSizes.isEmpty) return 0;
    
    // Handle edge case where we're at the very beginning
    if (scrollOffset <= 0) return 0;
    
    int left = 0;
    int right = itemSizes.length - 1;
    
    while (left < right) {
      final mid = (left + right) ~/ 2;
      final position = _getItemPosition(mid);
      final itemEnd = position + itemSizes[mid];
      
      if (itemEnd <= scrollOffset) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }
    
    return math.max(0, left);
  }
  
  /// Find last visible item using optimized search
  int _findLastVisibleIndex(double maxOffset, List<double> itemSizes) {
    if (itemSizes.isEmpty) return 0;
    
    // Handle edge case where we can see beyond the end
    final totalHeight = _getItemPosition(itemSizes.length - 1) + itemSizes.last;
    if (maxOffset >= totalHeight) return itemSizes.length - 1;
    
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
    
    return math.max(0, left);
  }
  
  /// Get cached item position
  double _getItemPosition(int index) {
    if (index < 0) return 0.0;
    if (index >= _itemPositionCache.length) return _itemPositionCache[_itemPositionCache.length - 1] ?? 0.0;
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
      position += math.max(1.0, itemSizes[i]); // Ensure minimum item size of 1
    }
    
    _cacheValid = true;
    
    if (config.debug && itemSizes.length <= 10) {
      print('$_logPrefix Position cache: $_itemPositionCache');
    }
  }
  
  /// Update scroll velocity for predictive rendering
  void _updateScrollVelocity(double scrollOffset) {
    final now = DateTime.now();
    final deltaTime = now.difference(_lastScrollTime).inMilliseconds;
    
    if (deltaTime > 0 && deltaTime < 1000) { // Ignore very large time gaps
      final deltaOffset = scrollOffset - _lastScrollOffset;
      final instantVelocity = (deltaOffset / deltaTime) * 1000; // pixels per second
      
      // Apply smoothing to reduce jitter
      _scrollVelocity = (_scrollVelocity * 0.7) + (instantVelocity * 0.3);
    }
    
    _lastScrollOffset = scrollOffset;
    _lastScrollTime = now;
  }
  
  /// Calculate additional buffer based on scroll velocity
  int _calculateVelocityBuffer() {
    final absVelocity = _scrollVelocity.abs();
    
    if (absVelocity < 50) {
      return 0; // Very slow scrolling - no additional buffer
    } else if (absVelocity < 200) {
      return 2; // Slow scrolling - small buffer
    } else if (absVelocity < 500) {
      return 5; // Medium scrolling - medium buffer
    } else if (absVelocity < 1000) {
      return 8; // Fast scrolling - large buffer
    } else {
      return 12; // Very fast scrolling - extra large buffer
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
    _ensurePositionCache(itemSizes);
    final lastIndex = itemSizes.length - 1;
    return _getItemPosition(lastIndex) + itemSizes[lastIndex];
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
    
    return intersectionSize / math.max(1.0, itemSize);
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
      'lastScrollOffset': _lastScrollOffset,
    };
  }
}