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
    
    // FIXED: Better orientation change tracking
    private var lastOrientation: UIDeviceOrientation = UIDevice.current.orientation
    private var isOrientationTransitioning: Bool = false
    private var orientationUpdateTimer: Timer?
    
    // FIXED: Track if we're in the middle of a layout update to prevent recursion
    private var isUpdatingContentSize: Bool = false
    
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
        
        // FIXED: Listen for orientation changes with better handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationWillChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Also listen for view controller transition events for better coordination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewControllerWillTransition),
            name: NSNotification.Name("UIViewControllerWillBeginRotation"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewControllerDidTransition),
            name: NSNotification.Name("UIViewControllerDidEndRotation"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        orientationUpdateTimer?.invalidate()
    }
    
    // MARK: - Orientation Change Handling
    
    @objc private func orientationWillChange() {
        print("🔄 VirtualizedScrollView: Orientation will change")
        isOrientationTransitioning = true
        
        // Cancel any pending updates during transition
        orientationUpdateTimer?.invalidate()
    }
    
    @objc private func viewControllerWillTransition() {
        print("🔄 VirtualizedScrollView: View controller will begin rotation")
        isOrientationTransitioning = true
    }
    
    @objc private func viewControllerDidTransition() {
        print("🔄 VirtualizedScrollView: View controller did end rotation")
        isOrientationTransitioning = false
        
        // Schedule content size update after rotation is complete
        scheduleOrientationContentSizeUpdate()
    }
    
    @objc private func orientationDidChange() {
        let currentOrientation = UIDevice.current.orientation
        
        // Skip if orientation is unknown or face up/down
        guard currentOrientation != .unknown && 
              currentOrientation != .faceUp && 
              currentOrientation != .faceDown else {
            return
        }
        
        print("🔄 VirtualizedScrollView: Orientation changed from \(lastOrientation.rawValue) to \(currentOrientation.rawValue)")
        print("🔄 Current frame: \(self.frame)")
        print("🔄 Current contentSize: \(self.contentSize)")
        
        if currentOrientation != lastOrientation {
            lastOrientation = currentOrientation
            
            // CRITICAL: Clear explicit content size on orientation change
            let hadExplicitSize = explicitContentSize != nil
            explicitContentSize = nil
            print("🔄 Cleared explicit content size (was set: \(hadExplicitSize))")
            
            // Mark that we're transitioning
            isOrientationTransitioning = true
            
            // Schedule update after a delay to ensure frame has been updated
            scheduleOrientationContentSizeUpdate()
        }
    }
    
    private func scheduleOrientationContentSizeUpdate() {
        // Cancel any existing timer
        orientationUpdateTimer?.invalidate()
        
        // FIXED: Use longer delay to ensure all layout changes are complete
        orientationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            print("🔄 Executing scheduled orientation content size update")
            print("🔄 Frame at update time: \(self.frame)")
            print("🔄 ContentSize before update: \(self.contentSize)")
            
            // Mark transition as complete
            self.isOrientationTransitioning = false
            
            // Force content size recalculation
            self.forceContentSizeRecalculation()
        }
    }
    
    // MARK: - Content Size Management
    
    /// Force content size recalculation - used after orientation changes
    private func forceContentSizeRecalculation() {
        // Prevent recursion
        guard !isUpdatingContentSize else {
            print("📐 Skipping content size update - already updating")
            return
        }
        
        // Clear explicit content size to force recalculation
        explicitContentSize = nil
        
        // Update immediately
        updateContentSizeFromYogaLayout()
    }
    
    /// Update content size based on Yoga layout results - React Native VirtualizedList approach
    func updateContentSizeFromYogaLayout() {
        // Prevent recursion during updates
        guard !isUpdatingContentSize else {
            print("📐 Skipping updateContentSizeFromYogaLayout - already updating")
            return
        }
        
        isUpdatingContentSize = true
        defer { isUpdatingContentSize = false }
        
        // FIXED: Always use current frame dimensions, not cached values
        let currentFrameWidth = self.frame.width
        let currentFrameHeight = self.frame.height
        
        print("📐 updateContentSizeFromYogaLayout called")
        print("📐   Current frame: \(currentFrameWidth) x \(currentFrameHeight)")
        print("📐   Last frame: \(lastFrameSize)")
        print("📐   Current contentSize: \(self.contentSize)")
        print("📐   Has explicit size: \(explicitContentSize != nil)")
        print("📐   Is transitioning: \(isOrientationTransitioning)")
        
        // Skip if we don't have valid dimensions yet
        guard currentFrameWidth > 0 && currentFrameHeight > 0 else {
            print("📐   Skipping - invalid frame dimensions")
            return
        }
        
        // Skip if we're in the middle of orientation transition (wait for it to complete)
        guard !isOrientationTransitioning else {
            print("📐   Skipping - orientation transition in progress")
            return
        }
        
        // If content size was explicitly set and frame hasn't changed significantly, use that
        if let explicitSize = explicitContentSize {
            let frameChanged = abs(lastFrameSize.width - currentFrameWidth) > 10.0 || 
                              abs(lastFrameSize.height - currentFrameHeight) > 10.0
            
            if !frameChanged {
                print("📐   Using explicit content size: \(explicitSize)")
                self.contentSize = explicitSize
                lastFrameSize = CGSize(width: currentFrameWidth, height: currentFrameHeight)
                return
            } else {
                print("📐   Frame changed significantly, clearing explicit size")
                explicitContentSize = nil
            }
        }
        
        print("📐   Calculating content size from subviews...")
        
        // Calculate content size from Yoga layout results
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        // Force layout of subviews first to ensure we have accurate positions
        self.layoutIfNeeded()
        
        // Recursively get the natural content size from ALL descendant views after Yoga layout
        func calculateMaxBounds(from view: UIView, offset: CGPoint = CGPoint.zero) {
            for subview in view.subviews {
                // Skip system scroll indicator views
                let className = NSStringFromClass(type(of: subview))
                guard !className.contains("UIScrollView") && 
                      !className.contains("_UIScrollViewScrollIndicator") &&
                      !className.contains("UIFieldEditor") else { 
                    continue 
                }
                
                // Skip if subview has zero or invalid frame
                guard subview.frame.width > 0 && subview.frame.height > 0 &&
                      subview.frame.width.isFinite && subview.frame.height.isFinite else {
                    continue
                }
                
                // Calculate absolute position relative to scroll view
                let absoluteFrame = subview.convert(subview.bounds, to: self)
                let right = absoluteFrame.origin.x + absoluteFrame.size.width
                let bottom = absoluteFrame.origin.y + absoluteFrame.size.height
                
                // Only consider positive coordinates
                if right > 0 {
                    maxWidth = max(maxWidth, right)
                }
                if bottom > 0 {
                    maxHeight = max(maxHeight, bottom)
                }
                
                print("📐     Subview \(className): frame=\(subview.frame), absolute=\(absoluteFrame)")
                
                // Recursively check subviews
                calculateMaxBounds(from: subview, offset: CGPoint(x: offset.x + subview.frame.origin.x, y: offset.y + subview.frame.origin.y))
            }
        }
        
        // Start recursive calculation from scroll view's direct children
        calculateMaxBounds(from: self)
        
        print("📐   Max bounds from subviews: \(maxWidth) x \(maxHeight)")
        
        // Apply virtualized content padding/offset
        if virtualizedContentOffsetStart > 0 || virtualizedContentPaddingTop > 0 {
            let extraPadding = max(virtualizedContentOffsetStart, virtualizedContentPaddingTop)
            print("📐   Applying extra padding: \(extraPadding)")
            
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
        
        // FIXED: Calculate final content size with proper minimum dimensions
        let finalContentSize: CGSize
        if isHorizontal {
            // For horizontal scrolling, content width should be at least as wide as the found max width
            // but content height should match the current frame height
            finalContentSize = CGSize(
                width: max(maxWidth, currentFrameWidth), 
                height: currentFrameHeight
            )
        } else {
            // For vertical scrolling, content height should be at least as tall as the found max height
            // but content width should match the current frame width
            finalContentSize = CGSize(
                width: currentFrameWidth, 
                height: max(maxHeight, currentFrameHeight)
            )
        }
        
        print("📐   Final calculated content size: \(finalContentSize)")
        
        // CRITICAL: Only update if the content size actually changed significantly
        let currentContentSize = self.contentSize
        let widthDiff = abs(currentContentSize.width - finalContentSize.width)
        let heightDiff = abs(currentContentSize.height - finalContentSize.height)
        
        if widthDiff > 1.0 || heightDiff > 1.0 {
            print("📐   Content size changed significantly, updating from \(currentContentSize) to \(finalContentSize)")
            self.contentSize = finalContentSize
            
            // Communicate content size update to Dart side
            notifyContentSizeUpdate(finalContentSize)
        } else {
            print("📐   Content size unchanged, skipping update")
        }
        
        // Update last frame size tracking
        lastFrameSize = CGSize(width: currentFrameWidth, height: currentFrameHeight)
    }
    
    /// Set explicit content size from Dart side - VirtualizedList approach
    func setExplicitContentSize(_ size: CGSize) {
        print("📐 Setting explicit content size: \(size)")
        explicitContentSize = size
        self.contentSize = size
        
        // Update tracking
        lastFrameSize = self.frame.size
        
        // Communicate content size update to Dart side
        notifyContentSizeUpdate(size)
    }
    
    /// Notify Dart side of content size updates through simple propagateEvent
    private func notifyContentSizeUpdate(_ size: CGSize) {
        print("📐 Notifying content size update: \(size)")
        propagateEvent(on: self, eventName: "onContentSizeChange", data: [
            "contentSize": [
                "width": size.width,
                "height": size.height
            ]
        ])
    }
    
    // MARK: - UIScrollView Overrides
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Don't update during orientation transitions
        guard !isOrientationTransitioning else {
            print("📐 layoutSubviews: Skipping during orientation transition")
            return
        }
        
        let currentFrameSize = self.frame.size
        
        print("📐 VirtualizedScrollView layoutSubviews:")
        print("📐   Current frame: \(currentFrameSize)")
        print("📐   Last frame: \(lastFrameSize)")
        print("📐   Current contentSize: \(self.contentSize)")
        print("📐   Is updating: \(isUpdatingContentSize)")
        
        // Update if frame size changed or if we don't have valid content size yet
        let frameChanged = abs(lastFrameSize.width - currentFrameSize.width) > 10.0 || 
                          abs(lastFrameSize.height - currentFrameSize.height) > 10.0
        let needsContentSizeUpdate = frameChanged || contentSize.width <= 0 || contentSize.height <= 0
        
        print("📐   Frame changed significantly: \(frameChanged)")
        print("📐   Needs content size update: \(needsContentSizeUpdate)")
        
        if needsContentSizeUpdate && currentFrameSize.width > 0 && currentFrameSize.height > 0 && !isUpdatingContentSize {
            // Clear explicit content size when frame changes to force recalculation
            if frameChanged {
                let hadExplicitSize = explicitContentSize != nil
                explicitContentSize = nil
                print("📐   Cleared explicit content size due to frame change (was set: \(hadExplicitSize))")
            }
            
            // Determine update timing based on change magnitude
            let frameDeltaWidth = abs(currentFrameSize.width - lastFrameSize.width)
            let frameDeltaHeight = abs(currentFrameSize.height - lastFrameSize.height)
            let isLargeFrameChange = frameDeltaWidth > 100 || frameDeltaHeight > 100
            
            print("📐   Frame delta: \(frameDeltaWidth) x \(frameDeltaHeight), large change: \(isLargeFrameChange)")
            
            if isLargeFrameChange {
                // Large frame change (likely orientation) - use delay
                print("📐   Scheduling delayed content size update for orientation change")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateContentSizeFromYogaLayout()
                }
            } else {
                // Small frame change - update immediately
                print("📐   Scheduling immediate content size update")
                DispatchQueue.main.async {
                    self.updateContentSizeFromYogaLayout()
                }
            }
        }
    }
    
    // FIXED: Override bounds setter to catch all frame changes
    override var bounds: CGRect {
        didSet {
            // Skip during transitions to prevent interference
            guard !isOrientationTransitioning else {
                return
            }
            
            print("🔲 VirtualizedScrollView bounds changed:")
            print("🔲   Old bounds: \(oldValue)")
            print("🔲   New bounds: \(bounds)")
            
            if abs(bounds.size.width - oldValue.size.width) > 10.0 || 
               abs(bounds.size.height - oldValue.size.height) > 10.0 {
                print("🔲   Bounds size changed significantly, triggering content size recalculation")
                
                // Clear explicit content size to force recalculation
                explicitContentSize = nil
                
                // Update with slight delay to ensure stability
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.updateContentSizeFromYogaLayout()
                }
            }
        }
    }
    
    // FIXED: Override frame setter as well
    override var frame: CGRect {
        didSet {
            // Skip during transitions
            guard !isOrientationTransitioning else {
                return
            }
            
            let oldSize = oldValue.size
            let newSize = frame.size
            
            if abs(newSize.width - oldSize.width) > 10.0 || 
               abs(newSize.height - oldSize.height) > 10.0 {
                print("📱 VirtualizedScrollView frame size changed significantly:")
                print("📱   Old size: \(oldSize)")
                print("📱   New size: \(newSize)")
                
                // Clear explicit content size to force recalculation
                explicitContentSize = nil
                
                // Update with slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.updateContentSizeFromYogaLayout()
                }
            }
        }
    }
}