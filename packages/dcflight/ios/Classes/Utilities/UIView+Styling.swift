/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit

// UIView extension for generic style application
extension UIView {
    /// Apply common style properties to this view, driven only by explicit props.
    public func applyStyles(props: [String: Any]) {
        // Apply background gradient first - it should be behind everything else
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            applyGradientBackground(gradientData: gradientData)
        }
        
        // Debug log for applied props
        // print("🎨 Applying generic styles to \(type(of: self)) [ID: \(self.accessibilityIdentifier ?? "nil")] : \(props.keys.joined(separator: ", "))")

        // Border Radius (Global)
        if let borderRadius = props["borderRadius"] as? CGFloat {
            layer.cornerRadius = borderRadius
            self.clipsToBounds = true // Enable clipping when border radius is set
        }

        // Per-corner Radius (Overrides global borderRadius if specific corners are set)
        var cornerMask: CACornerMask = []
        var customRadius: CGFloat? = nil // Use the first specified radius

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
            if let radius = customRadius {
                layer.cornerRadius = radius // Apply the radius if specific corners are masked
                self.clipsToBounds = true // Enable clipping for rounded corners
            }
        }
        // Remove reset logic - only apply if explicitly provided


        // Border color and width - Apply only if specified
        // Using inset border approach to match web/Flutter behavior
        if let borderColorStr = props["borderColor"] as? String {
            layer.borderColor = ColorUtilities.color(fromHexString: borderColorStr)?.cgColor
        }
        // No default reset for borderColor

        if let borderWidth = props["borderWidth"] as? CGFloat {
            layer.borderWidth = borderWidth
            // Ensure content is clipped to avoid overlap
            self.clipsToBounds = true
        }
        // No default reset for borderWidth


        // Background color - Apply only if specified
        if let backgroundColorStr = props["backgroundColor"] as? String {
            self.backgroundColor = ColorUtilities.color(fromHexString: backgroundColorStr)
            // print("   - Applied backgroundColor: \(backgroundColorStr)")
        }
        
        // Background gradient - Apply only if specified
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            applyGradientBackground(gradientData: gradientData)
        }
        // Remove adaptive reset logic - only apply if explicitly provided


        // Opacity (Alpha) - Apply only if specified
        if let opacity = props["opacity"] as? CGFloat {
            self.alpha = opacity
            // print("   - Applied opacity: \(opacity)")
        }
        // No default reset for alpha


        // Shadow properties - Apply only if specified
        var needsMasksToBoundsFalse = false // Track if shadow requires masksToBounds = false
        if let shadowColorStr = props["shadowColor"] as? String {
            layer.shadowColor = ColorUtilities.color(fromHexString: shadowColorStr)?.cgColor
            needsMasksToBoundsFalse = true
        }
        // No default reset

        if let shadowOpacity = props["shadowOpacity"] as? Float {
            layer.shadowOpacity = shadowOpacity
            needsMasksToBoundsFalse = true
        }
        // No default reset

        if let shadowRadius = props["shadowRadius"] as? CGFloat {
            layer.shadowRadius = shadowRadius
            needsMasksToBoundsFalse = true
        }
        // No default reset

        // Handle shadow offset - apply individual values or both
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
        // No default reset

        // Set masksToBounds based *only* on whether shadow properties were applied
        if needsMasksToBoundsFalse {
            layer.masksToBounds = false
        }
        // IMPORTANT: Do NOT set masksToBounds = true here. Components (like those with cornerRadius)
        // might need it to be false even without shadows, or true even with shadows (if clipping content).
        // The component's updateView should manage masksToBounds/clipsToBounds.


        // Transform handling removed - now handled by the layout system instead

        // Hit Slop - Apply only if specified (extends touch area)
        if let hitSlopMap = props["hitSlop"] as? [String: Any] {
            var hitSlopInsets = UIEdgeInsets.zero
            
            if let top = hitSlopMap["top"] as? CGFloat {
                hitSlopInsets.top = -top // Negative to expand touch area
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
            
            // Store hit slop for use in hit testing (requires custom hit test implementation)
            objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: "hitSlop".hashValue)!, 
                                   NSValue(uiEdgeInsets: hitSlopInsets), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        // No default reset for hit slop

        // Elevation (Android-style) - Convert to shadow for iOS
        if let elevation = props["elevation"] as? CGFloat {
            // Convert elevation to appropriate shadow settings for iOS
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
        // No default reset for elevation

        // Apply masksToBounds setting if needed for elevation shadows
        if needsMasksToBoundsFalse {
            layer.masksToBounds = false
        }


        // Accessibility properties - Apply only if specified
        if let accessible = props["accessible"] as? Bool {
            self.isAccessibilityElement = accessible
        }
        // No default setting

        if let label = props["accessibilityLabel"] as? String {
            self.accessibilityLabel = label
        }

        if let testID = props["testID"] as? String {
            self.accessibilityIdentifier = testID // Used for view lookup and testing
        }

        // Pointer Events - Apply only if specified
        if let pointerEvents = props["pointerEvents"] as? String {
            switch pointerEvents {
            case "none":
                self.isUserInteractionEnabled = false
                // print("   - Applied pointerEvents: none")
            case "box-none":
                // View itself doesn't receive events, but children can.
                self.isUserInteractionEnabled = false // Correct for the view itself
                // print("   - Applied pointerEvents: box-none (view interaction disabled)")
            case "box-only":
                // View receives events, children do not (UIKit default handles this if children are disabled).
                self.isUserInteractionEnabled = true
                // print("   - Applied pointerEvents: box-only (view interaction enabled)")
            case "auto", "all":
                fallthrough
            default:
                self.isUserInteractionEnabled = true
                // print("   - Applied pointerEvents: auto/all (view interaction enabled)")
            }
        }
        // No default setting for isUserInteractionEnabled - rely on UIKit defaults.
    }
    
    /// Apply adaptive background color based on view type and iOS version
    private func applyAdaptiveBackgroundColor() {
        // Different views have different appropriate adaptive backgrounds
        if self is UILabel {
            // Text views typically have transparent backgrounds
            self.backgroundColor = UIColor.clear
        } else if self is UIImageView {
            // Image views typically have transparent backgrounds unless they need placeholders
            if #available(iOS 13.0, *) {
                self.backgroundColor = UIColor.systemBackground
            } else {
                self.backgroundColor = UIColor.white
            }
        } else if self is UICollectionView || self is UITableView || self is UIScrollView {
            // List/scroll views should use system background
            if #available(iOS 13.0, *) {
                self.backgroundColor = UIColor.systemBackground
            } else {
                self.backgroundColor = UIColor.white
            }
        } else {
            // Default view background
            if #available(iOS 13.0, *) {
                self.backgroundColor = UIColor.systemBackground
            } else {
                self.backgroundColor = UIColor.white
            }
        }
    }
    
    /// Apply gradient background to the view
    private func applyGradientBackground(gradientData: [String: Any]) {
        // Debug log to trace gradient application
        print("🎨 Applying gradient background with data: \(gradientData)")
        
        // Remove any existing gradient layer
        let existingGradientLayers = layer.sublayers?.filter { $0 is CAGradientLayer } ?? []
        for gradientLayer in existingGradientLayers {
            gradientLayer.removeFromSuperlayer()
        }
        
        guard let type = gradientData["type"] as? String,
              let colorsArray = gradientData["colors"] as? [String] else {
            return
        }
        
        // Convert color strings to CGColors
        let cgColors: [CGColor] = colorsArray.compactMap { colorString in
            let color = ColorUtilities.color(fromHexString: colorString)?.cgColor
            if color == nil {
                print("⚠️ Warning: Failed to parse color: \(colorString)")
            }
            return color
        }
        
        guard cgColors.count >= 2 else {
            print("⚠️ Warning: Gradient needs at least 2 valid colors, got \(cgColors.count)")
            return
        }
        
        print("✅ Creating gradient with \(cgColors.count) colors")
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = cgColors
        gradientLayer.frame = bounds
        
        // Set gradient stops if provided
        if let stops = gradientData["stops"] as? [Double] {
            gradientLayer.locations = stops.map { NSNumber(value: $0) }
        }
        
        // Configure gradient based on type
        switch type {
        case "linear":
            // Linear gradient configuration
            let startX = gradientData["startX"] as? Double ?? 0.0
            let startY = gradientData["startY"] as? Double ?? 0.0
            let endX = gradientData["endX"] as? Double ?? 1.0
            let endY = gradientData["endY"] as? Double ?? 1.0
            
            gradientLayer.startPoint = CGPoint(x: startX, y: startY)
            gradientLayer.endPoint = CGPoint(x: endX, y: endY)
            gradientLayer.type = .axial
            
            print("📐 Linear gradient: start(\(startX), \(startY)) to end(\(endX), \(endY))")
            
        case "radial":
            // Radial gradient configuration
            let centerX = gradientData["centerX"] as? Double ?? 0.5
            let centerY = gradientData["centerY"] as? Double ?? 0.5
            let radius = gradientData["radius"] as? Double ?? 0.5
            
            gradientLayer.type = .radial
            gradientLayer.startPoint = CGPoint(x: centerX, y: centerY)
            // For radial gradients, endPoint determines the radius
            let radiusX = centerX + radius
            let radiusY = centerY + radius
            gradientLayer.endPoint = CGPoint(x: min(radiusX, 1.0), y: min(radiusY, 1.0))
            
            print("📐 Radial gradient: center(\(centerX), \(centerY)), radius: \(radius)")
            
        default:
            print("⚠️ Warning: Unsupported gradient type: \(type)")
            return
        }
        
        // Set frame and insert at the back
        gradientLayer.frame = bounds
        
        // Create a name for the gradient layer to identify it
        gradientLayer.name = "backgroundGradient"
        
        // Insert at index 0 to be behind all other content
        layer.insertSublayer(gradientLayer, at: 0)
        
        print("✅ Gradient layer added with frame: \(gradientLayer.frame)")
        
        // Store gradient layer for later updates
        objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!, 
                               gradientLayer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// UIView extension for gradient management
extension UIView {
    /// Update gradient layer frame when view bounds change
    @objc public func updateGradientFrame() {
        guard !bounds.isEmpty else { return } // Skip empty bounds
        
        if let gradientLayer = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!) as? CAGradientLayer {
            // Only update if frame has actually changed
            if gradientLayer.frame != bounds {
                CATransaction.begin()
                CATransaction.setDisableActions(true) // Prevent animation
                gradientLayer.frame = bounds
                CATransaction.commit()
                
                print("🔄 Updated gradient layer frame to \(bounds)")
            }
        }
    }
    
    /// Override layoutSubviews to ensure gradient frames are updated
    @objc private func swizzled_layoutSubviews() {
        swizzled_layoutSubviews() // Call original implementation
        updateGradientFrame()
    }
}

// Method swizzling to automatically update gradient frames
extension UIView {
    static let swizzleLayoutSubviews: Void = {
        let originalSelector = #selector(UIView.layoutSubviews)
        let swizzledSelector = #selector(UIView.swizzled_layoutSubviews)
        
        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    // This will ensure the swizzling is performed once when the app starts
    public static func performSwizzling() {
        _ = swizzleLayoutSubviews
    }
}
