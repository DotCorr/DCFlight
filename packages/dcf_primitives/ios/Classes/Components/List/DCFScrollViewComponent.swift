/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFScrollViewComponent: NSObject, DCFComponent, UIScrollViewDelegate {
    private static let sharedInstance = DCFScrollViewComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let scrollView = DCFScrollableView()
        
        scrollView.delegate = DCFScrollViewComponent.sharedInstance
        
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.bounces = true
        
        if let tertiaryColorStr = props["tertiaryColor"] as? String {
            if let indicatorColor = ColorUtilities.color(fromHexString: tertiaryColorStr) {
                let brightness = indicatorColor.cgColor.components?.reduce(0, +) ?? 0.5
                scrollView.indicatorStyle = brightness > 0.5 ? .black : .white
            } else {
                scrollView.indicatorStyle = .default
            }
        } else {
            scrollView.indicatorStyle = .default
        }
        
        updateView(scrollView, withProps: props)
        
        scrollView.applyStyles(props: props)
        
        return scrollView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let scrollView = view as? DCFScrollableView else { return false }
        
        if let showsScrollIndicator = props["showsScrollIndicator"] as? Bool {
            scrollView.showsVerticalScrollIndicator = showsScrollIndicator
            scrollView.showsHorizontalScrollIndicator = showsScrollIndicator
        }
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // tertiaryColor: scroll indicator color
        if let tertiaryColor = props["tertiaryColor"] as? String,
           let indicatorColor = ColorUtilities.color(fromHexString: tertiaryColor) {
            if #available(iOS 13.0, *) {
                objc_setAssociatedObject(scrollView, 
                                       UnsafeRawPointer(bitPattern: "scrollIndicatorColor".hashValue)!, 
                                       indicatorColor, 
                                       .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        if let scrollIndicatorSize = props["scrollIndicatorSize"] {
            objc_setAssociatedObject(scrollView, 
                                   UnsafeRawPointer(bitPattern: "scrollIndicatorSize".hashValue)!, 
                                   scrollIndicatorSize, 
                                   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        if let bounces = props["bounces"] as? Bool {
            scrollView.bounces = bounces
        }
        
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
        
        if let pagingEnabled = props["pagingEnabled"] as? Bool {
            scrollView.isPagingEnabled = pagingEnabled
        }
        
        if let scrollEnabled = props["scrollEnabled"] as? Bool {
            scrollView.isScrollEnabled = scrollEnabled
        }
        
        if let clipsToBounds = props["clipsToBounds"] as? Bool {
            scrollView.clipsToBounds = clipsToBounds
        }
        
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                scrollView.backgroundColor = uiColor
            }
        }
        
        // NO FALLBACK: backgroundColor comes from StyleSheet only
        // StyleSheet will always provide this via toMap() fallbacks
        
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
        
        if let contentOffsetStart = props["contentOffsetStart"] as? CGFloat, contentOffsetStart > 0 {
            scrollView.virtualizedContentOffsetStart = contentOffsetStart
        }
        
        if let contentPaddingTop = props["contentPaddingTop"] as? CGFloat, contentPaddingTop > 0 {
            scrollView.virtualizedContentPaddingTop = contentPaddingTop
        }
        
        handleCommand(scrollView: scrollView, props: props)
        
        scrollView.applyStyles(props: props)
        
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let scrollView = view as? DCFScrollableView else { return }
        
        let newFrame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
        scrollView.frame = newFrame
        
        
        scrollView.layoutIfNeeded()
        
        DispatchQueue.main.async {
            scrollView.updateContentSizeFromYogaLayout()
        }
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        if let scrollView = view as? DCFScrollableView {
            scrollView.nodeId = nodeId
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollView.updateContentSizeFromYogaLayout()
            }
        }
    }
    
    
    
    /// Handle commands passed as props - the new declarative command pattern
    private func handleCommand(scrollView: DCFScrollableView, props: [String: Any]) {
        guard let commandData = props["command"] as? [String: Any] else {
            return
        }
        
        if let scrollToPositionData = commandData["scrollToPosition"] as? [String: Any] {
            if let x = scrollToPositionData["x"] as? Double, let y = scrollToPositionData["y"] as? Double {
                let animated = scrollToPositionData["animated"] as? Bool ?? true
                scrollView.setContentOffset(CGPoint(x: CGFloat(x), y: CGFloat(y)), animated: animated)
            }
        }
        
        if let scrollToTopData = commandData["scrollToTop"] as? [String: Any] {
            let animated = scrollToTopData["animated"] as? Bool ?? true
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0), animated: animated)
        }
        
        if let scrollToBottomData = commandData["scrollToBottom"] as? [String: Any] {
            let animated = scrollToBottomData["animated"] as? Bool ?? true
            let bottomOffset = CGPoint(x: scrollView.contentOffset.x, 
                                     y: scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(bottomOffset, animated: animated)
        }
        
        if let flashScrollIndicators = commandData["flashScrollIndicators"] as? Bool, flashScrollIndicators {
            scrollView.flashScrollIndicators()
        }
        
        if let updateContentSize = commandData["updateContentSize"] as? Bool, updateContentSize {
            scrollView.updateContentSizeFromYogaLayout()
        }
        
        if let setContentSizeData = commandData["setContentSize"] as? [String: Any] {
            if let width = setContentSizeData["width"] as? Double, let height = setContentSizeData["height"] as? Double {
                scrollView.setExplicitContentSize(CGSize(width: CGFloat(width), height: CGFloat(height)))
            }
        }
    }
    
    
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
    
    
    /// Handle content size change notifications from DCFScrollableView
    func notifyContentSizeChange(_ scrollView: DCFScrollableView, size: CGSize) {
        propagateEvent(on: scrollView, eventName: "onContentSizeChange", data: [
            "contentSize": [
                "width": size.width,
                "height": size.height
            ]
        ])
    }
}
