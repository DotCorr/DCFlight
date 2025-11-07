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
        if let primaryColorStr = props["primaryColor"] as? String {
            switchControl.onTintColor = ColorUtilities.color(fromHexString: primaryColorStr) ?? DCFTheme.getAccentColor(traitCollection: switchControl.traitCollection)
            switchControl.thumbTintColor = ColorUtilities.color(fromHexString: primaryColorStr) ?? DCFTheme.getAccentColor(traitCollection: switchControl.traitCollection)
        } else {
            switchControl.onTintColor = DCFTheme.getAccentColor(traitCollection: switchControl.traitCollection)
            switchControl.thumbTintColor = DCFTheme.getAccentColor(traitCollection: switchControl.traitCollection)
        }
        
        if let secondaryColorStr = props["secondaryColor"] as? String {
            switchControl.backgroundColor = ColorUtilities.color(fromHexString: secondaryColorStr) ?? DCFTheme.getSurfaceColor(traitCollection: switchControl.traitCollection)
        } else {
            switchControl.backgroundColor = DCFTheme.getSurfaceColor(traitCollection: switchControl.traitCollection)
        }
        
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
        if let primaryColor = props["primaryColor"] as? String {
            switchControl.onTintColor = ColorUtilities.color(fromHexString: primaryColor)
            switchControl.thumbTintColor = ColorUtilities.color(fromHexString: primaryColor)
        } else {
            // Fall back to DCFTheme (framework colors) if no semantic color provided
            switchControl.onTintColor = DCFTheme.getAccentColor(traitCollection: switchControl.traitCollection)
            switchControl.thumbTintColor = DCFTheme.getAccentColor(traitCollection: switchControl.traitCollection)
        }
        
        if let secondaryColor = props["secondaryColor"] as? String {
            switchControl.backgroundColor = ColorUtilities.color(fromHexString: secondaryColor)
        } else {
            // Fall back to DCFTheme (framework colors) if no semantic color provided
            switchControl.backgroundColor = DCFTheme.getSurfaceColor(traitCollection: switchControl.traitCollection)
        }
        
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
}
