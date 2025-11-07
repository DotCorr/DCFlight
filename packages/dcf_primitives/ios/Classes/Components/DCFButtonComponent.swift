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
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: button text color
        // backgroundColor: handled by applyStyles from StyleSheet
        if let primaryColor = props["primaryColor"] as? String {
            button.setTitleColor(ColorUtilities.color(fromHexString: primaryColor), for: .normal)
        } else {
            // Fall back to white text if no semantic color provided
            button.setTitleColor(UIColor.white, for: .normal)
        }
        
        // Use DCFTheme as default (framework controls colors)
        // StyleSheet.backgroundColor will override if provided
        button.backgroundColor = DCFTheme.getAccentColor(traitCollection: button.traitCollection)
        
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
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: button text color
        // IMPORTANT: Set text color AFTER applyStyles to ensure it's not overridden
        if let primaryColor = props["primaryColor"] as? String {
            button.setTitleColor(ColorUtilities.color(fromHexString: primaryColor), for: .normal)
        } else {
            // Default to white text for buttons (typically on colored backgrounds)
            button.setTitleColor(UIColor.white, for: .normal)
        }
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
