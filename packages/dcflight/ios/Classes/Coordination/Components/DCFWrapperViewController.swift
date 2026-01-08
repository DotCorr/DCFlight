/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/**
 * DCFWrapperViewController - Wraps DCFlight-managed views in a UIViewController
 * 
 * Purpose:
 * 1. Cache layout guides (topLayoutGuide, bottomLayoutGuide) so views can access them at any time
 * 2. Refresh scroll view content insets when layout guides change (e.g., navigation bar height changes)
 * 3. Prevent UINavigationController from resetting frames for DCFlight-managed views
 * 4. Handle navigation bar appearance and configuration
 * 
 * Used by:
 * - Navigation screens (each screen in navigation stack)
 * - Tab screens (each tab in tab bar)
 */
@objc public class DCFWrapperViewController: UIViewController, DCFViewControllerProtocol {
    private var _wrapperView: UIView?
    private var _contentView: UIView
    private var _previousTopLayoutLength: CGFloat = 0
    private var _previousBottomLayoutLength: CGFloat = 0
    
    @objc public var currentTopLayoutGuide: UILayoutSupport {
        return topLayoutGuide
    }
    
    @objc public var currentBottomLayoutGuide: UILayoutSupport {
        return bottomLayoutGuide
    }
    
    /**
     * Designated initializer - wraps a content view in a view controller
     */
    @objc public init(contentView: UIView) {
        self._contentView = contentView
        super.init(nibName: nil, bundle: nil)
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Layout guides are updated here - we cache them via the protocol
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Refresh scroll view insets when layout guides change
        // This handles cases like navigation bar height changes, rotation, etc.
        let currentTopLength = topLayoutGuide.length
        let currentBottomLength = bottomLayoutGuide.length
        
        if _previousTopLayoutLength != currentTopLength ||
           _previousBottomLayoutLength != currentBottomLength {
            findScrollViewAndRefreshContentInset(in: _contentView)
            _previousTopLayoutLength = currentTopLength
            _previousBottomLayoutLength = currentBottomLength
        }
    }
    
    override public func loadView() {
        // Add a wrapper so that the wrapper view managed by the
        // UINavigationController doesn't end up resetting the frames for
        // contentView which is a DCFlight-managed view.
        _wrapperView = UIView(frame: _contentView.bounds)
        _wrapperView?.addSubview(_contentView)
        self.view = _wrapperView
    }
    
    /**
     * Find scroll views implementing DCFAutoInsetsProtocol and refresh their content insets when layout guides change
     */
    private func findScrollViewAndRefreshContentInset(in view: UIView) -> Bool {
        if let autoInsetsView = view as? DCFAutoInsetsProtocol {
            autoInsetsView.refreshContentInset()
            return true
        }
        
        for subview in view.subviews {
            if findScrollViewAndRefreshContentInset(in: subview) {
                return true
            }
        }
        
        return false
    }
}

