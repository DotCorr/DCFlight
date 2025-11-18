/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show OverlayEntry, OverlayState, MediaQuery, Stack, IgnorePointer, SizedBox, Container, Color;
import 'package:dcflight/framework/utils/widget_to_dcf_adaptor.dart' show widgetRegistry;

/// Renders Flutter widgets into FlutterViews using Flutter's embedding API
/// 
/// This uses Flutter's existing rendering pipeline - we just create widget trees
/// that render into the FlutterViews. The native view is just a host.
class FlutterWidgetRenderer {
  static final FlutterWidgetRenderer instance = FlutterWidgetRenderer._();
  FlutterWidgetRenderer._();
  
  static const MethodChannel _channel = MethodChannel('dcflight/flutter_widget');
  
  static bool _initialized = false;
  
  // Map of viewId -> widget tree host (like mini runApp instances)
  final Map<String, _WidgetTreeHost> _hosts = {};
  
  // Map of viewId -> OverlayEntry for rendering widgets
  final Map<String, OverlayEntry> _overlayEntries = {};
  
  // Map of viewId -> frame information (x, y, width, height)
  final Map<String, _ViewFrame> _viewFrames = {};
  
  // Map of widgetId -> viewId (to find which view to rebuild when widget updates)
  final Map<String, String> _widgetIdToViewId = {};
  
  // Global OverlayState for rendering widgets
  OverlayState? _overlayState;
  
  /// Initialize the renderer
  static void initialize() {
    if (_initialized) return;
    
    _channel.setMethodCallHandler(instance._handleMethodCall);
    _initialized = true;
  }
  
      Future<dynamic> _handleMethodCall(MethodCall call) async {
        switch (call.method) {
          case 'renderWidget':
            final args = call.arguments as Map<dynamic, dynamic>;
            final widgetId = args['widgetId'] as String;
            final viewId = args['viewId'] as String;
            
            // Get frame information if available
            final x = (args['x'] as num?)?.toDouble();
            final y = (args['y'] as num?)?.toDouble();
            final width = (args['width'] as num?)?.toDouble();
            final height = (args['height'] as num?)?.toDouble();
            
            print('🎨 FlutterWidgetRenderer: Rendering widget $widgetId into view $viewId');
            if (x != null && y != null && width != null && height != null) {
              print('   Frame: ($x, $y, $width, $height)');
            }
            
            // Get widget from registry
            final widget = widgetRegistry.get(widgetId);
            if (widget != null) {
              print('✅ FlutterWidgetRenderer: Found widget in registry');
              // Render widget into FlutterView using Flutter's embedding API
              _renderWidgetIntoView(widget, widgetId, viewId, x, y, width, height);
              return {'status': 'success', 'widgetId': widgetId};
            }
            print('❌ FlutterWidgetRenderer: Widget not found in registry: $widgetId');
            return {'status': 'error', 'message': 'Widget not found'};
          case 'updateWidgetFrame':
            final args = call.arguments as Map<dynamic, dynamic>;
            final viewId = args['viewId'] as String;
            final x = (args['x'] as num?)?.toDouble();
            final y = (args['y'] as num?)?.toDouble();
            final width = (args['width'] as num?)?.toDouble();
            final height = (args['height'] as num?)?.toDouble();
            
            if (x != null && y != null && width != null && height != null) {
              _viewFrames[viewId] = _ViewFrame(x: x, y: y, width: width, height: height);
              print('🎨 FlutterWidgetRenderer: Updated frame for view $viewId: ($x, $y, $width, $height)');
              
              // Mark overlay entry as needing rebuild to update position
              final entry = _overlayEntries[viewId];
              if (entry != null) {
                print('🎨 FlutterWidgetRenderer: Marking OverlayEntry for rebuild...');
                entry.markNeedsBuild();
                // Force a frame to ensure the rebuild happens
                WidgetsBinding.instance.scheduleFrame();
                print('✅ FlutterWidgetRenderer: OverlayEntry marked for rebuild, frame scheduled');
              } else {
                print('⚠️ FlutterWidgetRenderer: No OverlayEntry found for view $viewId, creating new one...');
                // If no entry exists, create one
                final host = _hosts[viewId];
                if (host != null) {
                  _updateCompositeTree();
                }
              }
              
              return {'status': 'success'};
            }
            return {'status': 'error', 'message': 'Invalid frame parameters'};
          case 'disposeWidget':
            final args = call.arguments as Map<dynamic, dynamic>;
            final viewId = args['viewId'] as String;
            _disposeWidgetTree(viewId);
            return {'status': 'success'};
          default:
            throw PlatformException(
              code: 'Unimplemented',
              details: 'Method ${call.method} not implemented',
            );
        }
      }
  
