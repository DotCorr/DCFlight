/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight
import CoreText

class DCFTextComponent: NSObject, DCFComponent {
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
            return false 
        }
        
        
        // Set content if specified
        if let content = props["content"] as? String {
            label.text = content
        }
        
        // Handle font properties only if they are provided (for incremental updates)
        let hasAnyFontProp = props["fontSize"] != nil || props["fontWeight"] != nil || 
                            props["fontFamily"] != nil || props["isFontAsset"] != nil
        
        if hasAnyFontProp {
            
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
        }
        
        // Handle color property - this is the key fix for incremental updates
        if props.keys.contains("color") {
            if let color = props["color"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: color)
                label.textColor = uiColor
            } else {
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
        }
        
        // Set number of lines if specified (preserve current numberOfLines if not in props)
        if let numberOfLines = props["numberOfLines"] as? Int {
            label.numberOfLines = numberOfLines
        }
        
        // Handle commands if provided
        if let commandData = props["command"] as? [String: Any] {
            handleCommand(commandData, on: label)
        }
        
        // Apply StyleSheet properties
        label.applyStyles(props: props)
        
        return true
    }
    
    // MARK: - Command Handling
    
    private func handleCommand(_ command: [String: Any], on label: UILabel) {
        guard let type = command["type"] as? String else { return }
        
        switch type {
        case "setText":
            if let text = command["text"] as? String {
                let animated = command["animated"] as? Bool ?? false
                let duration = command["duration"] as? Double ?? 0.3
                
                if animated {
                    UIView.transition(with: label, duration: duration, options: .transitionCrossDissolve, animations: {
                        label.text = text
                    }, completion: nil)
                } else {
                    label.text = text
                }
            }
            
        case "setTextColor":
            if let colorString = command["color"] as? String {
                let animated = command["animated"] as? Bool ?? false
                let duration = command["duration"] as? Double ?? 0.3
                let uiColor = ColorUtilities.color(fromHexString: colorString)
                
                if animated {
                    UIView.animate(withDuration: duration) {
                        label.textColor = uiColor
                    }
                } else {
                    label.textColor = uiColor
                }
            }
            
        case "setFontSize":
            if let fontSize = command["fontSize"] as? Double {
                let animated = command["animated"] as? Bool ?? false
                let duration = command["duration"] as? Double ?? 0.3
                let currentFont = label.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
                let newFont = currentFont.withSize(CGFloat(fontSize))
                
                if animated {
                    UIView.animate(withDuration: duration) {
                        label.font = newFont
                    }
                } else {
                    label.font = newFont
                }
            }
            
        case "animateText":
            if let animationType = command["animationType"] as? String {
                let duration = command["duration"] as? Double ?? 0.3
                let direction = command["direction"] as? String
                
                switch animationType {
                case "fade":
                    UIView.animate(withDuration: duration / 2, animations: {
                        label.alpha = 0.0
                    }) { _ in
                        UIView.animate(withDuration: duration / 2) {
                            label.alpha = 1.0
                        }
                    }
                    
                case "scale":
                    label.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                    UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
                        label.transform = CGAffineTransform.identity
                    }, completion: nil)
                    
                case "slide":
                    var transform = CGAffineTransform.identity
                    switch direction {
                    case "up": transform = CGAffineTransform(translationX: 0, y: 30)
                    case "down": transform = CGAffineTransform(translationX: 0, y: -30)
                    case "left": transform = CGAffineTransform(translationX: 30, y: 0)
                    case "right": transform = CGAffineTransform(translationX: -30, y: 0)
                    default: transform = CGAffineTransform(translationX: 0, y: 30)
                    }
                    
                    label.transform = transform
                    label.alpha = 0.0
                    UIView.animate(withDuration: duration) {
                        label.transform = CGAffineTransform.identity
                        label.alpha = 1.0
                    }
                    
                default:
                    break
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Font Utility Functions
    
    private func fontWeightFromString(_ weight: String) -> UIFont.Weight {
        switch weight.lowercased() {
        case "thin":           return .thin
        case "ultralight":     return .ultraLight
        case "light":          return .light
        case "regular", "normal", "400": return .regular
        case "medium":         return .medium
        case "semibold":       return .semibold
        case "bold":           return .bold
        case "heavy":          return .heavy
        case "black":          return .black
        // Legacy numeric support
        case "100":            return .ultraLight
        case "200":            return .thin
        case "300":            return .light
        case "500":            return .medium
        case "600":            return .semibold
        case "700":            return .bold
        case "800":            return .heavy
        case "900":            return .black
        default:               return .regular
        }
    }
    
    private func loadFontFromAsset(_ fontAsset: String, path: String?, fontSize: CGFloat, weight: UIFont.Weight, completion: @escaping (UIFont?) -> Void) {
        // Create a unique key for caching
        let cacheKey = "\(fontAsset)_\(fontSize)_\(weight.rawValue)"
        
        // Check cache first
        if let cachedFont = DCFTextComponent.fontCache[cacheKey] {
            completion(cachedFont)
            return
        }
        
        // Ensure we have a valid path
        guard let fontPath = path, !fontPath.isEmpty else {
            completion(nil)
            return
        }
        
        // Check if the file exists
        guard FileManager.default.fileExists(atPath: fontPath) else {
            completion(nil)
            return
        }
        
        // Load and register the font
        if registerFontFromPath(fontPath) {
            // Try to get the font name from the file
            if let fontName = getFontNameFromPath(fontPath) {
                if let font = UIFont(name: fontName, size: fontSize) {
                    // Apply weight if needed
                    let finalFont: UIFont
                    if weight != .regular {
                        let descriptor = font.fontDescriptor.addingAttributes([
                            .traits: [UIFontDescriptor.TraitKey.weight: weight]
                        ])
                        finalFont = UIFont(descriptor: descriptor, size: fontSize) ?? font
                    } else {
                        finalFont = font
                    }
                    
                    // Cache the font
                    DCFTextComponent.fontCache[cacheKey] = finalFont
                    
                    completion(finalFont)
                    return
                }
            }
        }
        
        // If we reach here, something went wrong
        completion(nil)
    }
    
    // Register a font with the system
    private func registerFontFromPath(_ path: String) -> Bool {
        guard let fontData = NSData(contentsOfFile: path) else {
            return false
        }
        
        guard let dataProvider = CGDataProvider(data: fontData) else {
            return false
        }
        
        guard let cgFont = CGFont(dataProvider) else {
            return false
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(cgFont, &error)
        
        if !success {
            if let err = error?.takeRetainedValue() {
                let description = CFErrorCopyDescription(err)
            }
            return false
        }
        
        return true
    }
    
    // Get the font name from a font file
    private func getFontNameFromPath(_ path: String) -> String? {
        guard let fontData = NSData(contentsOfFile: path) else { return nil }
        guard let dataProvider = CGDataProvider(data: fontData) else { return nil }
        guard let cgFont = CGFont(dataProvider) else { return nil }
        
        if let postScriptName = cgFont.postScriptName as String? {
            return postScriptName
        }
        
        return nil
    }

}



