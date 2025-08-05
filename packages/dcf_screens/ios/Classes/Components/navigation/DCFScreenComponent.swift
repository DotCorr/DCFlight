import UIKit
import dcflight
import SVGKit

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

        // 🎯 REMOVED: Smart context key system - use simple screen name
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(screenName)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            DCFScreenComponent.screenPresentationRegistry[screenName] = presentationStyle
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)' and registered presentation style '\(presentationStyle)'")
        }

        configureScreen(screenContainer, props: props)
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        storeModalConfiguration(screenContainer, props: props)
        storePopoverConfiguration(screenContainer, props: props)
        storeOverlayConfiguration(screenContainer, props: props)
        storeSheetConfiguration(screenContainer, props: props)

        let _ = updateView(screenContainer.contentView, withProps: props)

        return screenContainer.contentView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        if let existingContainer = findScreenContainer(for: view) {
            return updateExistingScreen(existingContainer, view: view, props: props)
        }

        guard let screenName = props["name"] as? String,
              let presentationStyle = props["presentationStyle"] as? String else {
            print("❌ DCFScreenComponent: Missing required props for update - applying basic styles only")
            view.applyStyles(props: props)
            return false
        }

        // 🎯 REMOVED: Smart context key system - use simple screen name
        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[screenName] {
            screenContainer = existing
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[screenName] = screenContainer
            DCFScreenComponent.screenPresentationRegistry[screenName] = presentationStyle
            print("✅ DCFScreenComponent: Created new screen container for '\(screenName)' during update")
            configureScreen(screenContainer, props: props)
        }

        return updateExistingScreen(screenContainer, view: view, props: props)
    }

    // 🎯 REMOVED: Complex createContextKey function - no longer needed

    private func updateExistingScreen(_ screenContainer: ScreenContainer, view: UIView, props: [String: Any]) -> Bool {
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        storeModalConfiguration(screenContainer, props: props)
        storePopoverConfiguration(screenContainer, props: props)
        storeOverlayConfiguration(screenContainer, props: props)
        storeSheetConfiguration(screenContainer, props: props)
        storeNavigationBarConfiguration(screenContainer, props: props)
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

        if let modalData = commandData["presentModal"] as? [String: Any] {
            if let targetScreenName = modalData["screenName"] as? String {
                let animated = modalData["animated"] as? Bool ?? true
                let params = modalData["params"] as? [String: Any]
                let presentationStyle = modalData["presentationStyle"] as? String
                presentModalScreen(targetScreenName, animated: animated, params: params, presentationStyle: presentationStyle, from: screenContainer)
            }
        }

        if let sheetData = commandData["presentSheet"] as? [String: Any] {
            if let targetScreenName = sheetData["screenName"] as? String {
                let animated = sheetData["animated"] as? Bool ?? true
                let params = sheetData["params"] as? [String: Any]
                presentSheetScreen(targetScreenName, animated: animated, params: params, from: screenContainer)
            }
        }

        if let popoverData = commandData["presentPopover"] as? [String: Any] {
            if let targetScreenName = popoverData["screenName"] as? String {
                let animated = popoverData["animated"] as? Bool ?? true
                let params = popoverData["params"] as? [String: Any]
                let sourceViewId = popoverData["sourceViewId"] as? String
                presentPopoverScreen(targetScreenName, animated: animated, params: params, sourceViewId: sourceViewId, from: screenContainer)
            }
        }

        if let overlayData = commandData["presentOverlay"] as? [String: Any] {
            if let targetScreenName = overlayData["screenName"] as? String {
                let animated = overlayData["animated"] as? Bool ?? true
                let params = overlayData["params"] as? [String: Any]
                presentOverlayScreen(targetScreenName, animated: animated, params: params, from: screenContainer)
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

        if let dismissData = commandData["dismissModal"] as? [String: Any] {
            let animated = dismissData["animated"] as? Bool ?? true
            let result = dismissData["result"] as? [String: Any]
            dismissModalScreen(animated: animated, result: result, from: screenContainer)
        }

        if let dismissSheetData = commandData["dismissSheet"] as? [String: Any] {
            let animated = dismissSheetData["animated"] as? Bool ?? true
            let result = dismissSheetData["result"] as? [String: Any]
            dismissSheetScreen(animated: animated, result: result, from: screenContainer)
        }

        if let dismissPopoverData = commandData["dismissPopover"] as? [String: Any] {
            let animated = dismissPopoverData["animated"] as? Bool ?? true
            let result = dismissPopoverData["result"] as? [String: Any]
            dismissPopoverScreen(animated: animated, result: result, from: screenContainer)
        }

        if let dismissOverlayData = commandData["dismissOverlay"] as? [String: Any] {
            let animated = dismissOverlayData["animated"] as? Bool ?? true
            let result = dismissOverlayData["result"] as? [String: Any]
            dismissOverlayScreen(animated: animated, result: result, from: screenContainer)
        }
    }

    private func pushToScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing push navigation to '\(screenName)'")

        // 🎯 REMOVED: Smart context key system - use direct screen name lookup
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: No screen container found for '\(screenName)' - cannot navigate")
            return
        }

        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No active navigation controller found for push")
            return
        }

        DCFScreenComponent().configureScreenForPush(targetContainer)

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

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
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate", 
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onAppear",
            data: ["screenName": screenName]
        )
        
        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onActivate",
            data: ["screenName": screenName]
        )

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "pushTo",
                "targetScreen": screenName,
                "animated": animated
            ]
        )

        print("✅ DCFScreenComponent: Successfully pushed container for '\(screenName)'")
    }

    private func presentModalScreen(_ screenName: String, animated: Bool, params: [String: Any]?, presentationStyle: String?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing modal presentation for '\(screenName)'")

        // 🎯 REMOVED: Smart context key system - use direct screen name lookup
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: No screen container found for '\(screenName)' - cannot present modal")
            return
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        configureModalPresentation(targetContainer: targetContainer, presentationStyle: presentationStyle)

        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }

        presentingViewController.present(targetContainer.viewController, animated: animated) {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenName]
            )
            
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onActivate",
                data: ["screenName": screenName]
            )

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

        print("✅ DCFScreenComponent: Successfully presented modal container for '\(screenName)'")
    }

    private func presentSheetScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing sheet presentation for '\(screenName)'")

        // 🎯 REMOVED: Smart context key system - use direct screen name lookup
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: No screen container found for '\(screenName)' - cannot present sheet")
            return
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found for sheet")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        if #available(iOS 15.0, *) {
            targetContainer.viewController.modalPresentationStyle = .pageSheet
            if let sheet = targetContainer.viewController.sheetPresentationController {
                configureSheetDetents(sheet: sheet, for: targetContainer)
            }
        } else {
            targetContainer.viewController.modalPresentationStyle = .formSheet
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
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenName]
            )
            
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onActivate",
                data: ["screenName": screenName]
            )

            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentSheet",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )
        }
    }

    private func presentPopoverScreen(_ screenName: String, animated: Bool, params: [String: Any]?, sourceViewId: String?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing popover presentation for '\(screenName)'")

        // 🎯 REMOVED: Smart context key system - use direct screen name lookup
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: No screen container found for '\(screenName)' - cannot present popover")
            return
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found for popover")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        targetContainer.viewController.modalPresentationStyle = .popover

        if let popoverController = targetContainer.viewController.popoverPresentationController {
            configurePopoverController(popoverController, for: targetContainer, presentingViewController: presentingViewController)
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
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenName]
            )
            
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onActivate",
                data: ["screenName": screenName]
            )

            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentPopover",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )
        }

        print("✅ DCFScreenComponent: Successfully presented popover container for '\(screenName)'")
    }

    private func presentOverlayScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing overlay presentation for '\(screenName)'")

        // 🎯 REMOVED: Smart context key system - use direct screen name lookup
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: No screen container found for '\(screenName)' - cannot present overlay")
            return
        }

        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("❌ DCFScreenComponent: No root view controller found for overlay")
            return
        }

        let overlayView = targetContainer.contentView
        overlayView.isHidden = false
        overlayView.alpha = 0.0

        configureOverlayView(overlayView, for: targetContainer)

        rootViewController.view.addSubview(overlayView)
        overlayView.frame = rootViewController.view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }

        if animated {
            UIView.animate(withDuration: 0.3) {
                overlayView.alpha = 1.0
            } completion: { _ in
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onAppear",
                    data: ["screenName": screenName]
                )
                
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onActivate",
                    data: ["screenName": screenName]
                )

                propagateEvent(
                    on: sourceContainer.contentView,
                    eventName: "onNavigationEvent",
                    data: [
                        "action": "presentOverlay",
                        "targetScreen": screenName,
                        "animated": animated
                    ]
                )
            }
        } else {
            overlayView.alpha = 1.0
            
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenName]
            )
            
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onActivate",
                data: ["screenName": screenName]
            )

            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentOverlay",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )
        }

        print("✅ DCFScreenComponent: Successfully presented overlay container for '\(screenName)'")
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
        for (screenName, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == targetViewController {
                targetScreenName = screenName
                break
            }
        }

        if let result = result, let targetName = targetScreenName {
            for (screenName, container) in DCFScreenComponent.screenRegistry {
                if screenName == targetName {
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
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

        if let targetName = targetScreenName {
            for (screenName, container) in DCFScreenComponent.screenRegistry {
                if screenName == targetName {
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onAppear",
                        data: ["screenName": targetName]
                    )
                    
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onActivate",
                        data: ["screenName": targetName]
                    )
                    break
                }
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

        var targetViewController: UIViewController?
        for (containerScreenName, container) in DCFScreenComponent.screenRegistry {
            if containerScreenName == screenName && navigationController.viewControllers.contains(container.viewController) {
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
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

        for (containerScreenName, container) in DCFScreenComponent.screenRegistry {
            if containerScreenName == screenName {
                propagateEvent(
                    on: container.contentView,
                    eventName: "onAppear",
                    data: ["screenName": screenName]
                )
                
                propagateEvent(
                    on: container.contentView,
                    eventName: "onActivate",
                    data: ["screenName": screenName]
                )
                break
            }
        }

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

        let rootViewController = navigationController.viewControllers.first
        var rootScreenName: String?
        
        for (screenName, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == rootViewController {
                rootScreenName = screenName
                break
            }
        }

        navigationController.popToRootViewController(animated: animated)

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

        if let rootName = rootScreenName {
            for (screenName, container) in DCFScreenComponent.screenRegistry {
                if screenName == rootName {
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onAppear",
                        data: ["screenName": rootName]
                    )
                    
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onActivate",
                        data: ["screenName": rootName]
                    )
                    break
                }
            }
        }

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

        // 🎯 REMOVED: Smart context key system - use direct screen name lookup
        guard let targetContainer = DCFScreenComponent.screenRegistry[screenName] else {
            print("❌ DCFScreenComponent: No screen container found for '\(screenName)' - cannot replace")
            return
        }

        DCFScreenComponent().configureScreenForPush(targetContainer)
        
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
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
       propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onAppear",
            data: ["screenName": screenName]
        )
        
        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onActivate",
            data: ["screenName": screenName]
        )

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
            for (screenName, container) in DCFScreenComponent.screenRegistry {
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

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

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

    private func dismissSheetScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
            for (screenName, container) in DCFScreenComponent.screenRegistry {
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

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

        sourceContainer.viewController.dismiss(animated: animated) {
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "dismissSheet",
                    "animated": animated
                ]
            )
        }

        print("✅ DCFScreenComponent: Dismissed sheet '\(sourceContainer.name)'")
    }

    private func dismissPopoverScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
            for (screenName, container) in DCFScreenComponent.screenRegistry {
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

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

        sourceContainer.viewController.dismiss(animated: animated) {
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "dismissPopover",
                    "animated": animated
                ]
            )
        }

        print("✅ DCFScreenComponent: Dismissed popover '\(sourceContainer.name)'")
    }

    private func dismissOverlayScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
        if let result = result {
            for (screenName, container) in DCFScreenComponent.screenRegistry {
                if container.presentationStyle != "overlay" {
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onReceiveParams",
                        data: ["result": result, "source": sourceContainer.name]
                    )
                    break
                }
            }
        }

        let overlayView = sourceContainer.contentView

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDisappear",
            data: ["screenName": sourceContainer.name]
        )
        
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["screenName": sourceContainer.name]
        )

        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                overlayView.alpha = 0.0
            }) { _ in
                overlayView.removeFromSuperview()
                propagateEvent(
                    on: sourceContainer.contentView,
                    eventName: "onNavigationEvent",
                    data: [
                        "action": "dismissOverlay",
                        "animated": animated
                    ]
                )
            }
        } else {
            overlayView.removeFromSuperview()
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "dismissOverlay",
                    "animated": animated
                ]
            )
        }

        print("✅ DCFScreenComponent: Dismissed overlay '\(sourceContainer.name)'")
    }

    private func configureModalPresentation(targetContainer: ScreenContainer, presentationStyle: String?) {
        let viewController = targetContainer.viewController
        
        print("🎯 Configuring modal presentation for '\(targetContainer.name)'")
        
        if #available(iOS 13.0, *) {
            viewController.modalPresentationStyle = .pageSheet
        } else {
            viewController.modalPresentationStyle = .formSheet
        }
        
        if #available(iOS 15.0, *) {
            if let sheet = viewController.sheetPresentationController {
                if let modalConfig = objc_getAssociatedObject(
                    targetContainer.viewController,
                    UnsafeRawPointer(bitPattern: "modalConfig".hashValue)!
                ) as? [String: Any] {
                    print("🎯 Found modal config: \(modalConfig)")
                    
                    if let customDetents = modalConfig["customDetents"] as? [[String: Any]] {
                        print("🎯 Applying custom detents: \(customDetents)")
                        applyCustomDetents(sheet: sheet, customDetents: customDetents, modalConfig: modalConfig)
                    }
                    else if let detents = modalConfig["detents"] as? [String] {
                        print("🎯 Applying standard detents: \(detents)")
                        applyStandardDetents(sheet: sheet, detents: detents, modalConfig: modalConfig)
                    }
                    else {
                        print("🎯 Using default large detent")
                        sheet.detents = [.large()]
                        sheet.selectedDetentIdentifier = .large
                    }
                    
                    sheet.prefersGrabberVisible = modalConfig["showDragIndicator"] as? Bool ?? true
                    
                    if let cornerRadius = modalConfig["cornerRadius"] as? CGFloat, #available(iOS 16.0, *) {
                        sheet.preferredCornerRadius = cornerRadius
                    }
                } else {
                    print("🎯 No modal config found - using default")
                    sheet.detents = [.large()]
                    sheet.selectedDetentIdentifier = .large
                    sheet.prefersGrabberVisible = true
                }
            }
        }
        
        if let style = presentationStyle {
            switch style.lowercased() {
            case "fullscreen":
                viewController.modalPresentationStyle = .fullScreen
            case "pagesheet":
                if #available(iOS 13.0, *) {
                    viewController.modalPresentationStyle = .pageSheet
                }
            case "formsheet":
                viewController.modalPresentationStyle = .formSheet
            default:
                break
            }
        }
    }

    @available(iOS 15.0, *)
    private func applyCustomDetents(sheet: UISheetPresentationController, customDetents: [[String: Any]], modalConfig: [String: Any]) {
        var sheetDetents: [UISheetPresentationController.Detent] = []
        
        for customDetent in customDetents {
            if let height = customDetent["height"] as? Double {
                let identifier = customDetent["identifier"] as? String ?? "custom_\(height)"
                
                if #available(iOS 16.0, *) {
                    sheetDetents.append(.custom(identifier: .init(identifier)) { context in
                        if height <= 1.0 {
                            return context.maximumDetentValue * height
                        } else {
                            return height
                        }
                    })
                } else {
                    if height <= 0.5 {
                        sheetDetents.append(.medium())
                    } else {
                        sheetDetents.append(.large())
                    }
                }
            }
        }
        
        if !sheetDetents.isEmpty {
            sheet.detents = sheetDetents
            if #available(iOS 16.0, *) {
                sheet.selectedDetentIdentifier = sheetDetents.first?.identifier
            }
        }
    }

    @available(iOS 15.0, *)
    private func applyStandardDetents(sheet: UISheetPresentationController, detents: [String], modalConfig: [String: Any]) {
        var sheetDetents: [UISheetPresentationController.Detent] = []
        
        for detentString in detents {
            switch detentString.lowercased() {
            case "small":
                if #available(iOS 16.0, *) {
                    sheetDetents.append(.custom(identifier: .init("small")) { context in
                        return context.maximumDetentValue * 0.25
                    })
                } else {
                    sheetDetents.append(.medium())
                }
            case "medium":
                sheetDetents.append(.medium())
            case "large":
                sheetDetents.append(.large())
            default:
                sheetDetents.append(.large())
            }
        }
        
        if !sheetDetents.isEmpty {
            sheet.detents = sheetDetents
            if #available(iOS 16.0, *) {
                sheet.selectedDetentIdentifier = sheetDetents.first?.identifier
            }
        }
    }

    private func configureOverlayView(_ overlayView: UIView, for screenContainer: ScreenContainer) {
        guard let overlayConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "overlayConfig".hashValue)!
        ) as? [String: Any] else {
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            return
        }

        if let backgroundColorString = overlayConfig["overlayBackgroundColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: backgroundColorString) {
                overlayView.backgroundColor = color
            }
        } else {
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }

        let dismissOnTap = overlayConfig["dismissOnTap"] as? Bool ?? true
        if dismissOnTap {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayBackgroundTapped(_:)))
            overlayView.addGestureRecognizer(tapGesture)

            objc_setAssociatedObject(
                tapGesture,
                UnsafeRawPointer(bitPattern: "screenContainer".hashValue)!,
                screenContainer,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        let blocksInteraction = overlayConfig["blocksInteraction"] as? Bool ?? true
        overlayView.isUserInteractionEnabled = blocksInteraction

        print("🎯 DCFScreenComponent: Applied overlay configuration - dismissOnTap: \(dismissOnTap), blocksInteraction: \(blocksInteraction)")
    }

    @objc private func overlayBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard let screenContainer = objc_getAssociatedObject(
            gesture,
            UnsafeRawPointer(bitPattern: "screenContainer".hashValue)!
        ) as? ScreenContainer else {
            return
        }

        print("🎯 DCFScreenComponent: Overlay background tapped - dismissing '\(screenContainer.name)'")
        dismissOverlayScreen(animated: true, result: ["dismissReason": "backgroundTap"], from: screenContainer)
    }

    private func configurePopoverController(_ popoverController: UIPopoverPresentationController, for screenContainer: ScreenContainer, presentingViewController: UIViewController) {
        guard let popoverConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "popoverConfig".hashValue)!
        ) as? [String: Any] else {
            popoverController.sourceView = presentingViewController.view
            popoverController.sourceRect = CGRect(x: presentingViewController.view.bounds.midX, y: presentingViewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = .any
            return
        }

        if let width = popoverConfig["preferredWidth"] as? CGFloat,
           let height = popoverConfig["preferredHeight"] as? CGFloat {
            screenContainer.viewController.preferredContentSize = CGSize(width: width, height: height)
        }

        if let arrowDirections = popoverConfig["permittedArrowDirections"] as? [String] {
            var directions: UIPopoverArrowDirection = []
            for direction in arrowDirections {
                switch direction.lowercased() {
                case "up":
                    directions.insert(.up)
                case "down":
                    directions.insert(.down)
                case "left":
                    directions.insert(.left)
                case "right":
                    directions.insert(.right)
                case "any":
                    directions = .any
                    break
                default:
                    break
                }
            }
            popoverController.permittedArrowDirections = directions
        } else {
            popoverController.permittedArrowDirections = .any
        }

        popoverController.sourceView = presentingViewController.view
        popoverController.sourceRect = CGRect(x: presentingViewController.view.bounds.midX, y: presentingViewController.view.bounds.midY, width: 0, height: 0)
    }

    @available(iOS 15.0, *)
    private func configureSheetDetents(sheet: UISheetPresentationController, for screenContainer: ScreenContainer) {
        guard let sheetConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "sheetConfig".hashValue)!
        ) as? [String: Any] else {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            return
        }

        var detents: [UISheetPresentationController.Detent] = []

        if let detentArray = sheetConfig["detents"] as? [String] {
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
        sheet.prefersGrabberVisible = sheetConfig["showDragIndicator"] as? Bool ?? true

        if let cornerRadius = sheetConfig["cornerRadius"] as? CGFloat {
            if #available(iOS 16.0, *) {
                sheet.preferredCornerRadius = cornerRadius
            }
        }
    }

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

    private func storeTabConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var tabConfig: [String: Any] = [:]

        if let tabConfigData = props["tabConfig"] as? [String: Any] {
            tabConfig = tabConfigData
        } else {
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

    private func storeModalConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var modalConfig: [String: Any] = [:]

        if let modalConfigData = props["modalConfig"] as? [String: Any] {
            modalConfig = modalConfigData
        } else {
            if let detents = props["detents"] as? [String] {
                modalConfig["detents"] = detents
            }

            if let showDragIndicator = props["showDragIndicator"] as? Bool {
                modalConfig["showDragIndicator"] = showDragIndicator
            }

            if let cornerRadius = props["cornerRadius"] as? CGFloat {
                modalConfig["cornerRadius"] = cornerRadius
            }

            if let transitionStyle = props["transitionStyle"] as? String {
                modalConfig["transitionStyle"] = transitionStyle
            }
        }

        if !modalConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "modalConfig".hashValue)!,
                modalConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private func storePopoverConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var popoverConfig: [String: Any] = [:]

        if let title = props["title"] as? String {
            popoverConfig["title"] = title
        }

        if let preferredWidth = props["preferredWidth"] as? CGFloat {
            popoverConfig["preferredWidth"] = preferredWidth
        }

        if let preferredHeight = props["preferredHeight"] as? CGFloat {
            popoverConfig["preferredHeight"] = preferredHeight
        }

        if let permittedArrowDirections = props["permittedArrowDirections"] as? [String] {
            popoverConfig["permittedArrowDirections"] = permittedArrowDirections
        }

        if let dismissOnOutsideTap = props["dismissOnOutsideTap"] as? Bool {
            popoverConfig["dismissOnOutsideTap"] = dismissOnOutsideTap
        }

        if !popoverConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "popoverConfig".hashValue)!,
                popoverConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private func storeOverlayConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var overlayConfig: [String: Any] = [:]

        if let title = props["title"] as? String {
            overlayConfig["title"] = title
        }

        if let overlayBackgroundColor = props["overlayBackgroundColor"] as? String {
            overlayConfig["overlayBackgroundColor"] = overlayBackgroundColor
        }

        if let dismissOnTap = props["dismissOnTap"] as? Bool {
            overlayConfig["dismissOnTap"] = dismissOnTap
        }

        if let animationDuration = props["animationDuration"] as? Double {
            overlayConfig["animationDuration"] = animationDuration
        }

        if let blocksInteraction = props["blocksInteraction"] as? Bool {
            overlayConfig["blocksInteraction"] = blocksInteraction
        }

        if !overlayConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "overlayConfig".hashValue)!,
                overlayConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private func storeSheetConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var sheetConfig: [String: Any] = [:]

        if let detents = props["detents"] as? [String] {
            sheetConfig["detents"] = detents
        }

        if let showDragIndicator = props["showDragIndicator"] as? Bool {
            sheetConfig["showDragIndicator"] = showDragIndicator
        }

        if let cornerRadius = props["cornerRadius"] as? CGFloat {
            sheetConfig["cornerRadius"] = cornerRadius
        }

        if !sheetConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "sheetConfig".hashValue)!,
                sheetConfig,
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
        case "sheet":
            configureSheetScreen(screenContainer, props: props)
        case "popover":
            configurePopoverScreen(screenContainer, props: props)
        case "overlay":
            configureOverlayScreen(screenContainer, props: props)
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
        
        configureNavigationBarForTabScreen(viewController, props: props)
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
                configureSheetDetents(sheet: sheet, for: screenContainer)
            }
        }
    }

    private func configureSheetScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController

        if let title = props["title"] as? String {
            viewController.navigationItem.title = title
        }
    }

    private func configurePopoverScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController

        if let title = props["title"] as? String {
            viewController.navigationItem.title = title
        }

        if let width = props["preferredWidth"] as? CGFloat,
           let height = props["preferredHeight"] as? CGFloat {
            viewController.preferredContentSize = CGSize(width: width, height: height)
        } else {
            viewController.preferredContentSize = CGSize(width: 320, height: 480)
        }
    }

    private func configureOverlayScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController

      if let title = props["title"] as? String {
            viewController.navigationItem.title = title
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

    // 🎯 FIXED: Simple screen container lookup by name
    static func getScreenContainer(name: String) -> ScreenContainer? {
        return screenRegistry[name]
    }

    static func getAllScreenContainers() -> [String: ScreenContainer] {
        return screenRegistry
    }

    static func removeScreenContainer(contextKey: String) {
        screenRegistry.removeValue(forKey: contextKey)
    }

    static func cleanupUnusedContainers() {
        let activeViewControllers = getAllActiveViewControllers()
        var keysToRemove: [String] = []

        for (contextKey, container) in screenRegistry {
            if contextKey.hasPrefix("tab_") {
                continue
            }

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

        if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController {
            for tabViewController in tabBarController.viewControllers ?? [] {
                if let navController = tabViewController as? UINavigationController {
                    activeControllers.formUnion(navController.viewControllers)
                } else {
                    activeControllers.insert(tabViewController)
                }
            }
        }

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

enum NavigationMethod: String, CaseIterable {
    case push = "push"
    case modal = "modal"
    case sheet = "sheet"
    case popover = "popover"
    case overlay = "overlay"
    case switchTab = "switchTab"

    var description: String {
        return self.rawValue
    }
}

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
    // 🎯 FIXED: Simple screen registry - no complex context keys
    static var screenRegistry: [String: ScreenContainer] = [:]
    static var screenPresentationRegistry: [String: String] = [:]
    static var currentNavigationController: UINavigationController? = nil

    static func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            cleanupUnusedContainers()
        }
    }

    static func printRegisteredScreens() {
        print("🎯 DCFScreenComponent: Registered screens:")
        for (screenName, presentationStyle) in screenPresentationRegistry {
            print("  - \(screenName): \(presentationStyle)")
        }
    }

    internal func storePushConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var pushConfig: [String: Any] = [:]

        if let pushConfigData = props["pushConfig"] as? [String: Any] {
            pushConfig = pushConfigData
        } else {
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

            if let prefixActions = props["prefixActions"] as? [[String: Any]] {
                pushConfig["prefixActions"] = prefixActions
                print("📝 Extension: Found \(prefixActions.count) prefix actions in props")
            }

            if let suffixActions = props["suffixActions"] as? [[String: Any]] {
                pushConfig["suffixActions"] = suffixActions
                print("📝 Extension: Found \(suffixActions.count) suffix actions in props")
            }
        }

        if !pushConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!,
                pushConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            print("🎯 Extension: Stored push config for '\(screenContainer.name)': \(pushConfig)")
        }
    }

    public func configureScreenForPush(_ screenContainer: ScreenContainer) {
        guard let pushConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!
        ) as? [String: Any] else {
            print("⚠️ DCFScreenComponent: No push config found for screen '\(screenContainer.name)'")
            return
        }

        print("🔧 DCFScreenComponent: Configuring push screen '\(screenContainer.name)' with config keys: \(pushConfig.keys)")

        let viewController = screenContainer.viewController

        if let title = pushConfig["title"] as? String {
            viewController.navigationItem.title = title
            print("✅ Set title: \(title)")
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

        configureHeaderActions(for: viewController, pushConfig: pushConfig)
    }

    private func configureHeaderActions(for viewController: UIViewController, pushConfig: [String: Any]) {
        print("🎯 DCFScreenComponent: Configuring header actions for '\(viewController.title ?? "Unknown")'")
        print("🎯 DCFScreenComponent: Push config keys: \(pushConfig.keys)")

        if let prefixActionsData = pushConfig["prefixActions"] as? [[String: Any]] {
            print("📝 Found \(prefixActionsData.count) prefix actions")
            print("📝 Prefix actions data: \(prefixActionsData)")

            let leftBarButtonItems = createBarButtonItems(from: prefixActionsData, for: viewController, position: .left)
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
            print("✅ Set \(leftBarButtonItems.count) left bar button items")
        } else {
            print("ℹ️ No prefix actions found in push config")
        }

        if let suffixActionsData = pushConfig["suffixActions"] as? [[String: Any]] {
            print("📝 Found \(suffixActionsData.count) suffix actions")
            print("📝 Suffix actions data: \(suffixActionsData)")

            let rightBarButtonItems = createBarButtonItems(from: suffixActionsData, for: viewController, position: .right)
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
            print("✅ Set \(rightBarButtonItems.count) right bar button items")
        } else {
            print("ℹ️ No suffix actions found in push config")
        }
    }

    internal enum BarButtonPosition {
        case left, right
    }

    internal func createBarButtonItems(from actionsData: [[String: Any]], for viewController: UIViewController, position: BarButtonPosition) -> [UIBarButtonItem] {
        var barButtonItems: [UIBarButtonItem] = []

        for (index, actionData) in actionsData.enumerated() {
            if let barButtonItem = createBarButtonItem(from: actionData, for: viewController, position: position, index: index) {
                barButtonItems.append(barButtonItem)
            }
        }

        return barButtonItems
    }

    private func createBarButtonItem(from actionData: [String: Any], for viewController: UIViewController, position: BarButtonPosition, index: Int) -> UIBarButtonItem? {
        let title = actionData["title"] as? String ?? ""
        let enabled = actionData["enabled"] as? Bool ?? true
        let actionId = actionData["actionId"] as? String ?? "action_\(position)_\(index)"

        print("🔨 Creating bar button item - Title: '\(title)', ActionId: '\(actionId)', Enabled: \(enabled)")

        guard let iconConfig = actionData["icon"] as? [String: Any] else {
            print("❌ DCFScreenComponent: Missing icon config for header action")
            return nil
        }

        let iconType = iconConfig["type"] as? String ?? "sf"
        print("🎨 Icon type: \(iconType)")

        var barButtonItem: UIBarButtonItem?

        switch iconType {
        case "text":
            barButtonItem = UIBarButtonItem(
                title: title,
                style: .plain,
                target: DCFHeaderActionHandler.shared,
                action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
            )
            print("✅ Created text-only button: '\(title)'")

        case "sf":
            if let symbolName = iconConfig["name"] as? String {
                let image = UIImage(systemName: symbolName)

                if !title.isEmpty {
                    barButtonItem = UIBarButtonItem(
                        title: title,
                        style: .plain,
                        target: DCFHeaderActionHandler.shared,
                        action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
                    )
                    barButtonItem?.image = image
                    print("✅ Created SF symbol button with title: '\(title)' + \(symbolName)")
                } else {
                    barButtonItem = UIBarButtonItem(
                        image: image,
                        style: .plain,
                        target: DCFHeaderActionHandler.shared,
                        action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
                    )
                    print("✅ Created SF symbol icon-only button: \(symbolName)")
                }
            } else {
                print("❌ Missing SF symbol name")
            }

        case "package":
            if let iconName = iconConfig["name"] as? String,
                let packageName = iconConfig["package"] as? String {
                let image = loadSVGForHeaderAction(iconName: iconName, packageName: packageName, iconConfig: iconConfig)

                if !title.isEmpty {
                    barButtonItem = UIBarButtonItem(
                        title: title,
                        style: .plain,
                        target: DCFHeaderActionHandler.shared,
                        action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
                    )
                    barButtonItem?.image = image
                    print("✅ Created SVG package button with title: '\(title)' + \(iconName)")
                } else {
                    barButtonItem = UIBarButtonItem(
                        image: image,
                        style: .plain,
                        target: DCFHeaderActionHandler.shared,
                        action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
                    )
                    print("✅ Created SVG package icon-only button: \(iconName)")
                }
            } else {
                print("❌ Missing SVG package config")
            }

        case "svg":
            if let assetPath = iconConfig["assetPath"] as? String {
                let image = loadSVGFromAssetPath(assetPath, iconConfig: iconConfig)

                if !title.isEmpty {
                    barButtonItem = UIBarButtonItem(
                        title: title,
                        style: .plain,
                        target: DCFHeaderActionHandler.shared,
                        action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
                    )
                    barButtonItem?.image = image
                    print("✅ Created SVG asset button with title: '\(title)' + \(assetPath)")
                } else {
                    barButtonItem = UIBarButtonItem(
                        image: image,
                        style: .plain,
                        target: DCFHeaderActionHandler.shared,
                        action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
                    )
                    print("✅ Created SVG asset icon-only button: \(assetPath)")
                }
            } else {
                print("❌ Missing SVG asset path")
            }

        default:
            print("⚠️ DCFScreenComponent: Unknown icon type '\(iconType)' for header action")
            barButtonItem = UIBarButtonItem(
                title: title,
                style: .plain,
                target: DCFHeaderActionHandler.shared,
                action: #selector(DCFHeaderActionHandler.headerActionPressed(_:))
            )
            print("✅ Created fallback text button: '\(title)'")
        }

        barButtonItem?.isEnabled = enabled

        if let barButtonItem = barButtonItem {
            objc_setAssociatedObject(
                barButtonItem,
                UnsafeRawPointer(bitPattern: "actionData".hashValue)!,
                actionData,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            objc_setAssociatedObject(
                barButtonItem,
                UnsafeRawPointer(bitPattern: "viewController".hashValue)!,
                viewController,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            print("✅ Bar button item created and configured successfully")
        } else {
            print("❌ Failed to create bar button item")
        }

        return barButtonItem
    }

    private func loadSVGForHeaderAction(iconName: String, packageName: String, iconConfig: [String: Any]) -> UIImage? {
        guard let key = sharedFlutterViewController?.lookupKey(
            forAsset: "assets/icons/\(iconName).svg",
            fromPackage: packageName
        ) else {
            print("❌ DCFScreenComponent: Could not find asset key for \(iconName) in package \(packageName)")
            return nil
        }

        let mainBundle = Bundle.main
        guard let path = mainBundle.path(forResource: key, ofType: nil), !path.isEmpty else {
            print("❌ DCFScreenComponent: Could not find file path for \(iconName) in package \(packageName)")
            return nil
        }

        return loadSVGImage(from: path, iconConfig: iconConfig)
    }

    private func loadSVGFromAssetPath(_ assetPath: String, iconConfig: [String: Any]) -> UIImage? {
        let key = sharedFlutterViewController?.lookupKey(forAsset: assetPath)
        let mainBundle = Bundle.main
        guard let path = mainBundle.path(forResource: key, ofType: nil) else {
            print("❌ DCFScreenComponent: Could not find SVG at asset path: \(assetPath)")
            return nil
        }

        return loadSVGImage(from: path, iconConfig: iconConfig)
    }

    private func loadSVGImage(from path: String, iconConfig: [String: Any]) -> UIImage? {
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ DCFScreenComponent: SVG file does not exist at path: \(path)")
            return nil
        }

        let cacheKey = path + "_header_action"
        if let cachedImage = DCFSvgComponent.getCachedImage(for: cacheKey) {
            return processHeaderActionSVG(cachedImage, iconConfig: iconConfig)
        }

        guard let svgImage = SVGKImage(contentsOfFile: path) else {
            print("❌ DCFScreenComponent: Failed to load SVG from path: \(path)")
            return nil
        }

        let iconSize = iconConfig["size"] as? CGFloat ?? 22.0
        let targetSize = CGSize(width: iconSize, height: iconSize)

        svgImage.size = targetSize

        DCFSvgComponent.setCachedImage(svgImage, for: cacheKey)

        return processHeaderActionSVG(svgImage, iconConfig: iconConfig)
    }

    private func processHeaderActionSVG(_ svgImage: SVGKImage, iconConfig: [String: Any]) -> UIImage? {
        guard let uiImage = svgImage.uiImage else { return nil }

        if let tintColor = iconConfig["tintColor"] as? String,
            let color = ColorUtilities.color(fromHexString: tintColor) {
            return createTintedImage(from: uiImage, color: color)
        }

        return uiImage.withRenderingMode(.alwaysTemplate)
    }

    private func createTintedImage(from image: UIImage, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let rect = CGRect(origin: .zero, size: image.size)
        context.clip(to: rect, mask: image.cgImage!)

        color.setFill()
        context.fill(rect)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    internal func configureNavigationBarForTabScreen(_ viewController: UIViewController, props: [String: Any]) {
        if let navigationBarTitle = props["navigationBarTitle"] as? String {
            viewController.navigationItem.title = navigationBarTitle
        }

        let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode = largeTitleDisplayMode ? .always : .never
        }

        let hideNavigationBar = props["hideNavigationBar"] as? Bool ?? false
        if hideNavigationBar {
            viewController.navigationController?.setNavigationBarHidden(hideNavigationBar, animated: false)
        }

        let hideBackButton = props["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton

        if let backButtonTitle = props["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }

        configureHeaderActionsFromProps(for: viewController, props: props)
    }

    private func configureHeaderActionsFromProps(for viewController: UIViewController, props: [String: Any]) {
        if let prefixActionsData = props["prefixActions"] as? [[String: Any]] {
            let leftBarButtonItems = createBarButtonItems(from: prefixActionsData, for: viewController, position: .left)
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
        }

        if let suffixActionsData = props["suffixActions"] as? [[String: Any]] {
            let rightBarButtonItems = createBarButtonItems(from: suffixActionsData, for: viewController, position: .right)
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
        }
    }

    internal func storeNavigationBarConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var navBarConfig: [String: Any] = [:]

        if let navigationBarTitle = props["navigationBarTitle"] as? String {
            navBarConfig["navigationBarTitle"] = navigationBarTitle
        }

        if let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool {
            navBarConfig["largeTitleDisplayMode"] = largeTitleDisplayMode
        }

        if let hideNavigationBar = props["hideNavigationBar"] as? Bool {
            navBarConfig["hideNavigationBar"] = hideNavigationBar
        }

        if let prefixActions = props["prefixActions"] as? [[String: Any]] {
            navBarConfig["prefixActions"] = prefixActions
        }

        if let suffixActions = props["suffixActions"] as? [[String: Any]] {
            navBarConfig["suffixActions"] = suffixActions
        }

        if !navBarConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "navigationBarConfig".hashValue)!,
                navBarConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

class DCFHeaderActionHandler: NSObject {
    static let shared = DCFHeaderActionHandler()
    
    private override init() {
        super.init()
    }
    
    @objc func headerActionPressed(_ sender: UIBarButtonItem) {
        print("🎯 DCFHeaderActionHandler: Header action button was pressed!")

        guard let actionData = objc_getAssociatedObject(
            sender,
            UnsafeRawPointer(bitPattern: "actionData".hashValue)!
        ) as? [String: Any],
              let viewController = objc_getAssociatedObject(
            sender,
            UnsafeRawPointer(bitPattern: "viewController".hashValue)!
        ) as? UIViewController else {
            print("❌ DCFHeaderActionHandler: No action data found for header action")
            return
        }

        let actionId = actionData["actionId"] as? String ?? "unknown_action"
        let title = actionData["title"] as? String ?? ""

        print("🎯 DCFHeaderActionHandler: Header action pressed - ID: \(actionId), Title: \(title)")

        var foundContainer = false
        for (_, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == viewController {
                foundContainer = true
                print("📡 DCFHeaderActionHandler: Found container '\(container.name)' for view controller")

                propagateEvent(
                    on: container.contentView,
                    eventName: "onHeaderActionPress",
                    data: [
                        "actionId": actionId,
                        "title": title,
                        "screenName": container.name,
                    ]
                )
                print("📡 DCFHeaderActionHandler: Sent onHeaderActionPress event to Dart")
                break
            }
        }

        if !foundContainer {
            print("❌ DCFHeaderActionHandler: Could not find container for view controller")
        }
    }
}