/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit
import SafariServices
import dcflight

// Associated object keys for storing URL per view
private struct AssociatedKeys {
    static var urlToOpen = "urlToOpen"
    static var openBehavior = "openBehavior"
}

class DCFUrlWrapperViewComponent: NSObject, DCFComponent {
    // Use shared instance like other working components
    private static let sharedInstance = DCFUrlWrapperViewComponent()
    
    private weak var containerView: UIView?  // Keep reference for finding view controller
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let containerView = UIView()
        
        // Store URL and behavior using associated objects
        let urlToOpen = props["url"] as? String
        let openBehavior = props["openBehavior"] as? String ?? "external"
        
        objc_setAssociatedObject(containerView, &AssociatedKeys.urlToOpen, urlToOpen, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(containerView, &AssociatedKeys.openBehavior, openBehavior, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        print("DCFUrlWrapperView: Creating view with URL: \(urlToOpen ?? "nil")")
        
        // Store container view reference
        self.containerView = containerView
        
        // Enable user interaction for gestures
        containerView.isUserInteractionEnabled = true
        
        // Handle adaptive theming
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                containerView.backgroundColor = UIColor.systemBackground
            } else {
                containerView.backgroundColor = UIColor.clear
            }
        }
        
        // Add gesture recognizers based on detection flags
        addGestureRecognizers(to: containerView, props: props)
        
        containerView.applyStyles(props: props)
        return containerView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Update URL and behavior using associated objects
        let urlToOpen = props["url"] as? String
        let openBehavior = props["openBehavior"] as? String ?? "external"
        
