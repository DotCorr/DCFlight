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
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let container = view as? FlutterWidgetContainer else { return .zero }
        let width = (props["width"] as? NSNumber)?.doubleValue ?? 0
        let height = (props["height"] as? NSNumber)?.doubleValue ?? 0
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
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
        // Request widget rendering from Dart side
        guard let widgetId = widgetId else {
            print("⚠️ FlutterWidgetContainer: No widgetId available")
            return
        }
        
        // Get viewId from tag (nodeId)
        let viewId = String(tag)
        
        // Convert frame to window coordinates
        guard let window = window else {
            print("⚠️ FlutterWidgetContainer: No window available yet")
            return
        }
        
        let windowFrame = convert(bounds, to: window)
        
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
    }
    
    func updateFlutterWidgetFrame() {
        guard let widgetId = widgetId, frame.width > 0 && frame.height > 0 else { return }
        
        // Get viewId from tag
        let viewId = String(tag)
        
        // Convert frame to window coordinates
        guard let window = window else { return }
        
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
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update Flutter widget frame when layout changes
        if frame.width > 0 && frame.height > 0 {
            updateFlutterWidgetFrame()
        }
    }
    
    func dispose() {
        // Get viewId from tag
        let viewId = String(tag)
        
        print("🎨 FlutterWidgetContainer: Disposing widget - viewId: \(viewId)")
        
        // Call Dart method channel to dispose widget
        methodChannel?.invokeMethod("disposeWidget", arguments: [
            "viewId": viewId
        ])
    }
}
