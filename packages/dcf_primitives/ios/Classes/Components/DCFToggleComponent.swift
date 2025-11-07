/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFToggleComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFToggleComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let switchControl = UISwitch()
        
        // UNIFIED SEMANTIC COLOR SYSTEM: Component handles semantic colors
        // primaryColor: active track and thumb color
        // secondaryColor: inactive track color
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        if let primaryColorStr = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColorStr) {
                switchControl.onTintColor = color
                switchControl.thumbTintColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        if let secondaryColorStr = props["secondaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: secondaryColorStr) {
                switchControl.backgroundColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no secondaryColor provided, don't set color (StyleSheet is the only source)
        
        switchControl.addTarget(DCFToggleComponent.sharedInstance, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        
        updateView(switchControl, withProps: props)
        switchControl.applyStyles(props: props)
        
        return switchControl
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let switchControl = view as? UISwitch else { return false }
        
        if let value = props["value"] as? Bool {
            switchControl.setOn(value, animated: props["animated"] as? Bool ?? true)
        }
        
        if let disabled = props["disabled"] as? Bool {
            switchControl.isEnabled = !disabled
            switchControl.alpha = disabled ? 0.5 : 1.0
        }
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: active track and thumb color
        // secondaryColor: inactive track color
        // tertiaryColor: inactive thumb color
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        if let primaryColor = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColor) {
                switchControl.onTintColor = color
                switchControl.thumbTintColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        if let secondaryColor = props["secondaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: secondaryColor) {
                switchControl.backgroundColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no secondaryColor provided, don't set color (StyleSheet is the only source)
        
        if let tertiaryColor = props["tertiaryColor"] as? String {
            // iOS doesn't have separate inactive thumb color, but we can use tertiaryColor if needed
        }
        
        switchControl.applyStyles(props: props)
        return true
    }
    
    @objc private func switchValueChanged(_ sender: UISwitch) {
        propagateEvent(on: sender, eventName: "onValueChange", data: [
            "value": sender.isOn
        ])
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let switchControl = view as? UISwitch else {
            return CGSize.zero
        }
        
        let size = switchControl.intrinsicContentSize
        return CGSize(width: max(1, size.width), height: max(1, size.height))
    }
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }

    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        objc_setAssociatedObject(view,
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}
