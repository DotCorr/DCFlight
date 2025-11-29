/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Based on React Native's RCTShadowView+Hierarchy.m (1:1 adaptation)
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

