/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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

