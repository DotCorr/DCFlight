/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import ObjectiveC.runtime

/// Maps style properties directly to native view properties.
///
/// This matches the standard model's approach where each style property
/// is directly mapped to a native view property setter, ensuring consistent
/// behavior and optimal performance.
///
/// **Usage:**
/// ```swift
/// let props = ["borderRadius": 8.0, "borderWidth": 2.0, "backgroundColor": "dcf:#0000ff"]
/// DCFViewPropertyMapper.applyProperties(to: view, props: props)
/// ```
class DCFViewPropertyMapper {
    
    /// Apply style properties directly to a view using property setters.
    ///
    /// Each property is mapped directly to its corresponding native view property,
    /// matching the standard model's direct property mapping approach.
    ///
    /// - Parameters:
    ///   - view: The view to apply properties to
    ///   - props: Dictionary of style properties
    static func applyProperties(to view: UIView, props: [String: Any]) {
        // Resolve style ID if present
        let resolvedProps = resolveStyleProps(props: props)
        
        // Apply each property directly using setters
        applyBorderRadius(to: view, props: resolvedProps)
        applyBorderWidth(to: view, props: resolvedProps)
        applyBorderColor(to: view, props: resolvedProps)
        applyBorderStyle(to: view, props: resolvedProps)
        applyBackgroundColor(to: view, props: resolvedProps)
        applyBackgroundGradient(to: view, props: resolvedProps)
        applyOpacity(to: view, props: resolvedProps)
        applyShadow(to: view, props: resolvedProps)
        applyElevation(to: view, props: resolvedProps)
        applyHitSlop(to: view, props: resolvedProps)
        applyAccessibility(to: view, props: resolvedProps)
        applyTransform(to: view, props: resolvedProps)
    }
    
    /// Helper to safely set a property on DCFView using runtime
    private static func safeSetValue(_ value: Any, forKey key: String, on view: UIView) {
        // Check if view responds to the setter selector before calling it
        let setterName = "set\(key.prefix(1).uppercased())\(key.dropFirst()):"
        let setter = NSSelectorFromString(setterName)
        
        guard view.responds(to: setter) else {
            // Property doesn't exist - ignore
            return
        }
        
        // Use Objective-C runtime to call the setter directly
        // This avoids KVC issues with CGColorRef and other non-object types
        let method = class_getInstanceMethod(type(of: view), setter)
        guard let methodImp = method else {
            return
        }
        
        // Get the method implementation
        let implementation = method_getImplementation(methodImp)
        
        // Call the setter based on the value type
        // Check for CGColor - use type check to avoid conditional downcast warning
        // When value is already CGColor (from color.cgColor), the cast will always succeed
        if value is CGColor {
            // For CGColorRef properties - use objc_msgSend directly
            let cgColor = value as! CGColor // Safe: we just checked the type
            typealias CGColorSetter = @convention(c) (AnyObject, Selector, CGColor) -> Void
            let setterFunc = unsafeBitCast(implementation, to: CGColorSetter.self)
            setterFunc(view, setter, cgColor)
        } else if let number = value as? NSNumber {
            // For CGFloat properties
            let cgFloatValue = CGFloat(truncating: number)
            typealias CGFloatSetter = @convention(c) (AnyObject, Selector, CGFloat) -> Void
            let setterFunc = unsafeBitCast(implementation, to: CGFloatSetter.self)
            setterFunc(view, setter, cgFloatValue)
        } else if let string = value as? String {
            // For NSString properties
            typealias StringSetter = @convention(c) (AnyObject, Selector, String) -> Void
            let setterFunc = unsafeBitCast(implementation, to: StringSetter.self)
            setterFunc(view, setter, string)
        } else if let color = value as? UIColor {
            // For UIColor properties
            typealias ColorSetter = @convention(c) (AnyObject, Selector, UIColor) -> Void
            let setterFunc = unsafeBitCast(implementation, to: ColorSetter.self)
            setterFunc(view, setter, color)
        } else {
            // Don't use KVC fallback for CGColorRef properties - they're not KVC-compliant
            // If we get here, the property type is unknown and we should skip it
            let valueTypeName = String(describing: type(of: value))
            print("⚠️ DCFViewPropertyMapper: Unknown value type '\(valueTypeName)' for key '\(key)' - skipping")
        }
    }
    
    // MARK: - Border Radius
    
