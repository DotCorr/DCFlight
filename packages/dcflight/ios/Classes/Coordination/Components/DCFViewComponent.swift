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
        
        // Get overflow property from props (sent as string from Dart)
        let overflow = props["overflow"] as? String
        
        // CRITICAL: Handle clipping based on 'overflow' prop
        // React Native/Web default is 'visible' (no clipping)
        if overflow == "hidden" || overflow == "scroll" {
            view.clipsToBounds = true
        } else {
            // Default to 'visible' (clipsToBounds = false)
            // This ensures transforms and absolute positioning work correctly without slicing
            view.clipsToBounds = false
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