  /// Render widget into FlutterView - uses Flutter's embedding API
  /// 
  /// Creates a widget tree that Flutter's rendering pipeline will render
  /// into the FlutterView. The FlutterView is already attached to the engine,
  /// so Flutter's rendering flow handles everything automatically.
  void _renderWidgetIntoView(Widget widget, String widgetId, String viewId, double? x, double? y, double? width, double? height) {
    // Dispose existing tree if any
    _disposeWidgetTree(viewId);
    
    // Store frame information if available
    if (x != null && y != null && width != null && height != null) {
      _viewFrames[viewId] = _ViewFrame(x: x, y: y, width: width, height: height);
      print('🎨 FlutterWidgetRenderer: Stored frame for view $viewId: ($x, $y, $width, $height)');
    }
    
      // Create widget tree host - this is like a mini app instance
      // Flutter's rendering pipeline will automatically render it into the FlutterView
      final host = _WidgetTreeHost(
        widget: widget,
        viewId: viewId,
      );
      
      _hosts[viewId] = host;
      
      // Map widgetId to viewId so we can rebuild when widget updates
      _widgetIdToViewId[widgetId] = viewId;
    
    // Use Flutter's embedding API to render the widget tree
    // The FlutterView is already part of the rendering flow, so we just need
    // to create the widget tree and Flutter will render it automatically
    _createWidgetTree(widget, viewId);
  }
  
  /// Create widget tree using Flutter's embedding API - replicates runApp flow
  /// 
  /// This replicates how runApp works:
  /// 1. Creates a widget tree (like runApp does)
  /// 2. Connects it to the FlutterView (like runApp does with main FlutterView)
  /// 3. Flutter's engine automatically renders it into the FlutterView
  /// 
  /// Since Flutter only supports one root widget tree per engine, we create
  /// a composite widget tree that contains all FlutterView widgets, and use
  /// Flutter's rendering pipeline to render them into their respective FlutterViews.
  void _createWidgetTree(Widget widget, String viewId) {
    print('🎨 FlutterWidgetRenderer: Creating widget tree for view $viewId (replicating runApp flow)');
    print('   Widget type: ${widget.runtimeType}');
    
    // Replicate runApp flow:
    // runApp does: WidgetsFlutterBinding.ensureInitialized() then attachRootWidget(widget)
    // We do the same but create a composite tree for all FlutterViews
    
    // Ensure binding is initialized (already done by DCFlight.init, but safe to call)
    WidgetsFlutterBinding.ensureInitialized();
    
    // Store the widget for this viewId
    final host = _hosts[viewId];
    if (host != null) {
      // Update existing host
      host.widget = widget;
    }
    
    // Create composite widget tree that contains all FlutterView widgets
    // This is like runApp - we create a root widget tree and Flutter renders it
    _updateCompositeTree();
    
    print('✅ FlutterWidgetRenderer: Widget tree created for view $viewId');
    print('   Composite tree updated, Flutter engine will render automatically');
    
    // Schedule a frame - this is what runApp does internally
    // Flutter's engine will render the widget tree into the FlutterView
    WidgetsBinding.instance.scheduleFrame();
  }
  