    /// Apply border radius properties directly to view.
    ///
    /// Maps borderRadius and individual corner radii to native properties.
    private static func applyBorderRadius(to view: UIView, props: [String: Any]) {
        // Check if view is DCFView by checking if it responds to DCFView setters
        let isDCFView = view.responds(to: NSSelectorFromString("setBorderRadius:"))
        
        if isDCFView {
            // Use safe property setting
            if let borderRadius = props["borderRadius"] as? CGFloat {
                safeSetValue(borderRadius, forKey: "borderRadius", on: view)
            }
            if let topLeft = props["borderTopLeftRadius"] as? CGFloat {
                safeSetValue(topLeft, forKey: "borderTopLeftRadius", on: view)
            }
            if let topRight = props["borderTopRightRadius"] as? CGFloat {
                safeSetValue(topRight, forKey: "borderTopRightRadius", on: view)
            }
            if let bottomLeft = props["borderBottomLeftRadius"] as? CGFloat {
                safeSetValue(bottomLeft, forKey: "borderBottomLeftRadius", on: view)
            }
            if let bottomRight = props["borderBottomRightRadius"] as? CGFloat {
                safeSetValue(bottomRight, forKey: "borderBottomRightRadius", on: view)
            }
        } else {
            // Fallback for regular UIView - use layer properties
            if let borderRadius = props["borderRadius"] as? CGFloat, borderRadius > 0 {
                view.layer.cornerRadius = borderRadius
                view.clipsToBounds = true
            }
        }
    }
    
    // MARK: - Border Width
    
    /// Apply border width properties directly to view.
    ///
    /// Maps borderWidth and individual side widths to native properties.
    private static func applyBorderWidth(to view: UIView, props: [String: Any]) {
        let isDCFView = view.responds(to: NSSelectorFromString("setBorderWidth:"))
        
        if isDCFView {
            // Use safe property setting
            if let borderWidth = props["borderWidth"] as? CGFloat {
                safeSetValue(borderWidth, forKey: "borderWidth", on: view)
            }
            if let topWidth = props["borderTopWidth"] as? CGFloat {
                safeSetValue(topWidth, forKey: "borderTopWidth", on: view)
            }
            if let rightWidth = props["borderRightWidth"] as? CGFloat {
                safeSetValue(rightWidth, forKey: "borderRightWidth", on: view)
            }
            if let bottomWidth = props["borderBottomWidth"] as? CGFloat {
                safeSetValue(bottomWidth, forKey: "borderBottomWidth", on: view)
            }
            if let leftWidth = props["borderLeftWidth"] as? CGFloat {
                safeSetValue(leftWidth, forKey: "borderLeftWidth", on: view)
            }
        } else {
            // Fallback for regular UIView
            if let borderWidth = props["borderWidth"] as? CGFloat, borderWidth > 0 {
                view.layer.borderWidth = borderWidth
            }
        }
    }
    
    // MARK: - Border Color
    
    /// Apply border color properties directly to view.
    ///
    /// Maps borderColor and individual side colors to native properties.
    private static func applyBorderColor(to view: UIView, props: [String: Any]) {
        let isDCFView = view.responds(to: NSSelectorFromString("setBorderColor:"))
        
        if isDCFView {
            // Use safe property setting with CGColorRef
            if let borderColorStr = props["borderColor"] as? String,
               let color = ColorUtilities.color(fromHexString: borderColorStr) {
                safeSetValue(color.cgColor, forKey: "borderColor", on: view)
            }
            if let topColorStr = props["borderTopColor"] as? String,
               let color = ColorUtilities.color(fromHexString: topColorStr) {
                safeSetValue(color.cgColor, forKey: "borderTopColor", on: view)
            }
            if let rightColorStr = props["borderRightColor"] as? String,
               let color = ColorUtilities.color(fromHexString: rightColorStr) {
                safeSetValue(color.cgColor, forKey: "borderRightColor", on: view)
            }
            if let bottomColorStr = props["borderBottomColor"] as? String,
               let color = ColorUtilities.color(fromHexString: bottomColorStr) {
                safeSetValue(color.cgColor, forKey: "borderBottomColor", on: view)
            }
            if let leftColorStr = props["borderLeftColor"] as? String,
               let color = ColorUtilities.color(fromHexString: leftColorStr) {
                safeSetValue(color.cgColor, forKey: "borderLeftColor", on: view)
            }
        } else {
            // Fallback for regular UIView
            if let borderColorStr = props["borderColor"] as? String,
               let color = ColorUtilities.color(fromHexString: borderColorStr) {
                view.layer.borderColor = color.cgColor
            }
        }
    }
    
    // MARK: - Border Style
    
    /// Apply border style property directly to view.
    private static func applyBorderStyle(to view: UIView, props: [String: Any]) {
        let isDCFView = view.responds(to: NSSelectorFromString("setBorderStyle:"))
        
        if isDCFView, let borderStyle = props["borderStyle"] as? String {
            safeSetValue(borderStyle, forKey: "borderStyle", on: view)
        }
    }
    
