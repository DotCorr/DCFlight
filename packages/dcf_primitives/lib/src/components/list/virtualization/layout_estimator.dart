/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:math' as math;
import 'types.dart';

/// Intelligent layout estimator for dynamic item sizes
/// Learns from measurements to provide increasingly accurate estimates
class LayoutEstimator {
  /// Global estimated item size (fallback)
  double _globalEstimatedSize;
  
  /// Measured sizes for specific indices
  final Map<int, double> _measuredSizes = {};
  
  /// Item type-based size estimates
  final Map<String, ItemSizeEstimate> _typeEstimates = {};
  
  /// Configuration
  final VirtualizationConfig config;
  
  /// Whether we're using fixed item sizes
  final bool hasFixedSize;
  
  /// Fixed size value (if hasFixedSize is true)
  final double? fixedSize;
  
  /// Running statistics for global estimation
  _RunningStats _globalStats = _RunningStats();
  
  /// Type-specific statistics
  final Map<String, _RunningStats> _typeStats = {};
  
  LayoutEstimator({
    required this.config,
    double? estimatedItemSize,
    this.hasFixedSize = false,
    this.fixedSize,
  }) : _globalEstimatedSize = estimatedItemSize ?? fixedSize ?? 50.0;
  
  /// Get size estimate for a specific item
  double getItemSize(int index, {String? itemType}) {
    // If fixed size, always return that
    if (hasFixedSize && fixedSize != null) {
      return fixedSize!;
    }
    
    // Return measured size if available
    if (_measuredSizes.containsKey(index)) {
      return _measuredSizes[index]!;
    }
    
    // Return type-based estimate if available
    if (itemType != null && _typeEstimates.containsKey(itemType)) {
      return _typeEstimates[itemType]!.height;
    }
    
    // Fall back to global estimate
    return _globalEstimatedSize;
  }
  
  /// Get all item sizes for virtualization calculations
  List<double> getAllItemSizes([int? itemCount]) {
    final int count = itemCount ?? _measuredSizes.keys.fold(0, (max, index) => math.max(max, index + 1));
    return List.generate(count, (index) => getItemSize(index));
  }
  
  /// Record actual measurement for learning
  void recordMeasurement(int index, double size, {String? itemType}) {
    if (hasFixedSize) return; // Don't learn if using fixed sizes
    
    // Store the measurement
    _measuredSizes[index] = size;
    
    // Update global statistics
    _globalStats.addSample(size);
    _globalEstimatedSize = _globalStats.mean;
    
    // Update type-specific statistics
    if (itemType != null) {
      final typeStats = _typeStats[itemType] ??= _RunningStats();
      typeStats.addSample(size);
      
      // Update type estimate
      final confidence = math.min(1.0, typeStats.sampleCount / 10.0); // Max confidence at 10 samples
      _typeEstimates[itemType] = ItemSizeEstimate(
        height: typeStats.mean,
        width: 0.0, // We only track height for now
        confidence: confidence,
        sampleSize: typeStats.sampleCount,
      );
    }
  }
  
  /// Get size estimate for multiple items efficiently
  List<double> getItemSizes(int startIndex, int count, {String Function(int)? getItemType}) {
    final sizes = <double>[];
    
    for (int i = 0; i < count; i++) {
      final index = startIndex + i;
      final itemType = getItemType?.call(index);
      sizes.add(getItemSize(index, itemType: itemType));
    }
    
    return sizes;
  }
  
  /// Calculate total height for a range of items
  double calculateRangeHeight(int startIndex, int endIndex, {String Function(int)? getItemType}) {
    double totalHeight = 0.0;
    
    for (int i = startIndex; i <= endIndex; i++) {
      final itemType = getItemType?.call(i);
      totalHeight += getItemSize(i, itemType: itemType);
    }
    
    return totalHeight;
  }
  
