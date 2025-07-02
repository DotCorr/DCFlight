/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:dcflight/framework/renderer/vdom/debug/vdom_logger.dart';
import 'package:dcflight/framework/renderer/vdom/mutator/vdom_mutator_extension_reg.dart';
import 'package:dcflight/framework/renderer/interface/interface.dart'
    show PlatformInterface;
import 'package:dcflight/framework/renderer/vdom/component/component.dart';
import 'package:dcflight/framework/renderer/vdom/component/error_boundary.dart';
import 'package:dcflight/framework/renderer/vdom/component/dcf_element.dart';
import 'package:dcflight/framework/renderer/vdom/component/component_node.dart';
import 'package:dcflight/framework/renderer/vdom/component/fragment.dart';

/// Virtual DOM implementation with efficient reconciliation and state handling
class VDom {
  /// Native bridge for UI operations
  final PlatformInterface _nativeBridge;

  /// Whether the VDom is ready for use
  final Completer<void> _readyCompleter = Completer<void>();

  /// Counter for generating unique view IDs
  int _viewIdCounter = 1;

  /// Map of view IDs to their associated VDomNodes
  final Map<String, DCFComponentNode> _nodesByViewId = {};

  /// Map to track component instances by their instance ID
  final Map<String, StatefulComponent> _statefulComponents = {};

  /// Map to track components by their instance ID
  final Map<String, StatelessComponent> _statelessComponents = {};

  /// Map to track previous rendered nodes for components (for proper reconciliation)
  final Map<String, DCFComponentNode> _previousRenderedNodes = {};

  /// Pending component updates for batching
  final Set<String> _pendingUpdates = {};

  /// Flag to track if an update batch is scheduled
  bool _isUpdateScheduled = false;

  /// Flag to track batch updates in progress
  bool _batchUpdateInProgress = false;

  /// Root component for the application
  DCFComponentNode? rootComponent;

  /// Error boundary registry
  final Map<String, ErrorBoundary> _errorBoundaries = {};

  /// Create a new VDom instance with the provided native bridge
  VDom(this._nativeBridge) {
    VDomDebugLogger.log('VDOM_INIT', 'Creating new VDom instance');
    _initialize();
  }

  /// Initialize the VDom with the native bridge
  Future<void> _initialize() async {
    VDomDebugLogger.log('VDOM_INIT', 'Starting VDom initialization');
    
    try {
      // Initialize bridge
      final success = await _nativeBridge.initialize();
      if (!success) {
        VDomDebugLogger.log('VDOM_INIT_ERROR', 'Failed to initialize native bridge');
        throw Exception('Failed to initialize native bridge');
      }

      // Register event handler
      _nativeBridge.setEventHandler(_handleNativeEvent);
      VDomDebugLogger.log('VDOM_INIT', 'Event handler registered');

      // Mark as ready
      _readyCompleter.complete();
      VDomDebugLogger.log('VDOM_INIT', 'VDom initialization completed successfully');
    } catch (e) {
      VDomDebugLogger.log('VDOM_INIT_ERROR', 'VDom initialization failed: $e');
      _readyCompleter.completeError(e);
    }
  }

  /// Future that completes when VDom is ready
  Future<void> get isReady => _readyCompleter.future;

  /// Generate a unique view ID
  String _generateViewId() {
    final viewId = (_viewIdCounter++).toString();
    VDomDebugLogger.log('VIEW_ID_GENERATE', 'Generated view ID: $viewId');
    return viewId;
  }

  /// Register a component in the VDOM
  void registerComponent(DCFComponentNode component) {
    VDomDebugLogger.logMount(component, context: 'registerComponent');
    
    if (component is StatefulComponent) {
      _statefulComponents[component.instanceId] = component;
      component.scheduleUpdate = () => _scheduleComponentUpdate(component);
      VDomDebugLogger.log('COMPONENT_REGISTER', 'Registered StatefulComponent: ${component.instanceId}');
    } else if (component is StatelessComponent) {
      _statelessComponents[component.instanceId] = component;
      VDomDebugLogger.log('COMPONENT_REGISTER', 'Registered StatelessComponent: ${component.instanceId}');
    }

    // Register error boundary if applicable
    if (component is ErrorBoundary) {
      _errorBoundaries[component.instanceId] = component;
      VDomDebugLogger.log('ERROR_BOUNDARY_REGISTER', 'Registered ErrorBoundary: ${component.instanceId}');
    }
  }

  /// Handle a native event by finding the appropriate component and calling its handler
  void _handleNativeEvent(
      String viewId, String eventType, Map<dynamic, dynamic> eventData) {
    VDomDebugLogger.log('NATIVE_EVENT', 'Received event: $eventType for view: $viewId', 
      extra: {'EventData': eventData.toString()});
    
    final node = _nodesByViewId[viewId];
    if (node == null) {
      VDomDebugLogger.log('NATIVE_EVENT_ERROR', 'No node found for view ID: $viewId');
      return;
    }

    if (node is DCFElement) {
      // Try multiple event handler formats to ensure compatibility
      final eventHandlerKeys = [
        eventType, // exact match (e.g., 'onScroll')
        'on${eventType.substring(0, 1).toUpperCase()}${eventType.substring(1)}', // onEventName format
        eventType.toLowerCase(), // lowercase
        'on${eventType.toLowerCase().substring(0, 1).toUpperCase()}${eventType.toLowerCase().substring(1)}' // normalized
      ];

      for (final key in eventHandlerKeys) {
        if (node.props.containsKey(key) && node.props[key] is Function) {
          VDomDebugLogger.log('EVENT_HANDLER_FOUND', 'Found handler for $eventType using key: $key');
          _executeEventHandler(node.props[key], eventData);
          return;
        }
      }
      
      VDomDebugLogger.log('EVENT_HANDLER_NOT_FOUND', 'No handler found for event: $eventType', 
        extra: {'AvailableProps': node.props.keys.toList()});
    }
  }

  /// Execute an event handler with proper error handling and flexible signatures
  void _executeEventHandler(Function handler, Map<dynamic, dynamic> eventData) {
    VDomDebugLogger.log('EVENT_HANDLER_EXECUTE', 'Executing event handler', 
      extra: {'HandlerType': handler.runtimeType.toString()});
    
    try {
      // Use reflection to determine the function signature and call appropriately
      // This approach handles ANY function signature dynamically

      // Try calling with Map<String, dynamic> first (most common for events)
      try {
        // Use Function.apply for maximum flexibility - handles any signature
        if (eventData.isNotEmpty) {
          // Try with eventData as the first parameter
          Function.apply(handler, [eventData]);
        } else {
          // Try with no parameters for simple events
          Function.apply(handler, []);
        }
        VDomDebugLogger.log('EVENT_HANDLER_SUCCESS', 'Event handler executed successfully');
        return;
      } catch (e) {
        // If that fails, try other common patterns
        VDomDebugLogger.log('EVENT_HANDLER_RETRY', 'Retrying with different signature');
      }

      if (eventData.containsKey('width') && eventData.containsKey('height')) {
        // Handle onContentSizeChange events that might expect (double, double)
        try {
          final width = eventData['width'] as double? ?? 0.0;
          final height = eventData['height'] as double? ?? 0.0;
          Function.apply(handler, [width, height]);
          VDomDebugLogger.log('EVENT_HANDLER_SUCCESS', 'Content size change handler executed');
          return;
        } catch (e) {
          // Continue to next pattern
        }
      }

      // Try with no parameters (for simple click events)
      try {
        Function.apply(handler, []);
        VDomDebugLogger.log('EVENT_HANDLER_SUCCESS', 'Parameter-less handler executed');
        return;
      } catch (e) {
        // Continue to final fallback
      }

      // Final fallback - try dynamic invocation
      try {
        (handler as dynamic)(eventData);
        VDomDebugLogger.log('EVENT_HANDLER_SUCCESS', 'Dynamic handler executed');
      } catch (e) {
        VDomDebugLogger.log('EVENT_HANDLER_ERROR', 'All handler execution attempts failed', 
          extra: {'Error': e.toString()});
        throw Exception(
          'Failed to execute event handler for $handler with data $eventData: $e',
        );
      }
    } catch (e) {
      VDomDebugLogger.log('EVENT_HANDLER_ERROR', 'Critical error in event handler execution', 
        extra: {'Error': e.toString()});
      throw Exception(
        'Error executing event handler: $e',
      );
    }
  }

