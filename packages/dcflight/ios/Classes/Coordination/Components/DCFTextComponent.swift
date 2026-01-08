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
        let textView = DCFTextView()
        
        storeProps(props.mapValues { $0 as Any? }, in: textView)
        
        updateView(textView, withProps: props)
        
        textView.applyStyles(props: props)
        
        return textView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let textView = view as? DCFTextView else { 
            return false 
        }
        
        let existingProps = getStoredProps(from: textView)
        let mergedProps = mergeProps(existingProps, with: props.mapValues { $0 as Any? })
        
        // 🔥 CRITICAL: Check if _systemVersion changed - this indicates system font scale or other system settings changed
        // When _systemVersion changes, we MUST force a re-measurement because the system font scale affects text rendering
        let oldSystemVersion = existingProps["_systemVersion"] as? NSNumber
        let newSystemVersion = mergedProps["_systemVersion"] as? NSNumber
        let systemVersionChanged = oldSystemVersion != nil && newSystemVersion != nil && oldSystemVersion != newSystemVersion
        
        if systemVersionChanged {
            print("🔄 DCFTextComponent: System version changed: \(oldSystemVersion?.intValue ?? 0) → \(newSystemVersion?.intValue ?? 0) - forcing re-measurement")
        }
        
        storeProps(mergedProps, in: textView)
        
        textView.applyStyles(props: mergedProps.compactMapValues { $0 })
        
        // 🔥 CRITICAL: When system version changes, force layout recalculation
        // This ensures Yoga recalculates text size with new font scale
        if systemVersionChanged {
            print("🔄 DCFTextComponent: Requesting layout recalculation due to system version change")
            // Force shadow view to recompute text storage with new font scale
            if let viewId = getViewId(from: textView),
               let shadowView = YogaShadowTree.shared.getShadowView(for: viewId) as? DCFTextShadowView {
                // Mark shadow view as dirty to force recomputation
                // This will clear cached text storage and mark Yoga node as dirty
                shadowView.dirtyText()
            }
            // Request layout recalculation
            textView.setNeedsLayout()
            textView.setNeedsDisplay()
            // Trigger layout calculation to apply changes
            DCFLayoutManager.shared.triggerLayoutCalculation()
        }
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Use the exact frame from Yoga - measurement already accounts for font metrics
        let frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        view.frame = frame
        
        guard let textView = view as? DCFTextView else {
            return
        }
        
        // Get shadow view to retrieve computed textStorage and textFrame
        guard let viewId = getViewId(from: view),
              let shadowView = YogaShadowTree.shared.getShadowView(for: viewId) as? DCFTextShadowView else {
            return
        }
        
        // Update text view with textStorage and textFrame from shadow view
        // Text storage and frame are set on the view during layout application
        textView.textStorage = shadowView.computedTextStorage
        textView.textFrame = shadowView.computedTextFrame
        textView.contentInset = shadowView.computedContentInset
        
        // Disable frame animation for text to prevent visual artifacts
        UIView.performWithoutAnimation {
            textView.setNeedsDisplay()
        }
    }
    
    private func getViewId(from view: UIView) -> Int? {
        // Find viewId by searching ViewRegistry
        for (viewId, viewInfo) in ViewRegistry.shared.registry {
            if viewInfo.view === view {
                return viewId
            }
        }
        return nil
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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