    // MARK: - Background Color
    
    /// Apply background color property directly to view.
    ///
    /// Maps backgroundColor to native view property.
    private static func applyBackgroundColor(to view: UIView, props: [String: Any]) {
        // Only apply if no gradient is present (gradient takes precedence)
        guard props["backgroundGradient"] == nil else {
            // Gradient exists - clear backgroundColor to prevent edge aliasing
            view.backgroundColor = .clear
            let isDCFView = view.responds(to: NSSelectorFromString("setDcfBackgroundColor:"))
            if isDCFView {
                safeSetValue(UIColor.clear, forKey: "dcfBackgroundColor", on: view)
            }
            return
        }
        
        // Handle semantic colors: primaryColor, secondaryColor, tertiaryColor, accentColor
        // These are sent as processed color strings from Dart side
        var backgroundColorStr = props["backgroundColor"] as? String
        
        // Check semantic colors if backgroundColor not explicitly set
        if backgroundColorStr == nil {
            if let primaryColor = props["primaryColor"] as? String {
                backgroundColorStr = primaryColor
            } else if let accentColor = props["accentColor"] as? String {
                backgroundColorStr = accentColor
            }
        }
        
        if let colorStr = backgroundColorStr,
           let color = ColorUtilities.color(fromHexString: colorStr) {
            view.backgroundColor = color
            let isDCFView = view.responds(to: NSSelectorFromString("setDcfBackgroundColor:"))
            if isDCFView {
                safeSetValue(color, forKey: "dcfBackgroundColor", on: view)
            }
        }
    }
    
    // MARK: - Background Gradient
    