  /// Update the composite widget tree that contains all FlutterView widgets
  /// 
  /// CRITICAL: Cannot use Overlay/OverlayState because it requires runApp which blocks DCF UI
  void _updateCompositeTree() {
    // CRITICAL: Cannot create root widget tree - runApp blocks DCF UI
    // Widgets cannot be rendered via Flutter's widget tree without blocking DCF
    if (_overlayState == null) {
      print('❌ FlutterWidgetRenderer: No OverlayState available - cannot render widgets without blocking DCF UI');
      return;
    }
    
    // For each widget host, create/update OverlayEntry
    for (final host in _hosts.values) {
      final viewId = host.viewId;
      
      // Remove existing overlay entry if any
      _overlayEntries[viewId]?.remove();
      
          // Create new OverlayEntry for this widget
          // CRITICAL: The builder must read the latest frame from _viewFrames each time it's called
          // because the frame can be updated after the entry is created
          final entry = OverlayEntry(
            opaque: false, // Make it non-opaque so we can see through if needed
            builder: (context) {
              print('🎨🎨🎨 FlutterWidgetRenderer: OverlayEntry builder CALLED for view $viewId');
              
              // ALWAYS read the latest frame from _viewFrames - don't use the closure variable!
              // The frame can be updated after the entry is created, so we need to read it fresh
              final currentFrame = _viewFrames[viewId];
              
              // Use frame information if available, otherwise fill screen
              double left, top, widgetWidth, widgetHeight;
              if (currentFrame != null && currentFrame.width > 0 && currentFrame.height > 0) {
                left = currentFrame.x;
                top = currentFrame.y;
                widgetWidth = currentFrame.width;
                widgetHeight = currentFrame.height;
                print('🎨 FlutterWidgetRenderer: Using CURRENT frame: ($left, $top, $widgetWidth, $widgetHeight)');
              } else {
                // Fallback to screen size
                try {
                  final screenSize = MediaQuery.of(context).size;
                  left = 0;
                  top = 0;
                  widgetWidth = screenSize.width;
                  widgetHeight = screenSize.height;
                  print('🎨 FlutterWidgetRenderer: Using screen size: ${widgetWidth}x${widgetHeight}');
                } catch (e) {
                  left = 0;
                  top = 0;
                  widgetWidth = 400;
                  widgetHeight = 800;
                  print('⚠️ FlutterWidgetRenderer: Using default size: ${widgetWidth}x${widgetHeight}');
                }
              }
          
          print('🎨 FlutterWidgetRenderer: Widget type: ${host.widget.runtimeType}');
          print('🎨 FlutterWidgetRenderer: Building widget at ($left, $top) with size ${widgetWidth}x${widgetHeight}');
          print('🎨🎨🎨 FlutterWidgetRenderer: OverlayEntry builder EXECUTING - this means the widget is being built!');
          
          // OverlayEntry builder must return widgets that work with Stack
          // Positioned widgets must be direct children of Stack
          // Use IgnorePointer at the Stack level so touches pass through to native DCF components
          // CRITICAL: Stack needs to expand to allow Positioned widgets to work correctly
          // But the Stack itself is transparent and only renders Positioned children
          return IgnorePointer(
            ignoring: true, // Let touches pass through to native DCF views
            child: Stack(
              // Expand to fill available space so Positioned widgets can work
              // The Stack itself is transparent and only renders its children
              fit: StackFit.expand,
              children: [
                // Only render the widget if we have valid dimensions
                // This ensures widgets only appear at their specific positions
                if (widgetWidth > 0 && widgetHeight > 0)
                  Positioned(
                    left: left,
                    top: top,
                    width: widgetWidth,
                    height: widgetHeight,
                    child: SizedBox(
                      width: widgetWidth,
                      height: widgetHeight,
                      child: host.widget,
                    ),
                  ),
                // Don't render anything if frame is invalid - Stack is transparent
              ],
            ),
          );
        },
      );
      
      _overlayEntries[viewId] = entry;
      
      // Insert into overlay
      if (_overlayState!.mounted) {
        _overlayState!.insert(entry);
        print('✅ FlutterWidgetRenderer: Inserted OverlayEntry for view $viewId');
        // Mark the entry as needing a rebuild to ensure it renders
        entry.markNeedsBuild();
        print('✅ FlutterWidgetRenderer: Marked OverlayEntry as needing build');
      } else {
        print('❌ FlutterWidgetRenderer: OverlayState not mounted, cannot insert entry');
      }
    }
    
    print('✅ FlutterWidgetRenderer: Updated ${_overlayEntries.length} OverlayEntries');
  }
  
