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
        // StyleSheet.toMap() ALWAYS provides primaryColor, so this should never be null
        if let primaryColor = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColor) {
                button.setTitleColor(color, for: .normal)
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor, don't set color (StyleSheet should always provide it)
        
        // NO FALLBACK: backgroundColor comes from StyleSheet only
        // StyleSheet will always provide this via toMap() fallbacks
        
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
        // StyleSheet.toMap() ALWAYS provides primaryColor, so this should never be null
        if let primaryColor = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColor) {
                button.setTitleColor(color, for: .normal)
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor, don't set color (StyleSheet should always provide it)
        return true
    }
    
    @objc func handleButtonPress(_ sender: UIButton) {
        propagateEvent(on: sender, eventName: "onPress", data: [
            "pressed": true,
            "timestamp": Date().timeIntervalSince1970,
            "title": sender.title(for: .normal) ?? ""
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
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let button = view as? UIButton else {
            return CGSize.zero
        }
        
        let title = button.title(for: .normal) ?? ""
        
        if title.isEmpty {
            return CGSize(width: 100, height: 50)
        }
        
        let size = button.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        
        return CGSize(width: max(100, size.width), height: max(50, size.height))
    }
}
