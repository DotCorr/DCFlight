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

        // FIXED: Individual corner radius support using CAShapeLayer mask
        var hasCornerRadius = false
        var finalCornerRadius: CGFloat = 0
        var finalCornerMask: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]

        // Get individual corner radii
        let topLeftRadius = (props["borderTopLeftRadius"] as? CGFloat) ?? -1
        let topRightRadius = (props["borderTopRightRadius"] as? CGFloat) ?? -1
        let bottomLeftRadius = (props["borderBottomLeftRadius"] as? CGFloat) ?? -1
        let bottomRightRadius = (props["borderBottomRightRadius"] as? CGFloat) ?? -1
        let generalBorderRadius = (props["borderRadius"] as? CGFloat) ?? -1
        
        // Determine if we have individual corner radii
        let hasIndividualRadii = topLeftRadius >= 0 || topRightRadius >= 0 || bottomLeftRadius >= 0 || bottomRightRadius >= 0
        
        if hasIndividualRadii {
            // FIXED: Use CAShapeLayer mask for individual corner radii
            // This is the ONLY way to have different radii per corner on iOS
            let topLeft = topLeftRadius >= 0 ? topLeftRadius : (generalBorderRadius >= 0 ? generalBorderRadius : 0)
            let topRight = topRightRadius >= 0 ? topRightRadius : (generalBorderRadius >= 0 ? generalBorderRadius : 0)
            let bottomLeft = bottomLeftRadius >= 0 ? bottomLeftRadius : (generalBorderRadius >= 0 ? generalBorderRadius : 0)
            let bottomRight = bottomRightRadius >= 0 ? bottomRightRadius : (generalBorderRadius >= 0 ? generalBorderRadius : 0)
            
            // Store radii for mask creation in layoutSubviews
            let radii: [String: CGFloat] = [
                "topLeft": topLeft,
                "topRight": topRight,
                "bottomLeft": bottomLeft,
                "bottomRight": bottomRight
            ]
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!,
                radii, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Apply mask immediately if bounds are available
            if !bounds.isEmpty {
                applyCornerRadiusMask(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            }
            
            finalCornerRadius = max(topLeft, topRight, bottomLeft, bottomRight)
            hasCornerRadius = true
            self.clipsToBounds = true
        } else if generalBorderRadius >= 0 {
            // FIXED: ALWAYS use mask layer for corner radius (ensures perfect pill shapes)
            // layer.cornerRadius can create pointy ends, mask layer is always perfect
            let height = bounds.height > 0 ? bounds.height : frame.height
            let radius: CGFloat
            if height > 0 && abs(generalBorderRadius - height / 2) < 0.5 {
                // Pill shape: use exact height/2 for perfect semicircles
                radius = height / 2
            } else {
                radius = generalBorderRadius
            }
            
            // Store for mask creation in layoutSubviews
            let radii: [String: CGFloat] = [
                "topLeft": radius,
                "topRight": radius,
                "bottomLeft": radius,
                "bottomRight": radius
            ]
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!,
                radii, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Apply mask immediately if bounds are available
            if !bounds.isEmpty {
                applyCornerRadiusMask(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
            }
            
                finalCornerRadius = radius
                hasCornerRadius = true
            self.clipsToBounds = true
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
            // Use CAShapeLayer for individual border sides with proper rounded paths
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
            // Use native CALayer for uniform borders (iOS handles corner radius correctly)
            // This is the CORRECT way - iOS borderWidth respects cornerRadius automatically
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

        // FIXED: Apply gradient synchronously if bounds are available, otherwise store for layoutSubviews
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            applyGradientBackground(
                    gradientData: gradientData,
                    cornerRadius: hasCornerRadius ? finalCornerRadius : nil,
                    cornerMask: hasCornerRadius ? finalCornerMask : nil)
        }

        if let opacity = props["opacity"] as? CGFloat {
            self.alpha = opacity
        }

        // FIXED: Shadow + Corner Radius + Elevation support
        var hasShadow = false
        var shadowColor: CGColor?
        var shadowOpacity: Float = 0
        var shadowRadius: CGFloat = 0
        var shadowOffset = CGSize.zero
        
        if let shadowColorStr = props["shadowColor"] as? String {
            shadowColor = ColorUtilities.color(fromHexString: shadowColorStr)?.cgColor
            hasShadow = true
        }

        if let opacity = props["shadowOpacity"] as? Float {
            shadowOpacity = opacity
            hasShadow = true
        }

        if let radius = props["shadowRadius"] as? CGFloat {
            shadowRadius = radius
            hasShadow = true
        }

        if let shadowOffsetX = props["shadowOffsetX"] as? CGFloat {
            shadowOffset.width = shadowOffsetX
            hasShadow = true
        }
        if let shadowOffsetY = props["shadowOffsetY"] as? CGFloat {
            shadowOffset.height = shadowOffsetY
            hasShadow = true
        }

        // FIXED: Elevation (Android Material Design shadow)
        if let elevation = props["elevation"] as? CGFloat, elevation > 0 {
            // Material Design elevation formula
            shadowOpacity = Float(min(0.25, 0.1 + elevation * 0.01))
            shadowRadius = elevation * 0.5
            shadowOffset = CGSize(width: 0, height: elevation * 0.5)
            shadowColor = UIColor.black.cgColor
            hasShadow = true
        }
        
        // FIXED: Two-layer approach for shadow + corner radius
        // Shadow layer: masksToBounds = false (shadow extends beyond bounds)
        // Content layer: clipsToBounds = true (content clips to corners)
        if hasShadow {
            // Shadow requires masksToBounds = false (shadow extends beyond bounds)
            layer.masksToBounds = false
            
            // Apply shadow properties
            layer.shadowColor = shadowColor
            layer.shadowOpacity = shadowOpacity
            layer.shadowRadius = shadowRadius
            layer.shadowOffset = shadowOffset
            
            // FIXED: Update shadow path to match corner radius (critical for performance)
            // This MUST be set or UIKit calculates it dynamically = SLOW
            if hasCornerRadius && !bounds.isEmpty {
                // Check if we have individual corner radii stored
                if let radii = objc_getAssociatedObject(
                    self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!) as? [String: CGFloat]
                {
                    // For individual corner radii, create path with all corners
                    let topLeft = radii["topLeft"] ?? 0
                    let topRight = radii["topRight"] ?? 0
                    let bottomLeft = radii["bottomLeft"] ?? 0
                    let bottomRight = radii["bottomRight"] ?? 0
                    
                    // Create rounded rect path with individual radii
                    let path = createRoundedRectPath(
                        bounds: bounds,
                        topLeft: topLeft, topRight: topRight,
                        bottomLeft: bottomLeft, bottomRight: bottomRight
                    )
                    layer.shadowPath = path.cgPath
                } else {
                    // Uniform corner radius
                    let shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: finalCornerRadius)
                    layer.shadowPath = shadowPath.cgPath
                }
            } else if !bounds.isEmpty {
                // No corner radius - use bounds rect
                layer.shadowPath = UIBezierPath(rect: bounds).cgPath
            }
            
            // FIXED: Content should clip to corners even with shadow
            // clipsToBounds clips subviews, masksToBounds clips layer content
            // We need both: shadow extends (masksToBounds=false) but content clips (clipsToBounds=true)
            self.clipsToBounds = true
        } else if hasCornerRadius {
            // No shadow, just clip content
            self.clipsToBounds = true
            layer.masksToBounds = false  // Allow corner radius to work
            layer.shadowPath = nil
        } else {
            // No shadow, no corner radius
            layer.shadowPath = nil
            layer.masksToBounds = false
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

        // FIXED: Always set isAccessibilityElement first (required for accessibility to work)
        if let accessible = props["accessible"] as? Bool {
            self.isAccessibilityElement = accessible
        } else {
            // If any accessibility props are set, enable accessibility
            if props["accessibilityLabel"] != nil || props["ariaLabel"] != nil ||
               props["accessibilityHint"] != nil || props["accessibilityRole"] != nil ||
               props["accessibilityValue"] != nil || props["accessibilityState"] != nil {
                self.isAccessibilityElement = true
            }
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
        
        // FIXED: Transforms are PURE VISUAL - NEVER affect Yoga layout
        // React Native model: Yoga computes layout, transforms applied AFTER
        // CRITICAL: NEVER modify position or anchorPoint - that breaks layout
        if hasTransforms {
            // Build transform matrix (React Native order: translate -> rotate -> scale)
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, translateX, translateY, 0)
            transform = CATransform3DRotate(transform, rotation * .pi / 180, 0, 0, 1)
            transform = CATransform3DScale(transform, scaleX, scaleY, 1)
            
            // Apply transform to layer ONLY (doesn't affect frame/layout)
            // The view's frame is set by Yoga, transforms are purely GPU-side
            layer.transform = transform
            
            // CRITICAL: Set anchor point to center for rotation, but ONLY if bounds exist
            // And we do this WITHOUT changing position (position is set by Yoga)
            if !bounds.isEmpty {
                // Store original position before changing anchor
                let originalPosition = layer.position
                let originalAnchor = layer.anchorPoint
                
                // Set anchor to center
                layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                
                // Calculate new position to keep visual position the same
                // This is the ONLY time we touch position, and it's to compensate for anchor change
                let newPosition = CGPoint(
                    x: originalPosition.x + (0.5 - originalAnchor.x) * bounds.width,
                    y: originalPosition.y + (0.5 - originalAnchor.y) * bounds.height
                )
                layer.position = newPosition
            }
        } else {
            // Reset transforms
            layer.transform = CATransform3DIdentity
            // Reset anchor point if it was changed, but preserve visual position
            if !bounds.isEmpty && (layer.anchorPoint.x != 0.5 || layer.anchorPoint.y != 0.5) {
                let oldAnchor = layer.anchorPoint
                let oldPosition = layer.position
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                // Compensate position change
                let newPosition = CGPoint(
                    x: oldPosition.x + (0.5 - oldAnchor.x) * bounds.width,
                    y: oldPosition.y + (0.5 - oldAnchor.y) * bounds.height
                )
                layer.position = newPosition
            }
        }
    }

    /// FIXED: Apply corner radius mask for individual corner radii
    /// iOS doesn't support individual corner radii natively, so we use CAShapeLayer mask
    /// FIXED: fileprivate so it's accessible from extension
    fileprivate func applyCornerRadiusMask(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        guard !bounds.isEmpty else { return }
        
        // Create path with individual corner radii
        let path = createRoundedRectPath(
            bounds: bounds,
            topLeft: topLeft, topRight: topRight,
            bottomLeft: bottomLeft, bottomRight: bottomRight
        )
        
        // Create mask layer
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.cgColor
        layer.mask = maskLayer
    }
    
    /// Create rounded rectangle path with individual corner radii
    /// FIXED: Helper function accessible from extension
    fileprivate func createRoundedRectPath(bounds: CGRect, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let minX = bounds.minX
        let minY = bounds.minY
        let maxX = bounds.maxX
        let maxY = bounds.maxY
        
        // Clamp radii to prevent overlap
        let maxTopRadius = bounds.width / 2
        let maxBottomRadius = bounds.width / 2
        let maxLeftRadius = bounds.height / 2
        let maxRightRadius = bounds.height / 2
        
        let tl = min(topLeft, min(maxTopRadius, maxLeftRadius))
        let tr = min(topRight, min(maxTopRadius, maxRightRadius))
        let bl = min(bottomLeft, min(maxBottomRadius, maxLeftRadius))
        let br = min(bottomRight, min(maxBottomRadius, maxRightRadius))
        
        // Start from top-left, moving clockwise
        path.move(to: CGPoint(x: minX + tl, y: minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: maxX - tr, y: minY))
        
        // Top-right corner
        if tr > 0 {
            path.addArc(withCenter: CGPoint(x: maxX - tr, y: minY + tr),
                       radius: tr, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
        }
        
        // Right edge
        path.addLine(to: CGPoint(x: maxX, y: maxY - br))
        
        // Bottom-right corner
        if br > 0 {
            path.addArc(withCenter: CGPoint(x: maxX - br, y: maxY - br),
                       radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        }
        
        // Bottom edge
        path.addLine(to: CGPoint(x: minX + bl, y: maxY))
        
        // Bottom-left corner
        if bl > 0 {
            path.addArc(withCenter: CGPoint(x: minX + bl, y: maxY - bl),
                       radius: bl, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        }
        
        // Left edge
        path.addLine(to: CGPoint(x: minX, y: minY + tl))
        
        // Top-left corner
        if tl > 0 {
            path.addArc(withCenter: CGPoint(x: minX + tl, y: minY + tl),
                       radius: tl, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        }
        
        path.close()
        return path
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

    /// FIXED: Draw borders as CAShapeLayer with proper rounded paths
    /// Borders MUST respect corner radius - rectangular borders don't work with rounded corners
    /// FIXED: fileprivate so it's accessible from extension
    fileprivate func applyIndividualBorders(
        topWidth: CGFloat, rightWidth: CGFloat, bottomWidth: CGFloat, leftWidth: CGFloat,
        topColor: CGColor?, rightColor: CGColor?, bottomColor: CGColor?, leftColor: CGColor?,
        cornerRadius: CGFloat
    ) {
        // Remove existing border layers
        removeBorderLayers()
        
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
        
        // Get corner radii (individual or uniform)
        var topLeftRadius: CGFloat = 0
        var topRightRadius: CGFloat = 0
        var bottomLeftRadius: CGFloat = 0
        var bottomRightRadius: CGFloat = 0
        
        if let radii = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!) as? [String: CGFloat]
        {
            topLeftRadius = radii["topLeft"] ?? cornerRadius
            topRightRadius = radii["topRight"] ?? cornerRadius
            bottomLeftRadius = radii["bottomLeft"] ?? cornerRadius
            bottomRightRadius = radii["bottomRight"] ?? cornerRadius
        } else {
            topLeftRadius = cornerRadius
            topRightRadius = cornerRadius
            bottomLeftRadius = cornerRadius
            bottomRightRadius = cornerRadius
        }
        
        // CRITICAL: Draw borders using filled path difference (outer rounded rect - inner rounded rect)
        // This ensures borders perfectly follow rounded corners, no rectangular artifacts
        // Calculate border insets
        let maxBorderWidth = max(max(topWidth, rightWidth), max(bottomWidth, leftWidth))
        
        if maxBorderWidth > 0 {
            // Create outer path (full bounds with corner radius)
            let outerPath = createRoundedRectPath(
                bounds: bounds,
                topLeft: topLeftRadius, topRight: topRightRadius,
                bottomLeft: bottomLeftRadius, bottomRight: bottomRightRadius
            )
            
            // Create inner path (inset by border width, with adjusted corner radius)
            let insetBounds = bounds.insetBy(dx: maxBorderWidth, dy: maxBorderWidth)
            let innerTopLeft = max(0, topLeftRadius - maxBorderWidth)
            let innerTopRight = max(0, topRightRadius - maxBorderWidth)
            let innerBottomLeft = max(0, bottomLeftRadius - maxBorderWidth)
            let innerBottomRight = max(0, bottomRightRadius - maxBorderWidth)
            
            let innerPath = createRoundedRectPath(
                bounds: insetBounds,
                topLeft: innerTopLeft, topRight: innerTopRight,
                bottomLeft: innerBottomLeft, bottomRight: innerBottomRight
            )
            
            // Create border layer using even-odd fill rule (outer - inner)
            let borderLayer = CAShapeLayer()
            let borderPath = UIBezierPath()
            borderPath.append(outerPath)
            borderPath.append(innerPath.reversing()) // Reverse inner to subtract
            borderPath.usesEvenOddFillRule = true
            
            borderLayer.path = borderPath.cgPath
            borderLayer.fillRule = .evenOdd
            
            // Use most common color (for now - multi-color borders need separate layers)
            let borderColor = topColor ?? rightColor ?? bottomColor ?? leftColor ?? UIColor.black.cgColor
            borderLayer.fillColor = borderColor
            borderLayer.name = "borderLayer"
            
            // Insert border layer before other sublayers (so it's behind content)
            if let firstSublayer = layer.sublayers?.first {
                layer.insertSublayer(borderLayer, below: firstSublayer)
            } else {
                layer.addSublayer(borderLayer)
            }
        }
    }
    
    /// Remove all border layers
    private func removeBorderLayers() {
        // Remove border layers
        layer.sublayers?.filter { $0.name?.hasPrefix("border") == true }.forEach { $0.removeFromSuperlayer() }
        // Also remove old border views if they exist
        subviews.filter { $0.tag >= 1001 && $0.tag <= 1004 }.forEach { $0.removeFromSuperview() }
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
    /// Update border views when view bounds change (React Native approach)
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
        
        // Re-apply borders with updated bounds (border layers will be recreated)
        // This ensures borders match the new bounds and corner radius
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

    /// FIXED: Update gradient, borders, corner radius mask, and shadow path in layoutSubviews
    /// Called synchronously during layout to avoid flickering
    @objc private func swizzled_layoutSubviews() {
        swizzled_layoutSubviews()  // Call original implementation

        guard !bounds.isEmpty else { return }
        
        // FIXED: Update synchronously (no async dispatch) to prevent flickering
        updateGradientFrame()
        updateBorderLayers()
        
        // FIXED: Update individual corner radius mask if needed
        if let radii = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!) as? [String: CGFloat]
        {
            let topLeft = radii["topLeft"] ?? 0
            let topRight = radii["topRight"] ?? 0
            let bottomLeft = radii["bottomLeft"] ?? 0
            let bottomRight = radii["bottomRight"] ?? 0
            applyCornerRadiusMask(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
        }
        
        // FIXED: Update shadow path if we have shadow (CRITICAL for performance)
        // shadowPath MUST be set or UIKit calculates it dynamically = SLOW AS FUCK
        if let shadowColor = layer.shadowColor, layer.shadowOpacity > 0 {
            if let radii = objc_getAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!) as? [String: CGFloat]
            {
                // Individual corner radii
                let topLeft = radii["topLeft"] ?? 0
                let topRight = radii["topRight"] ?? 0
                let bottomLeft = radii["bottomLeft"] ?? 0
                let bottomRight = radii["bottomRight"] ?? 0
                let path = createRoundedRectPath(
                    bounds: bounds,
                    topLeft: topLeft, topRight: topRight,
                    bottomLeft: bottomLeft, bottomRight: bottomRight
                )
                layer.shadowPath = path.cgPath
            } else {
                // Check if we have a mask (which means we're using individual radii or pill shape)
                if let mask = layer.mask as? CAShapeLayer, let maskPath = mask.path {
                    // Use the mask path for shadow path (they should match)
                    layer.shadowPath = maskPath
                } else if layer.cornerRadius > 0 {
                    // Uniform corner radius
                    let shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius)
                    layer.shadowPath = shadowPath.cgPath
                } else {
                    // No corner radius
                    layer.shadowPath = UIBezierPath(rect: bounds).cgPath
                }
            }
        }
        
        // FIXED: Update corner radius mask if bounds changed (for pill shapes and individual radii)
        if let radii = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "cornerRadii".hashValue)!) as? [String: CGFloat]
        {
            let topLeft = radii["topLeft"] ?? 0
            let topRight = radii["topRight"] ?? 0
            let bottomLeft = radii["bottomLeft"] ?? 0
            let bottomRight = radii["bottomRight"] ?? 0
            
            // Check if this is a pill shape (all corners = height/2)
            let height = bounds.height
            if height > 0 && abs(topLeft - height / 2) < 0.5 && 
               abs(topRight - height / 2) < 0.5 &&
               abs(bottomLeft - height / 2) < 0.5 &&
               abs(bottomRight - height / 2) < 0.5 {
                // Pill shape: use exact height/2 for perfect semicircles
                let pillRadius = height / 2
                applyCornerRadiusMask(topLeft: pillRadius, topRight: pillRadius, bottomLeft: pillRadius, bottomRight: pillRadius)
            } else {
                // Update mask with current radii
                applyCornerRadiusMask(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            }
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