/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

/**
 * Protocol for scrollable views (1:1 with React Native's RCTScrollableProtocol)
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











