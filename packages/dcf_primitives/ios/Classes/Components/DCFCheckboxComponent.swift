/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
        
        if let checkedColor = ColorUtilities.getColor(
            explicitColor: "checkedColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            checkbox.checkedColor = checkedColor
        }
        
        if let checkmarkColor = ColorUtilities.getColor(
            explicitColor: "checkmarkColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            checkbox.checkmarkColor = checkmarkColor
        }
        
        if let uncheckedColor = ColorUtilities.getColor(
            explicitColor: "uncheckedColor",
            semanticColor: "secondaryColor",
            from: props
        ) {
            checkbox.uncheckedColor = uncheckedColor
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
        
        if let checkedColor = ColorUtilities.getColor(
            explicitColor: "checkedColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            checkbox.checkedColor = checkedColor
        }
        
        if let checkmarkColor = ColorUtilities.getColor(
            explicitColor: "checkmarkColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            checkbox.checkmarkColor = checkmarkColor
        }
        
        if let uncheckedColor = ColorUtilities.getColor(
            explicitColor: "uncheckedColor",
            semanticColor: "secondaryColor",
            from: props
        ) {
            checkbox.uncheckedColor = uncheckedColor
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
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }

    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view,
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}


class DCFCheckboxView: UIControl {
    var isChecked: Bool = false {
        didSet {
            setNeedsDisplay()
            updateAccessibility()
        }
    }
    
    var checkedColor: UIColor = UIColor.clear {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var uncheckedColor: UIColor = UIColor.clear {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    var checkmarkColor: UIColor = UIColor.clear {
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
