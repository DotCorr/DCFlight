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
    
    // MARK: - Border Radius
    
    /// Apply border radius properties directly to view.
    ///
    /// Maps borderRadius and individual corner radii to native properties.
    private static func applyBorderRadius(to view: UIView, props: [String: Any]) {
        // Check if view is DCFView (Objective-C class)
        let isDCFView = type(of: view).description() == "DCFView"
        
        if isDCFView {
            // Use runtime to set properties (DCFView is Objective-C)
            if let borderRadius = props["borderRadius"] as? CGFloat {
                view.setValue(borderRadius, forKey: "borderRadius")
            }
            if let topLeft = props["borderTopLeftRadius"] as? CGFloat {
                view.setValue(topLeft, forKey: "borderTopLeftRadius")
            }
            if let topRight = props["borderTopRightRadius"] as? CGFloat {
                view.setValue(topRight, forKey: "borderTopRightRadius")
            }
            if let bottomLeft = props["borderBottomLeftRadius"] as? CGFloat {
                view.setValue(bottomLeft, forKey: "borderBottomLeftRadius")
            }
            if let bottomRight = props["borderBottomRightRadius"] as? CGFloat {
                view.setValue(bottomRight, forKey: "borderBottomRightRadius")
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
        let isDCFView = type(of: view).description() == "DCFView"
        
        if isDCFView {
            // Use runtime to set properties
            if let borderWidth = props["borderWidth"] as? CGFloat {
                view.setValue(borderWidth, forKey: "borderWidth")
            }
            if let topWidth = props["borderTopWidth"] as? CGFloat {
                view.setValue(topWidth, forKey: "borderTopWidth")
            }
            if let rightWidth = props["borderRightWidth"] as? CGFloat {
                view.setValue(rightWidth, forKey: "borderRightWidth")
            }
            if let bottomWidth = props["borderBottomWidth"] as? CGFloat {
                view.setValue(bottomWidth, forKey: "borderBottomWidth")
            }
            if let leftWidth = props["borderLeftWidth"] as? CGFloat {
                view.setValue(leftWidth, forKey: "borderLeftWidth")
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
        let isDCFView = type(of: view).description() == "DCFView"
        
        if isDCFView {
            // Use runtime to set properties
            if let borderColorStr = props["borderColor"] as? String,
               let color = ColorUtilities.color(fromHexString: borderColorStr) {
                view.setValue(color.cgColor, forKey: "borderColor")
            }
            if let topColorStr = props["borderTopColor"] as? String,
               let color = ColorUtilities.color(fromHexString: topColorStr) {
                view.setValue(color.cgColor, forKey: "borderTopColor")
            }
            if let rightColorStr = props["borderRightColor"] as? String,
               let color = ColorUtilities.color(fromHexString: rightColorStr) {
                view.setValue(color.cgColor, forKey: "borderRightColor")
            }
            if let bottomColorStr = props["borderBottomColor"] as? String,
               let color = ColorUtilities.color(fromHexString: bottomColorStr) {
                view.setValue(color.cgColor, forKey: "borderBottomColor")
            }
            if let leftColorStr = props["borderLeftColor"] as? String,
               let color = ColorUtilities.color(fromHexString: leftColorStr) {
                view.setValue(color.cgColor, forKey: "borderLeftColor")
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
        let isDCFView = type(of: view).description() == "DCFView"
        
        if isDCFView, let borderStyle = props["borderStyle"] as? String {
            view.setValue(borderStyle, forKey: "borderStyle")
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
            let isDCFView = type(of: view).description() == "DCFView"
            if isDCFView {
                view.setValue(UIColor.clear, forKey: "dcfBackgroundColor")
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
            let isDCFView = type(of: view).description() == "DCFView"
            if isDCFView {
                view.setValue(color, forKey: "dcfBackgroundColor")
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
        
        // Clear backgroundColor when gradient exists
        view.backgroundColor = .clear
        let isDCFView = type(of: view).description() == "DCFView"
        if isDCFView {
            view.setValue(UIColor.clear, forKey: "dcfBackgroundColor")
        }
        
        // Apply gradient - create CAGradientLayer
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        
        // Parse gradient data
        if let type = gradientData["type"] as? String,
           let colors = gradientData["colors"] as? [String] {
            
            // Convert color strings to CGColor
            let cgColors = colors.compactMap { colorStr -> CGColor? in
                return ColorUtilities.color(fromHexString: colorStr)?.cgColor
            }
            gradientLayer.colors = cgColors
            
            // Handle gradient direction
            if type == "linear" {
                let startX = (gradientData["startX"] as? CGFloat) ?? 0.0
                let startY = (gradientData["startY"] as? CGFloat) ?? 0.0
                let endX = (gradientData["endX"] as? CGFloat) ?? 1.0
                let endY = (gradientData["endY"] as? CGFloat) ?? 1.0
                
                gradientLayer.startPoint = CGPoint(x: startX, y: startY)
                gradientLayer.endPoint = CGPoint(x: endX, y: endY)
            } else if type == "radial" {
                // Radial gradient - use diagonal for proper fill
                let centerX = (gradientData["centerX"] as? CGFloat) ?? 0.5
                let centerY = (gradientData["centerY"] as? CGFloat) ?? 0.5
                let radius = (gradientData["radius"] as? CGFloat) ?? 0.5
                
                // Calculate endPoint based on diagonal (Pythagorean theorem)
                let diagonal = sqrt(view.bounds.width * view.bounds.width + view.bounds.height * view.bounds.height)
                let scale = diagonal / min(view.bounds.width, view.bounds.height)
                
                gradientLayer.startPoint = CGPoint(x: centerX, y: centerY)
                gradientLayer.endPoint = CGPoint(
                    x: centerX + radius * scale,
                    y: centerY + radius * scale
                )
            }
            
            // Handle color stops
            if let stops = gradientData["stops"] as? [CGFloat] {
                gradientLayer.locations = stops.map { NSNumber(value: Float($0)) }
            }
        }
        
        // Insert gradient layer at bottom
        if let existingGradient = view.layer.sublayers?.first(where: { $0 is CAGradientLayer }) {
            existingGradient.removeFromSuperlayer()
        }
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Update gradient frame when view bounds change
        gradientLayer.frame = view.bounds
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
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, translateX, translateY, 0)
            transform = CATransform3DRotate(transform, rotation * .pi / 180, 0, 0, 1)
            transform = CATransform3DScale(transform, scaleX, scaleY, 1)
            
            // Keep anchorPoint at center
            view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            view.layer.transform = transform
        } else {
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
    func applyProperties(props: [String: Any]) {
        DCFViewPropertyMapper.applyProperties(to: self, props: props)
    }
}
