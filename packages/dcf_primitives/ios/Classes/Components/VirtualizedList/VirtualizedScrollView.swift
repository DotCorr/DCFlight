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
        // If content size was explicitly set, use that
        if let explicitSize = explicitContentSize {
            self.contentSize = explicitSize
            print("📏 VirtualizedScrollView: Using explicit content size: \(explicitSize)")
            return
        }
        
        // Calculate content size from Yoga layout results
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        // Recursively get the natural content size from ALL descendant views after Yoga layout
        // This is crucial because content might be nested deep in the view hierarchy
        func calculateMaxBounds(from view: UIView, offset: CGPoint = CGPoint.zero) {
            for subview in view.subviews {
                // Skip system scroll indicator views
                let className = NSStringFromClass(type(of: subview))
                guard !className.contains("UIScrollView") && !className.contains("_UIScrollViewScrollIndicator") else { continue }
                
                // Calculate absolute position relative to scroll view
                let absoluteFrame = subview.convert(subview.bounds, to: self)
                let right = absoluteFrame.origin.x + absoluteFrame.size.width
                let bottom = absoluteFrame.origin.y + absoluteFrame.size.height
                
                maxWidth = max(maxWidth, right)
                maxHeight = max(maxHeight, bottom)
                
                print("📐 VirtualizedScrollView: Found view at absolute bounds: \(absoluteFrame) -> maxWidth: \(maxWidth), maxHeight: \(maxHeight)")
                
                // Recursively check subviews
                calculateMaxBounds(from: subview, offset: CGPoint(x: offset.x + subview.frame.origin.x, y: offset.y + subview.frame.origin.y))
            }
        }
        
        // Start recursive calculation from scroll view's direct children
        calculateMaxBounds(from: self)
        
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
        
        // Set content size based on layout direction
        let availableWidth = self.frame.width
        let availableHeight = self.frame.height
        
        let finalContentSize: CGSize
        if isHorizontal {
            // For horizontal scrolling, content width should be at least as wide as the found max width
            finalContentSize = CGSize(width: max(maxWidth, availableWidth), height: availableHeight)
        } else {
            // For vertical scrolling, content height should be at least as tall as the found max height
            finalContentSize = CGSize(width: availableWidth, height: max(maxHeight, availableHeight))
        }
        
        // This is the key: explicit content size management separate from Yoga layout
        self.contentSize = finalContentSize
        
        print("📏 VirtualizedScrollView: Updated content size to \(finalContentSize)")
        print("📏 VirtualizedScrollView: Available space (frame): \(availableWidth)x\(availableHeight)")
        print("📏 VirtualizedScrollView: Natural content dimensions: (\(maxWidth), \(maxHeight))")
        print("📏 VirtualizedScrollView: Direction: \(isHorizontal ? "horizontal" : "vertical")")
        
        // Communicate content size update to Dart side if needed
        notifyContentSizeUpdate(finalContentSize)
    }
    
    /// Set explicit content size from Dart side - VirtualizedList approach
    func setExplicitContentSize(_ size: CGSize) {
        explicitContentSize = size
        self.contentSize = size
        
        print("📏 VirtualizedScrollView: Set explicit content size: \(size)")
        
        // Communicate content size update to Dart side
        notifyContentSizeUpdate(size)
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
        
        // Update content size after layout if frame size has changed
        // This ensures content size is recalculated when the scroll view is resized
        let currentFrameSize = self.frame.size
        
        if lastFrameSize != currentFrameSize {
            lastFrameSize = currentFrameSize
            
            // Only update content size if we have a valid frame
            if currentFrameSize.width > 0 && currentFrameSize.height > 0 {
                DispatchQueue.main.async {
                    self.updateContentSizeFromYogaLayout()
                }
            }
        }
    }
}