  /// Create a minimal root widget tree with Overlay
  /// CRITICAL: DO NOT call runApp - it blocks the entire DCF UI with a white screen
  /// We cannot create a root widget tree without blocking DCF
  void _createRootWidgetTree() {
    // Check if there's already a root widget attached
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement != null) {
      print('⚠️ FlutterWidgetRenderer: Root widget already attached, trying to get OverlayState from existing tree');
      _tryGetOverlayFromExistingTree();
      return;
    }
    
    // CRITICAL: DO NOT create root widget tree - runApp blocks DCF UI
    // Even with transparent Container, runApp creates a RenderView that covers everything
    // We need a different approach that doesn't use runApp
    print('❌ FlutterWidgetRenderer: Cannot create root widget tree - runApp blocks DCF UI');
    print('❌ FlutterWidgetRenderer: Widgets will not render until we find a solution that doesn\'t block DCF');
    // Don't create root widget tree - it blocks the entire DCF UI
  }
  
  /// Try to get OverlayState from existing widget tree
  void _tryGetOverlayFromExistingTree() {
    // Try to find OverlayState in the existing widget tree
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement != null) {
      // Navigate the widget tree to find Overlay
      final context = rootElement as BuildContext;
      try {
        final overlayState = Overlay.of(context);
        if (overlayState.mounted) {
          _overlayState = overlayState;
          print('✅ FlutterWidgetRenderer: Found OverlayState in existing tree');
          _updateCompositeTree();
          return;
        }
      } catch (e) {
        print('⚠️ FlutterWidgetRenderer: Could not find OverlayState in existing tree: $e');
      }
    }
    print('⚠️ FlutterWidgetRenderer: Cannot find OverlayState, will create new root widget tree');
  }
  
  /// Set the OverlayState for rendering widgets
  /// This should be called when the FlutterView is ready
  void setOverlayState(OverlayState overlayState) {
    _overlayState = overlayState;
    
    // Insert all existing overlay entries
    for (final entry in _overlayEntries.values) {
      if (overlayState.mounted) {
        overlayState.insert(entry);
      }
    }
    
    print('✅ FlutterWidgetRenderer: OverlayState set, inserted ${_overlayEntries.length} entries');
  }
  
  void _disposeWidgetTree(String viewId) {
    // Remove overlay entry
    final entry = _overlayEntries.remove(viewId);
    entry?.remove();
    
    // Remove host
    final host = _hosts.remove(viewId);
    host?.dispose();
    
    // Remove frame information
    _viewFrames.remove(viewId);
    
    // Remove widgetId mapping
    _widgetIdToViewId.removeWhere((_, vId) => vId == viewId);
    
    print('✅ FlutterWidgetRenderer: Disposed widget tree for view $viewId');
  }
  
  /// Mark widget for rebuild when state changes
  /// Called by WidgetToDCFAdaptor when widget is updated in registry
  void markWidgetForRebuild(String widgetId) {
    final viewId = _widgetIdToViewId[widgetId];
    if (viewId != null) {
      // Update the host widget to the latest from registry
      final host = _hosts[viewId];
      final updatedWidget = widgetRegistry.get(widgetId);
      if (host != null && updatedWidget != null) {
        host.widget = updatedWidget;
        // Mark overlay entry for rebuild
        final entry = _overlayEntries[viewId];
        entry?.markNeedsBuild();
        WidgetsBinding.instance.scheduleFrame();
        print('🔄 FlutterWidgetRenderer: Marked widget $widgetId (view $viewId) for rebuild due to state change');
      }
    }
  }
}

