/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFSpinnerComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFSpinnerComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        
        let spinner: UIActivityIndicatorView
        
        let style = props["style"] as? String ?? "medium"
        
        if #available(iOS 13.0, *) {
            switch style.lowercased() {
            case "large":
                spinner = UIActivityIndicatorView(style: .large)
            case "small":
                spinner = UIActivityIndicatorView(style: .medium)
            default: // medium
                spinner = UIActivityIndicatorView(style: .medium)
            }
        } else {
            switch style.lowercased() {
            case "large":
                spinner = UIActivityIndicatorView(style: .whiteLarge)
            case "small":
                spinner = UIActivityIndicatorView(style: .white)
            default: // medium
                spinner = UIActivityIndicatorView(style: .gray)
            }
        }
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        if let primaryColorStr = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColorStr) {
                spinner.color = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        updateView(spinner, withProps: props)
        spinner.applyStyles(props: props)
        
        return spinner
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let spinner = view as? UIActivityIndicatorView else { return false }
        
        if let animating = props["animating"] as? Bool {
            if animating {
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
            }
        } else {
            spinner.startAnimating()
        }
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // primaryColor: spinner color
        if let primaryColor = props["primaryColor"] as? String,
           let spinnerColor = ColorUtilities.color(fromHexString: primaryColor) {
            spinner.color = spinnerColor
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        if let hidesWhenStopped = props["hidesWhenStopped"] as? Bool {
            spinner.hidesWhenStopped = hidesWhenStopped
        } else {
            spinner.hidesWhenStopped = true // Default behavior
        }
        
        spinner.applyStyles(props: props)
        return true
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let spinner = view as? UIActivityIndicatorView else {
            return CGSize.zero
        }
        
        let size = spinner.intrinsicContentSize
        return CGSize(width: max(1, size.width), height: max(1, size.height))
    }
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }

    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        objc_setAssociatedObject(view,
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}
