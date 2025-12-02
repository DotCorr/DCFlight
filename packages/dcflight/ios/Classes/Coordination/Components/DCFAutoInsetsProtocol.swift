/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/**
 * Defines a View that wants to support auto insets adjustment
 * 
 */
@objc public protocol DCFAutoInsetsProtocol {
    var contentInset: UIEdgeInsets { get set }
    var automaticallyAdjustContentInsets: Bool { get set }
    
    /**
     * Automatically adjusted content inset depends on view controller's top and bottom
     * layout guides so if you've changed one of them (e.g. after rotation or manually) you should call this method
     * to recalculate and refresh content inset.
     * To handle case with changing navigation bar height call this method from viewDidLayoutSubviews:
     * of your view controller.
     */
    func refreshContentInset()
}

