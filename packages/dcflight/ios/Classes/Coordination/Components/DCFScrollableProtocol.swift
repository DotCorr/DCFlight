/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/**
 * Protocol for scrollable views
 * Any view that has scrolling features should implement these methods.
 */
@objc public protocol DCFScrollableProtocol {
    var contentSize: CGSize { get }
    
    func scrollToOffset(_ offset: CGPoint)
    func scrollToOffset(_ offset: CGPoint, animated: Bool)
    
    /**
     * If this is a vertical scroll view, scrolls to the bottom.
     * If this is a horizontal scroll view, scrolls to the right.
     */
    func scrollToEnd(_ animated: Bool)
    func zoomToRect(_ rect: CGRect, animated: Bool)
    
    func addScrollListener(_ scrollListener: UIScrollViewDelegate)
    func removeScrollListener(_ scrollListener: UIScrollViewDelegate)
}

