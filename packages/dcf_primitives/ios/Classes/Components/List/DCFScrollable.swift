/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/// Custom UIScrollView that implements VirtualizedList content size management
/// Key insight: Yoga handles layout, but contentSize must be explicitly managed
class DCFScrollableView: UIScrollView {
    
    var isHorizontal: Bool = false
    var nodeId: String?
    
    private var explicitContentSize: CGSize?
    private var isUpdatingContentSize: Bool = false // Prevent redundant calculations
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDCFScrollableView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDCFScrollableView()
    }
    
    private func setupDCFScrollableView() {
        self.clipsToBounds = true
        // Important: Ensure contentInsetAdjustmentBehavior is automatic or never, depending on needs
        // For now, let's stick to default, but be aware of it.
        if #available(iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
    }
    
    /// Update content size based on Yoga layout results
    ///
    /// Simplified approach:
    /// 1. Iterate over direct subviews (which are Yoga nodes).
    /// 2. Find the maximum extent (maxX, maxY).
    /// 3. Set contentSize to that extent.
    func updateContentSizeFromYogaLayout() {
        guard !isUpdatingContentSize else { return }
        isUpdatingContentSize = true
        defer { isUpdatingContentSize = false }
        
        if let explicitSize = explicitContentSize {
            self.contentSize = explicitSize
            return
        }
        
        // Ensure layout is up to date
        self.layoutIfNeeded()
        
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        
        // Get all content children (exclude scroll indicators)
        let contentChildren = self.subviews.filter { subview in
            let className = NSStringFromClass(type(of: subview))
            return !className.contains("UIScrollView") && !className.contains("_UIScrollViewScrollIndicator")
        }
        
        for child in contentChildren {
            // Trust the frame set by Yoga/Layout system
            let right = child.frame.maxX
            let bottom = child.frame.maxY
            
            maxX = max(maxX, right)
            maxY = max(maxY, bottom)
        }
        
        // Ensure content size is at least the size of the scroll view if needed,
        // but typically scroll view content size should just be the content.
        // If content is smaller than viewport, it won't scroll (which is correct).
        
        let finalContentSize = CGSize(width: maxX, height: maxY)
        
        if self.contentSize != finalContentSize {
            self.contentSize = finalContentSize
            notifyContentSizeUpdate(finalContentSize)
        }
    }
    
    /// Set explicit content size from Dart side - VirtualizedList approach
    func setExplicitContentSize(_ size: CGSize) {
        explicitContentSize = size
        
        if self.contentSize != size {
            self.contentSize = size
            notifyContentSizeUpdate(size)
        }
    }
    
    /// Notify Dart side of content size updates through simple propagateEvent
    private func notifyContentSizeUpdate(_ size: CGSize) {
        propagateEvent(on: self, eventName: "onContentSizeChange", data: [
            "contentSize": [
                "width": size.width,
                "height": size.height
            ]
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Check if we need to update content size
        // We can do this check cheaply
        if !isUpdatingContentSize {
             // Debounce or check if update is needed?
             // For now, let's just trigger it if we have children
             if self.subviews.count > 0 {
                 // Use a small delay or run on next runloop to allow layout to settle
                 DispatchQueue.main.async { [weak self] in
                     self?.updateContentSizeFromYogaLayout()
                 }
             }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if let previous = previousTraitCollection,
           previous.verticalSizeClass != self.traitCollection.verticalSizeClass ||
           previous.horizontalSizeClass != self.traitCollection.horizontalSizeClass {
            explicitContentSize = nil
        }
    }
}
