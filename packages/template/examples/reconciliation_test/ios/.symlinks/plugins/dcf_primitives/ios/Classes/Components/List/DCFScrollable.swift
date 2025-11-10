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
    var virtualizedContentOffsetStart: CGFloat = 0
    var virtualizedContentPaddingTop: CGFloat = 0
    var nodeId: String?
    
    private var explicitContentSize: CGSize?
    private var lastFrameSize: CGSize = .zero
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
    }
    
    /// Update content size based on Yoga layout results - React Native VirtualizedList approach
    func updateContentSizeFromYogaLayout() {
        guard !isUpdatingContentSize else { return }
        isUpdatingContentSize = true
        defer { isUpdatingContentSize = false }
        
        if let explicitSize = explicitContentSize {
            self.contentSize = explicitSize
            return
        }
        
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for subview in self.subviews {
            let className = NSStringFromClass(type(of: subview))
            guard !className.contains("UIScrollView") && !className.contains("_UIScrollViewScrollIndicator") else { continue }
            
            let right = subview.frame.origin.x + subview.frame.size.width
            let bottom = subview.frame.origin.y + subview.frame.size.height
            
            maxWidth = max(maxWidth, right)
            maxHeight = max(maxHeight, bottom)
        }
        
        if virtualizedContentOffsetStart > 0 || virtualizedContentPaddingTop > 0 {
            let extraPadding = max(virtualizedContentOffsetStart, virtualizedContentPaddingTop)
            
            if isHorizontal {
                maxWidth += extraPadding
                
                for subview in self.subviews {
                    let className = NSStringFromClass(type(of: subview))
                    guard !className.contains("UIScrollView") else { continue }
                    
                    var frame = subview.frame
                    frame.origin.x += extraPadding
                    subview.frame = frame
                }
            } else {
                maxHeight += extraPadding
                
                for subview in self.subviews {
                    let className = NSStringFromClass(type(of: subview))
                    guard !className.contains("UIScrollView") else { continue }
                    
                    var frame = subview.frame
                    frame.origin.y += extraPadding
                    subview.frame = frame
                }
            }
        }
        
        let availableWidth = self.frame.width
        let availableHeight = self.frame.height
        
        let finalContentSize: CGSize
        if isHorizontal {
            finalContentSize = CGSize(width: maxWidth, height: availableHeight)
        } else {
            finalContentSize = CGSize(width: availableWidth, height: maxHeight)
        }
        
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
        
        let currentFrameSize = self.frame.size
        
        if lastFrameSize != currentFrameSize && !isUpdatingContentSize {
            lastFrameSize = currentFrameSize
            
            if currentFrameSize.width > 0 && currentFrameSize.height > 0 && self.subviews.count > 0 {
                // 🚀 CRITICAL: Delay to ensure Yoga layout is complete after orientation change
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard !self.isUpdatingContentSize else { return }
                    self.updateContentSizeFromYogaLayout()
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
