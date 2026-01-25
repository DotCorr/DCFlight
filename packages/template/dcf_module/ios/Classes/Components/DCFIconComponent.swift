/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


import UIKit
import dcflight

class DCFIconComponent: NSObject, DCFComponent {
    private let svgComponent = DCFSvgComponent()

    required override init() {
        super.init()
    }

    func createView(props: [String: Any]) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        if let iconColor = ColorUtilities.getColor(
            explicitColor: "iconColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            imageView.tintColor = iconColor
        }
        
        updateView(imageView, withProps: props)
        
        imageView.applyStyles(props: props)
        
        return imageView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        
        guard let imageView = view as? UIImageView else { 
            return false 
        }

        var svgProps = props
        
        if let iconName = props["name"] as? String, let packageName = props["package"] as? String {
            
            guard let key = sharedFlutterViewController?.lookupKey(forAsset: "assets/icons/\(iconName).svg", fromPackage: packageName) else {
                return false
            }
            let mainBundle = Bundle.main
            let path = mainBundle.path(forResource: key, ofType: nil)
            
            svgProps["asset"] = path
        } else {
        }
        
        if let iconColor = ColorUtilities.getColor(
            explicitColor: "iconColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            iconColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let hexString = String(format: "#%02X%02X%02X", 
                                   Int(red * 255), 
                                   Int(green * 255), 
                                   Int(blue * 255))
            svgProps["tintColor"] = hexString
        } else if let primaryColor = props["primaryColor"] as? String {
            svgProps["tintColor"] = primaryColor
        }
        
        let result = svgComponent.updateView(imageView, withProps: svgProps)
        
        imageView.applyStyles(props: props)
        
        return result
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        guard let imageView = view as? UIImageView else {
            return CGSize.zero
        }
        
        let size = props["size"] as? CGFloat ?? 24
        
        return CGSize(width: size, height: size)
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
