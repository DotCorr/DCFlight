/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Foundation

/**
 * WorkletRuntime - Provides a Reanimated-like API for worklets to directly access and modify native views.
 * 
 * This abstracts away shadow views, layout managers, and component-specific glue code.
 * Worklets can directly manipulate views like React Native Reanimated.
 * 
 * Example usage in worklet IR:
 * - `WorkletRuntime.getView(viewId).setProperty("text", value)`
 * - `WorkletRuntime.getView(viewId).setProperty("opacity", value)`
 * - `WorkletRuntime.getView(viewId).setProperty("transform.scale", value)`
 */
public class WorkletRuntime {
    public static let shared = WorkletRuntime()
    
    private init() {}
    
    /**
     * Get a view proxy that allows direct property manipulation.
     * This is the main entry point for worklets to access views.
     */
    public static func getView(_ viewId: Int) -> WorkletViewProxy? {
        guard let viewInfo = ViewRegistry.shared.registry[viewId] else {
            return nil
        }
        return WorkletViewProxy(viewId: viewId, view: viewInfo.view)
    }
    
    /**
     * Get a view by tag (if views support tags).
     */
    public static func getViewByTag(_ tag: Int) -> WorkletViewProxy? {
        // Find view by tag in ViewRegistry
        for (viewId, viewInfo) in ViewRegistry.shared.registry {
            if viewInfo.view.tag == tag {
                return WorkletViewProxy(viewId: viewId, view: viewInfo.view)
            }
        }
        return nil
    }
}

/**
 * WorkletViewProxy - A proxy object that allows worklets to directly manipulate view properties.
 * 
 * This is similar to React Native Reanimated's view API where you can do:
 * `view.opacity = value` or `view.text = value`
 * 
 * All property updates automatically handle shadow view updates and layout recalculation.
 */
public class WorkletViewProxy {
    public let viewId: Int
    public let view: UIView
    
    public init(viewId: Int, view: UIView) {
        self.viewId = viewId
        self.view = view
    }
    
    /**
     * Set a property on the view. This is the main API for worklets.
     * 
     * Supported properties:
     * - "text" - Updates text content (for text views)
     * - "opacity" - Updates alpha/opacity
     * - "scale" - Updates scale transform
     * - "scaleX", "scaleY" - Updates individual scale components
     * - "translateX", "translateY" - Updates translation
     * - "rotation" - Updates rotation
     * - "transform.scale" - Nested property access
     * 
     * All updates automatically:
     * 1. Update the native view
     * 2. Update the shadow view (if applicable)
     * 3. Trigger layout recalculation (if needed)
     */
    public func setProperty(_ property: String, _ value: Any) {
        switch property {
        case "text":
            setText(value as? String ?? "")
        case "opacity", "alpha":
            setOpacity(value as? Double ?? 1.0)
        case "scale":
            setScale(value as? Double ?? 1.0)
        case "scaleX":
            setScaleX(value as? Double ?? 1.0)
        case "scaleY":
            setScaleY(value as? Double ?? 1.0)
        case "translateX":
            setTranslateX(value as? Double ?? 0.0)
        case "translateY":
            setTranslateY(value as? Double ?? 0.0)
        case "rotation", "rotationZ":
            setRotation(value as? Double ?? 0.0)
        case "rotationX":
            setRotationX(value as? Double ?? 0.0)
        case "rotationY":
            setRotationY(value as? Double ?? 0.0)
        default:
            // Try nested property access (e.g., "transform.scale")
            if property.contains(".") {
                setNestedProperty(property, value)
            } else {
                print("⚠️ WORKLET: Unknown property '\(property)' for viewId=\(viewId)")
            }
        }
    }
    
    /**
     * Set text property - automatically handles shadow view and layout updates.
     */
    private func setText(_ text: String) {
        // Update shadow view if it's a text shadow view
        if let shadowView = YogaShadowTree.shared.getShadowView(for: viewId) as? DCFTextShadowView {
            shadowView.text = text
            shadowView.dirtyText()
            // Trigger layout to update native view
            DCFLayoutManager.shared.calculateLayoutNow()
        } else {
            // Fallback: try to update native view directly if it's a text view
            if let textView = view as? DCFTextView {
                // For direct native updates, we'd need to update the text storage
                // But this should go through shadow view for consistency
                print("⚠️ WORKLET: Cannot update text - shadow view not found for viewId=\(viewId)")
            }
        }
    }
    
