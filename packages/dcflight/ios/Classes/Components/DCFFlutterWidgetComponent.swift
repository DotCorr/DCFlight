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
        
        // Get widget type from props
        let widgetType = props["widgetType"] as? String ?? "Unknown"
        
        // The Flutter widget will be rendered directly by Flutter's engine
        updateView(container, withProps: props)
        container.applyStyles(props: props)
        
        return container
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let container = view as? FlutterWidgetContainer else { return false }
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
        container.onReady()
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Apply Yoga layout to the container
        view.frame = CGRect(
            x: layout.left,
            y: layout.top,
            width: layout.width,
            height: layout.height
        )
    }
    
    func prepareForRecycle(_ view: UIView) {
        // Cleanup if needed
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
    
    func onReady() {
        // The Flutter widget will be rendered by Flutter's engine directly
        // through the WidgetToDCFAdaptor mechanism
        propagateEvent(on: self, eventName: "onReady", data: [
            "width": frame.width,
            "height": frame.height
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        propagateEvent(on: self, eventName: "onSizeChanged", data: [
            "width": frame.width,
            "height": frame.height
        ])
    }
}

