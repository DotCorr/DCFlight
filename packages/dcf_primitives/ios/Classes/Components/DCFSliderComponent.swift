/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFSliderComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFSliderComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        
        let slider = UISlider()
        
        // UNIFIED SEMANTIC COLOR SYSTEM: Component handles semantic colors
        // primaryColor: minimum track and thumb color
        // secondaryColor: maximum track color
        if let primaryColorStr = props["primaryColor"] as? String {
            slider.minimumTrackTintColor = ColorUtilities.color(fromHexString: primaryColorStr) ?? DCFTheme.getAccentColor(traitCollection: slider.traitCollection)
            slider.thumbTintColor = ColorUtilities.color(fromHexString: primaryColorStr) ?? DCFTheme.getAccentColor(traitCollection: slider.traitCollection)
        } else {
            slider.minimumTrackTintColor = DCFTheme.getAccentColor(traitCollection: slider.traitCollection)
            slider.thumbTintColor = DCFTheme.getAccentColor(traitCollection: slider.traitCollection)
        }
        
        if let secondaryColorStr = props["secondaryColor"] as? String {
            slider.maximumTrackTintColor = ColorUtilities.color(fromHexString: secondaryColorStr) ?? DCFTheme.getSurfaceColor(traitCollection: slider.traitCollection)
        } else {
            slider.maximumTrackTintColor = DCFTheme.getSurfaceColor(traitCollection: slider.traitCollection)
        }
        
        slider.addTarget(DCFSliderComponent.sharedInstance, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.addTarget(DCFSliderComponent.sharedInstance, action: #selector(sliderTouchBegan(_:)), for: .touchDown)
        slider.addTarget(DCFSliderComponent.sharedInstance, action: #selector(sliderTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        updateView(slider, withProps: props)
        slider.applyStyles(props: props)
        
        return slider
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let slider = view as? UISlider else { return false }
        
        if let value = props["value"] as? Float {
            slider.value = value
        } else if let value = props["value"] as? Double {
            slider.value = Float(value)
        }
        
        if let minValue = props["minimumValue"] as? Float {
            slider.minimumValue = minValue
        } else if let minValue = props["minimumValue"] as? Double {
            slider.minimumValue = Float(minValue)
        }
        
        if let maxValue = props["maximumValue"] as? Float {
            slider.maximumValue = maxValue
        } else if let maxValue = props["maximumValue"] as? Double {
            slider.maximumValue = Float(maxValue)
        }
        
        if let step = props["step"] as? Float {
        }
        
        if let disabled = props["disabled"] as? Bool {
            slider.isEnabled = !disabled
            slider.alpha = disabled ? 0.5 : 1.0
        }
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: minimum track and thumb color
        // secondaryColor: maximum track color
        if let primaryColor = props["primaryColor"] as? String,
           let color = ColorUtilities.color(fromHexString: primaryColor) {
            slider.minimumTrackTintColor = color
            slider.thumbTintColor = color
        } else {
            // Fall back to DCFTheme (framework colors) if no semantic color provided
            slider.minimumTrackTintColor = DCFTheme.getAccentColor(traitCollection: slider.traitCollection)
            slider.thumbTintColor = DCFTheme.getAccentColor(traitCollection: slider.traitCollection)
        }

        if let secondaryColor = props["secondaryColor"] as? String,
           let color = ColorUtilities.color(fromHexString: secondaryColor) {
            slider.maximumTrackTintColor = color
        } else {
            // Fall back to DCFTheme (framework colors) if no semantic color provided
            slider.maximumTrackTintColor = DCFTheme.getSurfaceColor(traitCollection: slider.traitCollection)
        }
        
        slider.applyStyles(props: props)
        return true
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        propagateEvent(on: sender, eventName: "onValueChange", data: [
            "value": sender.value
        ])
    }
    
    @objc private func sliderTouchBegan(_ sender: UISlider) {
        propagateEvent(on: sender, eventName: "onSlidingStart", data: [
            "value": sender.value
        ])
    }
    
    @objc private func sliderTouchEnded(_ sender: UISlider) {
        propagateEvent(on: sender, eventName: "onSlidingComplete", data: [
            "value": sender.value
        ])
    }
}