    /**
     * Set opacity - directly updates native view (no shadow view needed).
     */
    private func setOpacity(_ opacity: Double) {
        DispatchQueue.main.async {
            self.view.alpha = CGFloat(max(0, min(1, opacity)))
        }
    }
    
    /**
     * Set scale - directly updates native view transform.
     */
    private func setScale(_ scale: Double) {
        DispatchQueue.main.async {
            let scaleValue = CGFloat(scale)
            self.view.transform = CGAffineTransform(scaleX: scaleValue, y: scaleValue)
        }
    }
    
    /**
     * Set scaleX - directly updates native view transform.
     */
    private func setScaleX(_ scaleX: Double) {
        DispatchQueue.main.async {
            var transform = self.view.transform
            transform.a = CGFloat(scaleX)
            self.view.transform = transform
        }
    }
    
    /**
     * Set scaleY - directly updates native view transform.
     */
    private func setScaleY(_ scaleY: Double) {
        DispatchQueue.main.async {
            var transform = self.view.transform
            transform.d = CGFloat(scaleY)
            self.view.transform = transform
        }
    }
    
    /**
     * Set translateX - directly updates native view transform.
     */
    private func setTranslateX(_ translateX: Double) {
        DispatchQueue.main.async {
            var transform = self.view.transform
            transform.tx = CGFloat(translateX)
            self.view.transform = transform
        }
    }
    
    /**
     * Set translateY - directly updates native view transform.
     */
    private func setTranslateY(_ translateY: Double) {
        DispatchQueue.main.async {
            var transform = self.view.transform
            transform.ty = CGFloat(translateY)
            self.view.transform = transform
        }
    }
    
    /**
     * Set rotation - directly updates native view transform.
     */
    private func setRotation(_ rotation: Double) {
        DispatchQueue.main.async {
            self.view.transform = CGAffineTransform(rotationAngle: CGFloat(rotation))
        }
    }
    
    /**
     * Set rotationX - directly updates native view layer transform (3D).
     */
    private func setRotationX(_ rotationX: Double) {
        DispatchQueue.main.async {
            var transform = self.view.layer.transform
            transform = CATransform3DRotate(transform, CGFloat(rotationX), 1, 0, 0)
            self.view.layer.transform = transform
        }
    }
    
    /**
     * Set rotationY - directly updates native view layer transform (3D).
     */
    private func setRotationY(_ rotationY: Double) {
        DispatchQueue.main.async {
            var transform = self.view.layer.transform
            transform = CATransform3DRotate(transform, CGFloat(rotationY), 0, 1, 0)
            self.view.layer.transform = transform
        }
    }
    
    /**
     * Set nested property (e.g., "transform.scale").
     */
    private func setNestedProperty(_ property: String, _ value: Any) {
        let parts = property.split(separator: ".")
        if parts.count == 2 {
            let parent = String(parts[0])
            let child = String(parts[1])
            
            if parent == "transform" {
                switch child {
                case "scale":
                    setScale(value as? Double ?? 1.0)
                case "scaleX":
                    setScaleX(value as? Double ?? 1.0)
                case "scaleY":
                    setScaleY(value as? Double ?? 1.0)
                case "translateX":
                    setTranslateX(value as? Double ?? 0.0)
                case "translateY":
                    setTranslateY(value as? Double ?? 0.0)
                case "rotation":
                    setRotation(value as? Double ?? 0.0)
                default:
                    print("⚠️ WORKLET: Unknown transform property '\(child)'")
                }
            } else {
                print("⚠️ WORKLET: Unknown parent property '\(parent)'")
            }
        } else {
            print("⚠️ WORKLET: Invalid nested property format '\(property)'")
        }
    }
}

