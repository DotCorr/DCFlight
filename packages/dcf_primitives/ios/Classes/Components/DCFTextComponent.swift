/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight
import CoreText

class DCFTextComponent: NSObject, DCFComponent, ComponentMethodHandler {
    // Dictionary to cache loaded fonts
    internal static var fontCache = [String: UIFont]()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create a label
        let label = UILabel()
        
        // Apply adaptive default styling - let OS handle light/dark mode
        label.numberOfLines = 0
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            // Use system colors that automatically adapt to light/dark mode
            if #available(iOS 13.0, *) {
                label.textColor = UIColor.label
            } else {
                label.textColor = UIColor.black
            }
        } else {
            label.textColor = UIColor.black
        }
        
        // Apply props
        updateView(label, withProps: props)
        
        // Apply StyleSheet properties
        label.applyStyles(props: props)
        
        return label
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let label = view as? UILabel else { 
            print("❌ DCFTextComponent: Failed to cast view to UILabel")
            return false 
        }
        
        print("🔄 DCFTextComponent: Updating view with props: \(props.keys)")
        
        // Set content if specified
        if let content = props["content"] as? String {
            label.text = content
            print("📝 DCFTextComponent: Set text content to: \(content)")
        }
        
        // Handle font properties only if they are provided (for incremental updates)
        let hasAnyFontProp = props["fontSize"] != nil || props["fontWeight"] != nil || 
                            props["fontFamily"] != nil || props["isFontAsset"] != nil
        
        if hasAnyFontProp {
            print("🎨 DCFTextComponent: Processing font properties")
            
            // Get current font as fallback
            let currentFont = label.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
            let finalFontSize = props["fontSize"] as? CGFloat ?? currentFont.pointSize
            
            // Determine font weight using centralized utility
            var finalFontWeight = UIFont.Weight.regular
            if let fontWeightString = props["fontWeight"] as? String {
                finalFontWeight = fontWeightFromString(fontWeightString)
            }
            
            // Check if font is from an asset
            let isFontAsset = props["isFontAsset"] as? Bool ?? false
            
            if let fontFamily = props["fontFamily"] as? String {
                if isFontAsset {
                    // Use the same asset resolution approach as SVG
                    let key = sharedFlutterViewController?.lookupKey(forAsset: fontFamily)
                    let mainBundle = Bundle.main
                    let path = mainBundle.path(forResource: key, ofType: nil)
                    
                    loadFontFromAsset(fontFamily, path: path, fontSize: finalFontSize, weight: finalFontWeight) { font in
                        if let font = font {
                            label.font = font
                        } else {
                            // Fallback to system font if custom font loading fails
                            label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
                        }
                    }
                } else {
                    // Try to use a pre-installed font by name
                    if let font = UIFont(name: fontFamily, size: finalFontSize) {
                        // Apply weight if needed
                        if finalFontWeight != .regular {
                            let descriptor = font.fontDescriptor.addingAttributes([
                                .traits: [UIFontDescriptor.TraitKey.weight: finalFontWeight]
                            ])
                            label.font = UIFont(descriptor: descriptor, size: finalFontSize)
                        } else {
                            label.font = font
                        }
                    } else {
                        // Fallback to system font if font not found
                        label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
                    }
                }
            } else {
                // Use system font with the specified size and weight
                label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
            }
            print("🎨 DCFTextComponent: Updated font properties")
        }
        
        // Handle color property - this is the key fix for incremental updates
        if props.keys.contains("color") {
            if let color = props["color"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: color)
                label.textColor = uiColor
                print("🎨 DCFTextComponent: Set text color to: \(color) -> \(uiColor)")
            } else {
                print("⚠️ DCFTextComponent: Color prop present but invalid value: \(props["color"] ?? "nil")")
            }
        }
        
        // Handle adaptive color only if explicitly provided and no color is set
        if props.keys.contains("adaptive") && !props.keys.contains("color") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    label.textColor = UIColor.label
                } else {
                    label.textColor = UIColor.black
                }
                print("🎨 DCFTextComponent: Applied adaptive color")
            }
        }
        
        // Set text alignment if specified (preserve current alignment if not in props)
        if let textAlign = props["textAlign"] as? String {
            switch textAlign {
            case "center":
                label.textAlignment = .center
            case "right":
                label.textAlignment = .right
            case "justify":
                label.textAlignment = .justified
            default:
                label.textAlignment = .left
            }
            print("📐 DCFTextComponent: Set text alignment to: \(textAlign)")
        }
        
        // Set number of lines if specified (preserve current numberOfLines if not in props)
        if let numberOfLines = props["numberOfLines"] as? Int {
            label.numberOfLines = numberOfLines
            print("📄 DCFTextComponent: Set number of lines to: \(numberOfLines)")
        }
        
        // Apply StyleSheet properties
        label.applyStyles(props: props)
        
        print("✅ DCFTextComponent: Successfully updated view")
        return true
    }
    
    // Handle component methods
        func handleMethod(methodName: String, args: [String: Any], view: UIView) -> Bool {
            guard let label = view as? UILabel else { return false }
            
            switch methodName {
            case "setText":
                if let text = args["text"] as? String {
                    label.text = text
                    return true
                }
            default:
                return false
            }
            
            return false
        }

}