  /// Schedule a component update when state changes
  /// This is a key method that triggers UI updates after state changes
  void _scheduleComponentUpdate(StatefulComponent component) {
    VDomDebugLogger.logUpdate(component, 'State change triggered update');
    
    // NEW: Check for custom state change handler
    final customHandler = VDomExtensionRegistry.instance.getStateChangeHandler(component.runtimeType);
    if (customHandler != null) {
      VDomDebugLogger.log('CUSTOM_STATE_HANDLER', 'Using custom state change handler for ${component.runtimeType}');
      
      final context = VDomStateChangeContext(
        scheduleUpdate: () => _scheduleComponentUpdateInternal(component),
        skipUpdate: () => VDomDebugLogger.log('STATE_CHANGE_SKIP', 'Custom handler skipped update'),
        partialUpdate: (node) => _partialUpdateNode(node),
      );
      
      // Let the custom handler decide what to do
      if (customHandler.shouldHandle(component, null)) {
        customHandler.handleStateChange(component, null, null, context);
        return;
      }
    }

    // Original logic continues
    _scheduleComponentUpdateInternal(component);
  }

  /// Internal method for scheduling component updates (separated for extension use)
  void _scheduleComponentUpdateInternal(StatefulComponent component) {
    VDomDebugLogger.log('SCHEDULE_UPDATE', 'Scheduling internal update for component: ${component.instanceId}');
    
    // Verify component is still registered
    if (!_statefulComponents.containsKey(component.instanceId)) {
      VDomDebugLogger.log('COMPONENT_REREGISTER', 'Re-registering untracked component: ${component.instanceId}');
      // Re-register the component to ensure it's tracked
      registerComponent(component);
    }

    // Only add this specific component to the update queue
    // Don't cascade to parent components to prevent infinite loops
    final wasEmpty = _pendingUpdates.isEmpty;
    _pendingUpdates.add(component.instanceId);
    
    VDomDebugLogger.log('UPDATE_QUEUE', 'Added component to pending updates', 
      extra: {
        'ComponentId': component.instanceId,
        'QueueSize': _pendingUpdates.length,
        'WasEmpty': wasEmpty
      });

    // Only schedule a new update if one isn't already scheduled
    if (!_isUpdateScheduled) {
      _isUpdateScheduled = true;
      VDomDebugLogger.log('BATCH_SCHEDULE', 'Scheduling new batch update');

      // Schedule updates asynchronously to batch multiple updates
      // Use a very short delay to allow multiple state changes to be batched together
      // but maintain responsiveness
      Future.microtask(_processPendingUpdates);
    }
  }

  /// NEW: Partial update for specific node (used by extensions)
  void _partialUpdateNode(DCFComponentNode node) {
    VDomDebugLogger.log('PARTIAL_UPDATE', 'Performing partial update', component: node.runtimeType.toString());
    
    // Custom logic for partial updates without full reconciliation
    // This could be used by optimized state management extensions
    if (node.effectiveNativeViewId != null) {
      // Trigger a targeted update for just this node
      VDomDebugLogger.log('PARTIAL_UPDATE_NATIVE', 'Triggering native update for view: ${node.effectiveNativeViewId}');
    }
  }

  /// Process all pending component updates in a batch
  Future<void> _processPendingUpdates() async {
    VDomDebugLogger.log('BATCH_START', 'Starting batch update processing', 
      extra: {
        'PendingCount': _pendingUpdates.length,
        'BatchInProgress': _batchUpdateInProgress
      });
    
    // Prevent re-entry during batch processing
    if (_batchUpdateInProgress) {
      VDomDebugLogger.log('BATCH_SKIP', 'Batch already in progress, skipping');
      return;
    }

    _batchUpdateInProgress = true;

    try {
      if (_pendingUpdates.isEmpty) {
        VDomDebugLogger.log('BATCH_EMPTY', 'No pending updates to process');
        _isUpdateScheduled = false;
        _batchUpdateInProgress = false;
        return;
      }

      // Copy the pending updates to allow for new ones during processing
      final updates = Set<String>.from(_pendingUpdates);
      _pendingUpdates.clear();
      VDomDebugLogger.log('BATCH_UPDATES_COPIED', 'Copied ${updates.length} updates for processing');

      // Start batch update in native layer
      VDomDebugLogger.logBridge('START_BATCH', 'root');
      await _nativeBridge.startBatchUpdate();

      try {
        // Process each component update
        for (final componentId in updates) {
          VDomDebugLogger.log('BATCH_PROCESS_COMPONENT', 'Processing update for: $componentId');
          await _updateComponentById(componentId);
        }

        // Commit all batched updates at once
        VDomDebugLogger.logBridge('COMMIT_BATCH', 'root');
        await _nativeBridge.commitBatchUpdate();
        VDomDebugLogger.log('BATCH_COMMIT_SUCCESS', 'Successfully committed batch updates');

        // Layout is now calculated automatically when layout props change
        // No manual layout calculation needed
      } catch (e) {
        // Cancel batch if there's an error
        VDomDebugLogger.logBridge('CANCEL_BATCH', 'root', data: {'Error': e.toString()});
        await _nativeBridge.cancelBatchUpdate();
        VDomDebugLogger.log('BATCH_ERROR', 'Batch update failed, cancelled', extra: {'Error': e.toString()});
        rethrow;
      }

      // Check if new updates were scheduled during processing
      if (_pendingUpdates.isNotEmpty) {
        VDomDebugLogger.log('BATCH_NEW_UPDATES', 'New updates scheduled during batch, processing in next microtask', 
          extra: {'NewUpdatesCount': _pendingUpdates.length});
        // Process new updates in next microtask
        Future.microtask(_processPendingUpdates);
      } else {
        VDomDebugLogger.log('BATCH_COMPLETE', 'Batch processing completed, no new updates');
        _isUpdateScheduled = false;
      }
    } finally {
      _batchUpdateInProgress = false;
    }
  }

  /// Update a component by its ID
  Future<void> _updateComponentById(String componentId) async {
    VDomDebugLogger.log('COMPONENT_UPDATE_START', 'Starting update for component: $componentId');
    
    final component =
        _statefulComponents[componentId] ?? _statelessComponents[componentId];
    if (component == null) {
      VDomDebugLogger.log('COMPONENT_UPDATE_NOT_FOUND', 'Component not found: $componentId');
      return;
    }

    try {
      // NEW: Call lifecycle interceptor before update
      final lifecycleInterceptor = VDomExtensionRegistry.instance.getLifecycleInterceptor(component.runtimeType);
      if (lifecycleInterceptor != null) {
        VDomDebugLogger.log('LIFECYCLE_INTERCEPTOR', 'Calling beforeUpdate interceptor');
        final context = VDomLifecycleContext(
          scheduleUpdate: () => _scheduleComponentUpdateInternal(component as StatefulComponent),
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isUpdating': true},
        );
        lifecycleInterceptor.beforeUpdate(component, context);
      }

      // Perform component-specific update preparation
      if (component is StatefulComponent) {
        VDomDebugLogger.log('COMPONENT_PREPARE', 'Preparing StatefulComponent for render');
        component.prepareForRender();
      }

      // Store the previous rendered node before re-rendering
      final oldRenderedNode = component.renderedNode;
      VDomDebugLogger.log('COMPONENT_OLD_NODE', 'Stored old rendered node', 
        extra: {'HasOldNode': oldRenderedNode != null});

      // Store a reference to the old rendered node for proper reconciliation
      if (oldRenderedNode != null) {
        _previousRenderedNodes[componentId] = oldRenderedNode;
      }

      // Force re-render by clearing cached rendered node
      component.renderedNode = null;
      final newRenderedNode = component.renderedNode;

      if (newRenderedNode == null) {
        VDomDebugLogger.log('COMPONENT_UPDATE_NULL', 'Component rendered null, skipping update');
        return;
      }

      VDomDebugLogger.log('COMPONENT_NEW_NODE', 'Generated new rendered node', 
        component: newRenderedNode.runtimeType.toString());

      // Set parent relationship for the new rendered node
      newRenderedNode.parent = component;

      // Reconcile trees to apply minimal changes
      final previousRenderedNode = _previousRenderedNodes[componentId];
      if (previousRenderedNode != null) {
        VDomDebugLogger.log('RECONCILE_START', 'Starting reconciliation with previous node');
        
        // Find parent native view ID and index for replacement
        final parentViewId = _findParentViewId(component);

        if (previousRenderedNode.effectiveNativeViewId == null ||
            parentViewId == null) {
          VDomDebugLogger.log('RECONCILE_FALLBACK', 'Using fallback reconciliation due to missing IDs');
          // For problematic components or when we don't have required IDs, use standard reconciliation
          await _reconcile(previousRenderedNode, newRenderedNode);

          // Update contentViewId reference from old to new
          if (previousRenderedNode.effectiveNativeViewId != null) {
            component.contentViewId =
                previousRenderedNode.effectiveNativeViewId;
          }
        } else {
          VDomDebugLogger.log('RECONCILE_NORMAL', 'Performing normal reconciliation');
          // Reconcile to preserve structure and update props efficiently
          await _reconcile(previousRenderedNode, newRenderedNode);

          // Update contentViewId reference
          component.contentViewId = previousRenderedNode.effectiveNativeViewId;
        }

        // Clean up the stored previous rendered node
        _previousRenderedNodes.remove(componentId);
        VDomDebugLogger.log('RECONCILE_CLEANUP', 'Cleaned up previous rendered node reference');
      } else {
        VDomDebugLogger.log('RENDER_FROM_SCRATCH', 'No previous rendering, creating from scratch');
        // No previous rendering, create from scratch
        final parentViewId = _findParentViewId(component);
        if (parentViewId != null) {
          final newViewId =
              await renderToNative(newRenderedNode, parentViewId: parentViewId);
          if (newViewId != null) {
            component.contentViewId = newViewId;
            VDomDebugLogger.log('RENDER_NEW_SUCCESS', 'Successfully rendered new component view: $newViewId');
          }
        } else {
          VDomDebugLogger.log('RENDER_NO_PARENT', 'No parent view ID found for rendering');
        }
      }

      // Run lifecycle methods
      if (component is StatefulComponent) {
        VDomDebugLogger.log('LIFECYCLE_DID_UPDATE', 'Calling componentDidUpdate');
        component.componentDidUpdate({});
        VDomDebugLogger.log('LIFECYCLE_EFFECTS', 'Running effects after render');
        component.runEffectsAfterRender();
      }

      // NEW: Call lifecycle interceptor after update
      if (lifecycleInterceptor != null) {
        VDomDebugLogger.log('LIFECYCLE_INTERCEPTOR', 'Calling afterUpdate interceptor');
        final context = VDomLifecycleContext(
          scheduleUpdate: () => _scheduleComponentUpdateInternal(component as StatefulComponent),
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isUpdating': false},
        );
        lifecycleInterceptor.afterUpdate(component, context);
      }
      
      VDomDebugLogger.log('COMPONENT_UPDATE_SUCCESS', 'Component update completed successfully: $componentId');
    } catch (e) {
      VDomDebugLogger.log('COMPONENT_UPDATE_ERROR', 'Component update failed', 
        extra: {'ComponentId': componentId, 'Error': e.toString()});
    }
  }

