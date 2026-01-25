/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import yoga

extension DCFShadowView {
    
    /**
     * Padding as UIEdgeInsets
     */
    public var paddingAsInsets: UIEdgeInsets {
        let yogaNode = self.yogaNode
        return UIEdgeInsets(
            top: CGFloat(YGNodeLayoutGetPadding(yogaNode, YGEdge.top)),
            left: CGFloat(YGNodeLayoutGetPadding(yogaNode, YGEdge.left)),
            bottom: CGFloat(YGNodeLayoutGetPadding(yogaNode, YGEdge.bottom)),
            right: CGFloat(YGNodeLayoutGetPadding(yogaNode, YGEdge.right))
        )
    }
    
    /**
     * Border as UIEdgeInsets
     */
    public var borderAsInsets: UIEdgeInsets {
        let yogaNode = self.yogaNode
        return UIEdgeInsets(
            top: CGFloat(YGNodeLayoutGetBorder(yogaNode, YGEdge.top)),
            left: CGFloat(YGNodeLayoutGetBorder(yogaNode, YGEdge.left)),
            bottom: CGFloat(YGNodeLayoutGetBorder(yogaNode, YGEdge.bottom)),
            right: CGFloat(YGNodeLayoutGetBorder(yogaNode, YGEdge.right))
        )
    }
    
    /**
     * Compound insets (border + padding)
     */
    public var compoundInsets: UIEdgeInsets {
        let borderInsets = self.borderAsInsets
        let paddingInsets = self.paddingAsInsets
        
        return UIEdgeInsets(
            top: borderInsets.top + paddingInsets.top,
            left: borderInsets.left + paddingInsets.left,
            bottom: borderInsets.bottom + paddingInsets.bottom,
            right: borderInsets.right + paddingInsets.right
        )
    }
    
}

