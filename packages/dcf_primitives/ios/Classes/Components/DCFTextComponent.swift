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
    internal static var fontCache = [String: UIFont]()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let label = UILabel()
        
        label.numberOfLines = 0
        
        storeProps(props.mapValues { $0 as Any? }, in: label)
        
        if let content = props["content"] as? String {
            label.text = content
        }
        
        updateView(label, withProps: props)
        
        label.applyStyles(props: props)
        
        if let textColor = ColorUtilities.getColor(
            explicitColor: "textColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            label.textColor = textColor
        }
        
        return label
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let label = view as? UILabel else { 
            return false 
        }
        
        let existingProps = getStoredProps(from: label)
        let mergedProps = mergeProps(existingProps, with: props.mapValues { $0 as Any? })
        storeProps(mergedProps, in: label)
        
        let nonNullProps = mergedProps.compactMapValues { $0 }
        
        if let content = nonNullProps["content"] as? String {
            label.text = content
        }
        
        let hasAnyFontProp = nonNullProps["fontSize"] != nil || nonNullProps["fontWeight"] != nil || 
                            nonNullProps["fontFamily"] != nil || nonNullProps["isFontAsset"] != nil
        
        if hasAnyFontProp {
            
            let currentFont = label.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
            let finalFontSize = nonNullProps["fontSize"] as? CGFloat ?? currentFont.pointSize
            
            var finalFontWeight = UIFont.Weight.regular
            if let fontWeightString = nonNullProps["fontWeight"] as? String {
                finalFontWeight = fontWeightFromString(fontWeightString)
            }
            
            let isFontAsset = nonNullProps["isFontAsset"] as? Bool ?? false
            
            if let fontFamily = nonNullProps["fontFamily"] as? String {
                if isFontAsset {
                    let key = sharedFlutterViewController?.lookupKey(forAsset: fontFamily)
                    let mainBundle = Bundle.main
                    let path = mainBundle.path(forResource: key, ofType: nil)
                    
                    loadFontFromAsset(fontFamily, path: path, fontSize: finalFontSize, weight: finalFontWeight) { font in
                        if let font = font {
                            label.font = font
                        } else {
                            label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
                        }
                    }
                } else {
                    if let font = UIFont(name: fontFamily, size: finalFontSize) {
                        if finalFontWeight != .regular {
                            let descriptor = font.fontDescriptor.addingAttributes([
                                .traits: [UIFontDescriptor.TraitKey.weight: finalFontWeight]
                            ])
                            label.font = UIFont(descriptor: descriptor, size: finalFontSize)
                        } else {
                            label.font = font
                        }
                    } else {
                        label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
                    }
                }
            } else {
                label.font = UIFont.systemFont(ofSize: finalFontSize, weight: finalFontWeight)
            }
        }

        if let textAlign = nonNullProps["textAlign"] as? String {
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
        
        if let numberOfLines = nonNullProps["numberOfLines"] as? Int {
            label.numberOfLines = numberOfLines
        }
        
        label.applyStyles(props: nonNullProps)
        
        if let textColor = ColorUtilities.getColor(
            explicitColor: "textColor",
            semanticColor: "primaryColor",
            from: nonNullProps
        ) {
            label.textColor = textColor
        }
        
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
    
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
        let cacheKey = "\(fontAsset)_\(fontSize)_\(weight.rawValue)"
        
        if let cachedFont = DCFTextComponent.fontCache[cacheKey] {
            completion(cachedFont)
            return
        }
        
        guard let fontPath = path, !fontPath.isEmpty else {
            completion(nil)
            return
        }
        
        guard FileManager.default.fileExists(atPath: fontPath) else {
            completion(nil)
            return
        }
        
        if registerFontFromPath(fontPath) {
            if let fontName = getFontNameFromPath(fontPath) {
                if let font = UIFont(name: fontName, size: fontSize) {
                    let finalFont: UIFont
                    if weight != .regular {
                        let descriptor = font.fontDescriptor.addingAttributes([
                            .traits: [UIFontDescriptor.TraitKey.weight: weight]
                        ])
                        finalFont = UIFont(descriptor: descriptor, size: fontSize) ?? font
                    } else {
                        finalFont = font
                    }
                    
                    DCFTextComponent.fontCache[cacheKey] = finalFont
                    
                    completion(finalFont)
                    return
                }
            }
        }
        
        completion(nil)
    }
    
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



