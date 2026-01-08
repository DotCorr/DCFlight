/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

extension UIView {
    /// Apply common style properties to this view, driven only by explicit props.
    public func applyStyles(props: [String: Any]) {

        var hasCornerRadius = false
        var finalCornerRadius: CGFloat = 0
        var finalCornerMask: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]

        if let borderRadius = props["borderRadius"] as? CGFloat {
            layer.cornerRadius = borderRadius
            finalCornerRadius = borderRadius
            hasCornerRadius = true
            self.clipsToBounds = true  // Enable clipping when border radius is set
        }

        var cornerMask: CACornerMask = []
        var customRadius: CGFloat? = nil  // Use the first specified radius

        if let radius = props["borderTopLeftRadius"] as? CGFloat, radius >= 0 {
            cornerMask.insert(.layerMinXMinYCorner)
            customRadius = customRadius ?? radius
        }
        if let radius = props["borderTopRightRadius"] as? CGFloat, radius >= 0 {
            cornerMask.insert(.layerMaxXMinYCorner)
            customRadius = customRadius ?? radius
        }
        if let radius = props["borderBottomLeftRadius"] as? CGFloat, radius >= 0 {
            cornerMask.insert(.layerMinXMaxYCorner)
            customRadius = customRadius ?? radius
        }
        if let radius = props["borderBottomRightRadius"] as? CGFloat, radius >= 0 {
            cornerMask.insert(.layerMaxXMaxYCorner)
            customRadius = customRadius ?? radius
        }

        if !cornerMask.isEmpty {
            layer.maskedCorners = cornerMask
            finalCornerMask = cornerMask
            if let radius = customRadius {
                layer.cornerRadius = radius  // Apply the radius if specific corners are masked
                finalCornerRadius = radius
                hasCornerRadius = true
                self.clipsToBounds = true  // Enable clipping for rounded corners
            }
        }

        // Handle borders - support individual sides for consistency with Android
        // Check if individual border sides are specified
        let borderTopWidth = (props["borderTopWidth"] as? CGFloat) ?? 0
        let borderRightWidth = (props["borderRightWidth"] as? CGFloat) ?? 0
        let borderBottomWidth = (props["borderBottomWidth"] as? CGFloat) ?? 0
        let borderLeftWidth = (props["borderLeftWidth"] as? CGFloat) ?? 0
        let generalBorderWidth = (props["borderWidth"] as? CGFloat) ?? 0
        
        let borderTopColor = (props["borderTopColor"] as? String).flatMap { ColorUtilities.color(fromHexString: $0)?.cgColor }
        let borderRightColor = (props["borderRightColor"] as? String).flatMap { ColorUtilities.color(fromHexString: $0)?.cgColor }
        let borderBottomColor = (props["borderBottomColor"] as? String).flatMap { ColorUtilities.color(fromHexString: $0)?.cgColor }
        let borderLeftColor = (props["borderLeftColor"] as? String).flatMap { ColorUtilities.color(fromHexString: $0)?.cgColor }
        let generalBorderColor = (props["borderColor"] as? String).flatMap { ColorUtilities.color(fromHexString: $0)?.cgColor }
        
        // Determine if we have individual border sides
        let hasIndividualBorders = borderTopWidth > 0 || borderRightWidth > 0 || borderBottomWidth > 0 || borderLeftWidth > 0 ||
                                   borderTopColor != nil || borderRightColor != nil || borderBottomColor != nil || borderLeftColor != nil
        
        if hasIndividualBorders {
            // Use CAShapeLayer for individual border sides
            applyIndividualBorders(
                topWidth: generalBorderWidth > 0 ? generalBorderWidth : borderTopWidth,
                rightWidth: generalBorderWidth > 0 ? generalBorderWidth : borderRightWidth,
                bottomWidth: generalBorderWidth > 0 ? generalBorderWidth : borderBottomWidth,
                leftWidth: generalBorderWidth > 0 ? generalBorderWidth : borderLeftWidth,
                topColor: generalBorderColor ?? borderTopColor,
                rightColor: generalBorderColor ?? borderRightColor,
                bottomColor: generalBorderColor ?? borderBottomColor,
                leftColor: generalBorderColor ?? borderLeftColor,
                cornerRadius: finalCornerRadius
            )
            self.clipsToBounds = true
        } else if generalBorderWidth > 0 {
            // Use native CALayer for uniform borders (more efficient)
            if let borderColor = generalBorderColor {
                layer.borderColor = borderColor
            }
            layer.borderWidth = generalBorderWidth
            self.clipsToBounds = true
        } else {
            // Remove any existing border layers
            layer.borderWidth = 0
            removeBorderLayers()
        }

