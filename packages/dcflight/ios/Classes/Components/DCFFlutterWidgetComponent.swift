/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter
import dcflight

/**
 * DCFFlutterWidgetComponent - Embeds Flutter widgets directly into native components
 * 
 * This directly embeds Flutter's rendering pipeline into native components
 * without using platform views, providing high performance integration.
 */
class DCFFlutterWidgetComponent: NSObject, DCFComponent {
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create a container that will host the Flutter widget
        let container = FlutterWidgetContainer(frame: .zero)
        
        // Get widgetId from props
        let widgetId = props["widgetId"] as? String
        
        // Store widgetId in container
        container.widgetId = widgetId
        
        // The Flutter widget will be rendered directly by Flutter's engine
        updateView(container, withProps: props)
        container.applyStyles(props: props)
        
        return container
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let container = view as? FlutterWidgetContainer else { return false }
        
        // Update widgetId if changed
        if let widgetId = props["widgetId"] as? String {
            container.widgetId = widgetId
        }
        
        container.applyStyles(props: props)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        guard let container = view as? FlutterWidgetContainer else { return }
        container.onReady(nodeId: nodeId)
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Apply Yoga layout to the container
        view.frame = CGRect(
            x: layout.left,
            y: layout.top,
            width: layout.width,
            height: layout.height
        )
        
        // Update Flutter widget frame when layout changes
        if let container = view as? FlutterWidgetContainer {
            container.updateFlutterWidgetFrame()
        }
    }
    
    func prepareForRecycle(_ view: UIView) {
        // Cleanup if needed
        if let container = view as? FlutterWidgetContainer {
            container.dispose()
        }
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

/**
 * Container that hosts Flutter widgets directly using Flutter's rendering pipeline
 * 
 * The actual widget rendering happens through Flutter's engine via WidgetToDCFAdaptor.
 * This container just provides a native view that Flutter can render into.
 */
private class FlutterWidgetContainer: UIView {
    var widgetId: String?
    private var methodChannel: FlutterMethodChannel?
    private var nodeId: String? // Store the actual nodeId from viewRegisteredWithShadowTree
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMethodChannel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMethodChannel()
    }
    
    private func setupMethodChannel() {
        // Get Flutter engine from shared FlutterViewController
        guard let flutterVC = sharedFlutterViewController else {
            print("⚠️ FlutterWidgetContainer: FlutterViewController not available")
            return
        }
        
        // FlutterViewController.engine is non-optional, so we can access it directly
        let engine = flutterVC.engine
        
        methodChannel = FlutterMethodChannel(
            name: "dcflight/flutter_widget",
            binaryMessenger: engine.binaryMessenger
        )
    }
    
    func onReady(nodeId: String) {
        // Store the nodeId for later use (this is the actual viewId)
        self.nodeId = nodeId
        
        // Request widget rendering from Dart side
        guard let widgetId = widgetId else {
            print("⚠️ FlutterWidgetContainer: No widgetId available")
            return
        }
        
        // Use stored nodeId (actual viewId), not tag
        let viewId = nodeId
        
        // Convert frame to window coordinates
        guard let window = window else {
            print("⚠️ FlutterWidgetContainer: No window available yet, will retry after layout")
            // Schedule a retry after layout completes
            DispatchQueue.main.async { [weak self] in
                self?.onReady(nodeId: nodeId)
            }
            return
        }
        
        // Use bounds (content area) converted to window coordinates
        // This gives us the content area position, accounting for padding
        // The widget will be positioned at (0, 0) within the FlutterView
        // LayoutBuilder already accounts for padding in constraints, so widget size is correct
        let windowFrame = convert(bounds, to: window)
        
        // Only call renderWidget if we have valid dimensions
        // If frame is invalid, updateWidgetFrame will be called later with correct frame
        if windowFrame.width > 0 && windowFrame.height > 0 {
            print("🎨 FlutterWidgetContainer: Requesting widget render - widgetId: \(widgetId), viewId: \(viewId), frame: \(windowFrame)")
            
            // Call Dart method channel to render widget
            methodChannel?.invokeMethod("renderWidget", arguments: [
                "widgetId": widgetId,
                "viewId": viewId,
                "x": windowFrame.origin.x,
                "y": windowFrame.origin.y,
                "width": windowFrame.width,
                "height": windowFrame.height
            ])
        } else {
            print("⚠️ FlutterWidgetContainer: Invalid frame (\(windowFrame)), will wait for updateWidgetFrame")
        }
    }
    
    func updateFlutterWidgetFrame() {
        guard let widgetId = widgetId, 
              let viewId = nodeId,
              frame.width > 0 && frame.height > 0 else { return }
        
        // Convert frame to window coordinates
        guard let window = window else { return }
        
        // Use bounds (content area) converted to window coordinates
        // This gives us the content area position, accounting for padding
        // The widget will be positioned at (0, 0) within the FlutterView
        // LayoutBuilder already accounts for padding in constraints, so widget size is correct
        let windowFrame = convert(bounds, to: window)
        
        print("🎨 FlutterWidgetContainer: Updating widget frame - viewId: \(viewId), frame: \(windowFrame)")
        
        // Call Dart method channel to update frame
        methodChannel?.invokeMethod("updateWidgetFrame", arguments: [
            "viewId": viewId,
            "x": windowFrame.origin.x,
            "y": windowFrame.origin.y,
            "width": windowFrame.width,
            "height": windowFrame.height
        ])
        
        // If renderWidget hasn't been called yet (widget not in hosts), call it now
        // This handles the case where onReady was called with invalid frame
        methodChannel?.invokeMethod("renderWidget", arguments: [
            "widgetId": widgetId,
            "viewId": viewId,
            "x": windowFrame.origin.x,
            "y": windowFrame.origin.y,
            "width": windowFrame.width,
            "height": windowFrame.height
        ]) { (result) in
            if let error = result as? FlutterError {
                print("⚠️ FlutterWidgetContainer: renderWidget error: \(error)")
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update Flutter widget frame when layout changes
        if frame.width > 0 && frame.height > 0 {
            updateFlutterWidgetFrame()
        }
    }
    
    func dispose() {
        // Use stored nodeId (actual viewId), not tag
        guard let viewId = nodeId else { return }
        
        print("🎨 FlutterWidgetContainer: Disposing widget - viewId: \(viewId)")
        
        // Call Dart method channel to dispose widget
        methodChannel?.invokeMethod("disposeWidget", arguments: [
            "viewId": viewId
        ])
    }
}