  /// Get estimated total content height
  double getEstimatedContentHeight(int itemCount, {String Function(int)? getItemType}) {
    if (hasFixedSize && fixedSize != null) {
      return itemCount * fixedSize!;
    }
    
    // If we have measurements for all items, use them
    if (_measuredSizes.length >= itemCount) {
      return calculateRangeHeight(0, itemCount - 1, getItemType: getItemType);
    }
    
    // Otherwise, estimate based on what we know
    double totalHeight = 0.0;
    
    for (int i = 0; i < itemCount; i++) {
      final itemType = getItemType?.call(i);
      totalHeight += getItemSize(i, itemType: itemType);
    }
    
    return totalHeight;
  }
  
  /// Get confidence level for estimates (0.0 - 1.0)
  double getEstimateConfidence({String? itemType}) {
    if (hasFixedSize) return 1.0;
    
    if (itemType != null && _typeEstimates.containsKey(itemType)) {
      return _typeEstimates[itemType]!.confidence;
    }
    
    // Global confidence based on number of samples
    return math.min(1.0, _globalStats.sampleCount / 20.0);
  }
  
  /// Check if we have enough data for reliable estimates
  bool hasReliableEstimates({String? itemType}) {
    return getEstimateConfidence(itemType: itemType) >= 0.7;
  }
  
  /// Optimize estimates by analyzing patterns
  void optimizeEstimates() {
    if (hasFixedSize) return;
    
    // Remove outliers from global statistics
    _removeOutliers();
    
    // Merge similar item type estimates
    _mergeSimilarTypeEstimates();
    
    // Update global estimate with weighted average
    _updateGlobalEstimate();
  }
  
  /// Remove statistical outliers to improve estimates
  void _removeOutliers() {
    if (_measuredSizes.length < 10) return; // Need enough data
    
    final values = _measuredSizes.values.toList()..sort();
    final q1Index = (values.length * 0.25).floor();
    final q3Index = (values.length * 0.75).floor();
    
    final q1 = values[q1Index];
    final q3 = values[q3Index];
    final iqr = q3 - q1;
    final lowerBound = q1 - 1.5 * iqr;
    final upperBound = q3 + 1.5 * iqr;
    
    // Remove outliers (but keep at least some measurements)
    final toRemove = <int>[];
    for (final entry in _measuredSizes.entries) {
      if ((entry.value < lowerBound || entry.value > upperBound) && 
          _measuredSizes.length > 20) {
        toRemove.add(entry.key);
      }
    }
    
    for (final index in toRemove) {
      _measuredSizes.remove(index);
    }
  }
  
  /// Merge item types with similar average sizes
  void _mergeSimilarTypeEstimates() {
    const similarityThreshold = 5.0; // pixels
    
    final types = _typeEstimates.keys.toList();
    
    for (int i = 0; i < types.length; i++) {
      for (int j = i + 1; j < types.length; j++) {
        final type1 = types[i];
        final type2 = types[j];
        
        final est1 = _typeEstimates[type1]!;
        final est2 = _typeEstimates[type2]!;
        
        if ((est1.height - est2.height).abs() < similarityThreshold) {
          // Merge the estimates
          final merged = est1.combineWith(est2);
          _typeEstimates[type1] = merged;
          _typeEstimates[type2] = merged;
        }
      }
    }
  }
  
  /// Update global estimate with weighted average of type estimates
  void _updateGlobalEstimate() {
    if (_typeEstimates.isEmpty) return;
    
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (final estimate in _typeEstimates.values) {
      final weight = estimate.confidence * estimate.sampleSize;
      weightedSum += estimate.height * weight;
      totalWeight += weight;
    }
    
    if (totalWeight > 0) {
      final newGlobalEstimate = weightedSum / totalWeight;
      
      // Smooth the transition to avoid sudden jumps
      _globalEstimatedSize = (_globalEstimatedSize * 0.7) + (newGlobalEstimate * 0.3);
    }
  }
  
