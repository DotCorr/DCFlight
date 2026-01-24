/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

// DCFView is defined in Objective-C (DCFView.h/DCFView.m)
// It's automatically available to Swift via the bridging header

class DCFViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Use DCFView for proper border rendering (matches standard model)
        let view = DCFView()
        
        // Check if this view is absolutely positioned
        let isAbsolutelyPositioned = (props["position"] as? String) == "absolute" || props["absoluteLayout"] != nil
        
        // CRITICAL: Enable clipping for views with padding/borderRadius to prevent child overflow
        // BUT: Disable clipping if this view is absolutely positioned (it needs to be visible outside parent bounds)
        if isAbsolutelyPositioned {
            view.clipsToBounds = false
        } else {
            view.clipsToBounds = true
        }
        
        // Apply properties using direct property mapping (standard model approach)
        view.applyProperties(props: props)
        
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
        
        // Apply properties using direct property mapping (standard model approach)
        view.applyProperties(props: props)
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // CRITICAL: Preserve transform when setting frame
        // React Native uses center + bounds to preserve transforms
        // Setting frame directly can reset transforms, so we use center + bounds instead
        let frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        
        // Store current transform to preserve it
        let currentTransform = view.layer.transform
        let currentAnchorPoint = view.layer.anchorPoint
        
        // Set frame using center + bounds (preserves transforms better)
        view.center = CGPoint(x: frame.midX, y: frame.midY)
        view.bounds = CGRect(origin: .zero, size: frame.size)
        
        // Restore transform and anchorPoint (they should be preserved, but ensure they are)
        view.layer.anchorPoint = currentAnchorPoint
        view.layer.transform = currentTransform
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