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
    
    // Global navigation state tracking
    static var currentNavigationController: UINavigationController? = nil
    
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
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(screenName)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)'")
        }
        
        // Configure screen based on presentation style and props
        configureScreen(screenContainer, props: props)
        
        // Store tab configuration for tab navigator to access
        storeTabConfiguration(screenContainer, props: props)
        
        // Store push configuration for push navigation
        storePushConfiguration(screenContainer, props: props)
        
        // Update view with current props FIRST
        let _ = updateView(screenContainer.contentView, withProps: props)
        
        // Only fire initial onAppear event for visible screens
        let isVisible = props["visible"] as? Bool ?? true
        if isVisible {
            DispatchQueue.main.async {
                self.activateScreen(screenContainer, props: props)
            }
        }
        
        return screenContainer.contentView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // CRITICAL FIX: Always check for screen name first, but handle gracefully if missing
        guard let screenName = props["name"] as? String else {
            // If no screen name in props, try to find it from existing registry
            if let container = findScreenContainer(for: view) {
                print("⚠️ DCFScreenComponent: Using existing screen name '\(container.name)' for update")
                return updateExistingScreen(container, view: view, props: props)
            } else {
                print("❌ DCFScreenComponent: Missing screen name in props and no existing container found")
                // Apply basic styles even if we can't identify the screen
                view.applyStyles(props: props)
                return false
            }
        }
        
        // Get or create screen container
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
        } else {
            // Create the screen container if it doesn't exist yet
            guard let presentationStyle = props["presentationStyle"] as? String else {
                print("❌ DCFScreenComponent: Missing presentationStyle for new screen '\(screenName)'")
                return false
            }
            
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)' during update")
            
            // Configure the newly created screen
            configureScreen(screenContainer, props: props)
        }
        
        return updateExistingScreen(screenContainer, view: view, props: props)
    }
    
    // CRITICAL FIX: Separate method to update existing screen
    private func updateExistingScreen(_ screenContainer: ScreenContainer, view: UIView, props: [String: Any]) -> Bool {
        // Update tab configuration whenever screen props change
        storeTabConfiguration(screenContainer, props: props)
        
        // Update push configuration whenever screen props change
        storePushConfiguration(screenContainer, props: props)
        
        // Handle navigation commands
        handleNavigationCommand(screenContainer: screenContainer, props: props)
        
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
    
    // MARK: - Navigation Command Handling
    
    private func handleNavigationCommand(screenContainer: ScreenContainer, props: [String: Any]) {
        guard let commandData = props["navigationCommand"] as? [String: Any] else {
            return
        }
        
        // CRITICAL FIX: Generate a unique command ID and track processed commands
        let commandId = generateCommandId(from: commandData)
        
        // Check if this command has already been processed
        if hasCommandBeenProcessed(commandId) {
            print("⚠️ DCFScreenComponent: Command '\(commandId)' already processed, skipping for '\(screenContainer.name)'")
            return
        }
        
        // Mark command as processed IMMEDIATELY
        markCommandAsProcessed(commandId)
        
        print("🚀 DCFScreenComponent: Processing navigation command for '\(screenContainer.name)': \(commandData)")
        
        // Handle pushTo command
        if let pushToData = commandData["pushTo"] as? [String: Any] {
            if let targetScreenName = pushToData["screenName"] as? String {
                let animated = pushToData["animated"] as? Bool ?? true
                let params = pushToData["params"] as? [String: Any]
                pushToScreen(targetScreenName, animated: animated, params: params, from: screenContainer)
            }
        }
        
        // Handle pop command
        if let popData = commandData["pop"] as? [String: Any] {
            let animated = popData["animated"] as? Bool ?? true
            let result = popData["result"] as? [String: Any]
            popCurrentScreen(animated: animated, result: result, from: screenContainer)
        }
        
        // Handle popTo command
        if let popToData = commandData["popTo"] as? [String: Any] {
            if let targetScreenName = popToData["screenName"] as? String {
                let animated = popToData["animated"] as? Bool ?? true
                popToScreen(targetScreenName, animated: animated, from: screenContainer)
            }
        }
        
        // Handle popToRoot command
        if let popToRootData = commandData["popToRoot"] as? [String: Any] {
            let animated = popToRootData["animated"] as? Bool ?? true
            popToRootScreen(animated: animated, from: screenContainer)
        }
        
        // Handle replaceWith command
        if let replaceData = commandData["replaceWith"] as? [String: Any] {
            if let targetScreenName = replaceData["screenName"] as? String {
                let animated = replaceData["animated"] as? Bool ?? true
                let params = replaceData["params"] as? [String: Any]
                replaceCurrentScreen(with: targetScreenName, animated: animated, params: params, from: screenContainer)
            }
        }
        
        // Handle presentModal command
        if let modalData = commandData["presentModal"] as? [String: Any] {
            if let targetScreenName = modalData["screenName"] as? String {
                let animated = modalData["animated"] as? Bool ?? true
                let params = modalData["params"] as? [String: Any]
                let presentationStyle = modalData["presentationStyle"] as? String
                presentModalScreen(targetScreenName, animated: animated, params: params, presentationStyle: presentationStyle, from: screenContainer)
            }
        }
        
        // Handle dismissModal command
        if let dismissData = commandData["dismissModal"] as? [String: Any] {
            let animated = dismissData["animated"] as? Bool ?? true
            let result = dismissData["result"] as? [String: Any]
            dismissModalScreen(animated: animated, result: result, from: screenContainer)
        }
    }
    
    // MARK: - Navigation Operations
    
    private func pushToScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        // CRITICAL FIX: Ensure target screen exists and is configured properly
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for push navigation")
            print("   Available screens: \(Array(DCFScreenComponent.screenRegistry.keys))")
            return
        }
        
        print("🚀 DCFScreenComponent: Pushing to screen '\(screenName)'")
        
        // Ensure we have a navigation controller
        let navigationController = getOrCreateNavigationController()
        
        // CRITICAL SAFETY CHECK: Don't push if the target screen is already in the stack
        if navigationController.viewControllers.contains(targetContainer.viewController) {
            print("⚠️ DCFScreenComponent: Screen '\(screenName)' is already in navigation stack, skipping push")
            return
        }
        
        // CRITICAL SAFETY CHECK: Don't push if the target screen is already the top view controller
        if navigationController.topViewController == targetContainer.viewController {
            print("⚠️ DCFScreenComponent: Screen '\(screenName)' is already the top view controller, skipping push")
            return
        }
        
        // Configure the target screen for push
        configureScreenForPush(targetContainer)
        
        // Pass parameters if provided
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        // Push the screen
        navigationController.pushViewController(targetContainer.viewController, animated: animated)
        
        // Fire navigation event
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "pushTo",
                "targetScreen": screenName,
                "animated": animated
            ]
        )
        
        print("✅ DCFScreenComponent: Successfully pushed screen '\(screenName)' from '\(sourceContainer.name)'")
    }
    
    private func popCurrentScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        guard let navigationController = DCFScreenComponent.currentNavigationController else {
            print("❌ DCFScreenComponent: No navigation controller found for pop")
            return
        }
        
        guard navigationController.viewControllers.count > 1 else {
            print("❌ DCFScreenComponent: Cannot pop root view controller")
            return
        }
        
        // Get the target screen (the one we're popping back to)
        let targetViewController = navigationController.viewControllers[navigationController.viewControllers.count - 2]
        
        // Find target screen name
        var targetScreenName: String? = nil
        for (name, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == targetViewController {
                targetScreenName = name
                break
            }
        }
        
        // Pass result if provided
        if let result = result, let targetName = targetScreenName, let targetContainer = DCFScreenComponent.screenRegistry[targetName] {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["result": result, "source": sourceContainer.name]
            )
        }
        
        // Pop the screen
        navigationController.popViewController(animated: animated)
        
        // Fire navigation event
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "pop",
                "targetScreen": targetScreenName as Any,
                "animated": animated
            ]
        )
        
        print("✅ DCFScreenComponent: Popped screen '\(sourceContainer.name)'")
    }
    
    private func popToScreen(_ screenName: String, animated: Bool, from sourceContainer: ScreenContainer) {
        guard let navigationController = DCFScreenComponent.currentNavigationController else {
            print("❌ DCFScreenComponent: No navigation controller found for popTo")
            return
        }
        
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for popTo")
            return
        }
        
        // Find the target view controller in the stack
        guard let targetViewController = navigationController.viewControllers.first(where: { $0 == targetContainer.viewController }) else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found in navigation stack")
            return
        }
        
        // Pop to the target screen
        navigationController.popToViewController(targetViewController, animated: animated)
        
        // Fire navigation event
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "popTo",
                "targetScreen": screenName,
                "animated": animated
            ]
        )
        
        print("✅ DCFScreenComponent: Popped to screen '\(screenName)' from '\(sourceContainer.name)'")
    }
    
    private func popToRootScreen(animated: Bool, from sourceContainer: ScreenContainer) {
        guard let navigationController = DCFScreenComponent.currentNavigationController else {
            print("❌ DCFScreenComponent: No navigation controller found for popToRoot")
            return
        }
        
        // Pop to root
        navigationController.popToRootViewController(animated: animated)
        
        // Fire navigation event
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "popToRoot",
                "animated": animated
            ]
        )
        
        print("✅ DCFScreenComponent: Popped to root from '\(sourceContainer.name)'")
    }
    
    private func replaceCurrentScreen(with screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        guard let navigationController = DCFScreenComponent.currentNavigationController else {
            print("❌ DCFScreenComponent: No navigation controller found for replace")
            return
        }
        
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for replace")
            return
        }
        
        // Configure the target screen for push
        configureScreenForPush(targetContainer)
        
        // Pass parameters if provided
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        // Replace current screen
        var viewControllers = navigationController.viewControllers
        viewControllers[viewControllers.count - 1] = targetContainer.viewController
        navigationController.setViewControllers(viewControllers, animated: animated)
        
        // Fire navigation event
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "replaceWith",
                "targetScreen": screenName,
                "animated": animated
            ]
        )
        
        print("✅ DCFScreenComponent: Replaced '\(sourceContainer.name)' with '\(screenName)'")
    }
    
    private func presentModalScreen(_ screenName: String, animated: Bool, params: [String: Any]?, presentationStyle: String?, from sourceContainer: ScreenContainer) {
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for modal presentation")
            print("   Available screens: \(Array(DCFScreenComponent.screenRegistry.keys))")
            return
        }
        
        print("🚀 DCFScreenComponent: Presenting modal '\(screenName)'")
        
        // Configure modal presentation style
        if let style = presentationStyle {
            switch style.lowercased() {
            case "fullscreen":
                targetContainer.viewController.modalPresentationStyle = .fullScreen
            case "pagesheet":
                if #available(iOS 13.0, *) {
                    targetContainer.viewController.modalPresentationStyle = .pageSheet
                }
            case "formsheet":
                targetContainer.viewController.modalPresentationStyle = .formSheet
            default:
                if #available(iOS 13.0, *) {
                    targetContainer.viewController.modalPresentationStyle = .pageSheet
                }
            }
        }
        
        // Pass parameters if provided
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        // Present modal
        sourceContainer.viewController.present(targetContainer.viewController, animated: animated) {
            // Fire navigation event after presentation
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentModal",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )
        }
        
        print("✅ DCFScreenComponent: Presented modal '\(screenName)' from '\(sourceContainer.name)'")
    }
    
    private func dismissModalScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        // Pass result to presenting screen if provided
        if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
            // Find presenting screen
            for (name, container) in DCFScreenComponent.screenRegistry {
                if container.viewController == presentingViewController {
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onReceiveParams",
                        data: ["result": result, "source": sourceContainer.name]
                    )
                    break
                }
            }
        }
        
        // Dismiss modal
        sourceContainer.viewController.dismiss(animated: animated) {
            // Fire navigation event after dismissal
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "dismissModal",
                    "animated": animated
                ]
            )
        }
        
        print("✅ DCFScreenComponent: Dismissed modal '\(sourceContainer.name)'")
    }
    
    // MARK: - Command Deduplication
    
    // Static storage for processed commands
    private static var processedCommands = Set<String>()
    private static let commandQueue = DispatchQueue(label: "com.dcf.navigation.commands", qos: .userInitiated)
    
    private func generateCommandId(from commandData: [String: Any]) -> String {
        // Create a unique ID based on command content and timestamp
        let commandString = String(describing: commandData)
        return "\(commandString.hashValue)"
    }
    
    private func hasCommandBeenProcessed(_ commandId: String) -> Bool {
        return DCFScreenComponent.commandQueue.sync {
            return DCFScreenComponent.processedCommands.contains(commandId)
        }
    }
    
    private func markCommandAsProcessed(_ commandId: String) {
        DCFScreenComponent.commandQueue.sync {
            DCFScreenComponent.processedCommands.insert(commandId)
            
            // Clean up old commands (keep only last 50)
            if DCFScreenComponent.processedCommands.count > 50 {
                let commandsArray = Array(DCFScreenComponent.processedCommands)
                let toRemove = commandsArray.prefix(commandsArray.count - 25)
                for command in toRemove {
                    DCFScreenComponent.processedCommands.remove(command)
                }
            }
        }
    }
    
    // MARK: - Navigation Controller Management
    
    private func getOrCreateNavigationController() -> UINavigationController {
        if let existing = DCFScreenComponent.currentNavigationController {
            return existing
        }
        
        // CRITICAL FIX: Check if there's already a navigation controller in the view hierarchy
        if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
           let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
            DCFScreenComponent.currentNavigationController = selectedNavController
            print("✅ DCFScreenComponent: Found existing navigation controller from tab bar")
            return selectedNavController
        }
        
        // Create new navigation controller only if none exists
        let navigationController = UINavigationController()
        DCFScreenComponent.currentNavigationController = navigationController
        
        // Configure navigation bar
        navigationController.navigationBar.prefersLargeTitles = true
        
        print("✅ DCFScreenComponent: Created new navigation controller")
        
        return navigationController
    }
    
    private func configureScreenForPush(_ screenContainer: ScreenContainer) {
        // Get stored push configuration
        guard let pushConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!
        ) as? [String: Any] else {
            return
        }
        
        let viewController = screenContainer.viewController
        
        // Configure navigation item
        if let title = pushConfig["title"] as? String {
            viewController.navigationItem.title = title
        }
        
        let hideBackButton = pushConfig["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton
        
        if let backButtonTitle = pushConfig["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }
        
        let largeTitleDisplayMode = pushConfig["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode = largeTitleDisplayMode ? .always : .never
        }
    }
    
    // MARK: - Screen Configuration (Existing Methods)
    
    /// Store tab configuration from screen props on the view controller
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
        }
    }
    
    /// Store push configuration from screen props on the view controller
    private func storePushConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var pushConfig: [String: Any] = [:]
        
        // Extract all push-related properties from props
        if let title = props["title"] as? String {
            pushConfig["title"] = title
        }
        
        if let hideNavigationBar = props["hideNavigationBar"] as? Bool {
            pushConfig["hideNavigationBar"] = hideNavigationBar
        }
        
        if let hideBackButton = props["hideBackButton"] as? Bool {
            pushConfig["hideBackButton"] = hideBackButton
        }
        
        if let backButtonTitle = props["backButtonTitle"] as? String {
            pushConfig["backButtonTitle"] = backButtonTitle
        }
        
        if let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool {
            pushConfig["largeTitleDisplayMode"] = largeTitleDisplayMode
        }
        
        // Store push config on the view controller for navigation to use
        if !pushConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!,
                pushConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
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
        
        // Set tab bar item tag for identification
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
        
        // Fire events on the actual content view that DCFlight tracks
        DispatchQueue.main.async {
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
    }
    
    private func deactivateScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        print("🔴 DCFScreenComponent: Deactivating screen '\(screenContainer.name)'")
        screenContainer.isActive = false
        
        // Fire events on the actual content view that DCFlight tracks
        DispatchQueue.main.async {
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