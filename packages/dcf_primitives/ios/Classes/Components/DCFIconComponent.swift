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
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            imageView.backgroundColor = UIColor.clear
        } else {
            imageView.backgroundColor = UIColor.clear
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
        
        if let color = props["color"] as? String {
            svgProps["tintColor"] = color
        }
        
        let result = svgComponent.updateView(imageView, withProps: svgProps)
        
        imageView.applyStyles(props: props)
        
        return result
    }
}