        objc_setAssociatedObject(view, &AssociatedKeys.urlToOpen, urlToOpen, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &AssociatedKeys.openBehavior, openBehavior, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Handle adaptive theming updates
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                view.backgroundColor = UIColor.systemBackground
            } else {
                view.backgroundColor = UIColor.clear
            }
        }
        
        // Remove existing gesture recognizers and add new ones
        view.gestureRecognizers?.removeAll()
        addGestureRecognizers(to: view, props: props)
        
        view.applyStyles(props: props)
        return true
    }
    
    // MARK: - DCFComponent Protocol Methods
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Track node registration for debugging
    }
    
    private func addGestureRecognizers(to view: UIView, props: [String: Any]) {
        let detectPress = props["detectPress"] as? Bool ?? true
        let detectLongPress = props["detectLongPress"] as? Bool ?? false
        let detectDoubleTap = props["detectDoubleTap"] as? Bool ?? false
        let detectSwipe = props["detectSwipe"] as? Bool ?? false
        let detectPan = props["detectPan"] as? Bool ?? false
        let disabled = props["disabled"] as? Bool ?? false
        
        if disabled {
            return
        }
        
        // Single tap gesture - use shared instance
        if detectPress {
            print("DCFUrlWrapperView: Adding single tap gesture")
            let tapGesture = UITapGestureRecognizer(target: DCFUrlWrapperViewComponent.sharedInstance, action: #selector(handleTap(_:)))
            tapGesture.numberOfTapsRequired = 1
            view.addGestureRecognizer(tapGesture)
        }
        
        // Double tap gesture
        if detectDoubleTap {
            let doubleTapGesture = UITapGestureRecognizer(target: DCFUrlWrapperViewComponent.sharedInstance, action: #selector(handleDoubleTap(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTapGesture)
            
            // Prevent single tap from firing when double tap is detected
            if detectPress {
                if let singleTap = view.gestureRecognizers?.first(where: { ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 1 }) as? UITapGestureRecognizer {
                    singleTap.require(toFail: doubleTapGesture)
                }
            }
        }
        
        // Long press gesture
        if detectLongPress {
            let longPressDelay = props["longPressDelay"] as? Int ?? 500
            let longPressGesture = UILongPressGestureRecognizer(target: DCFUrlWrapperViewComponent.sharedInstance, action: #selector(handleLongPress(_:)))
            longPressGesture.minimumPressDuration = TimeInterval(longPressDelay) / 1000.0
            view.addGestureRecognizer(longPressGesture)
        }
        
        // Swipe gestures
        if detectSwipe {
            for direction in [UISwipeGestureRecognizer.Direction.left, .right, .up, .down] {
                let swipeGesture = UISwipeGestureRecognizer(target: DCFUrlWrapperViewComponent.sharedInstance, action: #selector(handleSwipe(_:)))
                swipeGesture.direction = direction
                view.addGestureRecognizer(swipeGesture)
            }
        }
        
        // Pan gesture
        if detectPan {
            let panGesture = UIPanGestureRecognizer(target: DCFUrlWrapperViewComponent.sharedInstance, action: #selector(handlePan(_:)))
            view.addGestureRecognizer(panGesture)
        }
        
        view.isUserInteractionEnabled = true
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        print("DCFUrlWrapperView: Tap detected! Opening URL natively (NO event propagation to Dart)")
        
        // Get the URL from the view's associated object or find it
        guard let view = gesture.view else { return }
        
        // Use shared instance to handle URL opening
        DCFUrlWrapperViewComponent.sharedInstance.openURLForView(view)
    }
    
    // Helper method to open URL for a specific view
    private func openURLForView(_ view: UIView) {
        // Get URL and behavior from the view's associated objects
        guard let urlString = objc_getAssociatedObject(view, &AssociatedKeys.urlToOpen) as? String,
              let url = URL(string: urlString) else {
            print("DCFUrlWrapperView: No URL to open for this view")
            return
        }
        
        let openBehavior = objc_getAssociatedObject(view, &AssociatedKeys.openBehavior) as? String ?? "external"
        
        print("DCFUrlWrapperView: Opening URL: \(urlString) with behavior: \(openBehavior) (native only, no Dart event)")
        openURL(url, behavior: openBehavior)
    }
    
    private func openURL(_ url: URL, behavior: String) {
        switch behavior {
        case "external":
            openExternal(url: url)
        case "safariView":
            openSafariView(url: url)
        case "inApp":
            openSafariView(url: url) // Fallback to Safari View
        case "customTab":
            openSafariView(url: url) // iOS fallback
        default:
            openExternal(url: url)
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // Double tap - no event propagation, just native handling
        print("DCFUrlWrapperView: Double tap detected (native only)")
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Long press - no event propagation, just native handling
            print("DCFUrlWrapperView: Long press detected (native only)")
        }
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        // Swipe - no event propagation, just native handling
        print("DCFUrlWrapperView: Swipe detected (native only)")
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Pan - no event propagation, just native handling
        print("DCFUrlWrapperView: Pan detected (native only)")
    }
    private func openExternal(url: URL) {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("DCFUrlWrapperView: Successfully opened URL externally: \(url.absoluteString)")
                } else {
                    print("DCFUrlWrapperView: Failed to open URL externally: \(url.absoluteString)")
                }
            }
        } else {
            let success = UIApplication.shared.openURL(url)
            if success {
                print("DCFUrlWrapperView: Successfully opened URL externally: \(url.absoluteString)")
            } else {
                print("DCFUrlWrapperView: Failed to open URL externally: \(url.absoluteString)")
            }
        }
    }
    
    private func openSafariView(url: URL) {
        guard let viewController = findViewController() else {
            print("DCFUrlWrapperView: No view controller found, falling back to external browser")
            openExternal(url: url)
            return
        }
        
        if #available(iOS 9.0, *) {
            let safariVC = SFSafariViewController(url: url)
            viewController.present(safariVC, animated: true) {
                print("DCFUrlWrapperView: Successfully opened URL in Safari View: \(url.absoluteString)")
            }
        } else {
            // Fallback to external browser for older iOS versions
            openExternal(url: url)
        }
    }
    
    private func findViewController() -> UIViewController? {
        guard let view = self.containerView else { return nil }
        
        var responder: UIResponder? = view
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}
