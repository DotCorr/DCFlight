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
    var childNavigators: [Any] = []
    
    init(name: String, presentationStyle: String) {
        self.name = name
        self.presentationStyle = presentationStyle
        
        switch presentationStyle {
        case "tab":
            self.viewController = UIViewController()
            
        case "push":
            self.viewController = UIViewController()
        case "modal":
            self.viewController = UIViewController()
        default:
            self.viewController = UIViewController()
        }
        
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
        
        print("🔧 DCFScreenComponent: Creating screen '\(screenName)' with style '\(presentationStyle)'")
        
        // Create or get existing screen container
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(screenName)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)'")
        }
        
        // Configure screen based on presentation style and props
        configureScreen(screenContainer, props: props)
        
        // Update view with current props
        let _ = updateView(screenContainer.contentView, withProps: props)
        
        return screenContainer.contentView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let screenName = props["name"] as? String,
              let screenContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Screen not found for update")
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
            print("❌ DCFScreenComponent: Could not find screen container for setChildren")
            return false
        }
        
        print("📱 DCFScreenComponent: Setting \(childViews.count) children for screen '\(screenContainer.name)'")
        
        // Clear existing children
        screenContainer.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new children
        for (index, childView) in childViews.enumerated() {
            screenContainer.contentView.addSubview(childView)
            childView.isHidden = false
            childView.alpha = 1.0
            
            print("  👶 Added child \(index) to screen '\(screenContainer.name)'")
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
        switch screenContainer.presentationStyle {
        case "tab":
            configureTabScreen(screenContainer, props: props)
        case "push":
            configurePushScreen(screenContainer, props: props)
        case "modal":
            configureModalScreen(screenContainer, props: props)
        default:
            print("⚠️ DCFScreenComponent: Unknown presentation style '\(screenContainer.presentationStyle)'")
        }
    }
    
    private func configureTabScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController
        
        // REMOVE automatic content inset adjustments
        if #available(iOS 11.0, *) {
            viewController.extendedLayoutIncludesOpaqueBars = true
            viewController.edgesForExtendedLayout = .all
            viewController.automaticallyAdjustsScrollViewInsets = false
        } else {
            viewController.automaticallyAdjustsScrollViewInsets = false
        }
        
        // Configure tab bar item (existing code)
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
    
    private func configurePushScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController
        
        // Configure navigation item
        if let title = props["title"] as? String {
            viewController.navigationItem.title = title
        }
        
        let hideNavigationBar = props["hideNavigationBar"] as? Bool ?? false
        viewController.navigationController?.setNavigationBarHidden(hideNavigationBar, animated: false)
        
        let hideBackButton = props["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton
        
        if let backButtonTitle = props["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }
        
        let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode = largeTitleDisplayMode ? .always : .never
        }
    }
    
    private func configureModalScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController
        
        // Configure modal presentation
        if let transitionStyle = props["transitionStyle"] as? String {
            switch transitionStyle.lowercased() {
            case "coververtical":
                viewController.modalTransitionStyle = .coverVertical
            case "fliphorizontal":
                viewController.modalTransitionStyle = .flipHorizontal
            case "crossdissolve":
                viewController.modalTransitionStyle = .crossDissolve
            case "partialcurl":
                if #available(iOS 3.2, *) {
                    viewController.modalTransitionStyle = .partialCurl
                }
            default:
                viewController.modalTransitionStyle = .coverVertical
            }
        }
        
        // Configure sheet presentation for iOS 15+
        if #available(iOS 15.0, *) {
            viewController.modalPresentationStyle = .pageSheet
            
            if let sheet = viewController.sheetPresentationController {
                configureSheetDetents(sheet: sheet, props: props)
            }
        }
    }
    
    @available(iOS 15.0, *)
    private func configureSheetDetents(sheet: UISheetPresentationController, props: [String: Any]) {
        var detents: [UISheetPresentationController.Detent] = []
        
        if let detentArray = props["detents"] as? [String] {
            for detentString in detentArray {
                switch detentString.lowercased() {
                case "small", "compact":
                    if #available(iOS 16.0, *) {
                        detents.append(.custom(identifier: .init("small")) { context in
                            return context.maximumDetentValue * 0.3
                        })
                    } else {
                        detents.append(.medium())
                    }
                case "medium", "half":
                    detents.append(.medium())
                case "large", "full":
                    detents.append(.large())
                default:
                    detents.append(.medium())
                }
            }
        } else {
            detents = [.medium(), .large()]
        }
        
        sheet.detents = detents
        sheet.prefersGrabberVisible = props["showDragIndicator"] as? Bool ?? true
        
        if let cornerRadius = props["cornerRadius"] as? CGFloat {
            if #available(iOS 16.0, *) {
                sheet.preferredCornerRadius = cornerRadius
            }
        }
    }
    
    // MARK: - Screen Lifecycle
    
    private func activateScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        print("🟢 DCFScreenComponent: Activating screen '\(screenContainer.name)'")
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
        print("🔴 DCFScreenComponent: Deactivating screen '\(screenContainer.name)'")
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
    
    // MARK: - Static Registry Methods
    
    /// Get a screen container by name
    static func getScreenContainer(name: String) -> ScreenContainer? {
        return screenRegistry[name]
    }
    
    /// Get all screen containers
    static func getAllScreenContainers() -> [String: ScreenContainer] {
        return screenRegistry
    }
    
    /// Remove a screen container
    static func removeScreenContainer(name: String) {
        screenRegistry.removeValue(forKey: name)
    }
    
    /// Get screen containers by presentation style
    static func getScreenContainers(byPresentationStyle style: String) -> [ScreenContainer] {
        return screenRegistry.values.filter { $0.presentationStyle == style }
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
