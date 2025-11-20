/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/widgets.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/utils/flutter_widget_renderer.dart';

/// Adaptor to embed Flutter widgets directly into DCFlight native components
/// 
/// This is just a component - Flutter renders it normally as if it's in a normal widget tree.
/// The native view is just a host. Flutter's rendering pipeline handles everything naturally.
class WidgetToDCFAdaptor extends DCFStatelessComponent {
  /// Builder function that creates the widget - called on every render to get fresh state
  final Widget Function() widgetBuilder;
  
  /// Layout properties
  final DCFLayout? layout;
  
  /// Style properties
  final DCFStyleSheet? styleSheet;
  
  /// Create a widget adaptor with a builder (recommended - widget rebuilds on state changes)
  WidgetToDCFAdaptor.builder({
    required this.widgetBuilder,
    this.layout,
    this.styleSheet,
    super.key,
  });
  
  /// Create a widget adaptor with a static widget (widget won't update on state changes)
  /// Use WidgetToDCFAdaptor.builder() for reactive widgets
  WidgetToDCFAdaptor({
    required Widget widget,
    this.layout,
    this.styleSheet,
    super.key,
  }) : widgetBuilder = (() => widget);
  
  // Static map to store widgetId by viewId (most stable - viewId persists across all recreations)
  static final Map<int, String> _widgetIdByViewId = {};
  // Fallback map for when viewId isn't available yet (by component instance)
  static final Map<int, String> _widgetIdByInstance = {};
  static int _widgetIdCounter = 0;
  
  /// Clear all widget ID mappings during hot restart
  static void clearAllForHotRestart() {
    _widgetIdByViewId.clear();
    _widgetIdByInstance.clear();
    _widgetIdCounter = 0;
  }
  
  // Instance variable to track the viewId assigned to this component instance
  int? _assignedViewId;
  
  @override
  DCFComponentNode render() {
    // Build fresh widget with current state - this ensures state changes are reflected
    final userWidget = widgetBuilder();
    
    // Just wrap with ClipRect to prevent overflow
    // The Positioned widget in flutter_widget_renderer.dart already provides exact constraints
    // SizedBox.expand() in flutter_widget_renderer.dart will fill the Positioned widget's bounds
    // No need for LayoutBuilder here - it was causing constraint issues on Android
    final widget = ClipRect(
      clipBehavior: Clip.hardEdge,
      child: userWidget,
    );
    
    // CRITICAL: DO NOT access renderedNode here - it causes infinite loop!
    // Use contentViewId if available (set after element is rendered), otherwise use instance hashCode
    String? widgetId;
    
    // Check if we have a contentViewId (set after the element is rendered)
    final currentViewId = contentViewId;
    if (currentViewId != null) {
      // Update _assignedViewId for future renders
      if (_assignedViewId != currentViewId) {
        _assignedViewId = currentViewId;
        // Migrate from instance-based to viewId-based mapping
        final instanceHash = hashCode;
        final instanceBasedWidgetId = _widgetIdByInstance[instanceHash];
        if (instanceBasedWidgetId != null) {
          _widgetIdByViewId[currentViewId] = instanceBasedWidgetId;
          _widgetIdByInstance.remove(instanceHash);
          widgetId = instanceBasedWidgetId;
        } else {
          // Create new widgetId for this viewId
          _widgetIdCounter++;
          widgetId = 'flutter_widget_$_widgetIdCounter';
          _widgetIdByViewId[currentViewId] = widgetId;
        }
      } else {
        // Use existing widgetId for this viewId
        widgetId = _widgetIdByViewId[currentViewId];
        if (widgetId == null) {
          _widgetIdCounter++;
          widgetId = 'flutter_widget_$_widgetIdCounter';
          _widgetIdByViewId[currentViewId] = widgetId;
        }
      }
    } else {
      // Fallback: Use component instance hashCode (works for initial render)
      final instanceHash = hashCode;
      widgetId = _widgetIdByInstance.putIfAbsent(instanceHash, () {
        _widgetIdCounter++;
        final newWidgetId = 'flutter_widget_$_widgetIdCounter';
        return newWidgetId;
      });
    }
    
    // Check if widget was already registered (component re-rendering due to state change)
    final wasRegistered = _WidgetRegistry.instance.isRegistered(widgetId);
    
    // Update widget in registry - this ensures the widget is always fresh with latest state
    _WidgetRegistry.instance.register(widgetId, widget);
    
    // If widget was already registered, update it in the renderer
    // Use microtask to defer rebuild until after current render cycle
    if (wasRegistered) {
      final widgetIdToRebuild = widgetId;
      Future.microtask(() {
        FlutterWidgetRenderer.instance.markWidgetForRebuild(widgetIdToRebuild);
      });
    }
    
    // Just create a DCFElement - Flutter will render the widget normally
    final nativeProps = <String, dynamic>{
      "widgetType": widget.runtimeType.toString(),
      "widgetId": widgetId, // Native side uses this to get the widget
    };
    
    if (layout != null) {
      nativeProps.addAll(layout!.toMap());
    }
    
    if (styleSheet != null) {
      nativeProps.addAll(styleSheet!.toMap());
    }
    
    return DCFElement(
      type: "FlutterWidget",
      elementProps: nativeProps,
      children: [],
    );
  }
}

/// Simple registry to store widgets - native side accesses directly
class _WidgetRegistry {
  static final _WidgetRegistry instance = _WidgetRegistry._();
  _WidgetRegistry._();
  
  final Map<String, Widget> _widgets = {};
  
  void register(String id, Widget widget) {
    _widgets[id] = widget;
  }
  
  Widget? get(String id) {
    return _widgets[id];
  }
  
  bool isRegistered(String id) {
    return _widgets.containsKey(id);
  }
  
  void unregister(String id) {
    _widgets.remove(id);
  }
  
  /// Clear all widgets during hot restart
  void clearAll() {
    _widgets.clear();
  }
}

// Export for native side access
_WidgetRegistry get widgetRegistry => _WidgetRegistry.instance;
