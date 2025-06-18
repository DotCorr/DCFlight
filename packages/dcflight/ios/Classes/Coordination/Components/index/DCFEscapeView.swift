/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// ✅ EscapeView: A special container that escapes normal rendering when needed
/// This allows views to be completely removed from the main UI tree while preserving their structure
/// for later use in modals, popovers, or other presentable components.
public class DCFEscapeView: UIView {
    private var escapedChildren: [UIView] = []
    private var isEscaped: Bool = false
    
    /// Escapes children from the main UI tree while preserving them internally
    public func escapeChildren() {
        guard !isEscaped else { return }
        print("🚁 EscapeView: Escaping children from main UI tree")
        
        // Store children temporarily
        escapedChildren = subviews
        
        // Remove all children from the view hierarchy
        subviews.forEach { $0.removeFromSuperview() }
        
        isEscaped = true
        
        // Make this view completely invisible and take ZERO space
        self.isHidden = true
        self.frame = CGRect.zero
        self.bounds = CGRect.zero
        self.alpha = 0.0
        self.isUserInteractionEnabled = false
    }
    
    /// Restores children to the main UI tree
    public func restoreChildren() {
        guard isEscaped else { return }
        print("🚁 EscapeView: Restoring children to main UI tree")
        
        // Add children back
        escapedChildren.forEach { addSubview($0) }
        escapedChildren.removeAll()
        
        isEscaped = false
        
        // Make view visible again
        self.isHidden = false
        self.alpha = 1.0
        self.isUserInteractionEnabled = true
    }
    
    /// Returns the escaped children (when escaped) or current subviews (when not escaped)
    public func getEscapedChildren() -> [UIView] {
        return isEscaped ? escapedChildren : subviews
    }
    
    /// Returns whether children are currently escaped
    public var areChildrenEscaped: Bool {
        return isEscaped
    }
}
