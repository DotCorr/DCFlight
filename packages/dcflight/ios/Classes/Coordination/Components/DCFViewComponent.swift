/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
        updateView(view, withProps: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let view = view as? UIView else { return false }
        
        // Match React Native default: overflow is 'visible' (clipsToBounds = false)
        // This ensures transforms and absolute positioning work correctly without slicing
        let overflow = props["overflow"] as? String
        view.clipsToBounds = (overflow == "hidden" || overflow == "scroll")
        
        // Handle absolutely positioned child (disable parent clipping)
        if (props["position"] as? String) == "absolute", let parent = view.superview {
            parent.clipsToBounds = false
        }
        
        // Apply properties using direct property mapping (standard model approach)
        view.applyProperties(props: props)
        
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