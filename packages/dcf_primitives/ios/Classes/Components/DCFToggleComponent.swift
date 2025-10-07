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
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                switchControl.onTintColor = UIColor.systemBlue
                switchControl.backgroundColor = UIColor.systemGray5
            } else {
                switchControl.onTintColor = UIColor.blue
                switchControl.backgroundColor = UIColor.lightGray
            }
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
        
        if let activeTrackColor = props["activeTrackColor"] as? String {
            switchControl.onTintColor = ColorUtilities.color(fromHexString: activeTrackColor)
        }
        
        if let inactiveTrackColor = props["inactiveTrackColor"] as? String {
            switchControl.backgroundColor = ColorUtilities.color(fromHexString: inactiveTrackColor)
        }
        
        if let activeThumbColor = props["activeThumbColor"] as? String {
            switchControl.thumbTintColor = ColorUtilities.color(fromHexString: activeThumbColor)
        }
        
        if let inactiveThumbColor = props["inactiveThumbColor"] as? String {
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
