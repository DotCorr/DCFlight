/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show runApp, OverlayEntry, OverlayState, MediaQuery, Stack, SizedBox, Container, Color;
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
            
            print('🎨🎨🎨 FlutterWidgetRenderer: renderWidget CALLED - widgetId=$widgetId, viewId=$viewId');
            if (x != null && y != null && width != null && height != null) {
              print('   Frame: ($x, $y, $width, $height)');
            }
            
            // Get widget from registry
            final widget = widgetRegistry.get(widgetId);
            if (widget != null) {
              print('✅ FlutterWidgetRenderer: Found widget in registry, type=${widget.runtimeType}');
              // Render widget into FlutterView using Flutter's embedding API
              _renderWidgetIntoView(widget, widgetId, viewId, x, y, width, height);
              return {'status': 'success', 'widgetId': widgetId};
            }
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
              
              // Update FlutterView position/size to match union of all widget frames
              _updateFlutterViewFrame();
              
              // Mark overlay entry as needing rebuild to update position
              final entry = _overlayEntries[viewId];
              if (entry != null) {
                print('🎨 FlutterWidgetRenderer: Marking OverlayEntry for rebuild...');
                entry.markNeedsBuild();
                // Force a frame to ensure the rebuild happens
                WidgetsBinding.instance.scheduleFrame();
                print('✅ FlutterWidgetRenderer: OverlayEntry marked for rebuild, frame scheduled');
              } else {
                // If no entry exists, check if widget has been rendered
                final host = _hosts[viewId];
                if (host != null) {
                  // Widget is rendered but no OverlayEntry yet - create it
                  print('⚠️ FlutterWidgetRenderer: Widget rendered but no OverlayEntry for view $viewId, creating one...');
                  _updateCompositeTree();
                } else {
                  // Widget hasn't been rendered yet - just store the frame
                  // The frame will be used when renderWidget is called
                  print('ℹ️ FlutterWidgetRenderer: Widget not rendered yet for view $viewId, frame stored for later use');
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
    // Check if widget is already rendered for this viewId
    final existingHost = _hosts[viewId];
    if (existingHost != null) {
      print('ℹ️ FlutterWidgetRenderer: Widget already rendered for view $viewId, updating widget and frame...');
      // Update the widget in case it changed
      existingHost.widget = widget;
      // Update frame if provided
      if (x != null && y != null && width != null && height != null && width > 0 && height > 0) {
        _viewFrames[viewId] = _ViewFrame(x: x, y: y, width: width, height: height);
        // Update FlutterView position/size to match union of all widget frames
        _updateFlutterViewFrame();
        // Mark overlay entry for rebuild
        final entry = _overlayEntries[viewId];
        entry?.markNeedsBuild();
        WidgetsBinding.instance.scheduleFrame();
      }
      return;
    }
    
    // Dispose existing tree if any (shouldn't happen, but safety check)
    _disposeWidgetTree(viewId);
    
    // Store frame information if available and valid (not 0x0)
    // If frame is invalid, check if we have a stored frame from updateWidgetFrame
    if (x != null && y != null && width != null && height != null) {
      if (width > 0 && height > 0) {
        _viewFrames[viewId] = _ViewFrame(x: x, y: y, width: width, height: height);
        print('🎨 FlutterWidgetRenderer: Stored frame for view $viewId: ($x, $y, $width, $height)');
        // Update FlutterView position/size to match union of all widget frames
        _updateFlutterViewFrame();
      } else {
        // Frame is invalid (0x0), check if we have a stored frame
        final storedFrame = _viewFrames[viewId];
        if (storedFrame != null && storedFrame.width > 0 && storedFrame.height > 0) {
          print('🎨 FlutterWidgetRenderer: Using stored frame for view $viewId: (${storedFrame.x}, ${storedFrame.y}, ${storedFrame.width}, ${storedFrame.height})');
        } else {
          print('⚠️ FlutterWidgetRenderer: Invalid frame for view $viewId: ($x, $y, $width, $height), will wait for updateWidgetFrame');
        }
      }
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
    
    print('🎨 FlutterWidgetRenderer: Widget host created for view $viewId, updating composite tree...');
    
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
  void _updateCompositeTree() {
    // If no OverlayState exists, create root widget tree first
    if (_overlayState == null) {
      print('⚠️ FlutterWidgetRenderer: No OverlayState available, creating root widget tree...');
      _createRootWidgetTree();
      // Wait for OverlayState to be set via callback
      // The callback will call _updateCompositeTree again
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
                // CRITICAL: Position widget at (0, 0) relative to FlutterView, not window coordinates
                // The FlutterView is already positioned at (currentFrame.x, currentFrame.y) in window coordinates
                // So the widget inside the FlutterView should be at (0, 0) relative to the FlutterView
                left = 0;
                top = 0;
                widgetWidth = currentFrame.width;
                widgetHeight = currentFrame.height;
                print('🎨 FlutterWidgetRenderer: Using CURRENT frame: widget at (0, 0) relative to FlutterView, size ($widgetWidth, $widgetHeight), FlutterView at window ($currentFrame.x, $currentFrame.y)');
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
          // CRITICAL: On Android, Overlay may provide unbounded constraints
          // Use MediaQuery to get screen size and constrain Stack explicitly
          // Note: Flutter widgets can receive touches - they handle their own hit testing
          return Builder(
              builder: (context) {
                // CRITICAL FIX: Platform-specific pixel conversion
                // iOS native sends logical pixels (already correct for Flutter)
                // Android native sends physical pixels (need to convert to logical)
                final screenSize = MediaQuery.of(context).size;
                final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
                
                // Only convert on Android - iOS already sends logical pixels
                final isAndroid = Platform.isAndroid;
                final finalWidth = isAndroid ? widgetWidth / devicePixelRatio : widgetWidth;
                final finalHeight = isAndroid ? widgetHeight / devicePixelRatio : widgetHeight;
                final finalLeft = isAndroid ? left / devicePixelRatio : left;
                final finalTop = isAndroid ? top / devicePixelRatio : top;
                
                // Stack should be at least as large as the widget
                final maxWidth = finalWidth > screenSize.width ? finalWidth : screenSize.width;
                final maxHeight = finalHeight > screenSize.height ? finalHeight : screenSize.height;
                
                return SizedBox(
                  width: maxWidth,
                  height: maxHeight,
                  child: Stack(
                    // Don't use StackFit.expand - explicitly constrain with SizedBox above
                    children: [
                      // Only render the widget if we have valid dimensions
                      // This ensures widgets only appear at their specific positions
                      if (finalWidth > 0 && finalHeight > 0)
                        Positioned(
                          left: finalLeft,
                          top: finalTop,
                          width: finalWidth,
                          height: finalHeight,
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: ConstrainedBox(
                              constraints: BoxConstraints.tightFor(
                                width: finalWidth,
                                height: finalHeight,
                              ),
                              child: host.widget,
                            ),
                          ),
                        ),
                      // Don't render anything if frame is invalid - Stack is transparent
                    ],
                  ),
                );
              },
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
  /// Uses runApp with a completely transparent, non-interactive root widget
  void _createRootWidgetTree() {
    // Check if there's already a root widget attached
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement != null) {
      print('⚠️ FlutterWidgetRenderer: Root widget already attached, trying to get OverlayState from existing tree');
      _tryGetOverlayFromExistingTree();
      return;
    }
    
    print('🎨 FlutterWidgetRenderer: Creating root widget tree with Overlay...');
    
    // CRITICAL: Enable FlutterView rendering BEFORE calling runApp
    // WebView and other platform channel plugins need the FlutterView to be
    // attached to the engine and in the view hierarchy before they can initialize
    _channel.invokeMethod('enableFlutterViewRendering').then((result) {
      print('✅ FlutterWidgetRenderer: enableFlutterViewRendering succeeded: $result');
      
      // Wait a microtask to ensure FlutterView is fully attached before runApp
      // This gives native side time to attach the view to the engine
      Future.microtask(() {
        // Create a completely transparent, non-interactive root widget
        // This provides an OverlayState without blocking DCF UI
        runApp(_FlutterWidgetRoot(
          onOverlayReady: (overlayState) {
            print('✅ FlutterWidgetRenderer: OverlayState ready from root widget tree');
            setOverlayState(overlayState);
          },
        ));
      });
    }).catchError((error) {
      print('⚠️ FlutterWidgetRenderer: Failed to enable FlutterView rendering: $error');
      // Continue anyway - runApp might still work, but plugins may fail
      runApp(_FlutterWidgetRoot(
        onOverlayReady: (overlayState) {
          print('✅ FlutterWidgetRenderer: OverlayState ready from root widget tree');
          setOverlayState(overlayState);
        },
      ));
    });
    
    print('✅ FlutterWidgetRenderer: Root widget tree created');
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
    
    print('✅ FlutterWidgetRenderer: OverlayState set, updating composite tree...');
    
    // Update composite tree to create/insert overlay entries
    _updateCompositeTree();
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
    
    // Update FlutterView position/size after disposing widget
    _updateFlutterViewFrame();
    
    // Remove widgetId mapping
    _widgetIdToViewId.removeWhere((_, vId) => vId == viewId);
    
    print('✅ FlutterWidgetRenderer: Disposed widget tree for view $viewId');
  }
  
  /// Mark widget for rebuild when state changes
  /// Called by WidgetToDCFAdaptor when widget is updated in registry
  /// Calculate union of all widget frames and update FlutterView position/size
  void _updateFlutterViewFrame() {
    if (_viewFrames.isEmpty) {
      // No widgets, hide FlutterView or set to zero size
      _channel.invokeMethod('updateFlutterViewFrame', {
        'x': 0.0,
        'y': 0.0,
        'width': 0.0,
        'height': 0.0,
      }).catchError((error) {
        print('⚠️ FlutterWidgetRenderer: Failed to update FlutterView frame: $error');
      });
      return;
    }
    
    // Calculate union of all frames (bounding box)
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final frame in _viewFrames.values) {
      if (frame.width > 0 && frame.height > 0) {
        minX = minX < frame.x ? minX : frame.x;
        minY = minY < frame.y ? minY : frame.y;
        final frameRight = frame.x + frame.width;
        final frameBottom = frame.y + frame.height;
        maxX = maxX > frameRight ? maxX : frameRight;
        maxY = maxY > frameBottom ? maxY : frameBottom;
      }
    }
    
    if (minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite) {
      final unionX = minX;
      final unionY = minY;
      final unionWidth = maxX - minX;
      final unionHeight = maxY - minY;
      
      print('🎨 FlutterWidgetRenderer: Updating FlutterView frame to union: ($unionX, $unionY, $unionWidth, $unionHeight)');
      
      _channel.invokeMethod('updateFlutterViewFrame', {
        'x': unionX,
        'y': unionY,
        'width': unionWidth,
        'height': unionHeight,
      }).catchError((error) {
        print('⚠️ FlutterWidgetRenderer: Failed to update FlutterView frame: $error');
      });
    }
  }
  
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
  
  /// Clear all Flutter widgets during hot restart
  /// This ensures Flutter widgets are disposed when native views are cleared
  void clearAllForHotRestart() {
    print('🔥 FlutterWidgetRenderer: Clearing all widgets for hot restart');
    
    // Dispose all widget trees
    final viewIds = _hosts.keys.toList();
    for (final viewId in viewIds) {
      _disposeWidgetTree(viewId);
    }
    
    // Clear all maps
    _hosts.clear();
    _overlayEntries.clear();
    _viewFrames.clear();
    _widgetIdToViewId.clear();
    
    // Reset overlay state (will be recreated on next render)
    _overlayState = null;
    
    print('✅ FlutterWidgetRenderer: All widgets cleared for hot restart');
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


