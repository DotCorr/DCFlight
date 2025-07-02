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
        
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(screenName)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)'")
        }
        
        configureScreen(screenContainer, props: props)
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        
        let _ = updateView(screenContainer.contentView, withProps: props)
        
        return screenContainer.contentView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let screenName = props["name"] as? String else {
            if let container = findScreenContainer(for: view) {
                print("⚠️ DCFScreenComponent: Using existing screen name '\(container.name)' for update")
                return updateExistingScreen(container, view: view, props: props)
            } else {
                print("❌ DCFScreenComponent: Missing screen name in props and no existing container found")
                view.applyStyles(props: props)
                return false
            }
        }
        
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
        } else {
            guard let presentationStyle = props["presentationStyle"] as? String else {
                print("❌ DCFScreenComponent: Missing presentationStyle for new screen '\(screenName)'")
                return false
            }
            
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)' during update")
            
            configureScreen(screenContainer, props: props)
        }
        
        return updateExistingScreen(screenContainer, view: view, props: props)
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
    
    private func pushToScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for push navigation")
            print("   Available screens: \(Array(DCFScreenComponent.screenRegistry.keys))")
            return
        }
        
        print("🚀 DCFScreenComponent: Pushing to screen '\(screenName)'")
        
        // CRITICAL FIX: Get the current navigation controller from the active tab
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No active navigation controller found for push")
            return
        }
        
        // 🎯 SIMPLE FIX: If it's a tab screen, don't push - just switch to that tab!
        if targetContainer.presentationStyle == "tab" {
            print("🎯 DCFScreenComponent: Switching to tab screen '\(screenName)' instead of pushing")
            switchToTabScreen(screenName)
            
            // Send params to the tab screen
            if let params = params {
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onReceiveParams",
                    data: ["params": params, "source": sourceContainer.name]
                )
            }
            
            // Send navigation event
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "pushTo",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )
            
            print("✅ DCFScreenComponent: Switched to tab screen '\(screenName)'")
            return
        }
        
        // Regular push for non-tab screens
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
        
        print("✅ DCFScreenComponent: Successfully pushed screen '\(screenName)' from '\(sourceContainer.name)'")
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
        for (name, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == targetViewController {
                targetScreenName = name
                break
            }
        }
        
        if let result = result, let targetName = targetScreenName, let targetContainer = DCFScreenComponent.screenRegistry[targetName] {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["result": result, "source": sourceContainer.name]
            )
        }
        
        navigationController.popViewController(animated: animated)
        
        // 🎯 FIX: Restore screen to its original tab if it was a tab screen
        if sourceContainer.presentationStyle == "tab" && sourceContainer.originalTabIndex != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.35 : 0.1)) {
                self.restoreScreenToTab(sourceContainer)
            }
        }
        
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
        
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for popTo")
            return
        }
        
        guard let targetViewController = navigationController.viewControllers.first(where: { $0 == targetContainer.viewController }) else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found in navigation stack")
            return
        }
        
        navigationController.popToViewController(targetViewController, animated: animated)
        
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
        
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for replace")
            return
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
    
    private func presentModalScreen(_ screenName: String, animated: Bool, params: [String: Any]?, presentationStyle: String?, from sourceContainer: ScreenContainer) {
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Target screen '\(screenName)' not found for modal presentation")
            print("   Available screens: \(Array(DCFScreenComponent.screenRegistry.keys))")
            return
        }
        
        print("🚀 DCFScreenComponent: Presenting modal '\(screenName)'")
        
        // CRITICAL FIX: Get the proper presenting view controller
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
        
        print("✅ DCFScreenComponent: Presented modal '\(screenName)' from '\(sourceContainer.name)'")
    }
    
    private func dismissModalScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
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
    
    // CRITICAL FIX: Helper to get the current active navigation controller
    private func getCurrentActiveNavigationController() -> UINavigationController? {
        // First try to get from the current tab bar's selected navigation controller
        if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
           let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
            return selectedNavController
        }
        
        // Fallback: look for any navigation controller in the hierarchy
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            return findNavigationController(in: rootViewController)
        }
        
        return nil
    }
    
    // CRITICAL FIX: Helper to get the proper presenting view controller
    private func getCurrentPresentingViewController() -> UIViewController? {
        // Get the topmost view controller that can present modals
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
        
        for (index, childView) in childViews.enumerated() {
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
    
    static func getScreenContainer(name: String) -> ScreenContainer? {
        return screenRegistry[name]
    }
    
    static func getAllScreenContainers() -> [String: ScreenContainer] {
        return screenRegistry
    }
    
    static func removeScreenContainer(name: String) {
        screenRegistry.removeValue(forKey: name)
    }
    
    // 🎯 MINIMAL HELPER: Restore tab screen after pop
    private func restoreScreenToTab(_ screenContainer: ScreenContainer) {
        guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
              let tabIndex = screenContainer.originalTabIndex,
              tabIndex >= 0 && tabIndex < (tabBarController.viewControllers?.count ?? 0) else {
            print("❌ DCFScreenComponent: Cannot restore '\(screenContainer.name)' - invalid tab index")
            return
        }
        
        guard let navController = tabBarController.viewControllers?[tabIndex] as? UINavigationController else {
            print("❌ DCFScreenComponent: Tab \(tabIndex) is not a navigation controller")
            return
        }
        
        // Restore the screen as the root of its original tab
        navController.setViewControllers([screenContainer.viewController], animated: false)
        
        // Clear the stolen flag
        screenContainer.originalTabIndex = nil
        
        print("✅ DCFScreenComponent: Restored '\(screenContainer.name)' to tab \(tabIndex)")
    }
    
    // 🎯 HELPER: Find which tab currently contains a screen
    private func findTabIndexForScreen(_ screenContainer: ScreenContainer) -> Int? {
        guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController else {
            return nil
        }
        
        for (index, viewController) in (tabBarController.viewControllers ?? []).enumerated() {
            if let navController = viewController as? UINavigationController {
                if navController.viewControllers.contains(screenContainer.viewController) {
                    return index
                }
            }
        }
        
        return nil
    }
    
    // 🎯 SIMPLE HELPER: Switch to the tab that contains the target screen
    private func switchToTabScreen(_ screenName: String) {
        guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
              let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: Cannot switch to tab screen '\(screenName)'")
            return
        }
        
        // Find which tab contains this screen
        for (index, viewController) in (tabBarController.viewControllers ?? []).enumerated() {
            if let navController = viewController as? UINavigationController,
               navController.viewControllers.contains(targetContainer.viewController) {
                
                print("🎯 DCFScreenComponent: Switching to tab \(index) for screen '\(screenName)'")
                tabBarController.selectedIndex = index
                return
            }
        }
        
        print("⚠️ DCFScreenComponent: Could not find tab containing screen '\(screenName)'")
    }
}

class ScreenContainer {
    let name: String
    let presentationStyle: String
    let viewController: UIViewController
    let contentView: UIView
    var childNavigators: [Any] = []
    
    // 🎯 TRACK: Which tab this screen was stolen from
    var originalTabIndex: Int? = nil
    
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
        
        self.contentView = UIView()
        self.contentView.backgroundColor = UIColor.clear
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.viewController.view = contentView
    }
}

extension DCFScreenComponent {
    static var screenRegistry: [String: ScreenContainer] = [:]
    static var currentNavigationController: UINavigationController? = nil
}
