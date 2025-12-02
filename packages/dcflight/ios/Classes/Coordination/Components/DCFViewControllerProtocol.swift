/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/**
 * A simple protocol that any DCFlight-managed ViewControllers should implement.
 * We need all of our ViewControllers to cache layoutGuide changes so any View
 * in our View hierarchy can access accurate layoutGuide info at any time.
 * 
 */
@objc public protocol DCFViewControllerProtocol {
    var currentTopLayoutGuide: UILayoutSupport { get }
    var currentBottomLayoutGuide: UILayoutSupport { get }
}

