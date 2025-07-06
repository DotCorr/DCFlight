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
        // Debug log for applied props

        // CRITICAL FIX: Apply border radius FIRST before gradient to avoid override
        var hasCornerRadius = false
        var finalCornerRadius: CGFloat = 0
        var finalCornerMask: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]

        // Border Radius (Global)
        if let borderRadius = props["borderRadius"] as? CGFloat {
            layer.cornerRadius = borderRadius
            finalCornerRadius = borderRadius
            hasCornerRadius = true
            self.clipsToBounds = true  // Enable clipping when border radius is set
        }

        // Per-corner Radius (Overrides global borderRadius if specific corners are set)
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

        // Border color and width - Apply only if specified
        if let borderColorStr = props["borderColor"] as? String {
            layer.borderColor = ColorUtilities.color(fromHexString: borderColorStr)?.cgColor
        }

        if let borderWidth = props["borderWidth"] as? CGFloat {
            layer.borderWidth = borderWidth
            // Ensure content is clipped to avoid overlap
            self.clipsToBounds = true
        }

        // Background color - Apply only if specified
        if let backgroundColorStr = props["backgroundColor"] as? String {
            self.backgroundColor = ColorUtilities.color(fromHexString: backgroundColorStr)
        }

        // CRITICAL FIX: Apply gradient AFTER border radius and ensure it respects corner radius
        if let gradientData = props["backgroundGradient"] as? [String: Any] {
            // Defer gradient application to ensure proper layering and corner radius respect
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.applyGradientBackground(
                    gradientData: gradientData,
                    cornerRadius: hasCornerRadius ? finalCornerRadius : nil,
                    cornerMask: hasCornerRadius ? finalCornerMask : nil)
            }
        }

        // Opacity (Alpha) - Apply only if specified
        if let opacity = props["opacity"] as? CGFloat {
            self.alpha = opacity
        }

        // Shadow properties - Apply only if specified
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

        // CRITICAL FIX: Handle masksToBounds conflict between shadows and corner radius
        if needsMasksToBoundsFalse && hasCornerRadius {
            // We have both shadows and corner radius - use a container approach
            layer.masksToBounds = false  // Allow shadows
            // The gradient layer will handle corner radius clipping
        } else if needsMasksToBoundsFalse {
            layer.masksToBounds = false
        }
        // If only corner radius, clipsToBounds is already set above

        // Transform handling removed - now handled by the layout system instead

        // Hit Slop - Apply only if specified (extends touch area)
        if let hitSlopMap = props["hitSlop"] as? [String: Any] {
            var hitSlopInsets = UIEdgeInsets.zero

            if let top = hitSlopMap["top"] as? CGFloat {
                hitSlopInsets.top = -top  // Negative to expand touch area
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
            objc_setAssociatedObject(
                self, UnsafeRawPointer(bitPattern: "hitSlop".hashValue)!,
                NSValue(uiEdgeInsets: hitSlopInsets), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

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
                // Handle masksToBounds conflict for elevation as well
                if hasCornerRadius {
                    layer.masksToBounds = false
                } else {
                    layer.masksToBounds = false
                }
            }
        }

        // Accessibility properties - Apply only if specified
        if let accessible = props["accessible"] as? Bool {
            self.isAccessibilityElement = accessible
        }

        if let label = props["accessibilityLabel"] as? String {
            self.accessibilityLabel = label
        }

        if let testID = props["testID"] as? String {
            self.accessibilityIdentifier = testID  // Used for view lookup and testing
        }

        // Pointer Events - Apply only if specified
        if let pointerEvents = props["pointerEvents"] as? String {
            switch pointerEvents {
            case "none":
                self.isUserInteractionEnabled = false
            case "box-none":
                // View itself doesn't receive events, but children can.
                self.isUserInteractionEnabled = false  // Correct for the view itself
            case "box-only":
                // View receives events, children do not (UIKit default handles this if children are disabled).
                self.isUserInteractionEnabled = true
            case "auto", "all":
                fallthrough
            default:
                self.isUserInteractionEnabled = true
            }
        }
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

    /// CRITICAL FIX: Apply gradient background with proper corner radius support
    private func applyGradientBackground(
        gradientData: [String: Any], cornerRadius: CGFloat? = nil, cornerMask: CACornerMask? = nil
    ) {
        // CRITICAL FIX: Ensure we have valid bounds before applying gradient
        guard !bounds.isEmpty else {
            // Store gradient data for later application when bounds are available
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

        // Remove any existing gradient layer
        let existingGradientLayers = layer.sublayers?.filter { $0 is CAGradientLayer } ?? []
        for gradientLayer in existingGradientLayers {
            gradientLayer.removeFromSuperlayer()
        }

        guard let type = gradientData["type"] as? String,
            let colorsArray = gradientData["colors"] as? [String]
        else {
            return
        }

        // Convert color strings to CGColors
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

        // CRITICAL FIX: Apply corner radius to gradient layer if needed
        if let cornerRadius = cornerRadius {
            gradientLayer.cornerRadius = cornerRadius
            if let cornerMask = cornerMask {
                gradientLayer.maskedCorners = cornerMask
            }
            // Don't set masksToBounds on the gradient layer - it will clip incorrectly
        }

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

        default:
            print("⚠️ Unknown gradient type: \(type)")
            return
        }

        // Create a name for the gradient layer to identify it
        gradientLayer.name = "backgroundGradient"

        // CRITICAL FIX: Ensure gradient is truly behind all content
        // Insert at index 0 ONLY if there are no child view layers yet
        let hasChildLayers = layer.sublayers?.contains { $0.name != "backgroundGradient" } ?? false

        if hasChildLayers {
            // If child layers exist, insert at the very beginning
            layer.insertSublayer(gradientLayer, at: 0)
        } else {
            // If no child layers yet, add as first sublayer
            layer.addSublayer(gradientLayer)
        }

        print(
            "✅ Applied gradient: \(type) with \(cgColors.count) colors at frame \(bounds) with cornerRadius: \(cornerRadius ?? 0)"
        )

        // Store gradient layer for later updates
        objc_setAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!,
            gradientLayer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Store corner radius info for updates
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

        // Clear pending gradient data since we've applied it
        objc_setAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "pendingGradientData".hashValue)!,
            nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// UIView extension for gradient management
extension UIView {
    /// Update gradient layer frame when view bounds change
    @objc public func updateGradientFrame() {
        guard !bounds.isEmpty else { return }  // Skip empty bounds

        // CRITICAL FIX: Check for pending gradient data first
        if let pendingData = objc_getAssociatedObject(
            self, UnsafeRawPointer(bitPattern: "pendingGradientData".hashValue)!) as? [String: Any]
        {
            // Apply pending gradient now that we have bounds
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
            // Only update if frame has actually changed
            if gradientLayer.frame != bounds {
                CATransaction.begin()
                CATransaction.setDisableActions(true)  // Prevent animation
                gradientLayer.frame = bounds

                // CRITICAL FIX: Update corner radius on gradient layer during frame update
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

                // CRITICAL FIX: Ensure gradient stays at the back after frame update
                if let sublayers = layer.sublayers,
                    let gradientIndex = sublayers.firstIndex(of: gradientLayer),
                    gradientIndex > 0
                {
                    // Move gradient to the back if it's not already there
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

    /// Override layoutSubviews to ensure gradient frames are updated
    @objc private func swizzled_layoutSubviews() {
        swizzled_layoutSubviews()  // Call original implementation

        // CRITICAL FIX: Only update gradient frame AFTER subviews are laid out
        // This ensures child components are positioned before gradient frame updates
        DispatchQueue.main.async { [weak self] in
            self?.updateGradientFrame()
        }
    }
}

// Method swizzling to automatically update gradient frames
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

    // This will ensure the swizzling is performed once when the app starts
    public static func performSwizzling() {
        _ = swizzleLayoutSubviews
    }
}

// MARK: - CACornerMask Extension for convenience
extension CACornerMask {
    static let allCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
    ]
}