    /// Apply background gradient property directly to view.
    ///
    /// Creates a CAGradientLayer and applies it to the view.
    private static func applyBackgroundGradient(to view: UIView, props: [String: Any]) {
        guard let gradientData = props["backgroundGradient"] as? [String: Any] else {
            return
        }
        
        // 🔥 PERFORMANCE FIX: Check if gradient data has actually changed
        // This prevents destroying and recreating layers 60 times a second during typing
        let lastProps = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "lastGradientProps".hashValue)!) as? [String: Any]
        if let last = lastProps, NSDictionary(dictionary: last).isEqual(to: gradientData) {
            return // Data hasn't changed, skip expensive work
        }
        objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "lastGradientProps".hashValue)!, gradientData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Clear backgroundColor when gradient exists
        view.backgroundColor = .clear
        let isDCFView = view.responds(to: NSSelectorFromString("setDcfBackgroundColor:"))
        if isDCFView {
            safeSetValue(UIColor.clear, forKey: "dcfBackgroundColor", on: view)
        }
        
        // Remove existing gradient layer if present
        if let existingGradient = view.layer.sublayers?.first(where: { $0 is CAGradientLayer }) {
            existingGradient.removeFromSuperlayer()
        }
        
        // Parse gradient data
        guard let type = gradientData["type"] as? String,
              let colors = gradientData["colors"] as? [String],
              !colors.isEmpty else {
            return
        }
        
        // Convert color strings to CGColor
        let cgColors = colors.compactMap { colorStr -> CGColor? in
            return ColorUtilities.color(fromHexString: colorStr)?.cgColor
        }
        
        guard !cgColors.isEmpty else {
            return
        }
        
        // Create gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = cgColors
        gradientLayer.frame = view.bounds
        
        // Ensure gradient layer is visible and properly configured
        gradientLayer.isHidden = false
        gradientLayer.opacity = 1.0
        
        // Handle gradient direction
        if type == "linear" {
            let startX = (gradientData["startX"] as? CGFloat) ?? 0.0
            let startY = (gradientData["startY"] as? CGFloat) ?? 0.0
            let endX = (gradientData["endX"] as? CGFloat) ?? 1.0
            let endY = (gradientData["endY"] as? CGFloat) ?? 1.0
            
            gradientLayer.startPoint = CGPoint(x: startX, y: startY)
            gradientLayer.endPoint = CGPoint(x: endX, y: endY)
        } else if type == "radial" {
            // Radial gradient - calculate endPoint to reach furthest corner
            let centerX = (gradientData["centerX"] as? CGFloat) ?? 0.5
            let centerY = (gradientData["centerY"] as? CGFloat) ?? 0.5
            let radius = (gradientData["radius"] as? CGFloat) ?? 0.5
            
            // Calculate endPoint based on diagonal (Pythagorean theorem)
            // For a radius of 0.5, the gradient should reach the furthest corner
            let width = max(view.bounds.width, 1.0) // Avoid division by zero
            let height = max(view.bounds.height, 1.0)
            
            // Calculate distance from center to furthest corner
            let centerXInPixels = centerX * width
            let centerYInPixels = centerY * height
            
            // Find furthest corner distance
            let corners = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: width, y: 0),
                CGPoint(x: 0, y: height),
                CGPoint(x: width, y: height)
            ]
            let maxDistance = corners.map { corner in
                let dx = corner.x - centerXInPixels
                let dy = corner.y - centerYInPixels
                return sqrt(dx * dx + dy * dy)
            }.max() ?? sqrt(width * width + height * height)
            
            // Scale radius to reach furthest corner
            // If radius is 0.5, it should reach 50% of maxDistance
            // For a full fill, radius of 0.5 should reach the edge
            let radiusInPixels = radius * maxDistance * 2.0
            
            // Convert to unit coordinates (normalized 0-1)
            let endX = centerX + (radiusInPixels / width)
            let endY = centerY + (radiusInPixels / height)
            
            gradientLayer.startPoint = CGPoint(x: centerX, y: centerY)
            gradientLayer.endPoint = CGPoint(x: endX, y: endY)
        }
        
        // Handle color stops
        if let stops = gradientData["stops"] as? [CGFloat], stops.count == cgColors.count {
            gradientLayer.locations = stops.map { NSNumber(value: Float($0)) }
        }
        
        // Insert gradient layer at bottom (index 0)
        // CRITICAL: Insert before any other sublayers to ensure it's behind content
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // CRITICAL: Ensure the gradient layer is behind all subviews
        // Set zPosition to be behind everything
        gradientLayer.zPosition = -1
        
        // Store gradient layer reference for frame updates
        // Use a stable key that can be retrieved in layoutSubviews
        let gradientKey = UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!
        objc_setAssociatedObject(
            view,
            gradientKey,
            gradientLayer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Also store using a string key for easier retrieval in Objective-C
        let stringKey = "gradientLayer" as NSString
        objc_setAssociatedObject(
            view,
            Unmanaged.passUnretained(stringKey).toOpaque(),
            gradientLayer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Update frame immediately - but if bounds are zero, it will be updated in layoutSubviews
        if !view.bounds.isEmpty {
            gradientLayer.frame = view.bounds
        } else {
            // Bounds are zero - set a placeholder frame that will be updated in layoutSubviews
            gradientLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
    }
    
    // MARK: - Opacity
    
    /// Apply opacity property directly to view.
    ///
    /// Maps opacity to UIView.alpha (direct property mapping).
    private static func applyOpacity(to view: UIView, props: [String: Any]) {
        if let opacity = props["opacity"] as? CGFloat {
            view.alpha = opacity
        }
    }
    
    // MARK: - Shadow
    
    /// Apply shadow properties directly to view layer.
    ///
    /// Maps shadow properties directly to CALayer properties.
    private static func applyShadow(to view: UIView, props: [String: Any]) {
        let layer = view.layer
        
        if let shadowColorStr = props["shadowColor"] as? String,
           let color = ColorUtilities.color(fromHexString: shadowColorStr) {
            layer.shadowColor = color.cgColor
        }
        
        if let shadowOpacity = props["shadowOpacity"] as? Float {
            layer.shadowOpacity = shadowOpacity
        }
        
        if let shadowRadius = props["shadowRadius"] as? CGFloat {
            layer.shadowRadius = shadowRadius
        }
        
        var shadowOffset = layer.shadowOffset
        if let shadowOffsetX = props["shadowOffsetX"] as? CGFloat {
            shadowOffset.width = shadowOffsetX
        }
        if let shadowOffsetY = props["shadowOffsetY"] as? CGFloat {
            shadowOffset.height = shadowOffsetY
        }
        layer.shadowOffset = shadowOffset
        
        // Shadow requires masksToBounds = false
        if layer.shadowOpacity > 0 && layer.shadowColor != nil {
            layer.masksToBounds = false
        }
    }
    
    // MARK: - Elevation
    
    /// Apply elevation property (Android Material Design).
    ///
    /// Converts elevation to shadow properties on iOS.
    private static func applyElevation(to view: UIView, props: [String: Any]) {
        if let elevation = props["elevation"] as? CGFloat, elevation > 0 {
            // Material Design elevation formula
            view.layer.shadowOpacity = Float(min(0.25, 0.1 + elevation * 0.01))
            view.layer.shadowRadius = elevation * 0.5
            view.layer.shadowOffset = CGSize(width: 0, height: elevation * 0.5)
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.masksToBounds = false
        }
    }
    
    // MARK: - Hit Slop
    
    /// Apply hit slop property directly to view.
    private static func applyHitSlop(to view: UIView, props: [String: Any]) {
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
                view, UnsafeRawPointer(bitPattern: "hitSlop".hashValue)!,
                NSValue(uiEdgeInsets: hitSlopInsets), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Accessibility
    
    /// Apply accessibility properties directly to view.
    private static func applyAccessibility(to view: UIView, props: [String: Any]) {
        if let accessible = props["accessible"] as? Bool {
            view.isAccessibilityElement = accessible
        }
        
        if let label = props["accessibilityLabel"] as? String {
            view.accessibilityLabel = label
        } else if let ariaLabel = props["ariaLabel"] as? String {
            view.accessibilityLabel = ariaLabel
        }
        
        if let hint = props["accessibilityHint"] as? String {
            view.accessibilityHint = hint
        }
        
        // Map accessibilityRole to UIAccessibilityTraits
        if let role = props["accessibilityRole"] as? String {
            var traits = view.accessibilityTraits
            switch role.lowercased() {
            case "button": traits.insert(.button)
            case "link": traits.insert(.link)
            case "header": traits.insert(.header)
            case "image": traits.insert(.image)
            case "text": traits.insert(.staticText)
            default: break
            }
            view.accessibilityTraits = traits
        }
        
        // Map accessibilityState
        if let state = props["accessibilityState"] as? [String: Any] {
            var traits = view.accessibilityTraits
            if let disabled = state["disabled"] as? Bool, disabled {
                traits.insert(.notEnabled)
            }
            if let selected = state["selected"] as? Bool, selected {
                traits.insert(.selected)
            }
            view.accessibilityTraits = traits
        }
    }
    
    // MARK: - Transform
    
    /// Apply transform properties directly to view layer.
    ///
    /// Maps transform properties to CATransform3D matrix.
    /// Matches React Native's transform order: Scale -> Rotate -> Translate
    private static func applyTransform(to view: UIView, props: [String: Any]) {
        var hasTransforms = false
        var rotation: CGFloat = 0
        var translateX: CGFloat = 0
        var translateY: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        
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
            // Build transform matrix
            // Order: Scale -> Rotate -> Translate (standard CSS/React Native order)
            // This ensures scaling and rotation happen around center, then translation moves the result
            var transform = CATransform3DIdentity
            
            // Step 1: Scale (around center)
            transform = CATransform3DScale(transform, scaleX, scaleY, 1)
            
            // Step 2: Rotate (around center)
            transform = CATransform3DRotate(transform, rotation * .pi / 180, 0, 0, 1)
            
            // Step 3: Translate (moves the scaled/rotated view)
            transform = CATransform3DTranslate(transform, translateX, translateY, 0)
            
            // Set anchorPoint to center for proper rotation/scale around center
            // Store center to prevent view shifting when anchorPoint changes
            let oldCenter = view.center
            view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            view.center = oldCenter // Restore center after anchorPoint change
            
            // Apply transform
            view.layer.transform = transform
        } else {
            // Reset transform and anchorPoint when no transforms are present
            view.layer.transform = CATransform3DIdentity
            view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
    }
}

/// Extension to UIView for applying properties using the property mapper.
extension UIView {
    /// Apply style properties using direct property mapping.
    ///
    /// This replaces the monolithic applyStyles approach with direct property setters,
    /// matching the standard model's architecture.
    ///
    /// **Usage:**
    /// ```swift
    /// view.applyProperties(props: ["borderRadius": 8.0, "borderWidth": 2.0])
    /// ```
    public func applyProperties(props: [String: Any]) {
        DCFViewPropertyMapper.applyProperties(to: self, props: props)
        
        // Update gradient frame if gradient layer exists
        // Try hash-based key first
        if let gradientLayer = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "gradientLayer".hashValue)!) as? CAGradientLayer {
            if !self.bounds.isEmpty {
                gradientLayer.frame = self.bounds
            }
        } else {
            // Try string key
            let stringKey = "gradientLayer" as NSString
            if let gradientLayer = objc_getAssociatedObject(self, Unmanaged.passUnretained(stringKey).toOpaque()) as? CAGradientLayer {
                if !self.bounds.isEmpty {
                    gradientLayer.frame = self.bounds
                }
            } else {
                // Fallback: find gradient layer in sublayers
                if let gradientLayer = self.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
                    if !self.bounds.isEmpty {
                        gradientLayer.frame = self.bounds
                    }
                }
            }
        }
    }
}
