/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

/**
 * UIView extension for layout guide utilities
 * 
 * Provides methods to find view controllers and calculate content insets based on layout guides.
 */
extension UIView {
    /**
     * Find the first view controller whose view, or any subview is the specified view.
     * 
     */
    @objc public var dcfViewController: UIViewController? {
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let viewController = currentResponder as? UIViewController {
                return viewController
            }
            responder = currentResponder.next
        }
        return nil
    }
    
    /**
     * Find content insets for a view based on its view controller's layout guides.
     */
    @objc public static func contentInsets(for view: UIView) -> UIEdgeInsets {
        var currentView: UIView? = view
        while let viewToCheck = currentView {
            if let controller = viewToCheck.dcfViewController {
                // Check if controller implements DCFViewControllerProtocol
                if let dcfController = controller as? DCFViewControllerProtocol {
                    return UIEdgeInsets(
                        top: dcfController.currentTopLayoutGuide.length,
                        left: 0,
                        bottom: dcfController.currentBottomLayoutGuide.length,
                        right: 0
                    )
                } else {
                    // Fallback to standard layout guides
                    return UIEdgeInsets(
                        top: controller.topLayoutGuide.length,
                        left: 0,
                        bottom: controller.bottomLayoutGuide.length,
                        right: 0
                    )
                }
            }
            currentView = viewToCheck.superview
        }
        return .zero
    }
    
    /**
     * Automatically adjust content insets for a scroll view based on layout guides.
     * 
     */
    @objc public static func autoAdjustInsets(
        for parentView: DCFAutoInsetsProtocol,
        with scrollView: UIScrollView,
        updateOffset: Bool
    ) {
        let baseInset = parentView.contentInset
        let previousInsetTop = scrollView.contentInset.top
        var contentOffset = scrollView.contentOffset
        
        var finalInset = baseInset
        
        if parentView.automaticallyAdjustContentInsets {
            // Get layout guide insets from the view hierarchy
            let autoInset = UIView.contentInsets(for: parentView as! UIView)
            finalInset.top += autoInset.top
            finalInset.bottom += autoInset.bottom
            finalInset.left += autoInset.left
            finalInset.right += autoInset.right
        }
        
        scrollView.contentInset = finalInset
        scrollView.scrollIndicatorInsets = finalInset
        
        if updateOffset {
            // If we're adjusting the top inset, then let's also adjust the contentOffset so that the view
            // elements above the top guide do not cover the content.
            // This is generally only needed when your views are initially laid out, for
            // manual changes to contentOffset, you can optionally disable this step
            let currentInsetTop = scrollView.contentInset.top
            if currentInsetTop != previousInsetTop {
                contentOffset.y -= (currentInsetTop - previousInsetTop)
                scrollView.contentOffset = contentOffset
            }
        }
    }
}

