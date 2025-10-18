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
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                spinner.color = UIColor.label
            } else {
                spinner.color = UIColor.gray
            }
        }
        
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
        
        if let color = props["color"] as? String,
           let spinnerColor = ColorUtilities.color(fromHexString: color) {
            spinner.color = spinnerColor
        }
        
        if let hidesWhenStopped = props["hidesWhenStopped"] as? Bool {
            spinner.hidesWhenStopped = hidesWhenStopped
        } else {
            spinner.hidesWhenStopped = true // Default behavior
        }
        
        spinner.applyStyles(props: props)
        return true
    }
}
