/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

class DCFViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
        }
        
        view.applyStyles(props: props)
        
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let view = view as? UIView else { return false }
        
        // Handle viewport detection (low-level API - any view can use it)
        // Uses DCFViewportObserver from dcflight framework
        let hasViewportCallbacks = props["onViewportEnter"] != nil || props["onViewportLeave"] != nil
        if hasViewportCallbacks {
            let viewportData = props["viewport"] as? [String: Any]
            let config = ViewportConfig(
                once: viewportData?["once"] as? Bool ?? false,
                amount: viewportData?["amount"] as? Double
            )
            DCFViewportObserver.shared.observe(view, config: config)
        } else {
            DCFViewportObserver.shared.unobserve(view)
        }
        
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            view.applyStyles(props: ["backgroundGradient": gradientData])
        }
        
        view.applyStyles(props: props)
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Setup viewport detection if callbacks are registered
        // Check props from associated object or wait for updateView
        DispatchQueue.main.async {
            // Viewport detection will be set up in updateView when props are available
        }
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}
