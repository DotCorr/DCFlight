/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFCheckboxComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFCheckboxComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let checkbox = DCFCheckboxView()
        
        // NO FALLBACK: Colors come from StyleSheet only
        // StyleSheet will always provide these via toMap() fallbacks
        checkbox.checkmarkColor = UIColor.white
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: active/checked color and checkmark color
        // secondaryColor: inactive/unchecked color
        if let primaryColor = props["primaryColor"] as? String,
           let color = ColorUtilities.color(fromHexString: primaryColor) {
            checkbox.checkedColor = color
            checkbox.checkmarkColor = color
        }

        if let secondaryColor = props["secondaryColor"] as? String,
           let color = ColorUtilities.color(fromHexString: secondaryColor) {
            checkbox.uncheckedColor = color
        }

        checkbox.addTarget(DCFCheckboxComponent.sharedInstance, action: #selector(checkboxTapped(_:)), for: .touchUpInside)

        updateView(checkbox, withProps: props)
        checkbox.applyStyles(props: props)
        
        checkbox.setNeedsDisplay()
        checkbox.layoutIfNeeded()
        
        return checkbox
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let checkbox = view as? DCFCheckboxView else { return false }
        
        if let checked = props["checked"] as? Bool {
            checkbox.isChecked = checked
        }
        
        if let disabled = props["disabled"] as? Bool {
            checkbox.isEnabled = !disabled
            checkbox.alpha = disabled ? 0.5 : 1.0
        }
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: active/checked color and checkmark color
        // secondaryColor: inactive/unchecked color
        if let primaryColor = props["primaryColor"] as? String {
            checkbox.checkedColor = ColorUtilities.color(fromHexString: primaryColor) ?? checkbox.checkedColor
            checkbox.checkmarkColor = ColorUtilities.color(fromHexString: primaryColor) ?? checkbox.checkmarkColor
        }
        
        if let secondaryColor = props["secondaryColor"] as? String {
            checkbox.uncheckedColor = ColorUtilities.color(fromHexString: secondaryColor) ?? checkbox.uncheckedColor
        }
        
        if let size = props["size"] as? CGFloat {
            checkbox.checkboxSize = size
        } else {
            let sizeString = props["size"] as? String ?? "medium"
            switch sizeString.lowercased() {
            case "small":
                checkbox.checkboxSize = 20.0
            case "large":
                checkbox.checkboxSize = 28.0
            default: // medium
                checkbox.checkboxSize = 24.0
            }
        }
        
        if let borderWidth = props["borderWidth"] as? CGFloat {
            checkbox.borderWidth = borderWidth
        }
        
        checkbox.setNeedsDisplay()
        checkbox.invalidateIntrinsicContentSize()
        
        checkbox.applyStyles(props: props)
        return true
    }
    
    @objc private func checkboxTapped(_ sender: DCFCheckboxView) {
        sender.isChecked.toggle()
        
        propagateEvent(on: sender, eventName: "onValueChange", data: [
            "value": sender.isChecked
        ])
    }
}


class DCFCheckboxView: UIControl {
    var isChecked: Bool = false {
        didSet {
            setNeedsDisplay()
            updateAccessibility()
        }
    }
    
    var checkedColor: UIColor = UIColor.systemBlue {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var uncheckedColor: UIColor = UIColor.systemGray4 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // NO FALLBACK: Colors come from StyleSheet only
        // StyleSheet will always provide these via toMap() fallbacks
    }
    
    var checkmarkColor: UIColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var checkboxSize: CGFloat = 24.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }
    
    var borderWidth: CGFloat = 2.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: checkboxSize, height: checkboxSize)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = true
        
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Checkbox"
        updateAccessibility()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let checkboxRect = CGRect(
            x: (bounds.width - checkboxSize) / 2,
            y: (bounds.height - checkboxSize) / 2,
            width: checkboxSize,
            height: checkboxSize
        )
        
        context.setFillColor(isChecked ? checkedColor.cgColor : UIColor.clear.cgColor)
        context.setStrokeColor(isChecked ? checkedColor.cgColor : uncheckedColor.cgColor)
        context.setLineWidth(borderWidth)
        
        let cornerRadius: CGFloat = 4.0
        let path = UIBezierPath(roundedRect: checkboxRect, cornerRadius: cornerRadius)
        
        if isChecked {
            context.addPath(path.cgPath)
            context.fillPath()
        } else {
            context.addPath(path.cgPath)
            context.strokePath()
        }
        
        if isChecked {
            context.setStrokeColor(checkmarkColor.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let checkmarkPath = UIBezierPath()
            let checkmarkSize = checkboxSize * 0.6
            let checkmarkOrigin = CGPoint(
                x: checkboxRect.minX + (checkboxSize - checkmarkSize) / 2,
                y: checkboxRect.minY + (checkboxSize - checkmarkSize) / 2
            )
            
            checkmarkPath.move(to: CGPoint(x: checkmarkOrigin.x + checkmarkSize * 0.2, y: checkmarkOrigin.y + checkmarkSize * 0.5))
            checkmarkPath.addLine(to: CGPoint(x: checkmarkOrigin.x + checkmarkSize * 0.45, y: checkmarkOrigin.y + checkmarkSize * 0.75))
            checkmarkPath.addLine(to: CGPoint(x: checkmarkOrigin.x + checkmarkSize * 0.8, y: checkmarkOrigin.y + checkmarkSize * 0.25))
            
            context.addPath(checkmarkPath.cgPath)
            context.strokePath()
        }
    }
    
    private func updateAccessibility() {
        accessibilityValue = isChecked ? "Checked" : "Unchecked"
    }
}
