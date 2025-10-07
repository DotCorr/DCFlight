/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit

/// Helper class for debugging layout issues
class LayoutDebugging {
    static let shared = LayoutDebugging()
    
    private init() {}
    
    /// Add a visual debug border to a view
    func addDebugBorder(to view: UIView, color: UIColor = .red, width: CGFloat = 1.0) {
        view.layer.borderColor = color.cgColor
        view.layer.borderWidth = width
    }
    
    /// Add a debug label to show dimensions
    func addDimensionLabel(to view: UIView, viewId: String) {
        view.subviews.forEach { subview in
            if subview.tag == 99999 {
                subview.removeFromSuperview()
            }
        }
        
        let label = UILabel()
        label.tag = 99999
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.text = "ID: \(viewId)\n\(Int(view.frame.width))×\(Int(view.frame.height))"
        label.numberOfLines = 2
        label.textAlignment = .center
        
        view.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        label.isUserInteractionEnabled = false
    }
    
    /// Enable visual debugging for all views in hierarchy
    func enableVisualDebugging(for rootView: UIView) {
        processViewHierarchy(rootView)
    }
    
    /// Enable visual debugging for all views in hierarchy except the root view
    func enableVisualDebuggingExceptRoot(for rootView: UIView) {
        for subview in rootView.subviews {
            addDebugBorder(to: subview, color: randomColor())
            
            let viewId = subview.accessibilityIdentifier ?? "unknown"
            addDimensionLabel(to: subview, viewId: viewId)
            
            processViewHierarchy(subview)
        }
    }
    
    private func processViewHierarchy(_ view: UIView) {
        addDebugBorder(to: view, color: randomColor())
        
        let viewId = view.accessibilityIdentifier ?? "unknown"
        addDimensionLabel(to: view, viewId: viewId)
        
        for subview in view.subviews {
            processViewHierarchy(subview)
        }
    }
    
    /// Generate a random color for debugging
    private func randomColor() -> UIColor {
        let hue = CGFloat(arc4random() % 256) / 256.0
        return UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: 1.0)
    }
    
    /// Print the view hierarchy with proper indentation
    func printViewHierarchy(_ view: UIView, level: Int = 0) {
        let indentation = String(repeating: "  ", count: level)
        let viewType = String(describing: type(of: view))
        let viewId = view.accessibilityIdentifier ?? "unknown"
        let frame = view.frame
        
        
        let hasExplicitDimensions = objc_getAssociatedObject(view, 
                                  UnsafeRawPointer(bitPattern: "hasExplicitDimensions".hashValue)!) as? Bool ?? false
        
        if hasExplicitDimensions {
        }
        
        for subview in view.subviews {
            printViewHierarchy(subview, level: level + 1)
        }
    }
}
