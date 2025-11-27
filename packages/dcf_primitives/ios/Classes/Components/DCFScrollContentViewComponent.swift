/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/**
 * DCFScrollContentViewComponent - Content view component manager
 * (1:1 with React Native's RCTScrollContentViewManager)
 * 
 * This component creates the content view that wraps ScrollView's children.
 * Yoga will layout this view, and the ScrollView will use its frame.size
 * as the contentSize (React Native pattern).
 */
class DCFScrollContentViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let contentView = DCFScrollContentView(frame: .zero)
        contentView.applyStyles(props: props)
        return contentView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        view.applyStyles(props: props)
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Apply Yoga layout to content view
        // The ScrollView will read this view's frame.size to set contentSize
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Content view is laid out by Yoga - no special handling needed
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize.zero
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

