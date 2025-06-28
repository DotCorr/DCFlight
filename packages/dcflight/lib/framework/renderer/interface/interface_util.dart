/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



// ignore_for_file: deprecated_member_use

import 'package:dcflight/dcflight.dart';

Map<String, dynamic> preprocessProps(Map<String, dynamic> props) {
    final processedProps = <String, dynamic>{};

    props.forEach((key, value) {
      if (value is Function) {
        
        // Handle event handlers - DO NOT send functions to native, only registration flags
        if (key.startsWith('on')) {
          // DON'T include the function itself - just add handler flag for native bridge detection
          processedProps['_has${key.substring(2)}Handler'] = true;
          // Store event type for registration
          processedProps['_eventType_$key'] = key;
        }
        // Skip all Function objects - they cannot be serialized over method channel
      } else if (value is Color) {
        // Convert Color objects to hex strings with alpha
        processedProps[key] =
            '#${value.value.toRadixString(16).padLeft(8, '0')}';
      } else if (value == double.infinity) {
        // Convert infinity to 100% string for percentage sizing
        processedProps[key] = '100%';
      } else if (value is String &&
          (value.endsWith('%') || value.startsWith('#'))) {
        // Pass percentage strings and color strings through directly
        processedProps[key] = value;
      } else if (key == 'width' ||
          key == 'height' ||
          key.startsWith('margin') ||
          key.startsWith('padding')) {
        // Make sure numeric values go through as doubles for consistent handling
        if (value is num) {
          processedProps[key] = value.toDouble();
        } else {
          processedProps[key] = value;
        }
      } else if (value != null) {
        processedProps[key] = value;
      }else if (value is List) {
        // Process lists recursively
        processedProps[key] = _processList(value);
      } else if (value is Map<String, dynamic>) {
        // Process nested maps recursively
        processedProps[key] = preprocessProps(value);
      } else {
        // For all other types, just pass through
        processedProps[key] = value;
      }
    });

    return processedProps;
  }



List<dynamic> _processList(List<dynamic> list) {
  return list.map((item) {
    if (item is double) {
      if (item.isInfinite || item.isNaN) {
        return 0.0;
      } else if (item.abs() > 1e6) {
        return item.clamp(-1e6, 1e6);
      }
      return item;
    } else if (item is Map<String, dynamic>) {
      return preprocessProps(item);
    } else if (item is List) {
      return _processList(item);
    }
    return item;
  }).toList();
}