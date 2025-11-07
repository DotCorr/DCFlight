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
        
        // UNIFIED SEMANTIC COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // primaryColor: minimum track and thumb color
        // secondaryColor: maximum track color
        if let primaryColorStr = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColorStr) {
                slider.minimumTrackTintColor = color
                slider.thumbTintColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        if let secondaryColorStr = props["secondaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: secondaryColorStr) {
                slider.maximumTrackTintColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no secondaryColor provided, don't set color (StyleSheet is the only source)
        
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
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // primaryColor: minimum track and thumb color
        // secondaryColor: maximum track color
        if let primaryColor = props["primaryColor"] as? String,
           let color = ColorUtilities.color(fromHexString: primaryColor) {
            slider.minimumTrackTintColor = color
            slider.thumbTintColor = color
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        if let secondaryColor = props["secondaryColor"] as? String,
           let color = ColorUtilities.color(fromHexString: secondaryColor) {
            slider.maximumTrackTintColor = color
        }
        // NO FALLBACK: If no secondaryColor provided, don't set color (StyleSheet is the only source)
        
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
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let slider = view as? UISlider else {
            return CGSize.zero
        }
        
        let size = slider.intrinsicContentSize
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
