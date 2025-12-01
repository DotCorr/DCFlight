/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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

