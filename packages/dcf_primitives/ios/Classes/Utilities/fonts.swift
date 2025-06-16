/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit

// Extension to help with font weight preservation
extension UIFont {
    func getFontWeight() -> UIFont.Weight {
        // Get the font descriptor attributes
        let attributes = self.fontDescriptor.fontAttributes
        
        // Check for the weight in the traits
        if let traits = attributes[.traits] as? [UIFontDescriptor.TraitKey: Any],
           let weightNumber = traits[.weight] as? NSNumber {
            let weightValue = CGFloat(weightNumber.doubleValue)
            
            // Map the weight value to a UIFont.Weight
            // The mapping is approximate as UIFont.Weight doesn't have public numeric values
            switch weightValue {
            case ...UIFont.Weight.ultraLight.rawValue:
                return .ultraLight
            case ...UIFont.Weight.thin.rawValue:
                return .thin
            case ...UIFont.Weight.light.rawValue:
                return .light
            case ...UIFont.Weight.regular.rawValue:
                return .regular
            case ...UIFont.Weight.medium.rawValue:
                return .medium
            case ...UIFont.Weight.semibold.rawValue:
                return .semibold
            case ...UIFont.Weight.bold.rawValue:
                return .bold
            case ...UIFont.Weight.heavy.rawValue:
                return .heavy
            default:
                return .black
            }
        }
        
        // Fall back to checking the font name
        let fontName = self.fontName.lowercased()
        if fontName.contains("bold") {
            return .bold
        } else if fontName.contains("light") {
            return .light
        } else if fontName.contains("medium") {
            return .medium
        } else if fontName.contains("heavy") || fontName.contains("black") {
            return .heavy
        } else if fontName.contains("semibold") {
            return .semibold
        } else if fontName.contains("thin") {
            return .thin
        } else if fontName.contains("ultralight") {
            return .ultraLight
        }
        
        // Default to regular weight
        return .regular
    }
}


// Helper to convert string weight to UIFont.Weight
 func fontWeightFromString(_ weight: String) -> UIFont.Weight {
    switch weight {
    case "bold", "700":    return .bold
    case "600":            return .semibold
    case "500":            return .medium
    case "400", "normal", "regular": return .regular
    case "300":            return .light
    case "200":            return .thin
    case "100":            return .ultraLight
    case "800":            return .heavy
    case "900":            return .black
    default:               return .regular
    }
}


// MARK: - Font Loading Methods
    
    internal func loadFontFromAsset(_ fontAsset: String, path: String?, fontSize: CGFloat, weight: UIFont.Weight, completion: @escaping (UIFont?) -> Void) {
        // Create a unique key for caching
        let cacheKey = "\(fontAsset)_\(fontSize)_\(weight.rawValue)"
        
        // Check cache first
        if let cachedFont = DCFTextComponent.fontCache[cacheKey] {
            print("✅ Using cached font: \(fontAsset)")
            completion(cachedFont)
            return
        }
        
        // Ensure we have a valid path
        guard let fontPath = path, !fontPath.isEmpty else {
            print("❌ Invalid font path for asset: \(fontAsset)")
            completion(nil)
            return
        }
        
        // Check if the file exists
        guard FileManager.default.fileExists(atPath: fontPath) else {
            print("❌ Font file does not exist at path: \(fontPath)")
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
                    
                    print("✅ Successfully loaded font: \(fontName) from \(fontAsset)")
                    completion(finalFont)
                    return
                }
            }
        }
        
        // If we reach here, something went wrong
        print("❌ Failed to load font from asset: \(fontAsset)")
        completion(nil)
    }
    
    // Register a font with the system
    internal func registerFontFromPath(_ path: String) -> Bool {
        guard let fontData = NSData(contentsOfFile: path) else {
            print("❌ Failed to read font data from path: \(path)")
            return false
        }
        
        guard let dataProvider = CGDataProvider(data: fontData) else {
            print("❌ Failed to create data provider for font")
            return false
        }
        
        guard let cgFont = CGFont(dataProvider) else {
            print("❌ Failed to create CGFont")
            return false
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(cgFont, &error)
        
        if !success {
            if let err = error?.takeRetainedValue() {
                let description = CFErrorCopyDescription(err)
                print("❌ Failed to register font: \(description ?? "unknown error" as CFString)")
            }
            return false
        }
        
        return true
    }
    
    // Get the font name from a font file
    internal func getFontNameFromPath(_ path: String) -> String? {
        guard let fontData = NSData(contentsOfFile: path) else { return nil }
        guard let dataProvider = CGDataProvider(data: fontData) else { return nil }
        guard let cgFont = CGFont(dataProvider) else { return nil }
        
        if let postScriptName = cgFont.postScriptName as String? {
            return postScriptName
        }
        
        return nil
    }
    

    
    