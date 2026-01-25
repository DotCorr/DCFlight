/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 *
 */

import UIKit

extension DCFShadowView {
    
    /**
     * Returns the root shadow view by traversing up the parent chain
     */
    public var rootView: DCFRootShadowView? {
        var view: DCFShadowView? = self
        while view != nil && !(view is DCFRootShadowView) {
            view = view?.superview
        }
        return view as? DCFRootShadowView
    }
}

