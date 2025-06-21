/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

// 🚀 CLEAN VIRTUALIZED SCROLL VIEW COMPONENT - Uses only propagateEvent()
class DCFVirtualizedScrollViewComponent: NSObject, DCFComponent, ComponentMethodHandler, UIScrollViewDelegate {
    private static let sharedInstance = DCFVirtualizedScrollViewComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create a VirtualizedScrollView that separates layout from content size management
        let scrollView = VirtualizedScrollView()
        
        // 🚀 CLEAN: Set shared instance as delegate to prevent deallocation
        scrollView.delegate = DCFVirtualizedScrollViewComponent.sharedInstance
        
        // Apply basic configuration
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bounces = true
        
        // Apply adaptive styling
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                scrollView.backgroundColor = UIColor.systemBackground
            } else {
                scrollView.backgroundColor = UIColor.white
            }
        } else {
            scrollView.backgroundColor = UIColor.clear
        }
        
        // Apply props
        updateView(scrollView, withProps: props)
        
        // Apply StyleSheet properties
        scrollView.applyStyles(props: props)
        
        return scrollView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let scrollView = view as? VirtualizedScrollView else { return false }
        
        // Set shows indicator if specified
        if let showsScrollIndicator = props["showsScrollIndicator"] as? Bool {
            scrollView.showsVerticalScrollIndicator = showsScrollIndicator
            scrollView.showsHorizontalScrollIndicator = showsScrollIndicator
            print("📜 VirtualizedScrollView showsScrollIndicator set to: \(showsScrollIndicator)")
        }
        
        // Set scroll indicator color if specified
        if let scrollIndicatorColorValue = props["scrollIndicatorColor"] {
            var indicatorColor: UIColor?
            
            if let colorString = scrollIndicatorColorValue as? String {
                indicatorColor = ColorUtilities.color(fromHexString: colorString)
            } else if let colorNumber = scrollIndicatorColorValue as? NSNumber {
                let colorInt = colorNumber.intValue
                let red = CGFloat((colorInt >> 16) & 0xFF) / 255.0
                let green = CGFloat((colorInt >> 8) & 0xFF) / 255.0
                let blue = CGFloat(colorInt & 0xFF) / 255.0
                indicatorColor = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
            }
            
            if let color = indicatorColor {
                if #available(iOS 13.0, *) {
                    objc_setAssociatedObject(scrollView, 
                                           UnsafeRawPointer(bitPattern: "scrollIndicatorColor".hashValue)!, 
                                           color, 
                                           .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    print("📜 VirtualizedScrollView indicator color stored: \(color)")
                }
            }
        }
        
        // Set scroll indicator size if specified  
        if let scrollIndicatorSize = props["scrollIndicatorSize"] {
            objc_setAssociatedObject(scrollView, 
                                   UnsafeRawPointer(bitPattern: "scrollIndicatorSize".hashValue)!, 
                                   scrollIndicatorSize, 
                                   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            print("📜 VirtualizedScrollView indicator size stored: \(scrollIndicatorSize)")
        }
        
        // Set bounces if specified
        if let bounces = props["bounces"] as? Bool {
            scrollView.bounces = bounces
        }
        
        // Set horizontal if specified
        if let horizontal = props["horizontal"] as? Bool {
            scrollView.isHorizontal = horizontal
            if horizontal {
                scrollView.alwaysBounceHorizontal = true
                scrollView.alwaysBounceVertical = false
                scrollView.showsHorizontalScrollIndicator = scrollView.showsHorizontalScrollIndicator
                scrollView.showsVerticalScrollIndicator = false
            } else {
                scrollView.alwaysBounceHorizontal = false
                scrollView.alwaysBounceVertical = true
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.showsVerticalScrollIndicator = scrollView.showsVerticalScrollIndicator
            }
        }
        
        // Set paging enabled if specified
        if let pagingEnabled = props["pagingEnabled"] as? Bool {
            scrollView.isPagingEnabled = pagingEnabled
        }
        
        // Set scroll enabled if specified
        if let scrollEnabled = props["scrollEnabled"] as? Bool {
            scrollView.isScrollEnabled = scrollEnabled
        }
        
        // Set clipping if specified
        if let clipsToBounds = props["clipsToBounds"] as? Bool {
            scrollView.clipsToBounds = clipsToBounds
        }
        
        // Handle background color property
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                scrollView.backgroundColor = uiColor
                print("🎨 VirtualizedScrollView: Set background color to: \(backgroundColor) -> \(uiColor)")
            }
        }
        
        // Handle adaptive color only if explicitly provided and no backgroundColor is set
        if props.keys.contains("adaptive") && !props.keys.contains("backgroundColor") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    scrollView.backgroundColor = UIColor.systemBackground
                } else {
                    scrollView.backgroundColor = UIColor.white
                }
            }
        }
        
        // Apply styling properties
        if let borderRadius = props["borderRadius"] as? CGFloat {
            scrollView.layer.cornerRadius = borderRadius
            scrollView.clipsToBounds = true  
        }
        
        if let borderWidth = props["borderWidth"] as? CGFloat {
            scrollView.layer.borderWidth = borderWidth
        }
        
        if let borderColor = props["borderColor"] as? String {
            scrollView.layer.borderColor = ColorUtilities.color(fromHexString: borderColor)?.cgColor
        }
        
        if let opacity = props["opacity"] as? CGFloat {
            scrollView.alpha = opacity
        }
        
        // Store content offset and padding for VirtualizedList management
        if let contentOffsetStart = props["contentOffsetStart"] as? CGFloat, contentOffsetStart > 0 {
            scrollView.virtualizedContentOffsetStart = contentOffsetStart
        }
        
        if let contentPaddingTop = props["contentPaddingTop"] as? CGFloat, contentPaddingTop > 0 {
            scrollView.virtualizedContentPaddingTop = contentPaddingTop
        }
        
        // Apply StyleSheet properties
        scrollView.applyStyles(props: props)
        
        return true
    }
    
    // Custom layout for VirtualizedScrollView - uses React Native's two-step approach
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let scrollView = view as? VirtualizedScrollView else { return }
        
        // Step 1: Let Yoga handle the scroll view frame layout
        let newFrame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        scrollView.frame = newFrame
        
        print("📏 VirtualizedScrollView: Frame set to \(newFrame)")
        
        // Force layout of subviews first to get Yoga layout results
        scrollView.layoutIfNeeded()
        
        // Step 2: Calculate content size based on Yoga layout results
        // This is the key difference - we separate frame layout from content size
        DispatchQueue.main.async {
            scrollView.updateContentSizeFromYogaLayout()
        }
    }
    
    // Add a view registration hook for content size updates
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Store node ID on the view
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // For VirtualizedScrollView, schedule content size update after Yoga layout
        if let scrollView = view as? VirtualizedScrollView {
            // Store the nodeId on the scroll view for bridge communication
            scrollView.nodeId = nodeId
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollView.updateContentSizeFromYogaLayout()
            }
        }
    }
    
    // MARK: - Event Handling
    // Note: VirtualizedScrollView uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
    
    // MARK: - Component Methods
    
    func handleMethod(methodName: String, args: [String: Any], view: UIView) -> Bool {
        guard let scrollView = view as? VirtualizedScrollView else { return false }
        
        switch methodName {
        case "scrollToPosition":
            if let x = args["x"] as? CGFloat, let y = args["y"] as? CGFloat {
                let animated = args["animated"] as? Bool ?? true
                scrollView.setContentOffset(CGPoint(x: x, y: y), animated: animated)
                return true
            }
        case "scrollToTop":
            let animated = args["animated"] as? Bool ?? true
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0), animated: animated)
            return true
        case "scrollToBottom":
            let animated = args["animated"] as? Bool ?? true
            let bottomOffset = CGPoint(x: scrollView.contentOffset.x, 
                                     y: scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(bottomOffset, animated: animated)
            return true
        case "flashScrollIndicators":
            scrollView.flashScrollIndicators()
            return true
        case "updateContentSize":
            // Explicit content size update through bridge communication
            scrollView.updateContentSizeFromYogaLayout()
            return true
        case "setContentSize":
            // Explicit content size setting from Dart side
            if let width = args["width"] as? CGFloat, let height = args["height"] as? CGFloat {
                scrollView.setExplicitContentSize(CGSize(width: width, height: height))
                return true
            }
        default:
            return false
        }
        
        return false
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
    
    // MARK: - Content Size Change Handler (Simplified)
    
    /// Handle content size change notifications from VirtualizedScrollView
    func notifyContentSizeChange(_ scrollView: VirtualizedScrollView, size: CGSize) {
        propagateEvent(on: scrollView, eventName: "onContentSizeChange", data: [
            "contentSize": [
                "width": size.width,
                "height": size.height
            ]
        ])
    }
}
