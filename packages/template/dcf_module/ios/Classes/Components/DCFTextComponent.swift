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
        guard let label = view as? UILabel else { return false }
        
        // Set content if specified
        if let content = props["content"] as? String {
            label.text = content
        }
        
        // Only update font properties if they're actually specified in props
        var shouldUpdateFont = false
        var fontSize: CGFloat?
        var fontWeight: UIFont.Weight?
        var fontFamily: String?
        var isFontAsset = false
        
        // Get font size if specified
        if let fontSizeValue = props["fontSize"] as? CGFloat {
            fontSize = fontSizeValue
            shouldUpdateFont = true
        }
        
        // Get font weight if specified
        if let fontWeightString = props["fontWeight"] as? String {
            fontWeight = fontWeightFromString(fontWeightString)
            shouldUpdateFont = true
        }
        
        // Get font family if specified
        if let fontFamilyValue = props["fontFamily"] as? String {
            fontFamily = fontFamilyValue
            isFontAsset = props["isFontAsset"] as? Bool ?? false
            shouldUpdateFont = true
        }
        
        // Only update font if at least one font property was specified
        if shouldUpdateFont {
            let currentFont = label.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
            let finalFontSize = fontSize ?? currentFont.pointSize
            let finalFontWeight = fontWeight ?? .regular
            
            if let fontFamily = fontFamily {
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
        }
        
        // Handle color property - key fix for incremental updates
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
        // Note: Don't reset color if not specified in props - preserve current color
        
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
        }
        // Note: Don't reset alignment if not specified in props - preserve current alignment
        
        // Set number of lines if specified (preserve current numberOfLines if not in props)
        if let numberOfLines = props["numberOfLines"] as? Int {
            label.numberOfLines = numberOfLines
        }
        // Note: Don't reset numberOfLines if not specified in props - preserve current value
        
        // Apply StyleSheet properties
        label.applyStyles(props: props)
        
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



