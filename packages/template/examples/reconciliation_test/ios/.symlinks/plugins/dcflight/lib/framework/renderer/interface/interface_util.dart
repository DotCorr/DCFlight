/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */




import 'package:dcflight/dcflight.dart';

Map<String, dynamic> preprocessProps(Map<String, dynamic> props) {
    final processedProps = <String, dynamic>{};

    props.forEach((key, value) {
      if (value is Function) {
        
        if (key.startsWith('on')) {
          processedProps['_has${key.substring(2)}Handler'] = true;
          processedProps['_eventType_$key'] = key;
        }
      } else if (value is Color) {
        // Use dcf: prefix to distinguish black from transparent
        final alpha = (value.a * 255.0).round() & 0xff;
        if (alpha == 0) {
          processedProps[key] = 'dcf:transparent';
        } else if (value.value == 0xFF000000) {
          processedProps[key] = 'dcf:black';
        } else if (alpha == 255) {
          final hexValue = value.toARGB32() & 0xFFFFFF;
          processedProps[key] = 'dcf:#${hexValue.toRadixString(16).padLeft(6, '0')}';
        } else {
          final argbValue = value.toARGB32();
          processedProps[key] = 'dcf:#${argbValue.toRadixString(16).padLeft(8, '0')}';
        }
      } else if (value == double.infinity) {
        processedProps[key] = '100%';
      } else if (value is String &&
          (value.endsWith('%') || value.startsWith('#'))) {
        processedProps[key] = value;
      } else if (key == 'width' ||
          key == 'height' ||
          key.startsWith('margin') ||
          key.startsWith('padding')) {
        if (value is num) {
          processedProps[key] = value.toDouble();
        } else {
          processedProps[key] = value;
        }
      } else if (value != null) {
        processedProps[key] = value;
      }else if (value is List) {
        processedProps[key] = _processList(value);
      } else if (value is Map<String, dynamic>) {
        processedProps[key] = preprocessProps(value);
      } else {
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