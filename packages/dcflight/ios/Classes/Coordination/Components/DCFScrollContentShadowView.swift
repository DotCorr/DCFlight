/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import yoga

/**
 * Shadow view for ScrollContentView
 * Handles RTL layout compensation
 */
public class DCFScrollContentShadowView: DCFShadowView {
    
    public required override init(viewId: Int) {
        super.init(viewId: viewId)
    }
    
    public override func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
        // Call super method if LTR layout is enforced.
        if effectiveLayoutDirection == .leftToRight {
            super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
            return
        }
        
        // Motivation:
        // Yoga places `contentView` on the right side of `scrollView` when RTL layout is enforced.
        // That breaks everything; it is completely pointless to (re)position `contentView`
        // because it is `contentView`'s job. So, we work around it here.
        
        // Step 1. Compensate `absolutePosition` change.
        var newAbsolutePosition = absolutePosition
        let xCompensation = CGFloat(YGNodeLayoutGetRight(node) - YGNodeLayoutGetLeft(node))
        newAbsolutePosition.x += xCompensation
        
        // Step 2. Call super method.
        super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: newAbsolutePosition)
        
        // Step 3. Reset the position.
        let roundedRight = round(CGFloat(YGNodeLayoutGetRight(node)) * UIScreen.main.scale) / UIScreen.main.scale
        frame.origin.x = roundedRight
    }
}

