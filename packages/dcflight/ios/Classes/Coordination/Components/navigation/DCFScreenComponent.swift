/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// Container for screen content and metadata
class ScreenContainer {
    let name: String
    let presentationStyle: String
    let viewController: UIViewController
    let contentView: UIView
    var isActive: Bool = false
    
    init(name: String, presentationStyle: String) {
        self.name = name
        self.presentationStyle = presentationStyle
        self.viewController = UIViewController()
        
        // Create content view that DCFlight will manage
        self.contentView = UIView()
        self.contentView.backgroundColor = UIColor.clear
        self.viewController.view = contentView
    }
}

/// Screen component that creates and manages screen containers
class DCFScreenComponent: NSObject, DCFComponent {
    
    // Registry of all screen containers by screen name
    static var screenRegistry: [String: ScreenContainer] = [:]
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        guard let screenName = props["name"] as? String,
              let presentationStyle = props["presentationStyle"] as? String else {
            print("❌ DCFScreenComponent: Missing required props 'name' or 'presentationStyle'")
            return UIView()
        }
        
        // Create or get existing screen container
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
        }
        
        // Configure screen based on presentation style and props
        configureScreen(screenContainer, props: props)
        
        // Update view with current props
        _ = updateView(screenContainer.contentView, withProps: props)
        
        return screenContainer.contentView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let screenName = props["name"] as? String,
              let screenContainer = DCFScreenComponent.screenRegistry[screenName] else {
            return false
        }
        
        // Handle visibility changes
        let isVisible = props["visible"] as? Bool ?? true
        if isVisible != screenContainer.isActive {
            if isVisible {
                activateScreen(screenContainer, props: props)
            } else {
                deactivateScreen(screenContainer, props: props)
            }
        }
        
        // Apply layout and style properties
        view.applyStyles(props: props)
        
        return true
    }
    
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        // Find the screen container for this view
        guard let screenContainer = findScreenContainer(for: view) else {
            return false
        }
        
        // Clear existing children
        screenContainer.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new children
        for childView in childViews {
            screenContainer.contentView.addSubview(childView)
            childView.isHidden = false
            childView.alpha = 1.0
        }
        
        // Trigger layout if screen is active
        if screenContainer.isActive {
            screenContainer.contentView.setNeedsLayout()
            screenContainer.contentView.layoutIfNeeded()
        }
        
        return true
    }
    
    // MARK: - Screen Configuration
    
    private func configureScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        if screenContainer.presentationStyle == "tab" {
            configureTabScreen(screenContainer, props: props)
        }
    }
    
    private func configureTabScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController
        
        // Configure tab bar item
        if let title = props["title"] as? String {
            viewController.title = title
        }
        
        if let iconName = props["icon"] as? String {
            viewController.tabBarItem.image = UIImage(systemName: iconName)
        }
        
        if let badge = props["badge"] as? String {
            viewController.tabBarItem.badgeValue = badge
        }
        
        let enabled = props["enabled"] as? Bool ?? true
        viewController.tabBarItem.isEnabled = enabled
    }
    
    // MARK: - Screen Lifecycle
    
    private func activateScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        screenContainer.isActive = true
        
        // Fire onAppear event
        propagateEvent(
            on: screenContainer.contentView,
            eventName: "onAppear",
            data: ["screenName": screenContainer.name]
        )
        
        // Fire onActivate event
        propagateEvent(
            on: screenContainer.contentView,
            eventName: "onActivate",
            data: ["screenName": screenContainer.name]
        )
    }
    
    private func deactivateScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        screenContainer.isActive = false
        
        // Fire onDisappear event
        propagateEvent(
            on: screenContainer.contentView,
            eventName: "onDisappear",
            data: ["screenName": screenContainer.name]
        )
        
        // Fire onDeactivate event
        propagateEvent(
            on: screenContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": screenContainer.name]
        )
    }
    
    // MARK: - Helper Methods
    
    private func findScreenContainer(for view: UIView) -> ScreenContainer? {
        for (_, container) in DCFScreenComponent.screenRegistry {
            if container.contentView == view {
                return container
            }
        }
        return nil
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
        return CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Associate the view with its node ID
        objc_setAssociatedObject(
            view,
            UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
            nodeId,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
