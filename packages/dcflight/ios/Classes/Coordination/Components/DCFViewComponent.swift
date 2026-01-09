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
        
        // Check if this view is absolutely positioned
        let isAbsolutelyPositioned = (props["position"] as? String) == "absolute" || props["absoluteLayout"] != nil
        
        // CRITICAL: Enable clipping for views with padding/borderRadius to prevent child overflow
        // BUT: Disable clipping if this view is absolutely positioned (it needs to be visible outside parent bounds)
        if isAbsolutelyPositioned {
            view.clipsToBounds = false
        } else {
            view.clipsToBounds = true
        }
        
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
        }
        
        view.applyStyles(props: props)
        
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let view = view as? UIView else { return false }
        
        // Check if this view is absolutely positioned
        let isAbsolutelyPositioned = (props["position"] as? String) == "absolute" || props["absoluteLayout"] != nil
        
        // CRITICAL: Enable clipping for views with padding/borderRadius to prevent child overflow
        // BUT: Disable clipping on parent if this view is absolutely positioned (it needs to be visible outside parent bounds)
        if isAbsolutelyPositioned {
            // If this view is absolutely positioned, ensure parent doesn't clip it
            // This allows absolutely positioned children to be visible outside the parent's bounds
            if let parent = view.superview {
                parent.clipsToBounds = false
                print("✅ DCFViewComponent: Disabled clipping on parent for absolutely positioned view")
            }
            // Don't clip absolutely positioned views themselves (they may be positioned outside their measured bounds)
            view.clipsToBounds = false
        } else {
            // Default to clipping for non-absolutely positioned views
            // This prevents content overflow for views with borderRadius, etc.
            view.clipsToBounds = true
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
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}