  /// Clear old measurements to prevent memory leaks
  void cleanupOldMeasurements({int keepCount = 1000}) {
    if (_measuredSizes.length <= keepCount) return;
    
    // Keep the most recent measurements
    final sortedIndices = _measuredSizes.keys.toList()..sort();
    final toRemove = sortedIndices.take(_measuredSizes.length - keepCount);
    
    for (final index in toRemove) {
      _measuredSizes.remove(index);
    }
  }
  
  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'globalEstimatedSize': _globalEstimatedSize,
      'hasFixedSize': hasFixedSize,
      'fixedSize': fixedSize,
      'measuredCount': _measuredSizes.length,
      'typeEstimatesCount': _typeEstimates.length,
      'globalStats': {
        'mean': _globalStats.mean,
        'sampleCount': _globalStats.sampleCount,
        'variance': _globalStats.variance,
      },
      'typeEstimates': _typeEstimates.map((k, v) => MapEntry(k, {
        'height': v.height,
        'confidence': v.confidence,
        'sampleSize': v.sampleSize,
      })),
    };
  }
  
  /// Reset all estimates
  void reset() {
    _measuredSizes.clear();
    _typeEstimates.clear();
    _typeStats.clear();
    _globalStats = _RunningStats();
    _globalEstimatedSize = fixedSize ?? 50.0;
  }
  
  /// Export learned data for persistence
  Map<String, dynamic> exportLearningData() {
    return {
      'globalEstimatedSize': _globalEstimatedSize,
      'typeEstimates': _typeEstimates.map((k, v) => MapEntry(k, {
        'height': v.height,
        'confidence': v.confidence,
        'sampleSize': v.sampleSize,
      })),
      'globalStats': {
        'mean': _globalStats.mean,
        'sampleCount': _globalStats.sampleCount,
        'sumOfSquares': _globalStats._sumOfSquares,
        'sum': _globalStats._sum,
      },
    };
  }
  
  /// Import previously learned data
  void importLearningData(Map<String, dynamic> data) {
    _globalEstimatedSize = data['globalEstimatedSize']?.toDouble() ?? _globalEstimatedSize;
    
    // Import type estimates
    final typeEstimates = data['typeEstimates'] as Map<String, dynamic>?;
    if (typeEstimates != null) {
      for (final entry in typeEstimates.entries) {
        final estimate = entry.value as Map<String, dynamic>;
        _typeEstimates[entry.key] = ItemSizeEstimate(
          height: estimate['height']?.toDouble() ?? 50.0,
          width: 0.0,
          confidence: estimate['confidence']?.toDouble() ?? 0.0,
          sampleSize: estimate['sampleSize']?.toInt() ?? 0,
        );
      }
    }
    
    // Import global stats
    final globalStats = data['globalStats'] as Map<String, dynamic>?;
    if (globalStats != null) {
      _globalStats = _RunningStats.fromData(
        mean: globalStats['mean']?.toDouble() ?? 0.0,
        sampleCount: globalStats['sampleCount']?.toInt() ?? 0,
        sumOfSquares: globalStats['sumOfSquares']?.toDouble() ?? 0.0,
        sum: globalStats['sum']?.toDouble() ?? 0.0,
      );
    }
  }
}

/// Running statistics calculator for efficient mean/variance calculation
class _RunningStats {
  double _sum = 0.0;
  double _sumOfSquares = 0.0;
  int _sampleCount = 0;
  
  _RunningStats();
  
  _RunningStats.fromData({
    required double mean,
    required int sampleCount,
    required double sumOfSquares,
    required double sum,
  }) : _sum = sum,
       _sumOfSquares = sumOfSquares,
       _sampleCount = sampleCount;
  
  void addSample(double value) {
    _sum += value;
    _sumOfSquares += value * value;
    _sampleCount++;
  }
  
  double get mean => _sampleCount > 0 ? _sum / _sampleCount : 0.0;
  
  double get variance => _sampleCount > 1 
      ? (_sumOfSquares - (_sum * _sum / _sampleCount)) / (_sampleCount - 1)
      : 0.0;
  
  double get standardDeviation => math.sqrt(variance);
  
  int get sampleCount => _sampleCount;
}