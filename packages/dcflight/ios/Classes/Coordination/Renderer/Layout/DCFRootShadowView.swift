/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import yoga

/**
 * Root shadow view for the entire view hierarchy
 */
public class DCFRootShadowView: DCFShadowView {
    
    /**
     * Available size to layout all views.
     * Defaults to {INFINITY, INFINITY}
     * Overrides the computed property from DCFShadowView+Layout extension
     */
    private var _availableSize: CGSize = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
    
    public override var availableSize: CGSize {
        get {
            return _availableSize
        }
        set {
            _availableSize = newValue
            // Mark as dirty when available size changes
            dirtyPropagation()
        }
    }
    
    /**
     * Layout direction (LTR or RTL) inherited from native environment and
     * is using as a base direction value in layout engine.
     * Defaults to LTR.
     */
    public var baseDirection: YGDirection = .LTR
    
    public required override init(viewId: Int) {
        super.init(viewId: viewId)
    }
    
    /**
     * Calculate all views whose frame needs updating after layout has been calculated.
     * Returns a set contains the shadowviews that need updating.
     */
    public func collectViewsWithUpdatedFrames() -> Set<DCFShadowView> {
        // Treating `INFINITY` as undefined (which equals `Float.nan`).
        // Yoga API: YGNodeCalculateLayout accepts Float, use Float.nan for undefined
        let availableWidth = availableSize.width == .infinity ? Float.nan : Float(availableSize.width)
        let availableHeight = availableSize.height == .infinity ? Float.nan : Float(availableSize.height)
        
        YGNodeCalculateLayout(yogaNode, availableWidth, availableHeight, baseDirection)
        
        let viewsWithNewFrame = NSMutableSet()
        applyLayoutNode(yogaNode, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: .zero)
        
        return Set(viewsWithNewFrame.allObjects as! [DCFShadowView])
    }
}