  /// Render a node to native UI
  Future<String?> renderToNative(DCFComponentNode node,
      {String? parentViewId, int? index}) async {
    await isReady;

    VDomDebugLogger.logRender('START', node, viewId: node.effectiveNativeViewId, parentId: parentViewId);

    try {
      // Handle Fragment nodes
      if (node is DCFFragment) {
        VDomDebugLogger.log('RENDER_FRAGMENT', 'Rendering fragment node');
        
        // NEW: Call lifecycle interceptor before mount
        final lifecycleInterceptor = VDomExtensionRegistry.instance.getLifecycleInterceptor(node.runtimeType);
        if (lifecycleInterceptor != null) {
          final context = VDomLifecycleContext(
            scheduleUpdate: () {},
            forceUpdate: (node) => _partialUpdateNode(node),
            vdomState: {'isMounting': true},
          );
          lifecycleInterceptor.beforeMount(node, context);
        }

        // Mount the fragment
        if (!node.isMounted) {
          VDomDebugLogger.logMount(node, context: 'Fragment mounting');
          node.mount(node.parent);
        }

        // Check if this fragment is a portal placeholder
        if (node.metadata != null &&
            node.metadata!['isPortalPlaceholder'] == true) {
          VDomDebugLogger.log('PORTAL_PLACEHOLDER', 'Rendering portal placeholder fragment');
          // This is a portal placeholder fragment - the enhanced portal manager
          // handles rendering the children to the target
          final targetId = node.metadata!['targetId'] as String?;
          final portalId = node.metadata!['portalId'] as String?;

          if (targetId != null && portalId != null) {
            VDomDebugLogger.log('PORTAL_PLACEHOLDER_DETAILS', 'Portal placeholder details', 
              extra: {'TargetId': targetId, 'PortalId': portalId});
            // Portal placeholder fragments don't render anything here
            // The enhanced portal manager handles all the portal logic

            return null; // Portal placeholders have no native view
          }
        }

        // Check if this fragment is a portal target
        if (node.metadata != null && node.metadata!['isPortalTarget'] == true) {
          final targetId = node.metadata!['targetId'] as String?;
          VDomDebugLogger.log('PORTAL_TARGET', 'Rendering portal target fragment', 
            extra: {'TargetId': targetId});

          if (targetId != null) {
            // For portal targets, we should render normally but also allow
            // the portal manager to inject content
            // The enhanced portal manager will handle the portal content injection
          }
        }

        // Regular fragment - render children directly to parent
        int childIndex = index ?? 0;
        final childIds = <String>[];

        VDomDebugLogger.log('FRAGMENT_CHILDREN', 'Rendering ${node.children.length} fragment children');
        for (final child in node.children) {
          final childId = await renderToNative(
            child,
            parentViewId: parentViewId,
            index: childIndex++,
          );

          if (childId != null && childId.isNotEmpty) {
            childIds.add(childId);
          }
        }

        // Store child IDs for cleanup later
        node.childViewIds = childIds;
        VDomDebugLogger.log('FRAGMENT_CHILDREN_COMPLETE', 'Fragment children rendered', 
          extra: {'ChildCount': childIds.length, 'ChildIds': childIds});

        // NEW: Call lifecycle interceptor after mount
        if (lifecycleInterceptor != null) {
          final context = VDomLifecycleContext(
            scheduleUpdate: () {},
            forceUpdate: (node) => _partialUpdateNode(node),
            vdomState: {'isMounting': false},
          );
          lifecycleInterceptor.afterMount(node, context);
        }

        return null; // Fragments don't have their own native view ID
      }

      // Handle Component nodes
      if (node is StatefulComponent || node is StatelessComponent) {
        VDomDebugLogger.log('RENDER_COMPONENT', 'Rendering component node', 
          component: node.runtimeType.toString());
        
        try {
          // NEW: Call lifecycle interceptor before mount
          final lifecycleInterceptor = VDomExtensionRegistry.instance.getLifecycleInterceptor(node.runtimeType);
          if (lifecycleInterceptor != null) {
            final context = VDomLifecycleContext(
              scheduleUpdate: () => _scheduleComponentUpdateInternal(node as StatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': true},
            );
            lifecycleInterceptor.beforeMount(node, context);
          }

          // Register the component
          registerComponent(node);

          // Get the rendered content
          final renderedNode = node.renderedNode;
          if (renderedNode == null) {
            VDomDebugLogger.logRender('ERROR', node, error: 'Component rendered null');
            throw Exception('Component rendered null');
          }

          VDomDebugLogger.log('COMPONENT_RENDERED_NODE', 'Component rendered content', 
            extra: {'RenderedType': renderedNode.runtimeType.toString()});

          // Set parent relationship
          renderedNode.parent = node;

          // Render the content
          final viewId = await renderToNative(renderedNode,
              parentViewId: parentViewId, index: index);

          // Store the view ID
          node.contentViewId = viewId;
          VDomDebugLogger.log('COMPONENT_VIEW_ID', 'Component view ID assigned', 
            extra: {'ViewId': viewId});

          // Call lifecycle method if not already mounted
          if (node is StatefulComponent && !node.isMounted) {
            VDomDebugLogger.log('LIFECYCLE_DID_MOUNT', 'Calling componentDidMount for StatefulComponent');
            node.componentDidMount();
          } else if (node is StatelessComponent && !node.isMounted) {
            VDomDebugLogger.log('LIFECYCLE_DID_MOUNT', 'Calling componentDidMount for StatelessComponent');
            node.componentDidMount();
          }

          // Run effects for stateful components
          if (node is StatefulComponent) {
            VDomDebugLogger.log('LIFECYCLE_EFFECTS', 'Running effects after render for StatefulComponent');
            node.runEffectsAfterRender();
          }

          // NEW: Call lifecycle interceptor after mount
          if (lifecycleInterceptor != null) {
            final context = VDomLifecycleContext(
              scheduleUpdate: () => _scheduleComponentUpdateInternal(node as StatefulComponent),
              forceUpdate: (node) => _partialUpdateNode(node),
              vdomState: {'isMounting': false},
            );
            lifecycleInterceptor.afterMount(node, context);
          }

          VDomDebugLogger.logRender('SUCCESS', node, viewId: viewId);
          return viewId;
        } catch (error, stackTrace) {
          VDomDebugLogger.logRender('ERROR', node, error: error.toString());
          
          // Try to find nearest error boundary
          final errorBoundary = _findNearestErrorBoundary(node);
          if (errorBoundary != null) {
            VDomDebugLogger.log('ERROR_BOUNDARY_HANDLE', 'Error handled by boundary: ${errorBoundary.instanceId}');
            errorBoundary.handleError(error, stackTrace);
            return null; // Error handled by boundary
          }

          VDomDebugLogger.log('ERROR_BOUNDARY_NOT_FOUND', 'No error boundary found, propagating error');
          // No error boundary, propagate error
          rethrow;
        }
      }
      // Handle Element nodes
      else if (node is DCFElement) {
        VDomDebugLogger.log('RENDER_ELEMENT', 'Rendering element node', 
          extra: {'ElementType': node.type});
        return await _renderElementToNative(node,
            parentViewId: parentViewId, index: index);
      }
      // Handle EmptyVDomNode
      else if (node is EmptyVDomNode) {
        VDomDebugLogger.log('RENDER_EMPTY', 'Rendering empty node');
        return null; // Empty nodes don't create native views
      }

      VDomDebugLogger.logRender('UNKNOWN', node, error: 'Unknown node type');
      return null;
    } catch (e) {
      VDomDebugLogger.logRender('ERROR', node, error: e.toString());
      return null;
    }
  }

  /// Render an element to native UI
  Future<String?> _renderElementToNative(DCFElement element,
      {String? parentViewId, int? index}) async {
    VDomDebugLogger.log('ELEMENT_RENDER_START', 'Starting element render', 
      extra: {'ElementType': element.type, 'ParentViewId': parentViewId, 'Index': index});
    
    // Use existing view ID or generate a new one
    final viewId = element.nativeViewId ?? _generateViewId();

    // Store map from view ID to node
    _nodesByViewId[viewId] = element;
    element.nativeViewId = viewId;
    VDomDebugLogger.log('ELEMENT_VIEW_MAPPING', 'Mapped element to view ID', 
      extra: {'ViewId': viewId, 'ElementType': element.type});

    // Create the view
    VDomDebugLogger.logBridge('CREATE_VIEW', viewId, data: {
      'ElementType': element.type,
      'Props': element.props.keys.toList()
    });
    final success =
        await _nativeBridge.createView(viewId, element.type, element.props);
    if (!success) {
      VDomDebugLogger.log('ELEMENT_CREATE_FAILED', 'Failed to create native view', 
        extra: {'ViewId': viewId, 'ElementType': element.type});
      return null;
    }

    // If parent is specified, attach to parent
    if (parentViewId != null) {
      VDomDebugLogger.logBridge('ATTACH_VIEW', viewId, data: {
        'ParentViewId': parentViewId,
        'Index': index ?? 0
      });
      await _nativeBridge.attachView(viewId, parentViewId, index ?? 0);
    }

    // Register event listeners
    final eventTypes = element.eventTypes;
    if (eventTypes.isNotEmpty) {
      VDomDebugLogger.logBridge('ADD_EVENT_LISTENERS', viewId, data: {
        'EventTypes': eventTypes
      });
      await _nativeBridge.addEventListeners(viewId, eventTypes);
    }

    // Render children
    final childIds = <String>[];
    VDomDebugLogger.log('ELEMENT_CHILDREN_START', 'Rendering ${element.children.length} children');

    for (var i = 0; i < element.children.length; i++) {
      final childId = await renderToNative(element.children[i],
          parentViewId: viewId, index: i);
      if (childId != null && childId.isNotEmpty) {
        childIds.add(childId);
      }
    }

    // Set children order
    if (childIds.isNotEmpty) {
      VDomDebugLogger.logBridge('SET_CHILDREN', viewId, data: {
        'ChildIds': childIds
      });
      await _nativeBridge.setChildren(viewId, childIds);
    }

    VDomDebugLogger.log('ELEMENT_RENDER_SUCCESS', 'Element render completed', 
      extra: {'ViewId': viewId, 'ChildCount': childIds.length});
    return viewId;
  }

  /// Reconcile two nodes by efficiently updating only what changed
  /// NOW WITH EXTENSION SUPPORT
  Future<void> _reconcile(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    
    VDomDebugLogger.logReconcile('START', oldNode, newNode, reason: 'Beginning reconciliation');
    
    // NEW: Check for custom reconciliation handler first
    final customHandler = VDomExtensionRegistry.instance.getReconciliationHandler(newNode.runtimeType);
    if (customHandler != null && customHandler.shouldHandle(oldNode, newNode)) {
      VDomDebugLogger.log('CUSTOM_RECONCILE', 'Using custom reconciliation handler', 
        component: newNode.runtimeType.toString());
      
      final context = VDomReconciliationContext(
        defaultReconcile: (old, new_) => _reconcile(old, new_),
        replaceNode: (old, new_) => _replaceNode(old, new_),
        mountNode: (node) => node.mount(node.parent),
        unmountNode: (node) => node.unmount(),
      );
      
      await customHandler.reconcile(oldNode, newNode, context);
      VDomDebugLogger.logReconcile('CUSTOM_COMPLETE', oldNode, newNode, reason: 'Custom reconciliation completed');
      return;
    }

    // Transfer important parent reference first
    newNode.parent = oldNode.parent;

    // If the node types are completely different, replace the node entirely
    if (oldNode.runtimeType != newNode.runtimeType) {
      VDomDebugLogger.logReconcile('REPLACE_TYPE', oldNode, newNode, reason: 'Different node types');
      await _replaceNode(oldNode, newNode);
      return;
    }

    // CRITICAL HOT RELOAD FIX: If the keys are different, replace the component entirely
    // This ensures that when we change component keys (like 'app_1' to 'app_2'),
    // a completely new component instance is created instead of trying to update the existing one
    if (oldNode.key != newNode.key) {
      VDomDebugLogger.logReconcile('REPLACE_KEY', oldNode, newNode, reason: 'Different keys - hot reload fix');
      await _replaceNode(oldNode, newNode);
      return;
    }

    // Handle different node types
    if (oldNode is DCFElement && newNode is DCFElement) {
      // If different element types, we need to replace it
      if (oldNode.type != newNode.type) {
        VDomDebugLogger.logReconcile('REPLACE_ELEMENT_TYPE', oldNode, newNode, reason: 'Different element types');
        await _replaceNode(oldNode, newNode);
      } else {
        VDomDebugLogger.logReconcile('UPDATE_ELEMENT', oldNode, newNode, reason: 'Same element type - updating props and children');
        // Same element type - update props and children only
        await _reconcileElement(oldNode, newNode);
      }
    }
    // Handle component nodes
    else if (oldNode is StatefulComponent && newNode is StatefulComponent) {
      VDomDebugLogger.logReconcile('UPDATE_STATEFUL', oldNode, newNode, reason: 'Reconciling StatefulComponent');
      
      // Transfer important properties between nodes
      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      // Update component tracking
      _statefulComponents[newNode.instanceId] = newNode;
      newNode.scheduleUpdate = oldNode.scheduleUpdate;

      // Register the new component instance
      registerComponent(newNode);

      // Handle reconciliation of the rendered trees
      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;

      // Standard reconciliation for components
      await _reconcile(oldRenderedNode, newRenderedNode);
    }
    // Handle stateless components
    else if (oldNode is StatelessComponent && newNode is StatelessComponent) {
      VDomDebugLogger.logReconcile('UPDATE_STATELESS', oldNode, newNode, reason: 'Reconciling StatelessComponent');
      
      // Transfer IDs
      newNode.nativeViewId = oldNode.nativeViewId;
      newNode.contentViewId = oldNode.contentViewId;

      // FRAMEWORK-LEVEL OPTIMIZATION:
      // If two stateless components are "semantically equal" (checked via operator==),
      // we can skip reconciling their children entirely. This avoids the need for
      // developers to manually memoize simple, static components.
      if (oldNode == newNode) {
        VDomDebugLogger.logReconcile('SKIP_STATELESS', oldNode, newNode, reason: 'Stateless components are semantically equal');
        return; // The new node is identical to the old one, so no work is needed.
      }

      // Handle reconciliation of the rendered trees
      final oldRenderedNode = oldNode.renderedNode;
      final newRenderedNode = newNode.renderedNode;

      await _reconcile(oldRenderedNode, newRenderedNode);
    }
    // Handle Fragment nodes
    else if (oldNode is DCFFragment && newNode is DCFFragment) {
      VDomDebugLogger.logReconcile('UPDATE_FRAGMENT', oldNode, newNode, reason: 'Reconciling Fragment');
      
      // Transfer children relationships
      newNode.parent = oldNode.parent;
      newNode.childViewIds = oldNode.childViewIds;

      // Reconcile fragment children directly since fragments don't have native view IDs
      if (oldNode.children.isNotEmpty || newNode.children.isNotEmpty) {
        // Find the parent view ID to reconcile children against
        final parentViewId = _findParentViewId(oldNode);
        if (parentViewId != null) {
          VDomDebugLogger.log('FRAGMENT_CHILDREN_RECONCILE', 'Reconciling fragment children', 
            extra: {'ParentViewId': parentViewId, 'OldChildCount': oldNode.children.length, 'NewChildCount': newNode.children.length});
          await _reconcileFragmentChildren(
              parentViewId, oldNode.children, newNode.children);
        }
      }
    }
    // Handle empty nodes
    else if (oldNode is EmptyVDomNode && newNode is EmptyVDomNode) {
      VDomDebugLogger.logReconcile('SKIP_EMPTY', oldNode, newNode, reason: 'Both nodes are empty');
      // Nothing to do for empty nodes
      return;
    }
    
    VDomDebugLogger.logReconcile('COMPLETE', oldNode, newNode, reason: 'Reconciliation completed successfully');
  }

  /// Replace a node entirely
  Future<void> _replaceNode(
      DCFComponentNode oldNode, DCFComponentNode newNode) async {
    VDomDebugLogger.log('REPLACE_NODE_START', 'Starting node replacement', 
      extra: {
        'OldNodeType': oldNode.runtimeType.toString(),
        'NewNodeType': newNode.runtimeType.toString(),
        'OldViewId': oldNode.effectiveNativeViewId
      });
    
    // NEW: Call lifecycle interceptor before unmount
    final lifecycleInterceptor = VDomExtensionRegistry.instance.getLifecycleInterceptor(oldNode.runtimeType);
    if (lifecycleInterceptor != null) {
      final context = VDomLifecycleContext(
        scheduleUpdate: () {},
        forceUpdate: (node) => _partialUpdateNode(node),
        vdomState: {'isUnmounting': true},
      );
      lifecycleInterceptor.beforeUnmount(oldNode, context);
    }

    // CRITICAL HOT RELOAD FIX: Properly dispose of old component instances
    await _disposeOldComponent(oldNode);

    // Can't replace if the old node has no view ID
    if (oldNode.effectiveNativeViewId == null) {
      VDomDebugLogger.log('REPLACE_NODE_NO_VIEW_ID', 'Old node has no view ID, cannot replace');
      return;
    }

    // Find parent info for placing the new node
    final parentViewId = _findParentViewId(oldNode);
    if (parentViewId == null) {
      VDomDebugLogger.log('REPLACE_NODE_NO_PARENT', 'No parent view ID found');
      return;
    }

    // Find index of node in parent
    final index = _findNodeIndexInParent(oldNode);
    VDomDebugLogger.log('REPLACE_NODE_POSITION', 'Found replacement position', 
      extra: {'ParentViewId': parentViewId, 'Index': index});

    // CRITICAL FIX: Temporarily exit batch mode to ensure atomic delete+create
    // This prevents createView from being queued while deleteView executes immediately
    final wasBatchMode = _batchUpdateInProgress;
    if (wasBatchMode) {
      VDomDebugLogger.log('REPLACE_BATCH_PAUSE', 'Temporarily pausing batch mode for atomic replacement');
      // Temporarily commit current batch to ensure proper ordering
      await _nativeBridge.commitBatchUpdate();
      _batchUpdateInProgress = false;
    }

    try {
      // Store the old view ID and event types for reuse
      final oldViewId = oldNode.effectiveNativeViewId!;
      final oldEventTypes =
          (oldNode is DCFElement) ? oldNode.eventTypes : <String>[];
      final newEventTypes =
          (newNode is DCFElement) ? newNode.eventTypes : <String>[];

      VDomDebugLogger.log('REPLACE_EVENT_TYPES', 'Comparing event types', 
        extra: {'OldEvents': oldEventTypes, 'NewEvents': newEventTypes});

      // Special case: If new node is a component that renders a fragment (like DCFPortal)
      if (newNode is StatefulComponent || newNode is StatelessComponent) {
        final renderedNode = newNode.renderedNode;
        if (renderedNode is DCFFragment) {
          VDomDebugLogger.log('REPLACE_COMPONENT_TO_FRAGMENT', 'Replacing component with fragment renderer');
          // Delete the old view since the component renders a fragment
          VDomDebugLogger.logBridge('DELETE_VIEW', oldViewId);
          await _nativeBridge.deleteView(oldViewId);
          _nodesByViewId.remove(oldViewId);

          // Render the component normally to parent
          await renderToNative(newNode,
              parentViewId: parentViewId, index: index);

          return;
        }
      }

      // CRITICAL EVENT FIX: Instead of deleting and recreating the view,
      // reuse the same view ID to preserve native event listener connections
      newNode.nativeViewId = oldViewId;
      VDomDebugLogger.log('REPLACE_REUSE_VIEW_ID', 'Reusing view ID for event preservation', 
        extra: {'ViewId': oldViewId});

      // Update the mapping to point to the new node IMMEDIATELY
      _nodesByViewId[oldViewId] = newNode;

      // Only update event listeners if they changed
      final oldEventSet = Set<String>.from(oldEventTypes);
      final newEventSet = Set<String>.from(newEventTypes);

      if (oldEventSet.length != newEventSet.length ||
          !oldEventSet.containsAll(newEventSet)) {
        VDomDebugLogger.log('REPLACE_UPDATE_EVENTS', 'Updating event listeners');
        
        // Remove old event listeners that are no longer needed
        final eventsToRemove = oldEventSet.difference(newEventSet);
        if (eventsToRemove.isNotEmpty) {
          VDomDebugLogger.logBridge('REMOVE_EVENT_LISTENERS', oldViewId, data: {'EventTypes': eventsToRemove.toList()});
          await _nativeBridge.removeEventListeners(
              oldViewId, eventsToRemove.toList());
        }

        // Add new event listeners
        final eventsToAdd = newEventSet.difference(oldEventSet);
        if (eventsToAdd.isNotEmpty) {
          VDomDebugLogger.logBridge('ADD_EVENT_LISTENERS', oldViewId, data: {'EventTypes': eventsToAdd.toList()});
          await _nativeBridge.addEventListeners(
              oldViewId, eventsToAdd.toList());
        }
      }

      // Delete the old view completely (this will create a new native view)
      VDomDebugLogger.logBridge('DELETE_VIEW', oldViewId);
      await _nativeBridge.deleteView(oldViewId);

      // Create the new view with the preserved view ID
      final newViewId = await renderToNative(newNode,
          parentViewId: parentViewId, index: index);

      // Verify the view creation was successful
      if (newViewId != null && newViewId.isNotEmpty) {
        VDomDebugLogger.log('REPLACE_NODE_SUCCESS', 'Node replacement completed successfully', 
          extra: {'NewViewId': newViewId});
      } else {
        VDomDebugLogger.log('REPLACE_NODE_FAILED', 'Node replacement failed - no view ID returned');
      }
    } finally {
      // Resume batch mode if we were previously in batch mode
      if (wasBatchMode) {
        VDomDebugLogger.log('REPLACE_BATCH_RESUME', 'Resuming batch mode');
        await _nativeBridge.startBatchUpdate();
        _batchUpdateInProgress = true;
      }
    }

    // NEW: Call lifecycle interceptor after unmount
    if (lifecycleInterceptor != null) {
      final context = VDomLifecycleContext(
        scheduleUpdate: () {},
        forceUpdate: (node) => _partialUpdateNode(node),
        vdomState: {'isUnmounting': false},
      );
      lifecycleInterceptor.afterUnmount(oldNode, context);
    }
  }

  /// Dispose of old component instance and clean up its state
  Future<void> _disposeOldComponent(DCFComponentNode oldNode) async {
    VDomDebugLogger.logUnmount(oldNode, context: 'Disposing old component');
    
    try {
      // NEW: Call lifecycle interceptor before unmount
      final lifecycleInterceptor = VDomExtensionRegistry.instance.getLifecycleInterceptor(oldNode.runtimeType);
      if (lifecycleInterceptor != null) {
        final context = VDomLifecycleContext(
          scheduleUpdate: () {},
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isDisposing': true},
        );
        lifecycleInterceptor.beforeUnmount(oldNode, context);
      }

      // Handle StatefulComponent disposal
      if (oldNode is StatefulComponent) {
        VDomDebugLogger.log('DISPOSE_STATEFUL', 'Disposing StatefulComponent', 
          extra: {'InstanceId': oldNode.instanceId});
        
        // Remove from component tracking FIRST to prevent further updates
        _statefulComponents.remove(oldNode.instanceId);
        _pendingUpdates.remove(oldNode.instanceId);
        _previousRenderedNodes.remove(oldNode.instanceId);

        // Call lifecycle cleanup
        try {
          oldNode.componentWillUnmount();
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT', 'Called componentWillUnmount for StatefulComponent');
        } catch (e) {
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount', 
            extra: {'Error': e.toString()});
        }

        // Recursively dispose rendered content
        await _disposeOldComponent(oldNode.renderedNode!);
            }
      // Handle StatelessComponent disposal
      else if (oldNode is StatelessComponent) {
        VDomDebugLogger.log('DISPOSE_STATELESS', 'Disposing StatelessComponent', 
          extra: {'InstanceId': oldNode.instanceId});
        
        // Remove from component tracking
        _statelessComponents.remove(oldNode.instanceId);

        // Call lifecycle cleanup
        try {
          oldNode.componentWillUnmount();
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT', 'Called componentWillUnmount for StatelessComponent');
        } catch (e) {
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount', 
            extra: {'Error': e.toString()});
        }

        // Recursively dispose rendered content
        await _disposeOldComponent(oldNode.renderedNode!);
            }
      // Handle DCFElement disposal
      else if (oldNode is DCFElement) {
        VDomDebugLogger.log('DISPOSE_ELEMENT', 'Disposing DCFElement', 
          extra: {'ElementType': oldNode.type, 'ChildCount': oldNode.children.length});
        
        // Recursively dispose child components
        for (final child in oldNode.children) {
          await _disposeOldComponent(child);
        }
      }

      // Remove from view tracking
      if (oldNode.effectiveNativeViewId != null) {
        _nodesByViewId.remove(oldNode.effectiveNativeViewId);
        VDomDebugLogger.log('DISPOSE_VIEW_TRACKING', 'Removed from view tracking', 
          extra: {'ViewId': oldNode.effectiveNativeViewId});
      }

      // NEW: Call lifecycle interceptor after unmount
      if (lifecycleInterceptor != null) {
        final context = VDomLifecycleContext(
          scheduleUpdate: () {},
          forceUpdate: (node) => _partialUpdateNode(node),
          vdomState: {'isDisposing': false},
        );
        lifecycleInterceptor.afterUnmount(oldNode, context);
      }
    } catch (e) {
      VDomDebugLogger.log('DISPOSE_ERROR', 'Error during component disposal', 
        extra: {'Error': e.toString(), 'NodeType': oldNode.runtimeType.toString()});
    }
  }

  /// Find a node's parent view ID
  String? _findParentViewId(DCFComponentNode node) {
    DCFComponentNode? current = node.parent;

    // Find the first parent with a native view ID
    while (current != null) {
      final viewId = current.effectiveNativeViewId;
      if (viewId != null && viewId.isNotEmpty) {
        VDomDebugLogger.log('PARENT_VIEW_FOUND', 'Found parent view ID', 
          extra: {'ParentViewId': viewId, 'ParentType': current.runtimeType.toString()});
        return viewId;
      }
      current = current.parent;
    }

    VDomDebugLogger.log('PARENT_VIEW_DEFAULT', 'No parent view found, using root');
    // Default to root if no parent found
    return "root";
  }

  /// Find a node's index in its parent's children
  int _findNodeIndexInParent(DCFComponentNode node) {
    // Can't determine index without parent
    if (node.parent == null) {
      VDomDebugLogger.log('NODE_INDEX_NO_PARENT', 'No parent found, using index 0');
      return 0;
    }

    // Only element parents can have indexed children
    if (node.parent is! DCFElement) {
      VDomDebugLogger.log('NODE_INDEX_NOT_ELEMENT', 'Parent is not DCFElement, using index 0');
      return 0;
    }

    final parent = node.parent as DCFElement;
    final index = parent.children.indexOf(node);
    VDomDebugLogger.log('NODE_INDEX_FOUND', 'Found node index in parent', 
      extra: {'Index': index, 'ParentChildCount': parent.children.length});
    return index;
  }

  /// Reconcile an element - update props and children
  Future<void> _reconcileElement(
      DCFElement oldElement, DCFElement newElement) async {
    VDomDebugLogger.log('RECONCILE_ELEMENT_START', 'Starting element reconciliation', 
      extra: {'ElementType': oldElement.type, 'ViewId': oldElement.nativeViewId});
    
    // Update properties if the element has a native view
    if (oldElement.nativeViewId != null) {
      // Copy native view ID to new element for tracking
      newElement.nativeViewId = oldElement.nativeViewId;

      // CRITICAL FIX: Always update the tracking map to maintain event handler lookup
      // This ensures scroll views and other event-emitting components stay connected
      _nodesByViewId[oldElement.nativeViewId!] = newElement;
      VDomDebugLogger.log('RECONCILE_UPDATE_TRACKING', 'Updated node tracking map');

      // CRITICAL EVENT FIX: Handle event registration changes during reconciliation
      final oldEventTypes = oldElement.eventTypes;
      final newEventTypes = newElement.eventTypes;

      // Check if event types have changed
      final oldEventSet = Set<String>.from(oldEventTypes);
      final newEventSet = Set<String>.from(newEventTypes);

      if (oldEventSet.length != newEventSet.length ||
          !oldEventSet.containsAll(newEventSet)) {
        VDomDebugLogger.log('RECONCILE_UPDATE_EVENTS', 'Event types changed, updating listeners', 
          extra: {'OldEvents': oldEventTypes, 'NewEvents': newEventTypes});
        
        // Remove old event listeners that are no longer needed
        final eventsToRemove = oldEventSet.difference(newEventSet);
        if (eventsToRemove.isNotEmpty) {
          VDomDebugLogger.logBridge('REMOVE_EVENT_LISTENERS', oldElement.nativeViewId!, 
            data: {'EventTypes': eventsToRemove.toList()});
          await _nativeBridge.removeEventListeners(
              oldElement.nativeViewId!, eventsToRemove.toList());
        }

        // Add new event listeners
        final eventsToAdd = newEventSet.difference(oldEventSet);
        if (eventsToAdd.isNotEmpty) {
          VDomDebugLogger.logBridge('ADD_EVENT_LISTENERS', oldElement.nativeViewId!, 
            data: {'EventTypes': eventsToAdd.toList()});
          await _nativeBridge.addEventListeners(
              oldElement.nativeViewId!, eventsToAdd.toList());
        }
      }

      // Find changed props using proper diffing algorithm
      final changedProps = _diffProps(oldElement.props, newElement.props);

      // Update props if there are changes
      if (changedProps.isNotEmpty) {
        VDomDebugLogger.logBridge('UPDATE_VIEW', oldElement.nativeViewId!, 
          data: {'ChangedProps': changedProps.keys.toList()});
        // Update the native view
        await _nativeBridge.updateView(oldElement.nativeViewId!, changedProps);
      } else {
        VDomDebugLogger.log('RECONCILE_NO_PROP_CHANGES', 'No prop changes detected');
      }

      // Now reconcile children with the most efficient algorithm
      VDomDebugLogger.log('RECONCILE_CHILDREN_START', 'Starting children reconciliation', 
        extra: {'OldChildCount': oldElement.children.length, 'NewChildCount': newElement.children.length});
      await _reconcileChildren(oldElement, newElement);
    }
    
    VDomDebugLogger.log('RECONCILE_ELEMENT_COMPLETE', 'Element reconciliation completed');
  }

  /// Compute differences between two prop maps
  Map<String, dynamic> _diffProps(
      Map<String, dynamic> oldProps, Map<String, dynamic> newProps) {
    final changedProps = <String, dynamic>{};
    int addedCount = 0;
    int changedCount = 0;
    int removedCount = 0;

    // Find added or changed props
    for (final entry in newProps.entries) {
      final key = entry.key;
      final value = entry.value;

      // Skip function handlers - they're managed separately by event system
      if (value is Function) continue;

      // Add to changes if prop is new or has different value
      if (!oldProps.containsKey(key)) {
        changedProps[key] = value;
        addedCount++;
      } else if (oldProps[key] != value) {
        changedProps[key] = value;
        changedCount++;
      }
    }

    // Find removed props (set to null to delete)
    for (final key in oldProps.keys) {
      if (!newProps.containsKey(key) && oldProps[key] is! Function) {
        changedProps[key] = null;
        removedCount++;
      }
    }

    // Handle event handlers - preserve them if not changed
    for (final key in oldProps.keys) {
      if (key.startsWith('on') &&
          oldProps[key] is Function &&
          !newProps.containsKey(key)) {
        changedProps[key] = oldProps[key];
      }
    }

    VDomDebugLogger.log('PROP_DIFF_COMPLETE', 'Props diffing completed', 
      extra: {
        'Added': addedCount,
        'Changed': changedCount,
        'Removed': removedCount,
        'Total': changedProps.length
      });

    return changedProps;
  }

  /// Reconcile children with keyed optimization
  Future<void> _reconcileChildren(
      DCFElement oldElement, DCFElement newElement) async {
    final oldChildren = oldElement.children;
    final newChildren = newElement.children;

    VDomDebugLogger.log('RECONCILE_CHILDREN', 'Starting children reconciliation', 
      extra: {
        'OldCount': oldChildren.length,
        'NewCount': newChildren.length,
        'ViewId': oldElement.nativeViewId
      });

    // Fast path: no children
    if (oldChildren.isEmpty && newChildren.isEmpty) {
      VDomDebugLogger.log('RECONCILE_CHILDREN_EMPTY', 'No children to reconcile');
      return;
    }

    // Check if children have keys for optimized reconciliation
    final hasKeys = _childrenHaveKeys(newChildren);
    VDomDebugLogger.log('RECONCILE_CHILDREN_STRATEGY', 'Choosing reconciliation strategy', 
      extra: {'HasKeys': hasKeys});

    if (hasKeys) {
      await _reconcileKeyedChildren(
          oldElement.nativeViewId!, oldChildren, newChildren);
    } else {
      await _reconcileSimpleChildren(
          oldElement.nativeViewId!, oldChildren, newChildren);
    }
  }

  /// Check if any children have explicit keys
  bool _childrenHaveKeys(List<DCFComponentNode> children) {
    if (children.isEmpty) return false;

    for (var child in children) {
      if (child.key != null) return true;
    }

    return false;
  }

  /// Reconcile fragment children directly without a container element
  Future<void> _reconcileFragmentChildren(
      String parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    VDomDebugLogger.log('RECONCILE_FRAGMENT_CHILDREN', 'Reconciling fragment children', 
      extra: {
        'ParentViewId': parentViewId,
        'OldCount': oldChildren.length,
        'NewCount': newChildren.length
      });
    
    // Use the same reconciliation logic as elements but for fragment children
    final hasKeys = _childrenHaveKeys(newChildren);

    if (hasKeys) {
      await _reconcileKeyedChildren(parentViewId, oldChildren, newChildren);
    } else {
      await _reconcileSimpleChildren(parentViewId, oldChildren, newChildren);
    }
  }

  /// Reconcile children with keys for optimal reordering
  Future<void> _reconcileKeyedChildren(
      String parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    VDomDebugLogger.log('RECONCILE_KEYED_START', 'Starting keyed children reconciliation', 
      extra: {
        'ParentViewId': parentViewId,
        'OldCount': oldChildren.length,
        'NewCount': newChildren.length
      });
    
    // Create map of old children by key for O(1) lookup
    final oldChildrenMap = <String?, DCFComponentNode>{};
    final oldChildOrderByKey = <String?, int>{};
    for (int i = 0; i < oldChildren.length; i++) {
      final oldChild = oldChildren[i];
      final key = oldChild.key ?? i.toString(); // Use index for null keys
      oldChildrenMap[key] = oldChild;
      oldChildOrderByKey[key] = i;
    }

    VDomDebugLogger.log('RECONCILE_KEYED_MAP', 'Created old children map', 
      extra: {'KeyCount': oldChildrenMap.length});

    // Track children that need to be in final list
    final updatedChildIds = <String>[];
    final processedOldChildren = <DCFComponentNode>{};
    bool hasStructuralChanges = false;

    // Process each new child
    for (int i = 0; i < newChildren.length; i++) {
      final newChild = newChildren[i];
      final key = newChild.key ?? i.toString();
      final oldChild = oldChildrenMap[key];

      String? childViewId;

      if (oldChild != null) {
        VDomDebugLogger.log('RECONCILE_KEYED_UPDATE', 'Updating existing child', 
          extra: {'Key': key, 'Position': i});
        
        // Mark as processed
        processedOldChildren.add(oldChild);

        // Update existing child
        await _reconcile(oldChild, newChild);

        // Get the view ID (which might come from different sources)
        childViewId = oldChild.effectiveNativeViewId;

        // Check if the position changed (reordering)
        final oldIndex = oldChildOrderByKey[key];
        if (oldIndex != null && oldIndex != i) {
          hasStructuralChanges = true;
          VDomDebugLogger.log('RECONCILE_KEYED_REORDER', 'Child position changed', 
            extra: {'Key': key, 'OldIndex': oldIndex, 'NewIndex': i});
          // Update position if needed
          if (childViewId != null) {
            await _moveChild(childViewId, parentViewId, i);
          }
        }
      } else {
        VDomDebugLogger.log('RECONCILE_KEYED_CREATE', 'Creating new child', 
          extra: {'Key': key, 'Position': i});
        
        // Create new child - this is a structural change
        hasStructuralChanges = true;
        childViewId = await renderToNative(newChild,
            parentViewId: parentViewId, index: i);
      }

      // Add to updated children list
      if (childViewId != null) {
        updatedChildIds.add(childViewId);
      }
    }

    // Remove old children that aren't in the new list
    for (var oldChild in oldChildren) {
      if (!processedOldChildren.contains(oldChild)) {
        hasStructuralChanges = true; // Removal is a structural change
        VDomDebugLogger.log('RECONCILE_KEYED_REMOVE', 'Removing old child', 
          extra: {'ChildType': oldChild.runtimeType.toString()});

        // CRITICAL FIX: Call componentWillUnmount on removed components
        try {
          oldChild.componentWillUnmount();
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT', 'Called componentWillUnmount for removed child');
        } catch (e) {
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount for removed child', 
            extra: {'Error': e.toString()});
        }

        final viewId = oldChild.effectiveNativeViewId;
        if (viewId != null) {
          VDomDebugLogger.logBridge('DELETE_VIEW', viewId);
          await _nativeBridge.deleteView(viewId);
          _nodesByViewId.remove(viewId);
        }
      }
    }

    // Only call setChildren if there were structural changes (additions, removals, or reorders)
    if (hasStructuralChanges && updatedChildIds.isNotEmpty) {
      VDomDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
        'ChildIds': updatedChildIds,
        'ChildCount': updatedChildIds.length
      });
      await _nativeBridge.setChildren(parentViewId, updatedChildIds);
    }
    
    VDomDebugLogger.log('RECONCILE_KEYED_COMPLETE', 'Keyed children reconciliation completed', 
      extra: {
        'StructuralChanges': hasStructuralChanges,
        'FinalChildCount': updatedChildIds.length
      });
  }

  /// Reconcile children without keys (simpler algorithm)
  Future<void> _reconcileSimpleChildren(
      String parentViewId,
      List<DCFComponentNode> oldChildren,
      List<DCFComponentNode> newChildren) async {
    VDomDebugLogger.log('RECONCILE_SIMPLE_START', 'Starting simple children reconciliation', 
      extra: {
        'ParentViewId': parentViewId,
        'OldCount': oldChildren.length,
        'NewCount': newChildren.length
      });
    
    final updatedChildIds = <String>[];
    final commonLength = math.min(oldChildren.length, newChildren.length);
    bool hasStructuralChanges = false;

    // Update common children
    for (int i = 0; i < commonLength; i++) {
      final oldChild = oldChildren[i];
      final newChild = newChildren[i];

      VDomDebugLogger.log('RECONCILE_SIMPLE_UPDATE', 'Updating child at index $i');

      // Reconcile the child
      await _reconcile(oldChild, newChild);

      // Add to updated children
      final childViewId = oldChild.effectiveNativeViewId;
      if (childViewId != null) {
        updatedChildIds.add(childViewId);
      }
    }

    // Handle length differences
    if (newChildren.length > oldChildren.length) {
      // Add any extra new children - this is a structural change
      hasStructuralChanges = true;
      VDomDebugLogger.log('RECONCILE_SIMPLE_ADD', 'Adding ${newChildren.length - commonLength} new children');
      
      for (int i = commonLength; i < newChildren.length; i++) {
        final childViewId = await renderToNative(newChildren[i],
            parentViewId: parentViewId, index: i);

        if (childViewId != null) {
          updatedChildIds.add(childViewId);
        }
      }
    } else if (oldChildren.length > newChildren.length) {
      // Remove any extra old children - this is a structural change
      hasStructuralChanges = true;
      VDomDebugLogger.log('RECONCILE_SIMPLE_REMOVE', 'Removing ${oldChildren.length - commonLength} old children');
      
      for (int i = commonLength; i < oldChildren.length; i++) {
        final oldChild = oldChildren[i];

        // CRITICAL FIX: Call componentWillUnmount on removed components
        try {
          oldChild.componentWillUnmount();
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT', 'Called componentWillUnmount for removed child');
        } catch (e) {
          VDomDebugLogger.log('LIFECYCLE_WILL_UNMOUNT_ERROR', 'Error in componentWillUnmount for removed child', 
            extra: {'Error': e.toString()});
        }

        final viewId = oldChild.effectiveNativeViewId;
        if (viewId != null) {
          VDomDebugLogger.logBridge('DELETE_VIEW', viewId);
          await _nativeBridge.deleteView(viewId);
          _nodesByViewId.remove(viewId);
        }
      }
    }

    // Only call setChildren if there were structural changes (additions or removals)
    if (hasStructuralChanges && updatedChildIds.isNotEmpty) {
      VDomDebugLogger.logBridge('SET_CHILDREN', parentViewId, data: {
        'ChildIds': updatedChildIds,
        'ChildCount': updatedChildIds.length
      });
      await _nativeBridge.setChildren(parentViewId, updatedChildIds);
    }
    
    VDomDebugLogger.log('RECONCILE_SIMPLE_COMPLETE', 'Simple children reconciliation completed', 
      extra: {
        'StructuralChanges': hasStructuralChanges,
        'FinalChildCount': updatedChildIds.length
      });
  }

  /// Move a child to a specific index in its parent
  Future<void> _moveChild(String childId, String parentId, int index) async {
    VDomDebugLogger.logBridge('MOVE_CHILD', childId, data: {
      'ParentId': parentId,
      'NewIndex': index
    });
    
    // Detach and then attach again at the right position
    await _nativeBridge.detachView(childId);
    await _nativeBridge.attachView(childId, parentId, index);
  }

  /// Find the nearest error boundary
  ErrorBoundary? _findNearestErrorBoundary(DCFComponentNode node) {
    DCFComponentNode? current = node;

    while (current != null) {
      if (current is ErrorBoundary) {
        VDomDebugLogger.log('ERROR_BOUNDARY_FOUND', 'Found error boundary', 
          extra: {'BoundaryId': current.instanceId});
        return current;
      }
      current = current.parent;
    }

    VDomDebugLogger.log('ERROR_BOUNDARY_NOT_FOUND', 'No error boundary found in component tree');
    return null;
  }

  /// Create the root component for the application
  Future<void> createRoot(DCFComponentNode component) async {
    VDomDebugLogger.log('CREATE_ROOT_START', 'Creating root component', 
      component: component.runtimeType.toString());

    // On hot restart, the new `component` instance will be different from the existing `rootComponent`.
    // In this case, we must tear down the old VDOM state and render fresh to match the native side,
    // which has already cleared its views.
    if (rootComponent != null && rootComponent != component) {
      VDomDebugLogger.log('CREATE_ROOT_HOT_RESTART', 'Hot restart detected. Tearing down old VDOM state.');

      // Dispose of the entire old component tree to clean up state and listeners.
      await _disposeOldComponent(rootComponent!);

      // Clear all VDOM tracking maps to ensure a clean slate.
      _statefulComponents.clear();
      _statelessComponents.clear();
      _nodesByViewId.clear();
      _previousRenderedNodes.clear();
      _pendingUpdates.clear();
      _errorBoundaries.clear();
      VDomDebugLogger.log('VDOM_STATE_CLEARED', 'All VDOM tracking maps have been cleared.');

      // Set the new root and render it from scratch.
      rootComponent = component;
      await renderToNative(component, parentViewId: "root");
      VDomDebugLogger.log('CREATE_ROOT_COMPLETE', 'Root component re-created successfully after hot restart.');
    } else {
      VDomDebugLogger.log('CREATE_ROOT_FIRST', 'Creating first root component');
      // First time creating root
      rootComponent = component;

      // Render to native
      final viewId = await renderToNative(component, parentViewId: "root");
      VDomDebugLogger.log('CREATE_ROOT_COMPLETE', 'Root component created successfully', 
        extra: {'ViewId': viewId});
    }
  }

  /// Create a portal container with optimized properties for portaling
  Future<String> createPortal(
    String portalId, {
    required String parentViewId,
    Map<String, dynamic>? props,
    int? index,
  }) async {
    await isReady;

    VDomDebugLogger.log('CREATE_PORTAL_START', 'Creating portal container', 
      extra: {
        'PortalId': portalId,
        'ParentViewId': parentViewId,
        'Index': index
      });

    // Create portal-specific properties
    final portalProps = {
      'portalId': portalId,
      'isPortalContainer': true,
      'backgroundColor': 'transparent',
      'clipsToBounds': false, // Allow content to overflow if needed
      'userInteractionEnabled': true,
      ...(props ?? {}),
    };

    try {
      // Create the portal container view using regular View type for native compatibility
      VDomDebugLogger.logBridge('CREATE_PORTAL', portalId, data: {
        'Type': 'View',
        'Props': portalProps.keys.toList()
      });
      await _nativeBridge.createView(portalId, 'View', portalProps);

      // Attach to parent
      VDomDebugLogger.logBridge('ATTACH_PORTAL', portalId, data: {
        'ParentViewId': parentViewId,
        'Index': index ?? 0
      });
      await _nativeBridge.attachView(portalId, parentViewId, index ?? 0);

      VDomDebugLogger.log('CREATE_PORTAL_SUCCESS', 'Portal container created successfully', 
        extra: {'PortalId': portalId});
      return portalId;
    } catch (e) {
      VDomDebugLogger.log('CREATE_PORTAL_ERROR', 'Failed to create portal container', 
        extra: {'PortalId': portalId, 'Error': e.toString()});
      rethrow;
    }
  }

  /// Get the current child view IDs of a view (for portal management)
  List<String> getCurrentChildren(String viewId) {
    VDomDebugLogger.log('GET_CURRENT_CHILDREN', 'Getting current children for view', 
      extra: {'ViewId': viewId});
    
    final node = _nodesByViewId[viewId];
    if (node is DCFElement) {
      // For elements, get the child view IDs from their children
      final childViewIds = <String>[];
      for (final child in node.children) {
        final childViewId = child.effectiveNativeViewId;
        if (childViewId != null) {
          childViewIds.add(childViewId);
        }
      }
      VDomDebugLogger.log('GET_CURRENT_CHILDREN_SUCCESS', 'Retrieved child view IDs', 
        extra: {'ViewId': viewId, 'ChildCount': childViewIds.length});
      return childViewIds;
    }
    
    VDomDebugLogger.log('GET_CURRENT_CHILDREN_EMPTY', 'No children found for view', 
      extra: {'ViewId': viewId});
    return [];
  }

  /// Update children of a view (for portal management)
  Future<void> updateViewChildren(String viewId, List<String> childIds) async {
    await isReady;
    VDomDebugLogger.logBridge('UPDATE_VIEW_CHILDREN', viewId, data: {
      'ChildIds': childIds,
      'ChildCount': childIds.length
    });
    await _nativeBridge.setChildren(viewId, childIds);
  }

  /// Delete views (for portal cleanup)
  Future<void> deleteViews(List<String> viewIds) async {
    await isReady;
    VDomDebugLogger.log('DELETE_VIEWS_START', 'Deleting multiple views', 
      extra: {'ViewIds': viewIds, 'Count': viewIds.length});
    
    for (final viewId in viewIds) {
      VDomDebugLogger.logBridge('DELETE_VIEW', viewId);
      await _nativeBridge.deleteView(viewId);
      _nodesByViewId.remove(viewId);
    }
    
    VDomDebugLogger.log('DELETE_VIEWS_COMPLETE', 'Successfully deleted views', 
      extra: {'Count': viewIds.length});
  }

  /// Print comprehensive VDOM statistics (for debugging)
  void printDebugStats() {
    VDomDebugLogger.printStats();
    
    // Additional VDOM-specific stats
    VDomDebugLogger.log('VDOM_STATS', 'Current VDOM state', extra: {
      'StatefulComponents': _statefulComponents.length,
      'StatelessComponents': _statelessComponents.length,
      'NodesByViewId': _nodesByViewId.length,
      'PendingUpdates': _pendingUpdates.length,
      'ErrorBoundaries': _errorBoundaries.length,
      'HasRootComponent': rootComponent != null,
      'BatchUpdateInProgress': _batchUpdateInProgress,
      'IsUpdateScheduled': _isUpdateScheduled,
    });
  }

  /// Reset debug logging (for testing)
  void resetDebugLogging() {
    VDomDebugLogger.reset();
  }

  /// Enable/disable debug logging
  void setDebugLogging(bool enabled) {
    VDomDebugLogger.enabled = enabled;
    VDomDebugLogger.log('DEBUG_LOGGING_CHANGED', 'Debug logging ${enabled ? 'enabled' : 'disabled'}');
  }
}