/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

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
    
    
    /// Store tab configuration from screen props on the view controller
//    critical for tabs
    private func storeTabConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var tabConfig: [String: Any] = [:]
        
        // Extract all tab-related properties from props
        if let title = props["title"] as? String {
            tabConfig["title"] = title
        }
        
        if let icon = props["icon"] {
            tabConfig["icon"] = icon
        }
        
        if let badge = props["badge"] as? String {
            tabConfig["badge"] = badge
        }
        
        if let enabled = props["enabled"] as? Bool {
            tabConfig["enabled"] = enabled
        }
        
        if let index = props["index"] as? Int {
            tabConfig["index"] = index
        }
        
        // Store tab config on the view controller for tab navigator to use
        if !tabConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "tabConfig".hashValue)!,
                tabConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            print("✅ DCFScreenComponent: Stored tab config for '\(screenContainer.name)': \(tabConfig)")
        }
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
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(screenName)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)'")
        }
        
        // Configure screen based on presentation style and props
        configureScreen(screenContainer, props: props)
        
        // CRITICAL: Store tab configuration for tab navigator to access
        storeTabConfiguration(screenContainer, props: props)
        
        // Update view with current props FIRST
        let _ = updateView(screenContainer.contentView, withProps: props)
        
        // Fire initial onAppear event when screen is created
        DispatchQueue.main.async {
            self.activateScreen(screenContainer, props: props)
        }
        
        return screenContainer.contentView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let screenName = props["name"] as? String,
              let screenContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print(" DCFScreenComponent: Screen not found for update.")
            return false
        }
        
        // CRITICAL: Update tab configuration whenever screen props change
        storeTabConfiguration(screenContainer, props: props)
        
        // Handle visibility changes
        let isVisible = props["visible"] as? Bool ?? true
        if isVisible != screenContainer.isActive {
            if isVisible {
                activateScreen(screenContainer, props: props)
            } else {
                deactivateScreen(screenContainer, props: props)
            }
        }

        view.applyStyles(props: props)
        
        return true
    }
    
    // CRITICAL FIX: Implement setChildren for DCFScreen component properly
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
        
        if #available(iOS 11.0, *) {
            viewController.extendedLayoutIncludesOpaqueBars = true
            viewController.edgesForExtendedLayout = .all
            viewController.automaticallyAdjustsScrollViewInsets = false
        } else {
            viewController.automaticallyAdjustsScrollViewInsets = false
        }
        
        // Configure tab bar item
        if let title = props["title"] as? String {
            viewController.title = title
            viewController.tabBarItem.title = title
        }
        
        if let iconName = props["icon"] as? String {
            viewController.tabBarItem.image = UIImage(systemName: iconName)
        }
        
        if let badge = props["badge"] as? String {
            viewController.tabBarItem.badgeValue = badge
        }
        
        let enabled = props["enabled"] as? Bool ?? true
        viewController.tabBarItem.isEnabled = enabled
        
        // CRITICAL FIX: Set tab bar item tag for identification
        if let index = props["index"] as? Int {
            viewController.tabBarItem.tag = index
        }
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
        
        // CRITICAL FIX: Fire events on the actual content view that DCFlight tracks
        DispatchQueue.main.async {
            // Fire onAppear event
            print("🚀 DCFScreenComponent: About to propagate onAppear event for '\(screenContainer.name)'")
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenContainer.name]
            )
            
            print("✅ DCFScreenComponent: Fired onAppear for '\(screenContainer.name)'")
            
            // Fire onActivate event
            print("🚀 DCFScreenComponent: About to propagate onActivate event for '\(screenContainer.name)'")
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onActivate",
                data: ["screenName": screenContainer.name]
            )
            
            print("✅ DCFScreenComponent: Fired onActivate for '\(screenContainer.name)'")
        }
    }
    
    private func deactivateScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        print("🔴 DCFScreenComponent: Deactivating screen '\(screenContainer.name)'")
        screenContainer.isActive = false
        
        // CRITICAL FIX: Fire events on the actual content view that DCFlight tracks
        DispatchQueue.main.async {
            // Fire onDisappear event
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onDisappear",
                data: ["screenName": screenContainer.name]
            )
            
            print("✅ DCFScreenComponent: Fired onDisappear for '\(screenContainer.name)'")
            
            // Fire onDeactivate event
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onDeactivate",
                data: ["screenName": screenContainer.name]
            )
            
            print("✅ DCFScreenComponent: Fired onDeactivate for '\(screenContainer.name)'")
        }
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
}
