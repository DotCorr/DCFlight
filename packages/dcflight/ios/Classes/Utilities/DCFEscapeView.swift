/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// 🚁 DCFEscapeView: A special container that escapes normal rendering
/// 
/// This view allows components to completely remove their children from the main UI tree
/// when they don't need to be rendered (e.g., modal content when modal is hidden).
/// This prevents content leak and ensures proper presentation layer separation.
/// 
/// Used by:
/// - DCFModal (children escaped when modal not visible)
/// - Future presentables (alerts, overlays, etc.)
public class DCFEscapeView: UIView {
    private var escapedChildren: [UIView] = []
    private var isEscaped: Bool = false
    
    /// Escapes all children from the main UI tree
    /// Children are stored internally but not rendered in the main view hierarchy
    public func escapeChildren() {
        guard !isEscaped else { return }
        print("🚁 DCFEscapeView: Escaping \(subviews.count) children from main UI tree")
        
        // Store children temporarily
        escapedChildren = Array(subviews)
        
        // Remove all children from the view hierarchy
        subviews.forEach { $0.removeFromSuperview() }
        
        isEscaped = true
        
        // Make this view completely invisible and take ZERO space
        self.isHidden = true
        self.frame = CGRect.zero
        self.bounds = CGRect.zero
        self.alpha = 0.0
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
    }
    
    /// Restores escaped children back to the main UI tree
    public func restoreChildren() {
        guard isEscaped else { return }
        print("🚁 DCFEscapeView: Restoring \(escapedChildren.count) children to main UI tree")
        
        // Add children back
        escapedChildren.forEach { addSubview($0) }
        escapedChildren.removeAll()
        
        isEscaped = false
        
        // Make view visible again (if needed)
        self.isHidden = false
        self.alpha = 1.0
        self.isUserInteractionEnabled = true
    }
    
    /// Gets the current children, whether escaped or in the view hierarchy
    public func getEscapedChildren() -> [UIView] {
        return isEscaped ? escapedChildren : subviews
    }
    
    /// Whether children are currently escaped
    public var areChildrenEscaped: Bool {
        return isEscaped
    }
    
    /// Adds a child to the escape view
    /// If escaped, child is stored but not added to hierarchy
    public override func addSubview(_ view: UIView) {
        if isEscaped {
            escapedChildren.append(view)
        } else {
            super.addSubview(view)
        }
    }
    
    /// Forces zero intrinsic size to prevent layout issues
    public override var intrinsicContentSize: CGSize {
        return CGSize.zero
    }
}
