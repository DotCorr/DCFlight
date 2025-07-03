import UIKit
import dcflight

class DCFScreenComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        guard let screenName = props["name"] as? String,
              let presentationStyle = props["presentationStyle"] as? String else {
            print("❌ DCFScreenComponent: Missing required props 'name' or 'presentationStyle'")
            return UIView()
        }
        
        // 🎯 FIXED: Create context-aware screen key for ALL presentation styles
        let contextKey = createContextKey(screenName: screenName, presentationStyle: presentationStyle)
        
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[contextKey] {
            screenContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(contextKey)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[contextKey] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(contextKey)'")
        }
        
        configureScreen(screenContainer, props: props)
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        
        let _ = updateView(screenContainer.contentView, withProps: props)
        
        return screenContainer.contentView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // 🎯 FIXED: Better prop handling - try to find existing container first
        if let existingContainer = findScreenContainer(for: view) {
            // Use existing container's info if props are missing
            return updateExistingScreen(existingContainer, view: view, props: props)
        }
        
        // If no existing container, we need name and presentationStyle
        guard let screenName = props["name"] as? String,
              let presentationStyle = props["presentationStyle"] as? String else {
            print("❌ DCFScreenComponent: Missing required props 'name' or 'presentationStyle' for new screen")
            // 🎯 FIXED: Apply basic styles even if we can't handle navigation
            view.applyStyles(props: props)
            return false
        }
        
        let contextKey = createContextKey(screenName: screenName, presentationStyle: presentationStyle)
        
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[contextKey] {
            screenContainer = existing
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[contextKey] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(contextKey)' during update")
            
            configureScreen(screenContainer, props: props)
        }
        
        return updateExistingScreen(screenContainer, view: view, props: props)
    }
    
    // 🎯 FIXED: Context-aware keys for ALL presentation styles
    private func createContextKey(screenName: String, presentationStyle: String) -> String {
        switch presentationStyle {
        case "tab":
            // Tab screens are singleton - one per screen name
            return "tab_\(screenName)"
        case "push":
            // Push screens can have multiple instances, but we'll reuse if possible
            // This prevents creating too many containers
            let existingPushKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("push_\(screenName)_") }
            if let existingKey = existingPushKeys.first {
                return existingKey
            }
            return "push_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "modal":
            // Modal screens can have multiple instances, but we'll reuse if possible
            let existingModalKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("modal_\(screenName)_") }
            if let existingKey = existingModalKeys.first {
                return existingKey
            }
            return "modal_\(screenName)_\(UUID().uuidString.prefix(8))"
        default:
            return "unknown_\(screenName)_\(UUID().uuidString.prefix(8))"
        }
    }
    
    private func updateExistingScreen(_ screenContainer: ScreenContainer, view: UIView, props: [String: Any]) -> Bool {
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        handleNavigationCommand(screenContainer: screenContainer, props: props)
        
        view.applyStyles(props: props)
        return true
    }
    
    private func handleNavigationCommand(screenContainer: ScreenContainer, props: [String: Any]) {
        guard let commandData = props["navigationCommand"] as? [String: Any] else {
            return
        }
        
        print("🚀 DCFScreenComponent: Processing navigation command for '\(screenContainer.name)': \(commandData)")
        
        if let pushToData = commandData["pushTo"] as? [String: Any] {
            if let targetScreenName = pushToData["screenName"] as? String {
                let animated = pushToData["animated"] as? Bool ?? true
                let params = pushToData["params"] as? [String: Any]
                pushToScreen(targetScreenName, animated: animated, params: params, from: screenContainer)
            }
        }
        
        if let popData = commandData["pop"] as? [String: Any] {
            let animated = popData["animated"] as? Bool ?? true
            let result = popData["result"] as? [String: Any]
            popCurrentScreen(animated: animated, result: result, from: screenContainer)
        }
        
        if let popToData = commandData["popTo"] as? [String: Any] {
            if let targetScreenName = popToData["screenName"] as? String {
                let animated = popToData["animated"] as? Bool ?? true
                popToScreen(targetScreenName, animated: animated, from: screenContainer)
            }
        }
        
        if let popToRootData = commandData["popToRoot"] as? [String: Any] {
            let animated = popToRootData["animated"] as? Bool ?? true
            popToRootScreen(animated: animated, from: screenContainer)
        }
        
        if let replaceData = commandData["replaceWith"] as? [String: Any] {
            if let targetScreenName = replaceData["screenName"] as? String {
                let animated = replaceData["animated"] as? Bool ?? true
                let params = replaceData["params"] as? [String: Any]
                replaceCurrentScreen(with: targetScreenName, animated: animated, params: params, from: screenContainer)
            }
        }
        
        if let modalData = commandData["presentModal"] as? [String: Any] {
            if let targetScreenName = modalData["screenName"] as? String {
                let animated = modalData["animated"] as? Bool ?? true
                let params = modalData["params"] as? [String: Any]
                let presentationStyle = modalData["presentationStyle"] as? String
                presentModalScreen(targetScreenName, animated: animated, params: params, presentationStyle: presentationStyle, from: screenContainer)
            }
        }
        
        if let dismissData = commandData["dismissModal"] as? [String: Any] {
            let animated = dismissData["animated"] as? Bool ?? true
            let result = dismissData["result"] as? [String: Any]
            dismissModalScreen(animated: animated, result: result, from: screenContainer)
        }
    }
    
    // 🎯 FIXED: Smart navigation that handles ALL presentation styles properly
    private func pushToScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("🎯 DCFScreenComponent: Smart push to '\(screenName)' from '\(sourceContainer.name)'")
        
        // 1. Check if target is a tab screen - if so, switch to tab
        let tabContextKey = "tab_\(screenName)"
        if let tabContainer = DCFScreenComponent.screenRegistry[tabContextKey] {
            print("🎯 DCFScreenComponent: Target '\(screenName)' is a tab screen - switching to tab instead of pushing")
            switchToTabScreen(screenName, params: params, from: sourceContainer, animated: animated)
            return
        }
        
        // 2. For non-tab screens, proceed with regular push
        let pushContextKey = createContextKey(screenName: screenName, presentationStyle: "push")
        
        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[pushContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing push container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "push")
            DCFScreenComponent.screenRegistry[pushContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new push container for '\(screenName)'")
        }
        
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No active navigation controller found for push")
            return
        }
        
        // Configure and push the screen
        configureScreenForPush(targetContainer)
        
        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground
        
        targetContainer.contentView.setNeedsLayout()
        targetContainer.contentView.layoutIfNeeded()
        
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        navigationController.pushViewController(targetContainer.viewController, animated: animated)
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "pushTo",
                "targetScreen": screenName,
                "animated": animated
            ]
        )
        
        print("✅ DCFScreenComponent: Successfully pushed new container for '\(screenName)'")
    }
    
    // 🎯 FIXED: Smart modal presentation
    private func presentModalScreen(_ screenName: String, animated: Bool, params: [String: Any]?, presentationStyle: String?, from sourceContainer: ScreenContainer) {
        print("🎯 DCFScreenComponent: Smart modal presentation for '\(screenName)' from '\(sourceContainer.name)'")
        
        // 1. Check if target is a tab screen - if so, switch to tab
        let tabContextKey = "tab_\(screenName)"
        if let tabContainer = DCFScreenComponent.screenRegistry[tabContextKey] {
            print("🎯 DCFScreenComponent: Target '\(screenName)' is a tab screen - switching to tab instead of presenting modal")
            switchToTabScreen(screenName, params: params, from: sourceContainer, animated: animated)
            return
        }
        
        // 2. Regular modal presentation - create new modal container
        let modalContextKey = createContextKey(screenName: screenName, presentationStyle: "modal")
        
        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[modalContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing modal container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "modal")
            DCFScreenComponent.screenRegistry[modalContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new modal container for '\(screenName)'")
        }
        
        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found")
            return
        }
        
        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground
        
        targetContainer.contentView.setNeedsLayout()
        targetContainer.contentView.layoutIfNeeded()
        
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
        
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        presentingViewController.present(targetContainer.viewController, animated: animated) {
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
        
        print("✅ DCFScreenComponent: Successfully presented new modal container for '\(screenName)'")
    }
    
    // 🎯 FIXED: Proper tab switching with full event handling
    private func switchToTabScreen(_ screenName: String, params: [String: Any]?, from sourceContainer: ScreenContainer, animated: Bool) {
        let tabContextKey = "tab_\(screenName)"
        guard let tabContainer = DCFScreenComponent.screenRegistry[tabContextKey] else {
            print("❌ DCFScreenComponent: Tab screen '\(screenName)' not found")
            return
        }
        
        // Switch to the tab
        guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController else {
            print("❌ DCFScreenComponent: No tab bar controller found")
            return
        }
        
        // Find which tab contains this screen
        var tabIndex: Int? = nil
        for (index, viewController) in (tabBarController.viewControllers ?? []).enumerated() {
            if let navController = viewController as? UINavigationController,
               navController.viewControllers.contains(tabContainer.viewController) {
                tabIndex = index
                break
            }
        }
        
        guard let foundTabIndex = tabIndex else {
            print("⚠️ DCFScreenComponent: Could not find tab containing screen '\(screenName)'")
            return
        }
        
        print("🎯 DCFScreenComponent: Switching to tab \(foundTabIndex) for screen '\(screenName)'")
        
        // Perform the tab switch
        tabBarController.selectedIndex = foundTabIndex
        
        // Send params to the tab screen
        if let params = params {
            propagateEvent(
                on: tabContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        // Send navigation event to source
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "switchToTab",
                "targetScreen": screenName,
                "animated": animated
            ]
        )
        
        // Trigger tab appear events
        propagateEvent(
            on: tabContainer.contentView,
            eventName: "onAppear",
            data: ["screenName": screenName]
        )
        
        propagateEvent(
            on: tabContainer.contentView,
            eventName: "onActivate",
            data: ["screenName": screenName]
        )
        
        print("✅ DCFScreenComponent: Successfully switched to tab '\(screenName)'")
    }
    
    private func popCurrentScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for pop")
            return
        }
        
        guard navigationController.viewControllers.count > 1 else {
            print("❌ DCFScreenComponent: Cannot pop root view controller")
            return
        }
        
        let targetViewController = navigationController.viewControllers[navigationController.viewControllers.count - 2]
        
        var targetScreenName: String? = nil
        for (_, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == targetViewController {
                targetScreenName = container.name
                break
            }
        }
        
        if let result = result, let targetName = targetScreenName {
            // Find the target container and send result
            for (_, container) in DCFScreenComponent.screenRegistry {
                if container.name == targetName {
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onReceiveParams",
                        data: ["result": result, "source": sourceContainer.name]
                    )
                    break
                }
            }
        }
        
        navigationController.popViewController(animated: animated)
        
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
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for popTo")
            return
        }
        
        // Find the target container in the navigation stack
        var targetViewController: UIViewController?
        for (_, container) in DCFScreenComponent.screenRegistry {
            if container.name == screenName && navigationController.viewControllers.contains(container.viewController) {
                targetViewController = container.viewController
                break
            }
        }
        
        guard let targetVC = targetViewController else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found in navigation stack")
            return
        }
        
        navigationController.popToViewController(targetVC, animated: animated)
        
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
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for popToRoot")
            return
        }
        
        navigationController.popToRootViewController(animated: animated)
        
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
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for replace")
            return
        }
        
        // Create new container for replacement
        let replaceContextKey = createContextKey(screenName: screenName, presentationStyle: "push")
        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[replaceContextKey] {
            targetContainer = existing
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "push")
            DCFScreenComponent.screenRegistry[replaceContextKey] = targetContainer
        }
        
        configureScreenForPush(targetContainer)
        
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }
        
        var viewControllers = navigationController.viewControllers
        viewControllers[viewControllers.count - 1] = targetContainer.viewController
        navigationController.setViewControllers(viewControllers, animated: animated)
        
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
    
    private func dismissModalScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
            // Find the presenting container and send result
            for (_, container) in DCFScreenComponent.screenRegistry {
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
        
        sourceContainer.viewController.dismiss(animated: animated) {
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
    
    // Helper methods
    private func getCurrentActiveNavigationController() -> UINavigationController? {
        if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
           let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
            return selectedNavController
        }
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            return findNavigationController(in: rootViewController)
        }
        
        return nil
    }
    
    private func getCurrentPresentingViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            return nil
        }
        
        return getTopmostViewController(from: rootViewController)
    }
    
    private func getTopmostViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return getTopmostViewController(from: presentedViewController)
        } else if let tabBarController = viewController as? UITabBarController,
                  let selectedViewController = tabBarController.selectedViewController {
            return getTopmostViewController(from: selectedViewController)
        } else if let navigationController = viewController as? UINavigationController,
                  let topViewController = navigationController.topViewController {
            return getTopmostViewController(from: topViewController)
        } else {
            return viewController
        }
    }
    
    private func findNavigationController(in viewController: UIViewController) -> UINavigationController? {
        if let navController = viewController as? UINavigationController {
            return navController
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return findNavigationController(in: selectedViewController)
        }
        
        for child in viewController.children {
            if let navController = findNavigationController(in: child) {
                return navController
            }
        }
        
        return nil
    }
    
    private func configureScreenForPush(_ screenContainer: ScreenContainer) {
        guard let pushConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!
        ) as? [String: Any] else {
            return
        }
        
        let viewController = screenContainer.viewController
        
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
    
    private func storeTabConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var tabConfig: [String: Any] = [:]
        
        if let tabConfigData = props["tabConfig"] as? [String: Any] {
            tabConfig = tabConfigData
        } else {
            // Fallback to individual props for backwards compatibility
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
        }
        
        if !tabConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "tabConfig".hashValue)!,
                tabConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private func storePushConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var pushConfig: [String: Any] = [:]
        
        if let pushConfigData = props["pushConfig"] as? [String: Any] {
            pushConfig = pushConfigData
        } else {
            // Fallback to individual props for backwards compatibility
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
        }
        
        if !pushConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!,
                pushConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        guard let screenContainer = findScreenContainer(for: view) else {
            print("❌ DCFScreenComponent: Could not find screen container for setChildren")
            return false
        }
        
        print("📱 DCFScreenComponent: Setting \(childViews.count) children for screen '\(screenContainer.name)'")
        
        screenContainer.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        for childView in childViews {
            screenContainer.contentView.addSubview(childView)
            
            childView.frame = screenContainer.contentView.bounds
            childView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            childView.isHidden = false
            childView.alpha = 1.0
        }
        
        screenContainer.contentView.setNeedsLayout()
        screenContainer.contentView.layoutIfNeeded()
        
        for childView in childViews {
            childView.setNeedsLayout()
            childView.layoutIfNeeded()
        }
        
        return true
    }
    
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
        
        if let index = props["index"] as? Int {
            viewController.tabBarItem.tag = index
        }
    }
    
    private func configurePushScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController
        
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
            
            private func findScreenContainer(for view: UIView) -> ScreenContainer? {
                for (_, container) in DCFScreenComponent.screenRegistry {
                    if container.contentView == view {
                        return container
                    }
                }
                return nil
            }
            
            // 🎯 FIXED: Context-aware screen container lookup
            static func getScreenContainer(name: String) -> ScreenContainer? {
                // First try tab context (most common)
                let tabKey = "tab_\(name)"
                if let tabContainer = screenRegistry[tabKey] {
                    return tabContainer
                }
                
                // Then try to find any container with matching name
                for (_, container) in screenRegistry {
                    if container.name == name {
                        return container
                    }
                }
                
                return nil
            }
            
            static func getAllScreenContainers() -> [String: ScreenContainer] {
                return screenRegistry
            }
            
            static func removeScreenContainer(contextKey: String) {
                screenRegistry.removeValue(forKey: contextKey)
            }
            
            // 🎯 CLEANUP: Automatic cleanup of unused containers
            static func cleanupUnusedContainers() {
                let activeViewControllers = getAllActiveViewControllers()
                var keysToRemove: [String] = []
                
                for (contextKey, container) in screenRegistry {
                    // Don't cleanup tab containers (they're persistent)
                    if contextKey.hasPrefix("tab_") {
                        continue
                    }
                    
                    // Check if the container's view controller is still active
                    if !activeViewControllers.contains(container.viewController) {
                        keysToRemove.append(contextKey)
                    }
                }
                
                for key in keysToRemove {
                    print("🧹 DCFScreenComponent: Cleaning up unused container '\(key)'")
                    screenRegistry.removeValue(forKey: key)
                }
                
                if keysToRemove.count > 0 {
                    print("✅ DCFScreenComponent: Cleaned up \(keysToRemove.count) unused containers")
                }
            }
            
            private static func getAllActiveViewControllers() -> Set<UIViewController> {
                var activeControllers: Set<UIViewController> = []
                
                // Get all view controllers from tab bar
                if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController {
                    for tabViewController in tabBarController.viewControllers ?? [] {
                        if let navController = tabViewController as? UINavigationController {
                            activeControllers.formUnion(navController.viewControllers)
                        } else {
                            activeControllers.insert(tabViewController)
                        }
                    }
                }
                
                // Get all presented view controllers
                if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                    collectPresentedViewControllers(from: rootViewController, into: &activeControllers)
                }
                
                return activeControllers
            }
            
            private static func collectPresentedViewControllers(from viewController: UIViewController, into activeControllers: inout Set<UIViewController>) {
                activeControllers.insert(viewController)
                
                if let presentedViewController = viewController.presentedViewController {
                    collectPresentedViewControllers(from: presentedViewController, into: &activeControllers)
                }
                
                for child in viewController.children {
                    collectPresentedViewControllers(from: child, into: &activeControllers)
                }
            }
        }

        // 🎯 SIMPLIFIED: ScreenContainer without originalTabIndex
        class ScreenContainer {
            let name: String
            let presentationStyle: String
            let viewController: UIViewController
            let contentView: UIView
            var childNavigators: [Any] = []
            
            init(name: String, presentationStyle: String) {
                self.name = name
                self.presentationStyle = presentationStyle
                
                self.viewController = UIViewController()
                self.contentView = UIView()
                self.contentView.backgroundColor = UIColor.clear
                self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                self.viewController.view = contentView
                
                print("📱 ScreenContainer: Created '\(name)' with style '\(presentationStyle)'")
            }
            
            deinit {
                print("🗑️ ScreenContainer: Deallocated '\(name)' with style '\(presentationStyle)'")
            }
        }

        extension DCFScreenComponent {
            static var screenRegistry: [String: ScreenContainer] = [:]
            static var currentNavigationController: UINavigationController? = nil
            
            // 🎯 PERIODIC CLEANUP: Call this periodically to clean up unused containers
            static func startPeriodicCleanup() {
                Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                    cleanupUnusedContainers()
                }
            }
        }