        if let backgroundColorStr = props["backgroundColor"] as? String {
            self.backgroundColor = ColorUtilities.color(fromHexString: backgroundColorStr)
        }

        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.applyGradientBackground(
                    gradientData: gradientData,
                    cornerRadius: hasCornerRadius ? finalCornerRadius : nil,
                    cornerMask: hasCornerRadius ? finalCornerMask : nil)
            }
        }

        if let opacity = props["opacity"] as? CGFloat {
            self.alpha = opacity
        }

        var needsMasksToBoundsFalse = false  // Track if shadow requires masksToBounds = false
        if let shadowColorStr = props["shadowColor"] as? String {
            layer.shadowColor = ColorUtilities.color(fromHexString: shadowColorStr)?.cgColor
            needsMasksToBoundsFalse = true
        }

        if let shadowOpacity = props["shadowOpacity"] as? Float {
            layer.shadowOpacity = shadowOpacity
            needsMasksToBoundsFalse = true
        }

        if let shadowRadius = props["shadowRadius"] as? CGFloat {
            layer.shadowRadius = shadowRadius
            needsMasksToBoundsFalse = true
        }

        var currentOffset = layer.shadowOffset
        var offsetChanged = false

        if let shadowOffsetX = props["shadowOffsetX"] as? CGFloat {
            currentOffset.width = shadowOffsetX
            offsetChanged = true
        }
        if let shadowOffsetY = props["shadowOffsetY"] as? CGFloat {
            currentOffset.height = shadowOffsetY
            offsetChanged = true
        }

        if offsetChanged {
            layer.shadowOffset = currentOffset
            needsMasksToBoundsFalse = true
        }

        if let elevation = props["elevation"] as? CGFloat {
            let shadowOpacity: Float = elevation > 0 ? 0.25 : 0
            let shadowRadius: CGFloat = elevation * 0.5
            let shadowOffset = CGSize(width: 0, height: elevation * 0.5)

            layer.shadowOpacity = shadowOpacity
            layer.shadowRadius = shadowRadius
            layer.shadowOffset = shadowOffset
            layer.shadowColor = UIColor.black.cgColor

            if elevation > 0 {
                needsMasksToBoundsFalse = true
            }
        }

        if needsMasksToBoundsFalse && hasCornerRadius {
            layer.masksToBounds = false
            self.clipsToBounds = true
        } else if needsMasksToBoundsFalse {
            layer.masksToBounds = false
        } else if hasCornerRadius {
            self.clipsToBounds = true
        }

        if let hitSlopMap = props["hitSlop"] as? [String: Any] {
            var hitSlopInsets = UIEdgeInsets.zero

            if let top = hitSlopMap["top"] as? CGFloat {
                hitSlopInsets.top = -top
            }
            if let bottom = hitSlopMap["bottom"] as? CGFloat {
                hitSlopInsets.bottom = -bottom
            }
            if let left = hitSlopMap["left"] as? CGFloat {
                hitSlopInsets.left = -left
            }
            if let right = hitSlopMap["right"] as? CGFloat {
                hitSlopInsets.right = -right
            }

            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "hitSlop".hashValue)!,
                NSValue(uiEdgeInsets: hitSlopInsets), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        if let accessible = props["accessible"] as? Bool {
            self.isAccessibilityElement = accessible
        }

        if let label = props["accessibilityLabel"] as? String {
            self.accessibilityLabel = label
        } else if let ariaLabel = props["ariaLabel"] as? String {
            self.accessibilityLabel = ariaLabel
        }

        if let hint = props["accessibilityHint"] as? String {
            self.accessibilityHint = hint
        }

        var hasExplicitAccessibilityValue = false
        if let value = props["accessibilityValue"] as? String {
            self.accessibilityValue = value
            hasExplicitAccessibilityValue = true
        } else if let valueDict = props["accessibilityValue"] as? [String: Any] {
            if let text = valueDict["text"] as? String {
                self.accessibilityValue = text
                hasExplicitAccessibilityValue = true
            }
        }

        if let role = props["accessibilityRole"] as? String {
            if #available(iOS 10.0, *) {
                switch role.lowercased() {
                case "button": self.accessibilityTraits = .button
                case "link": self.accessibilityTraits = .link
                case "header": self.accessibilityTraits = .header
                case "image": self.accessibilityTraits = .image
                case "text": self.accessibilityTraits = .staticText
                case "none": self.accessibilityTraits = .none
                case "search": self.accessibilityTraits = .searchField
                case "adjustable": self.accessibilityTraits = .adjustable
                case "imagebutton": self.accessibilityTraits = [.button, .image]
                case "keyboardkey": self.accessibilityTraits = .keyboardKey
                case "summary": self.accessibilityTraits = .summaryElement
                case "alert": self.accessibilityTraits = .staticText
                default: break
                }
            }
        }

        if let state = props["accessibilityState"] as? [String: Any] {
            var traits: UIAccessibilityTraits = []
            if let disabled = state["disabled"] as? Bool, disabled {
                traits.insert(.notEnabled)
            }
            if let selected = state["selected"] as? Bool, selected {
                traits.insert(.selected)
            }
            if let checked = state["checked"] as? Bool {
                if checked {
                    traits.insert(.selected)
                }
            } else if let checked = state["checked"] as? String, checked == "mixed" {
                traits.insert(.none)
            }
            if let busy = state["busy"] as? Bool, busy {
                traits.insert(.updatesFrequently)
            }
            if !traits.isEmpty {
                self.accessibilityTraits.insert(traits)
            }
            
            if let expanded = state["expanded"] as? Bool, !hasExplicitAccessibilityValue {
                if expanded {
                    self.accessibilityValue = "expanded"
                } else {
                    self.accessibilityValue = "collapsed"
                }
            }
        }

        if let elementsHidden = props["accessibilityElementsHidden"] as? Bool {
            self.accessibilityElementsHidden = elementsHidden
        } else if let ariaHidden = props["ariaHidden"] as? Bool {
            self.accessibilityElementsHidden = ariaHidden
        }

        if let language = props["accessibilityLanguage"] as? String {
            if #available(iOS 13.0, *) {
                self.accessibilityLanguage = language
            }
        }

        if let ignoresInvert = props["accessibilityIgnoresInvertColors"] as? Bool {
            if #available(iOS 11.0, *) {
                self.accessibilityIgnoresInvertColors = ignoresInvert
            }
        }

        if let isModal = props["accessibilityViewIsModal"] as? Bool {
            self.accessibilityViewIsModal = isModal
        } else if let ariaModal = props["ariaModal"] as? Bool {
            self.accessibilityViewIsModal = ariaModal
        }

        // accessibilityLiveRegion / ariaLive - Android has this, iOS doesn't have direct equivalent
        // iOS doesn't have a direct equivalent, but we can store it for reference
        if let liveRegion = props["accessibilityLiveRegion"] as? String {
            // iOS doesn't have accessibilityLiveRegion, but we store it for consistency
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "accessibilityLiveRegion".hashValue)!,
                liveRegion, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else if let ariaLive = props["ariaLive"] as? String {
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "accessibilityLiveRegion".hashValue)!,
                ariaLive, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        // importantForAccessibility - Android has this, iOS doesn't have direct equivalent
        // iOS uses isAccessibilityElement, but importantForAccessibility is Android-specific
        if let important = props["importantForAccessibility"] as? String {
            // Store for reference, but iOS doesn't have this concept
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "importantForAccessibility".hashValue)!,
                important, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        if let testID = props["testID"] as? String {
            self.accessibilityIdentifier = testID
        }

        if let pointerEvents = props["pointerEvents"] as? String {
            switch pointerEvents {
            case "none":
                self.isUserInteractionEnabled = false
            case "box-none":
                self.isUserInteractionEnabled = false  // Correct for the view itself
            case "box-only":
                self.isUserInteractionEnabled = true
            case "auto", "all":
                fallthrough
            default:
                self.isUserInteractionEnabled = true
            }
        }
        
        // Transforms - match Android behavior exactly
        var rotation: CGFloat = 0
        var translateX: CGFloat = 0
        var translateY: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var hasTransforms = false
        
        if let rotate = props["rotateInDegrees"] as? CGFloat {
            rotation = rotate
            hasTransforms = true
        }
        
        if let tx = props["translateX"] as? CGFloat {
            translateX = tx
            hasTransforms = true
        }
        
        if let ty = props["translateY"] as? CGFloat {
            translateY = ty
            hasTransforms = true
        }
        
        if let scale = props["scale"] as? CGFloat {
            scaleX = scale
            scaleY = scale
            hasTransforms = true
        }
        
        if let sx = props["scaleX"] as? CGFloat {
            scaleX = sx
            hasTransforms = true
        }
        
        if let sy = props["scaleY"] as? CGFloat {
            scaleY = sy
            hasTransforms = true
        }
        
        if hasTransforms {
            // Apply pivot at center for rotation (matches Android)
            // Use frame instead of bounds to handle zero-size views
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            if !frame.isEmpty {
                layer.position = CGPoint(x: frame.midX, y: frame.midY)
            }
            
            // Apply transforms
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, translateX, translateY, 0)
            transform = CATransform3DRotate(transform, rotation * .pi / 180, 0, 0, 1)
            transform = CATransform3DScale(transform, scaleX, scaleY, 1)
            layer.transform = transform
        } else {
            // Reset transforms if none specified (matches Android)
            layer.transform = CATransform3DIdentity
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
    }

    /// Apply adaptive background color based on view type and iOS version
    private func applyAdaptiveBackgroundColor() {
        if self is UILabel {
            self.backgroundColor = UIColor.clear
        } else if self is UIImageView {
            if #available(iOS 13.0, *) {
                self.backgroundColor = UIColor.systemBackground
            } else {
                self.backgroundColor = UIColor.white
            }
        } else if self is UICollectionView || self is UITableView || self is UIScrollView {
            if #available(iOS 13.0, *) {
                self.backgroundColor = UIColor.systemBackground
            } else {
                self.backgroundColor = UIColor.white
            }
        } else {
            if #available(iOS 13.0, *) {
                self.backgroundColor = UIColor.systemBackground
            } else {
                self.backgroundColor = UIColor.white
            }
        }
    }

    /// Apply individual border sides using CAShapeLayer
    /// This ensures consistent behavior with Android when individual border sides are specified
    private func applyIndividualBorders(
        topWidth: CGFloat, rightWidth: CGFloat, bottomWidth: CGFloat, leftWidth: CGFloat,
        topColor: CGColor?, rightColor: CGColor?, bottomColor: CGColor?, leftColor: CGColor?,
        cornerRadius: CGFloat
    ) {
        // Remove existing border layers
        removeBorderLayers()
        
        // Only create layers for sides that have width > 0
        let bounds = self.bounds
        guard !bounds.isEmpty else {
            // Store border config for later when bounds are available
            let borderConfig: [String: Any] = [
                "topWidth": topWidth,
                "rightWidth": rightWidth,
                "bottomWidth": bottomWidth,
                "leftWidth": leftWidth,
                "topColor": topColor != nil ? UIColor(cgColor: topColor!) : NSNull(),
                "rightColor": rightColor != nil ? UIColor(cgColor: rightColor!) : NSNull(),
                "bottomColor": bottomColor != nil ? UIColor(cgColor: bottomColor!) : NSNull(),
                "leftColor": leftColor != nil ? UIColor(cgColor: leftColor!) : NSNull(),
                "cornerRadius": cornerRadius
            ]
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "pendingBorderConfig".hashValue)!,
                borderConfig, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }
        
        // Top border
        if topWidth > 0, let color = topColor {
            let topLayer = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: cornerRadius, y: topWidth / 2))
            path.addLine(to: CGPoint(x: bounds.width - cornerRadius, y: topWidth / 2))
            topLayer.path = path.cgPath
            topLayer.strokeColor = color
            topLayer.lineWidth = topWidth
            topLayer.fillColor = nil
            topLayer.name = "borderTop"
            layer.addSublayer(topLayer)
        }
        
        // Right border
        if rightWidth > 0, let color = rightColor {
            let rightLayer = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: bounds.width - rightWidth / 2, y: cornerRadius))
            path.addLine(to: CGPoint(x: bounds.width - rightWidth / 2, y: bounds.height - cornerRadius))
            rightLayer.path = path.cgPath
            rightLayer.strokeColor = color
            rightLayer.lineWidth = rightWidth
            rightLayer.fillColor = nil
            rightLayer.name = "borderRight"
            layer.addSublayer(rightLayer)
        }
        
        // Bottom border
        if bottomWidth > 0, let color = bottomColor {
            let bottomLayer = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: cornerRadius, y: bounds.height - bottomWidth / 2))
            path.addLine(to: CGPoint(x: bounds.width - cornerRadius, y: bounds.height - bottomWidth / 2))
            bottomLayer.path = path.cgPath
            bottomLayer.strokeColor = color
            bottomLayer.lineWidth = bottomWidth
            bottomLayer.fillColor = nil
            bottomLayer.name = "borderBottom"
            layer.addSublayer(bottomLayer)
        }
        
        // Left border
        if leftWidth > 0, let color = leftColor {
            let leftLayer = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: leftWidth / 2, y: cornerRadius))
            path.addLine(to: CGPoint(x: leftWidth / 2, y: bounds.height - cornerRadius))
            leftLayer.path = path.cgPath
            leftLayer.strokeColor = color
            leftLayer.lineWidth = leftWidth
            leftLayer.fillColor = nil
            leftLayer.name = "borderLeft"
            layer.addSublayer(leftLayer)
        }
    }
    
    /// Remove all border layers
    private func removeBorderLayers() {
        layer.sublayers?.filter { $0.name?.hasPrefix("border") == true }.forEach { $0.removeFromSuperlayer() }
        objc_setAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "pendingBorderConfig".hashValue)!,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    /// CRITICAL FIX: Apply gradient background with proper corner radius support
    private func applyGradientBackground(
        gradientData: [String: Any], cornerRadius: CGFloat? = nil, cornerMask: CACornerMask? = nil
    ) {
        guard !bounds.isEmpty else {
            let pendingData: [String: Any] = [
                "gradientData": gradientData,
                "cornerRadius": cornerRadius ?? 0,
                "cornerMask": cornerMask?.rawValue ?? CACornerMask.allCorners.rawValue,
            ]
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "pendingGradientData".hashValue)!,
                pendingData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        let existingGradientLayers = layer.sublayers?.filter { $0 is CAGradientLayer } ?? []
        for gradientLayer in existingGradientLayers {
            gradientLayer.removeFromSuperlayer()
        }

        guard let type = gradientData["type"] as? String,
            let colorsArray = gradientData["colors"] as? [String]
        else {
            return
        }

        let cgColors: [CGColor] = colorsArray.compactMap { colorString in
            let color = ColorUtilities.color(fromHexString: colorString)?.cgColor
            if color == nil {
                print("⚠️ Failed to convert color: \(colorString)")
            }
            return color
        }

        guard cgColors.count >= 2 else {
            print("⚠️ Gradient needs at least 2 colors, got \(cgColors.count)")
            return
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = cgColors
        gradientLayer.frame = bounds

        if let cornerRadius = cornerRadius {
            gradientLayer.cornerRadius = cornerRadius
            if let cornerMask = cornerMask {
                gradientLayer.maskedCorners = cornerMask
            }
        }

        if let stops = gradientData["stops"] as? [Double] {
            gradientLayer.locations = stops.map { NSNumber(value: $0) }
        }

        switch type {
        case "linear":
            let startX = gradientData["startX"] as? Double ?? 0.0
            let startY = gradientData["startY"] as? Double ?? 0.0
            let endX = gradientData["endX"] as? Double ?? 1.0
            let endY = gradientData["endY"] as? Double ?? 1.0

            gradientLayer.startPoint = CGPoint(x: startX, y: startY)
            gradientLayer.endPoint = CGPoint(x: endX, y: endY)
            gradientLayer.type = .axial

        case "radial":
            let centerX = gradientData["centerX"] as? Double ?? 0.5
            let centerY = gradientData["centerY"] as? Double ?? 0.5
            let radius = gradientData["radius"] as? Double ?? 0.5

            gradientLayer.type = .radial
            gradientLayer.startPoint = CGPoint(x: centerX, y: centerY)
            let radiusX = centerX + radius
            let radiusY = centerY + radius
            gradientLayer.endPoint = CGPoint(x: min(radiusX, 1.0), y: min(radiusY, 1.0))

        default:
            print("⚠️ Unknown gradient type: \(type)")
            return
        }

        gradientLayer.name = "backgroundGradient"

        let hasChildLayers = layer.sublayers?.contains { $0.name != "backgroundGradient" } ?? false

        if hasChildLayers {
            layer.insertSublayer(gradientLayer, at: 0)
        } else {
            layer.addSublayer(gradientLayer)
        }

        print(
            "✅ Applied gradient: \(type) with \(cgColors.count) colors at frame \(bounds) with cornerRadius: \(cornerRadius ?? 0)"
        )

        objc_setAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!,
            gradientLayer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if let cornerRadius = cornerRadius {
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "gradientCornerRadius".hashValue)!,
                cornerRadius, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        if let cornerMask = cornerMask {
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "gradientCornerMask".hashValue)!,
                cornerMask.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        objc_setAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "pendingGradientData".hashValue)!,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

extension UIView {
    /// Update border layers when view bounds change
    @objc private func updateBorderLayers() {
        guard !bounds.isEmpty else { return }
        
        if let borderConfig = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "pendingBorderConfig".hashValue)!) as? [String: Any]
        {
            let topWidth = (borderConfig["topWidth"] as? CGFloat) ?? 0
            let rightWidth = (borderConfig["rightWidth"] as? CGFloat) ?? 0
            let bottomWidth = (borderConfig["bottomWidth"] as? CGFloat) ?? 0
            let leftWidth = (borderConfig["leftWidth"] as? CGFloat) ?? 0
            let cornerRadius = (borderConfig["cornerRadius"] as? CGFloat) ?? 0
            
            let topColor = (borderConfig["topColor"] as? UIColor)?.cgColor
            let rightColor = (borderConfig["rightColor"] as? UIColor)?.cgColor
            let bottomColor = (borderConfig["bottomColor"] as? UIColor)?.cgColor
            let leftColor = (borderConfig["leftColor"] as? UIColor)?.cgColor
            
            applyIndividualBorders(
                topWidth: topWidth, rightWidth: rightWidth, bottomWidth: bottomWidth, leftWidth: leftWidth,
                topColor: topColor, rightColor: rightColor, bottomColor: bottomColor, leftColor: leftColor,
                cornerRadius: cornerRadius
            )
        }
    }
    
    /// Update gradient layer frame when view bounds change
    @objc public func updateGradientFrame() {
        guard !bounds.isEmpty else { return }  // Skip empty bounds

        if let pendingData = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "pendingGradientData".hashValue)!) as? [String: Any]
        {
            let gradientData = pendingData["gradientData"] as? [String: Any] ?? [:]
            let cornerRadius = pendingData["cornerRadius"] as? CGFloat
            let cornerMaskRaw = pendingData["cornerMask"] as? UInt
            let cornerMask = cornerMaskRaw != nil ? CACornerMask(rawValue: cornerMaskRaw!) : nil

            applyGradientBackground(
                gradientData: gradientData,
                cornerRadius: cornerRadius != 0 ? cornerRadius : nil,
                cornerMask: cornerMask)
            return
        }

        if let gradientLayer = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!) as? CAGradientLayer
        {
            if gradientLayer.frame != bounds {
                CATransaction.begin()
                CATransaction.setDisableActions(true)  // Prevent animation
                gradientLayer.frame = bounds

                if let cornerRadius = objc_getAssociatedObject(
                    self, UnsafeRawPointer(bitPattern: "gradientCornerRadius".hashValue)!)
                    as? CGFloat
                {
                    gradientLayer.cornerRadius = cornerRadius
                }
                if let cornerMaskRaw = objc_getAssociatedObject(
                    self, UnsafeRawPointer(bitPattern: "gradientCornerMask".hashValue)!) as? UInt
                {
                    gradientLayer.maskedCorners = CACornerMask(rawValue: cornerMaskRaw)
                }

                if let sublayers = layer.sublayers,
                    let gradientIndex = sublayers.firstIndex(of: gradientLayer),
                    gradientIndex > 0
                {
                    gradientLayer.removeFromSuperlayer()
                    layer.insertSublayer(gradientLayer, at: 0)
                    print("🔧 Moved gradient layer back to index 0 after frame update")
                }

                CATransaction.commit()
                print(
                    "📐 Updated gradient frame to \(bounds) with cornerRadius: \(gradientLayer.cornerRadius)"
                )
            }
        }
    }

    /// Override layoutSubviews to ensure gradient frames and borders are updated
    @objc private func swizzled_layoutSubviews() {
        swizzled_layoutSubviews()  // Call original implementation

        DispatchQueue.main.async { [weak self] in
            self?.updateGradientFrame()
            self?.updateBorderLayers()
        }
    }
}

extension UIView {
    static let swizzleLayoutSubviews: Void = {
        let originalSelector = #selector(UIView.layoutSubviews)
        let swizzledSelector = #selector(UIView.swizzled_layoutSubviews)

        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector)
        else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    public static func performSwizzling() {
        _ = swizzleLayoutSubviews
    }
}

extension CACornerMask {
    static let allCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
    ]
}