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
        
        // Apply properties using direct property mapping (standard model approach)
        // This will trigger the overflow/clipping logic in updateView
        view.applyProperties(props: props)
        
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let view = view as? UIView else { return false }
        
        // Check if this view is absolutely positioned
        let isAbsolutelyPositioned = (props["position"] as? String) == "absolute" || props["absoluteLayout"] != nil
        
        // Check if this view has transforms that could cause overflow
        let hasRotation = (props["rotateInDegrees"] as? CGFloat) != nil
        let hasScale = (props["scale"] as? CGFloat) != nil ||
                      (props["scaleX"] as? CGFloat) != nil ||
                      (props["scaleY"] as? CGFloat) != nil
        let hasTranslation = (props["translateX"] as? CGFloat) != nil ||
                            (props["translateY"] as? CGFloat) != nil
        let hasOverflowCausingTransforms = hasRotation || hasScale || hasTranslation
        
        // Check overflow prop (explicitly set from Dart side)
        let overflow = props["overflow"] as? String
        
        // CRITICAL: Handle clipping based on 'overflow' prop or detected transforms
        if let overflow = overflow {
            view.clipsToBounds = (overflow != "visible")
        } else if isAbsolutelyPositioned || hasOverflowCausingTransforms {
            // Disable clipping for transformed or absolutely positioned views by default
            view.clipsToBounds = false
        } else {
            // Default to clipping for normal views (to respect borderRadius, etc.)
            view.clipsToBounds = true
        }
        
        // Apply properties using direct property mapping
        view.applyProperties(props: props)
        
        // After applying properties, if we detect overflow potential, 
        // we must ensure the parent doesn't clip us either.
        if !view.clipsToBounds || isAbsolutelyPositioned || hasOverflowCausingTransforms {
            if let parent = view.superview {
                parent.clipsToBounds = false
            }
        }
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // CRITICAL: Preserve transform when setting frame
        let frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        
        // Store current transform to preserve it
        let currentTransform = view.layer.transform
        let currentAnchorPoint = view.layer.anchorPoint
        
        // Set frame using center + bounds (preserves transforms better)
        view.center = CGPoint(x: frame.midX, y: frame.midY)
        view.bounds = CGRect(origin: .zero, size: frame.size)
        
        // Restore transform and anchorPoint
        view.layer.anchorPoint = currentAnchorPoint
        view.layer.transform = currentTransform
        
        // If the view is meant to be visible outside its bounds (due to transforms or absolute position),
        // ensure its parent doesn't clip it during the layout pass.
        if !view.clipsToBounds {
            if let parent = view.superview {
                parent.clipsToBounds = false
            }
        }
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