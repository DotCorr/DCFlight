/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

// Note: ScrollViewKey is defined in DCFScrollView.swift as a global variable
// Both files use the same memory address via &ScrollViewKey

/**
 * DCFScrollContentViewComponent - Content view component manager
 * 
 * This component creates the content view that wraps ScrollView's children.
 * Yoga will layout this view, and the ScrollView will use its frame.size
 * as the contentSize.
 */
class DCFScrollContentViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let contentView = DCFScrollContentView(frame: .zero)
        contentView.applyStyles(props: props)
        return contentView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        view.applyStyles(props: props)
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Apply Yoga layout to content view
        // The ScrollView will read this view's frame.size to set contentSize
        // CRITICAL: ScrollContentView should always start at (0, 0) relative to ScrollView
        // Yoga may calculate a negative Y position, but we need to reset it to 0
        // The height should be determined by children, not constrained
        let frame = CGRect(
            x: 0, // Always start at x=0 relative to ScrollView
            y: 0, // Always start at y=0 relative to ScrollView (ignore Yoga's calculated top)
            width: max(0, layout.width), // Use Yoga's calculated width
            height: max(0, layout.height) // Use Yoga's calculated height (should grow with children)
        )
        
        // CRITICAL: Store the frame in an associated object so we can restore it after attachment
        // UIKit may reset the frame when the view is added to a superview
        objc_setAssociatedObject(view,
                                 UnsafeRawPointer(bitPattern: "pendingFrame".hashValue)!,
                                 NSValue(cgRect: frame),
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // CRITICAL: Set frame directly (applyLayout is called on main thread from DCFLayoutManager)
        // Disable autoresizing to prevent UIKit from resetting the frame
        view.translatesAutoresizingMaskIntoConstraints = false
        view.autoresizingMask = []
        
        // Set frame using CATransaction to prevent implicit animations and ensure it's set immediately
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.frame = frame
        CATransaction.commit()
        
        // Force layout to ensure frame is applied
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // CRITICAL: Always restore frame if it's zero or doesn't match, regardless of attachment status
        // This handles the case where applyLayout runs before or after setChildren
        let needsFrameRestore = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "needsFrameRestore".hashValue)!) as? NSNumber
        if view.frame.width == 0 || view.frame.height == 0 || view.frame != frame || (needsFrameRestore?.boolValue ?? false) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            view.frame = frame
            CATransaction.commit()
            view.setNeedsLayout()
            view.layoutIfNeeded()
            print("⚠️ DCFScrollContentViewComponent.applyLayout: Frame was zero/mismatch/needsRestore - restored to \(frame), actualFrame=\(view.frame)")
            
            // Clear the needsFrameRestore flag
            objc_setAssociatedObject(view,
                                     UnsafeRawPointer(bitPattern: "needsFrameRestore".hashValue)!,
                                     nil,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        print("🔍 DCFScrollContentViewComponent.applyLayout: Set frame=\(frame), actualFrame=\(view.frame), superview=\(view.superview?.description ?? "nil")")
        
        // CRITICAL: Find ScrollView and update contentSize
        // ALWAYS use stored reference first (set by insertContentView) - this is the most reliable method
        // The stored reference is set BEFORE the view is added to the hierarchy, so it's always available
        var scrollView = objc_getAssociatedObject(view, &ScrollViewKey) as? DCFScrollView
        
        // Fallback: Try to find through hierarchy if stored reference is nil
        if scrollView == nil {
            // Method 1: Through DCFCustomScrollView (normal case)
            if let customScrollView = view.superview as? DCFCustomScrollView {
                scrollView = customScrollView.superview as? DCFScrollView
            }
            
            // Method 2: Direct parent (fallback)
            if scrollView == nil, let directScrollView = view.superview as? DCFScrollView {
                scrollView = directScrollView
            }
            
            // Method 3: Walk up the hierarchy to find DCFScrollView
            if scrollView == nil {
                var currentView: UIView? = view.superview
                while currentView != nil {
                    if let foundScrollView = currentView as? DCFScrollView {
                        scrollView = foundScrollView
                        break
                    }
                    currentView = currentView?.superview
                }
            }
        }
        
        // Update contentSize if ScrollView found
        if let sv = scrollView {
            // CRITICAL: Ensure frame is correct before updating contentSize
            // The frame might have been reset by UIKit, so restore it if needed
            if view.frame.width == 0 || view.frame.height == 0 || view.frame != frame {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                view.frame = frame
                CATransaction.commit()
                view.setNeedsLayout()
                view.layoutIfNeeded()
                print("⚠️ DCFScrollContentViewComponent.applyLayout: Frame was incorrect, restored to \(frame), actualFrame=\(view.frame)")
            }
            
            print("✅ DCFScrollContentViewComponent.applyLayout: Found ScrollView (stored=\(objc_getAssociatedObject(view, &ScrollViewKey) != nil)), contentView.frame=\(view.frame), updating contentSize")
            sv.updateContentSizeFromContentView()
        } else {
            // If not found, the view might not be attached yet or stored reference wasn't set
            // Use async to retry after a brief delay to ensure attachment is complete
            DispatchQueue.main.async { [weak view, frame] in
                guard let contentView = view else { return }
                
                // CRITICAL: Always restore frame first - it might have been reset
                if contentView.frame.width == 0 || contentView.frame.height == 0 || contentView.frame != frame {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    contentView.frame = frame
                    CATransaction.commit()
                    contentView.setNeedsLayout()
                    contentView.layoutIfNeeded()
                    print("⚠️ DCFScrollContentViewComponent.applyLayout (async): Restored frame=\(frame), actualFrame=\(contentView.frame)")
                }
                
                // Try to find ScrollView using stored reference first (most reliable)
                var foundScrollView = objc_getAssociatedObject(contentView, &ScrollViewKey) as? DCFScrollView
                
                // Fallback: Try hierarchy
                if foundScrollView == nil {
                    if let customScrollView = contentView.superview as? DCFCustomScrollView {
                        foundScrollView = customScrollView.superview as? DCFScrollView
                    }
                    
                    if foundScrollView == nil, let directScrollView = contentView.superview as? DCFScrollView {
                        foundScrollView = directScrollView
                    }
                    
                    if foundScrollView == nil {
                        var currentView: UIView? = contentView.superview
                        while currentView != nil {
                            if let sv = currentView as? DCFScrollView {
                                foundScrollView = sv
                                break
                            }
                            currentView = currentView?.superview
                        }
                    }
                }
                
                if let sv = foundScrollView {
                    print("✅ DCFScrollContentViewComponent.applyLayout (async): Found ScrollView, contentView.frame=\(contentView.frame), updating contentSize")
                    sv.updateContentSizeFromContentView()
                } else {
                    print("⚠️ DCFScrollContentViewComponent.applyLayout (async): Could not find ScrollView, contentView.superview=\(contentView.superview?.description ?? "nil"), frame=\(contentView.frame), storedRef=\(objc_getAssociatedObject(contentView, &ScrollViewKey) != nil)")
                }
            }
        }
        
        print("🔍 DCFScrollContentViewComponent.applyLayout: layout=(\(layout.left), \(layout.top), \(layout.width), \(layout.height)) -> set frame=\(frame)")
    }
    
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        print("🔍 DCFScrollContentViewComponent.setChildren: Called for viewId=\(viewId), childViews.count=\(childViews.count), viewType=\(type(of: view))")
        
        // ScrollContentView should contain all its children directly
        // Remove existing children
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new children
        for (index, childView) in childViews.enumerated() {
            // Get viewId from associated object
            let childViewId = objc_getAssociatedObject(childView, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String ?? "unknown"
            print("🔍 DCFScrollContentViewComponent.setChildren: Adding child \(index): viewId=\(childViewId), frame=\(childView.frame), type=\(type(of: childView))")
            view.addSubview(childView)
        }
        
        print("✅ DCFScrollContentViewComponent.setChildren: Added \(childViews.count) children to ScrollContentView (viewId=\(viewId)), view now has \(view.subviews.count) subviews, frame=\(view.frame)")
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        // Content view is laid out by Yoga - no special handling needed
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

