/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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