/// Lightweight widget tree host - like a mini app instance
/// Uses Flutter's existing rendering pipeline, just sandboxed to a specific view
class _WidgetTreeHost {
  Widget widget;
  final String viewId;
  
  _WidgetTreeHost({
    required this.widget,
    required this.viewId,
  });
  
  void dispose() {
    // Cleanup if needed
    // Flutter's rendering pipeline will handle the rest
  }
}

/// Frame information for a view
class _ViewFrame {
  final double x;
  final double y;
  final double width;
  final double height;
  
  _ViewFrame({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Root widget tree for Flutter widgets
/// This creates an Overlay that widgets can render into
/// Replicates runApp by creating a widget tree
class _FlutterWidgetRoot extends StatefulWidget {
  final void Function(OverlayState) onOverlayReady;
  
  const _FlutterWidgetRoot({
    required this.onOverlayReady,
  });
  
  @override
  State<_FlutterWidgetRoot> createState() => _FlutterWidgetRootState();
}

class _FlutterWidgetRootState extends State<_FlutterWidgetRoot> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  
  @override
  void initState() {
    super.initState();
    print('🎨 _FlutterWidgetRootState: initState() called');
    
    // Schedule callback after first frame to ensure Overlay is built and RenderView is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🎨 _FlutterWidgetRootState: PostFrameCallback called');
      final overlayState = _overlayKey.currentState;
      print('🎨 _FlutterWidgetRootState: OverlayState: $overlayState, mounted: ${overlayState?.mounted}');
      if (overlayState != null && overlayState.mounted) {
        print('✅ _FlutterWidgetRootState: OverlayState ready, calling onOverlayReady');
        widget.onOverlayReady(overlayState);
      } else {
        print('⚠️ _FlutterWidgetRootState: OverlayState not ready, retrying...');
        // Retry after a short delay if not ready yet
        Future.delayed(const Duration(milliseconds: 100), () {
          final retryState = _overlayKey.currentState;
          print('🎨 _FlutterWidgetRootState: Retry - OverlayState: $retryState, mounted: ${retryState?.mounted}');
          if (retryState != null && retryState.mounted) {
            print('✅ _FlutterWidgetRootState: OverlayState ready on retry, calling onOverlayReady');
            widget.onOverlayReady(retryState);
          } else {
            print('❌ _FlutterWidgetRootState: OverlayState still not ready after retry');
          }
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    print('🎨 _FlutterWidgetRootState: build() called');
    
    // We can't use View widget with existing FlutterView (it's already a root render tree)
    // Instead, create a simple widget tree that provides Overlay
    // The FlutterView is already attached to the engine, so we just need to provide
    // a widget tree that Flutter can render into it
    print('🎨 _FlutterWidgetRootState: Creating widget tree with Overlay (no View widget)');
    
    // Create a minimal root widget tree with Overlay
    // CRITICAL: This widget tree must be completely transparent and non-blocking
    // It should only serve as a container for the Overlay, not render anything visible
    // The Overlay will only render widgets where they're positioned
    // Use a transparent Container that fills screen but renders nothing
    return Container(
      color: const Color(0x00000000), // Fully transparent - doesn't block DCF UI
      child: Directionality(
        textDirection: TextDirection.ltr, // Default to LTR, can be made configurable
        child: Overlay(
          key: _overlayKey,
          initialEntries: [],
        ),
      ),
    );
  }
}


