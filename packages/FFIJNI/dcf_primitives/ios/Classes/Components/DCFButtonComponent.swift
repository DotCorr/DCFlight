/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFButtonComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFButtonComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
    print("🔧 DCFButtonComponent: Found props keys: \(Array(props.keys))")
    
    let eventTypes = props.keys.filter { $0.hasPrefix("on") }
    print("🔧 DCFButtonComponent: Extracted event types: \(eventTypes)")
    
        let button = UIButton(type: .system)
        
        button.isUserInteractionEnabled = true
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            button.backgroundColor = UIColor.systemBlue
            button.setTitleColor(UIColor.white, for: .normal)
        } else {
            button.backgroundColor = UIColor.blue
            button.setTitleColor(UIColor.white, for: .normal)
        }
        
        button.addTarget(DCFButtonComponent.sharedInstance, action: #selector(handleButtonPress(_:)), for: .touchUpInside)
        button.addTarget(DCFButtonComponent.sharedInstance, action: #selector(handleButtonTouchDown(_:)), for: .touchDown)
        button.addTarget(DCFButtonComponent.sharedInstance, action: #selector(handleButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        updateView(button, withProps: props)
        button.applyStyles(props: props)
        
        return button
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let button = view as? UIButton else { return false }
        
        if let title = props["title"] as? String {
            button.setTitle(title, for: .normal)
        }
        
        if let disabled = props["disabled"] as? Bool {
            button.isEnabled = !disabled
            button.alpha = disabled ? 0.5 : 1.0
        }
        
        button.applyStyles(props: props)
        return true
    }
    
    @objc func handleButtonPress(_ sender: UIButton) {
        propagateEvent(on: sender, eventName: "onPress", data: [
            "pressed": true,
            "timestamp": Date().timeIntervalSince1970,
            "buttonTitle": sender.title(for: .normal) ?? ""
        ])
    }
    
    @objc func handleButtonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15) {
            sender.alpha = 0.7
        }
    }
    
    @objc func handleButtonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15) {
            sender.alpha = 1.0
        }
    }
}
