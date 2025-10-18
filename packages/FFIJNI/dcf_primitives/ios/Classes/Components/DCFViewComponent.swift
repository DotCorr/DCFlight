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
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                view.backgroundColor = UIColor.systemBackground
            } else {
                view.backgroundColor = UIColor.white
            }
        } else {
            view.backgroundColor = UIColor.clear
        }
        
        view.applyStyles(props: props)
        
        updateView(view, withProps: props)
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let view = view as? UIView else { return false }
        
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            view.applyStyles(props: ["backgroundGradient": gradientData])
        }
        
        view.applyStyles(props: props)
        
        return true
    }
    
}
