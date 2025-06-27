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
class VirtualizedScrollView: UIScrollView {
    
    // VirtualizedList properties
    var isHorizontal: Bool = false
    var virtualizedContentOffsetStart: CGFloat = 0
    var virtualizedContentPaddingTop: CGFloat = 0
    var nodeId: String?
    
    // Track whether content size was explicitly set
    private var explicitContentSize: CGSize?
    private var lastFrameSize: CGSize = .zero
    private var isUpdatingContentSize: Bool = false // Prevent redundant calculations
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupVirtualizedScrollView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupVirtualizedScrollView()
    }
    
    private func setupVirtualizedScrollView() {
        // Configure for VirtualizedList behavior
        self.clipsToBounds = true
    }
    
    /// Update content size based on Yoga layout results - React Native VirtualizedList approach
    func updateContentSizeFromYogaLayout() {
        // Prevent redundant calculations during orientation changes
        guard !isUpdatingContentSize else { return }
        isUpdatingContentSize = true
        defer { isUpdatingContentSize = false }
        
        // If content size was explicitly set, use that
        if let explicitSize = explicitContentSize {
            self.contentSize = explicitSize
            return
        }
        
        // 🚀 FIXED: Calculate content size from DIRECT CHILDREN ONLY - no deep recursion
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        // Only look at immediate children of the scroll view - this is the correct approach
        for subview in self.subviews {
            // Skip system scroll indicator views
            let className = NSStringFromClass(type(of: subview))
            guard !className.contains("UIScrollView") && !className.contains("_UIScrollViewScrollIndicator") else { continue }
            
            // Use the subview's actual frame (already positioned by Yoga)
            let right = subview.frame.origin.x + subview.frame.size.width
            let bottom = subview.frame.origin.y + subview.frame.size.height
            
            maxWidth = max(maxWidth, right)
            maxHeight = max(maxHeight, bottom)
        }
        
        // Apply virtualized content padding/offset
        if virtualizedContentOffsetStart > 0 || virtualizedContentPaddingTop > 0 {
            let extraPadding = max(virtualizedContentOffsetStart, virtualizedContentPaddingTop)
            
            if isHorizontal {
                maxWidth += extraPadding
                
                // Reposition existing subviews to add space at the start
                for subview in self.subviews {
                    let className = NSStringFromClass(type(of: subview))
                    guard !className.contains("UIScrollView") else { continue }
                    
                    var frame = subview.frame
                    frame.origin.x += extraPadding
                    subview.frame = frame
                }
            } else {
                maxHeight += extraPadding
                
                // Reposition existing subviews to add space at the top
                for subview in self.subviews {
                    let className = NSStringFromClass(type(of: subview))
                    guard !className.contains("UIScrollView") else { continue }
                    
                    var frame = subview.frame
                    frame.origin.y += extraPadding
                    subview.frame = frame
                }
            }
        }
        
        // 🚀 FIXED: Set content size based purely on content, not viewport
        // Don't force content size to be at least as large as viewport - this was causing the rotation issue
        let availableWidth = self.frame.width
        let availableHeight = self.frame.height
        
        let finalContentSize: CGSize
        if isHorizontal {
            // For horizontal scrolling: content width = actual content width, height = viewport height
            finalContentSize = CGSize(width: maxWidth, height: availableHeight)
        } else {
            // For vertical scrolling: width = viewport width, height = actual content height
            finalContentSize = CGSize(width: availableWidth, height: maxHeight)
        }
        
        // Only update if the content size actually changed to prevent unnecessary updates
        if self.contentSize != finalContentSize {
            self.contentSize = finalContentSize
            
            // Communicate content size update to Dart side
            notifyContentSizeUpdate(finalContentSize)
        }
    }
    
    /// Set explicit content size from Dart side - VirtualizedList approach
    func setExplicitContentSize(_ size: CGSize) {
        explicitContentSize = size
        
        // Only update if different to prevent unnecessary updates
        if self.contentSize != size {
            self.contentSize = size
            
            // Communicate content size update to Dart side
            notifyContentSizeUpdate(size)
        }
    }
    
    /// Notify Dart side of content size updates through simple propagateEvent
    private func notifyContentSizeUpdate(_ size: CGSize) {
        // 🚀 SIMPLIFIED: Use direct propagateEvent like other components
        propagateEvent(on: self, eventName: "onContentSizeChange", data: [
            "contentSize": [
                "width": size.width,
                "height": size.height
            ]
        ])
    }
    
    // Override to prevent UIScrollView from automatically managing content size
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 🚀 IMPROVED: Only update content size when frame size changes AND we have valid bounds
        let currentFrameSize = self.frame.size
        
        if lastFrameSize != currentFrameSize && !isUpdatingContentSize {
            lastFrameSize = currentFrameSize
            
            // Only update content size if we have a valid frame and actual content
            if currentFrameSize.width > 0 && currentFrameSize.height > 0 && self.subviews.count > 0 {
                // 🚀 CRITICAL: Delay to ensure Yoga layout is complete after orientation change
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Double-check we're not in the middle of another update
                    guard !self.isUpdatingContentSize else { return }
                    self.updateContentSizeFromYogaLayout()
                }
            }
        }
    }
    
    // 🚀 IMPROVED: Handle trait collection changes (including orientation)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Clear explicit content size during orientation changes to allow proper recalculation
        if let previous = previousTraitCollection,
           previous.verticalSizeClass != self.traitCollection.verticalSizeClass ||
           previous.horizontalSizeClass != self.traitCollection.horizontalSizeClass {
            explicitContentSize = nil
        }
    }
}
