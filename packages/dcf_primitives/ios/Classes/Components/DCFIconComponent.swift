/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        if let primaryColorStr = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColorStr) {
                imageView.tintColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
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
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // primaryColor: icon color
        if let primaryColor = props["primaryColor"] as? String {
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
