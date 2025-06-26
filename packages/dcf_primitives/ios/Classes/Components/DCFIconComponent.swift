/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

//Clone or copy this file with the accompanying dart side to create a custom icon package
class DCFIconComponent: NSObject, DCFComponent {
    private let svgComponent = DCFSvgComponent()

    required override init() {
        super.init()
    }

    func createView(props: [String: Any]) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        // Set up adaptive background color (icons typically transparent)
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            imageView.backgroundColor = UIColor.clear
        } else {
            imageView.backgroundColor = UIColor.clear
        }
        
        updateView(imageView, withProps: props)
        
        // Apply StyleSheet properties
        imageView.applyStyles(props: props)
        
        return imageView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        
        guard let imageView = view as? UIImageView else { 
            return false 
        }

        // Handle prop updates - some props might not include name/package for incremental updates
        var svgProps = props
        
        // Check if we have name and package to set up the asset path
        if let iconName = props["name"] as? String, let packageName = props["package"] as? String {
            
            // Use Flutter lookupKey to resolve logical asset path
            guard let key = sharedFlutterViewController?.lookupKey(forAsset: "assets/icons/\(iconName).svg", fromPackage: packageName) else {
                return false
            }
            let mainBundle = Bundle.main
            let path = mainBundle.path(forResource: key, ofType: nil)
            
            svgProps["asset"] = path
        } else {
            // For prop updates, we don't need to set the asset again
            // The SVG component should handle updates to existing assets
        }
        
        // Convert "color" prop to "tintColor" for SVG component
        if let color = props["color"] as? String {
            svgProps["tintColor"] = color
        }
        
        let result = svgComponent.updateView(imageView, withProps: svgProps)
        
        // Apply StyleSheet properties
        imageView.applyStyles(props: props)
        
        return result
    }
}
