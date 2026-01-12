/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Centralized Event Registry - Clean, correct, no fallbacks
/// 
/// This is the single source of truth for all event handling.
/// Events are registered by viewId and automatically managed through lifecycle.
/// 
/// Key principles:
/// - No fallbacks - if not registered, event is ignored (fail-fast)
/// - Automatic lifecycle management - events are cleaned up when views are removed
/// - Central registry - all events go through this system
/// - Type-safe - events are registered with their handlers upfront
class EventRegistry {
  static final EventRegistry _instance = EventRegistry._internal();
  factory EventRegistry() => _instance;
  EventRegistry._internal();

  /// Map of viewId -> eventType -> handler
  final Map<int, Map<String, Function>> _handlers = {};

  /// Map of viewId -> Set of registered event types
  final Map<int, Set<String>> _registeredEvents = {};

  /// Global event handler (fallback for unhandled events - can be null)
  void Function(int viewId, String eventType, Map<String, dynamic> eventData)? _globalHandler;

  /// Register event handlers for a view
  /// 
  /// [viewId]: The unique identifier for the view
  /// [events]: Map of eventType -> handler function
  /// 
  /// Example:
  /// ```dart
  /// EventRegistry().register(123, {
  ///   'onPress': () => print('Pressed!'),
  ///   'onLongPress': (data) => print('Long pressed: $data'),
  /// });
  /// ```
  void register(int viewId, Map<String, Function> events) {
    if (events.isEmpty) return;

    _handlers[viewId] ??= {};
    _registeredEvents[viewId] ??= <String>{};

    events.forEach((eventType, handler) {
      _handlers[viewId]![eventType] = handler;
      _registeredEvents[viewId]!.add(eventType);
    });
  }

  /// Unregister all events for a view (called automatically on view removal)
  void unregister(int viewId) {
    _handlers.remove(viewId);
    _registeredEvents.remove(viewId);
  }

  /// Unregister a specific event type for a view
  void unregisterEvent(int viewId, String eventType) {
    _handlers[viewId]?.remove(eventType);
    _registeredEvents[viewId]?.remove(eventType);
  }

  /// Handle an event from native
  /// 
  /// Returns true if event was handled, false if not registered
  bool handleEvent(int viewId, String eventType, Map<String, dynamic> eventData) {
    final handler = _handlers[viewId]?[eventType];
    
    if (handler != null) {
      try {
        // Call handler with event data if it accepts parameters, otherwise call without
        if (handler is Function(Map<String, dynamic>)) {
          handler(eventData);
        } else if (handler is Function()) {
          handler();
        } else {
          // Try to call with apply for dynamic handlers
          Function.apply(handler, [], {});
        }
        return true;
      } catch (e) {
        print('❌ EventRegistry: Error in handler for view $viewId, event $eventType: $e');
        return false;
      }
    }

    // If no specific handler, try global handler
    if (_globalHandler != null) {
      try {
        _globalHandler!(viewId, eventType, eventData);
        return true;
      } catch (e) {
        print('❌ EventRegistry: Error in global handler: $e');
        return false;
      }
    }

    // Event not registered - fail-fast (no fallback)
    return false;
  }

  /// Set global event handler (optional - for debugging or catch-all)
  void setGlobalHandler(void Function(int viewId, String eventType, Map<String, dynamic> eventData)? handler) {
    _globalHandler = handler;
  }

  /// Check if an event is registered for a view
  bool isRegistered(int viewId, String eventType) {
    return _registeredEvents[viewId]?.contains(eventType) ?? false;
  }

  /// Get all registered event types for a view
  Set<String>? getRegisteredEvents(int viewId) {
    return _registeredEvents[viewId];
  }

  /// Clear all registrations (for hot restart)
  void clear() {
    _handlers.clear();
    _registeredEvents.clear();
    _globalHandler = null;
  }
}

