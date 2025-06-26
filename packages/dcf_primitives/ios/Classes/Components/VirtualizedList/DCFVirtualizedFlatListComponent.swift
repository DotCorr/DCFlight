/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

// 🚀 FIXED VIRTUALIZED FLAT LIST COMPONENT - Per-view delegates with clean propagateEvent() and prop-based commands
class DCFVirtualizedFlatListComponent: NSObject, DCFComponent, UIScrollViewDelegate {
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create a VirtualizedScrollView instead of a regular UIScrollView
        let virtualizedScrollView = VirtualizedScrollView()
        
        // 🔧 FIXED: Create a new delegate instance for each scroll view
        let delegateInstance = DCFVirtualizedFlatListComponent()
        virtualizedScrollView.delegate = delegateInstance
        
        // 🔧 CRITICAL: Store the delegate instance on the scroll view to prevent deallocation
        objc_setAssociatedObject(virtualizedScrollView, 
                               UnsafeRawPointer(bitPattern: "delegateInstance".hashValue)!, 
                               delegateInstance, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Configure as a flat list
        virtualizedScrollView.isHorizontal = props["horizontal"] as? Bool ?? false
        
        // Apply basic flat list properties
        virtualizedScrollView.showsVerticalScrollIndicator = true
        virtualizedScrollView.showsHorizontalScrollIndicator = false
        virtualizedScrollView.bounces = true
        virtualizedScrollView.clipsToBounds = true
        
        // Apply adaptive styling
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                virtualizedScrollView.backgroundColor = UIColor.systemBackground
            } else {
                virtualizedScrollView.backgroundColor = UIColor.white
            }
        } else {
            virtualizedScrollView.backgroundColor = UIColor.clear
        }
        
        // Apply props
        updateView(virtualizedScrollView, withProps: props)
        
        // Apply StyleSheet properties
        virtualizedScrollView.applyStyles(props: props)
        
        
        return virtualizedScrollView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let virtualizedScrollView = view as? VirtualizedScrollView else { return false }
        
        // Update horizontal property
        if let horizontal = props["horizontal"] as? Bool {
            virtualizedScrollView.isHorizontal = horizontal
            if horizontal {
                virtualizedScrollView.alwaysBounceHorizontal = true
                virtualizedScrollView.alwaysBounceVertical = false
                virtualizedScrollView.showsHorizontalScrollIndicator = true
                virtualizedScrollView.showsVerticalScrollIndicator = false
            } else {
                virtualizedScrollView.alwaysBounceHorizontal = false
                virtualizedScrollView.alwaysBounceVertical = true
                virtualizedScrollView.showsHorizontalScrollIndicator = false
                virtualizedScrollView.showsVerticalScrollIndicator = true
            }
        }
        
        // Set shows indicator if specified
        if let showsScrollIndicator = props["showsScrollIndicator"] as? Bool {
            if virtualizedScrollView.isHorizontal {
                virtualizedScrollView.showsHorizontalScrollIndicator = showsScrollIndicator
            } else {
                virtualizedScrollView.showsVerticalScrollIndicator = showsScrollIndicator
            }
        }
        
        // Set bounces if specified
        if let bounces = props["bounces"] as? Bool {
            virtualizedScrollView.bounces = bounces
        }
        
        // Set paging enabled if specified
        if let pagingEnabled = props["pagingEnabled"] as? Bool {
            virtualizedScrollView.isPagingEnabled = pagingEnabled
        }
        
        // Set scroll enabled if specified
        if let scrollEnabled = props["scrollEnabled"] as? Bool {
            virtualizedScrollView.isScrollEnabled = scrollEnabled
        }
        
        // Handle background color property
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                virtualizedScrollView.backgroundColor = uiColor
            }
        }
        
        // Handle adaptive color only if explicitly provided and no backgroundColor is set
        if props.keys.contains("adaptive") && !props.keys.contains("backgroundColor") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    virtualizedScrollView.backgroundColor = UIColor.systemBackground
                } else {
                    virtualizedScrollView.backgroundColor = UIColor.white
                }
            }
        }
        
        // Apply styling properties
        if let borderRadius = props["borderRadius"] as? CGFloat {
            virtualizedScrollView.layer.cornerRadius = borderRadius
            virtualizedScrollView.clipsToBounds = true  
        }
        
        if let borderWidth = props["borderWidth"] as? CGFloat {
            virtualizedScrollView.layer.borderWidth = borderWidth
        }
        
        if let borderColor = props["borderColor"] as? String {
            virtualizedScrollView.layer.borderColor = ColorUtilities.color(fromHexString: borderColor)?.cgColor
        }
        
        if let opacity = props["opacity"] as? CGFloat {
            virtualizedScrollView.alpha = opacity
        }
        
        // Store flat list specific properties
        if let contentOffsetStart = props["contentOffsetStart"] as? CGFloat, contentOffsetStart > 0 {
            virtualizedScrollView.virtualizedContentOffsetStart = contentOffsetStart
        }
        
        if let contentPaddingTop = props["contentPaddingTop"] as? CGFloat, contentPaddingTop > 0 {
            virtualizedScrollView.virtualizedContentPaddingTop = contentPaddingTop
        }
        
        // ✅ HANDLE COMMANDS - New prop-based command pattern
        handleCommand(virtualizedScrollView: virtualizedScrollView, props: props)
        
        // Apply StyleSheet properties
        virtualizedScrollView.applyStyles(props: props)
        
        return true
    }
    
    // Custom layout for VirtualizedFlatList - uses VirtualizedScrollView approach
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let virtualizedScrollView = view as? VirtualizedScrollView else { return }
        
        // Step 1: Let Yoga handle the scroll view frame layout
        let newFrame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        virtualizedScrollView.frame = newFrame
        
        
        // Step 2: Immediately update content size from Yoga layout
        // Don't use async here - do it synchronously after frame is set
        virtualizedScrollView.updateContentSizeFromYogaLayout()
    }
    
    // Add a view registration hook for content size updates
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Store node ID on the view
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // For VirtualizedFlatList, use VirtualizedScrollView content size management
        if let virtualizedScrollView = view as? VirtualizedScrollView {
            virtualizedScrollView.nodeId = nodeId
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                virtualizedScrollView.updateContentSizeFromYogaLayout()
            }
        }
    }
    
    // MARK: - Event Handling
    // Note: VirtualizedFlatList uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
    
    // MARK: - Command Handling (New Prop-Based Pattern)
    
    /// Handle commands passed as props - the new declarative command pattern
    private func handleCommand(virtualizedScrollView: VirtualizedScrollView, props: [String: Any]) {
        guard let commandData = props["command"] as? [String: Any],
              let commandType = commandData["type"] as? String else {
            return
        }
        
        switch commandType {
        case "scrollToPosition":
            if let x = commandData["x"] as? CGFloat, let y = commandData["y"] as? CGFloat {
                let animated = commandData["animated"] as? Bool ?? true
                virtualizedScrollView.setContentOffset(CGPoint(x: x, y: y), animated: animated)
            }
        case "scrollToTop":
            let animated = commandData["animated"] as? Bool ?? true
            virtualizedScrollView.setContentOffset(CGPoint(x: virtualizedScrollView.contentOffset.x, y: 0), animated: animated)
        case "scrollToBottom":
            let animated = commandData["animated"] as? Bool ?? true
            let bottomOffset = CGPoint(x: virtualizedScrollView.contentOffset.x, 
                                     y: virtualizedScrollView.contentSize.height - virtualizedScrollView.bounds.height)
            virtualizedScrollView.setContentOffset(bottomOffset, animated: animated)
        case "scrollToIndex":
            // FlatList specific - scroll to a specific item index
            if let index = commandData["index"] as? Int {
                let animated = commandData["animated"] as? Bool ?? true
                scrollToIndex(virtualizedScrollView, index: index, animated: animated)
            }
        case "flashScrollIndicators":
            virtualizedScrollView.flashScrollIndicators()
        case "updateContentSize":
            virtualizedScrollView.updateContentSizeFromYogaLayout()
        case "setContentSize":
            if let width = commandData["width"] as? CGFloat, let height = commandData["height"] as? CGFloat {
                virtualizedScrollView.setExplicitContentSize(CGSize(width: width, height: height))
            }
        default:
            break
        }
    }
    
    // MARK: - FlatList Specific Methods
    
    private func scrollToIndex(_ virtualizedScrollView: VirtualizedScrollView, index: Int, animated: Bool) {
        // Calculate position based on estimated item size and index
        // This is a simplified implementation - in React Native VirtualizedList, 
        // this would use more sophisticated calculations
        
        let estimatedItemHeight: CGFloat = 50 // Default estimated height
        let estimatedItemWidth: CGFloat = 100 // Default estimated width
        
        let targetOffset: CGPoint
        if virtualizedScrollView.isHorizontal {
            let targetX = CGFloat(index) * estimatedItemWidth
            targetOffset = CGPoint(x: targetX, y: virtualizedScrollView.contentOffset.y)
        } else {
            let targetY = CGFloat(index) * estimatedItemHeight
            targetOffset = CGPoint(x: virtualizedScrollView.contentOffset.x, y: targetY)
        }
        
        // Ensure the target offset is within bounds
        let maxOffset = CGPoint(
            x: max(0, virtualizedScrollView.contentSize.width - virtualizedScrollView.bounds.width),
            y: max(0, virtualizedScrollView.contentSize.height - virtualizedScrollView.bounds.height)
        )
        
        let clampedOffset = CGPoint(
            x: min(max(0, targetOffset.x), maxOffset.x),
            y: min(max(0, targetOffset.y), maxOffset.y)
        )
        
        virtualizedScrollView.setContentOffset(clampedOffset, animated: animated)
        
    }
    
    // MARK: - UIScrollViewDelegate Methods (Clean Global Event System)
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        propagateEvent(on: scrollView, eventName: "onScrollBeginDrag", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ]
        ])
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        propagateEvent(on: scrollView, eventName: "onScrollEndDrag", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ],
            "willDecelerate": decelerate
        ])
        
        if !decelerate {
            propagateEvent(on: scrollView, eventName: "onScrollEnd", data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y
                ]
            ])
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        propagateEvent(on: scrollView, eventName: "onScrollEnd", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ]
        ])
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        propagateEvent(on: scrollView, eventName: "onScroll", data: [
            "contentOffset": [
                "x": scrollView.contentOffset.x,
                "y": scrollView.contentOffset.y
            ],
            "contentSize": [
                "width": scrollView.contentSize.width,
                "height": scrollView.contentSize.height
            ],
            "layoutMeasurement": [
                "width": scrollView.bounds.width,
                "height": scrollView.bounds.height
            ]
        ])
    }
}
