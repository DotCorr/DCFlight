/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import SVGKit
import UIKit
import dcflight

class DCFScreenComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }

    func createView(props: [String: Any]) -> UIView {
        guard let route = props["route"] as? String,
            let presentationStyle = props["presentationStyle"] as? String
        else {
            print("❌ DCFScreenComponent: Missing required props 'route' or 'presentationStyle'")
            return UIView()
        }

        print(
            "🔧 DCFScreenComponent: Creating screen for route '\(route)' with style '\(presentationStyle)'"
        )

        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.routeRegistry[route] {
            screenContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing container for route '\(route)'")
        } else {
            screenContainer = ScreenContainer(route: route, presentationStyle: presentationStyle)
            DCFScreenComponent.routeRegistry[route] = screenContainer
            print("✅ DCFScreenComponent: Created new container for route '\(route)'")
        }

        configureScreen(screenContainer, props: props)
        storeConfigurations(screenContainer, props: props)

        let _ = updateView(screenContainer.contentView, withProps: props)

        return screenContainer.contentView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        if let existingContainer = findScreenContainer(for: view) {
            return updateExistingScreen(existingContainer, view: view, props: props)
        }

        guard let route = props["route"] as? String,
            let presentationStyle = props["presentationStyle"] as? String
        else {
            print(
                "❌ DCFScreenComponent: Missing required props for update - applying basic styles only"
            )
            view.applyStyles(props: props)
            return false
        }

        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.routeRegistry[route] {
            screenContainer = existing
        } else {
            screenContainer = ScreenContainer(route: route, presentationStyle: presentationStyle)
            DCFScreenComponent.routeRegistry[route] = screenContainer
            print("✅ DCFScreenComponent: Created new container for route '\(route)' during update")
            configureScreen(screenContainer, props: props)
        }

        return updateExistingScreen(screenContainer, view: view, props: props)
    }

    private func updateExistingScreen(
        _ screenContainer: ScreenContainer, view: UIView, props: [String: Any]
    ) -> Bool {
        storeConfigurations(screenContainer, props: props)
        handleRouteNavigationCommand(screenContainer: screenContainer, props: props)
        view.applyStyles(props: props)
        return true
    }

    private func handleRouteNavigationCommand(
        screenContainer: ScreenContainer, props: [String: Any]
    ) {
        guard let commandData = props["routeNavigationCommand"] as? [String: Any] else {
            return
        }

        print(
            "🚀 DCFScreenComponent: Processing route navigation command for '\(screenContainer.route)': \(commandData)"
        )

        if let targetRoute = commandData["navigateToRoute"] as? String {
            let animated = commandData["animated"] as? Bool ?? true
            let params = commandData["params"] as? [String: Any]
            navigateToRoute(targetRoute, animated: animated, params: params, from: screenContainer)
        }

        if let targetRoute = commandData["popToRoute"] as? String {
            let animated = commandData["animated"] as? Bool ?? true
            popToRoute(targetRoute, animated: animated, from: screenContainer)
        }

        if let popCommand = commandData["pop"] as? [String: Any] {
            let animated = popCommand["animated"] as? Bool ?? true
            let result = popCommand["result"] as? [String: Any]
            popCurrentRoute(animated: animated, result: result, from: screenContainer)
        }

        if let popToRootCommand = commandData["popToRoot"] as? [String: Any] {
            let animated = popToRootCommand["animated"] as? Bool ?? true
            popToRootRoute(animated: animated, from: screenContainer)
        }

        if let replaceCommand = commandData["replaceWithRoute"] as? [String: Any] {
            if let targetRoute = replaceCommand["route"] as? String {
                let animated = replaceCommand["animated"] as? Bool ?? true
                let params = replaceCommand["params"] as? [String: Any]
                replaceCurrentRoute(
                    with: targetRoute, animated: animated, params: params, from: screenContainer)
            }
        }

        if let modalCommand = commandData["presentModalRoute"] as? [String: Any] {
            if let targetRoute = modalCommand["route"] as? String {
                let animated = modalCommand["animated"] as? Bool ?? true
                let params = modalCommand["params"] as? [String: Any]
                let presentationStyle = modalCommand["presentationStyle"] as? String
                presentModalRoute(
                    targetRoute, animated: animated, params: params,
                    presentationStyle: presentationStyle, from: screenContainer)
            }
        }

        if let dismissModalCommand = commandData["dismissModal"] as? [String: Any] {
            let animated = dismissModalCommand["animated"] as? Bool ?? true
            let result = dismissModalCommand["result"] as? [String: Any]
            dismissModalRoute(animated: animated, result: result, from: screenContainer)
        }
    }

    private func navigateToRoute(
        _ targetRoute: String, animated: Bool, params: [String: Any]?,
        from sourceContainer: ScreenContainer
    ) {

        if let targetContainer = DCFScreenComponent.routeRegistry[targetRoute] {
            print("✅ DCFScreenComponent: Found direct route '\(targetRoute)' in registry")

            guard let navigationController = getCurrentActiveNavigationController() else {
                print("❌ DCFScreenComponent: No active navigation controller found")
                return
            }

            // Set up navigation delegate to handle user-initiated gestures
            setupNavigationDelegate(navigationController)

            // Check if this view controller is already in the navigation stack
            if navigationController.viewControllers.contains(targetContainer.viewController) {
                print(
                    "⚠️ DCFScreenComponent: View controller for '\(targetRoute)' is already in navigation stack, skipping push"
                )
                return
            }

            configureScreenForPush(targetContainer)

            if let params = params {
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onReceiveParams",
                    data: ["params": params, "sourceRoute": sourceContainer.route]
                )
            }

            // Store current view controllers BEFORE navigation for user-initiated pop tracking
            objc_setAssociatedObject(
                navigationController, &DCFScreenComponent.previousViewControllersKey,
                navigationController.viewControllers,
                .OBJC_ASSOCIATION_RETAIN)

            navigationController.pushViewController(
                targetContainer.viewController, animated: animated)
            updateRouteStack(navigationController)

            print("✅ DCFScreenComponent: Successfully navigated to route '\(targetRoute)'")
            return
        }

        // If direct route not found, try the old parsing logic as fallback
        // But this should not be needed for your use case
        print(
            "⚠️ DCFScreenComponent: Route '\(targetRoute)' not found in registry, attempting parsing"
        )

        let routes = parseRoute(targetRoute)
        guard !routes.isEmpty else {
            print("❌ DCFScreenComponent: Invalid route '\(targetRoute)'")
            return
        }

        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No active navigation controller found")
            return
        }

        // Set up navigation delegate to handle user-initiated gestures
        setupNavigationDelegate(navigationController)

        // Only push the final route if it exists
        if let finalRoute = routes.last,
            let finalContainer = DCFScreenComponent.routeRegistry[finalRoute]
        {

            // Check if already in stack
            if navigationController.viewControllers.contains(finalContainer.viewController) {
                print(
                    "⚠️ DCFScreenComponent: View controller for '\(finalRoute)' is already in navigation stack"
                )
                return
            }

            configureScreenForPush(finalContainer)

            // Store current view controllers BEFORE navigation for user-initiated pop tracking
            objc_setAssociatedObject(
                navigationController, &DCFScreenComponent.previousViewControllersKey,
                navigationController.viewControllers,
                .OBJC_ASSOCIATION_RETAIN)

            navigationController.pushViewController(
                finalContainer.viewController, animated: animated)
            updateRouteStack(navigationController)
        } else {
            print("❌ DCFScreenComponent: Could not find container for final route")
        }
    }

    private func popToRoute(
        _ targetRoute: String, animated: Bool, from sourceContainer: ScreenContainer
    ) {
        print("🗺️ DCFScreenComponent: Popping to route '\(targetRoute)'")

        let routes = parseRoute(targetRoute)
        guard let finalRoute = routes.last else {
            print("❌ DCFScreenComponent: Invalid route '\(targetRoute)'")
            return
        }

        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No active navigation controller found")
            return
        }

        guard let targetContainer = DCFScreenComponent.routeRegistry[finalRoute] else {
            print("❌ DCFScreenComponent: Route '\(finalRoute)' not found in registry")
            return
        }

        guard navigationController.viewControllers.contains(targetContainer.viewController) else {
            print("❌ DCFScreenComponent: Route '\(finalRoute)' not in current navigation stack")
            return
        }

        navigationController.popToViewController(targetContainer.viewController, animated: animated)

        updateRouteStack(navigationController)

        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onAppear",
            data: ["route": finalRoute]
        )

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "popToRoute",
                "targetRoute": finalRoute,
                "animated": animated,
            ]
        )

        print("✅ DCFScreenComponent: Successfully popped to route '\(finalRoute)'")
    }

    private func popCurrentRoute(
        animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer
    ) {
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for pop")
            return
        }

        guard navigationController.viewControllers.count > 1 else {
            print("❌ DCFScreenComponent: Cannot pop root view controller")
            return
        }

        let targetViewController = navigationController.viewControllers[
            navigationController.viewControllers.count - 2]

        var targetRoute: String? = nil
        for (route, container) in DCFScreenComponent.routeRegistry {
            if container.viewController == targetViewController {
                targetRoute = route
                break
            }
        }

        if let result = result, let targetRoute = targetRoute {
            if let targetContainer = DCFScreenComponent.routeRegistry[targetRoute] {
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onReceiveParams",
                    data: ["result": result, "sourceRoute": sourceContainer.route]
                )
            }
        }

        navigationController.popViewController(animated: animated)

        updateRouteStack(navigationController)

        if let targetRoute = targetRoute,
            let targetContainer = DCFScreenComponent.routeRegistry[targetRoute]
        {
            fireNavigationEvents(
                sourceContainer: sourceContainer,
                targetContainer: targetContainer,
                action: "pop",
                animated: animated
            )
        }

        print("✅ DCFScreenComponent: Successfully popped current route")
    }

    private func popToRootRoute(animated: Bool, from sourceContainer: ScreenContainer) {
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for popToRoot")
            return
        }

        guard navigationController.viewControllers.count > 1 else {
            print("ℹ️ DCFScreenComponent: Already at root, no need to pop")
            return
        }

        navigationController.popToRootViewController(animated: animated)

        updateRouteStack(navigationController)

        print("✅ DCFScreenComponent: Successfully popped to root")
    }

    private func replaceCurrentRoute(
        with targetRoute: String, animated: Bool, params: [String: Any]?,
        from sourceContainer: ScreenContainer
    ) {
        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No navigation controller found for replace")
            return
        }

        guard
            let targetContainer = getOrCreateScreenContainer(
                for: targetRoute, presentationStyle: "push")
        else {
            print("❌ DCFScreenComponent: Could not create container for route '\(targetRoute)'")
            return
        }

        configureScreenForPush(targetContainer)

        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "sourceRoute": sourceContainer.route]
            )
        }

        var viewControllers = navigationController.viewControllers
        viewControllers[viewControllers.count - 1] = targetContainer.viewController
        navigationController.setViewControllers(viewControllers, animated: animated)

        updateRouteStack(navigationController)

        print("✅ DCFScreenComponent: Successfully replaced current route with '\(targetRoute)'")
    }

    private func presentModalRoute(
        _ targetRoute: String, animated: Bool, params: [String: Any]?, presentationStyle: String?,
        from sourceContainer: ScreenContainer
    ) {
        print("🗺️ DCFScreenComponent: Presenting modal route '\(targetRoute)'")

        guard
            let targetContainer = getOrCreateScreenContainer(
                for: targetRoute, presentationStyle: "modal")
        else {
            print("❌ DCFScreenComponent: Could not create container for route '\(targetRoute)'")
            return
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        configureModalPresentation(
            targetContainer: targetContainer, presentationStyle: presentationStyle)

        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "sourceRoute": sourceContainer.route]
            )
        }

        presentingViewController.present(targetContainer.viewController, animated: animated) {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["route": targetRoute]
            )

            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentModalRoute",
                    "targetRoute": targetRoute,
                    "animated": animated,
                ]
            )
        }

        print("✅ DCFScreenComponent: Successfully presented modal route '\(targetRoute)'")
    }

    private func dismissModalRoute(
        animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer
    ) {
        if let result = result,
            let presentingViewController = sourceContainer.viewController.presentingViewController
        {
            for (route, container) in DCFScreenComponent.routeRegistry {
                if container.viewController == presentingViewController {
                    propagateEvent(
                        on: container.contentView,
                        eventName: "onReceiveParams",
                        data: ["result": result, "sourceRoute": sourceContainer.route]
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
                    "action": "dismissModalRoute",
                    "animated": animated,
                ]
            )
        }

        print("✅ DCFScreenComponent: Successfully dismissed modal route")
    }

    private func getOrCreateScreenContainer(for route: String, presentationStyle: String)
        -> ScreenContainer?
    {
        if let existing = DCFScreenComponent.routeRegistry[route] {
            return existing
        }

        let container = ScreenContainer(route: route, presentationStyle: presentationStyle)
        DCFScreenComponent.routeRegistry[route] = container
        print("✅ DCFScreenComponent: Created new container for route '\(route)'")
        return container
    }

    private func parseRoute(_ route: String) -> [String] {
        return route.split(separator: "/").map(String.init)
    }

    private func findCommonPrefixLength(_ array1: [String], _ array2: [String]) -> Int {
        var commonLength = 0
        let minLength = min(array1.count, array2.count)

        for i in 0..<minLength {
            if array1[i] == array2[i] {
                commonLength += 1
            } else {
                break
            }
        }

        return commonLength
    }

    private func getCurrentRouteStack(from navigationController: UINavigationController) -> [String]
    {
        var routes: [String] = []

        for viewController in navigationController.viewControllers {
            for (route, container) in DCFScreenComponent.routeRegistry {
                if container.viewController == viewController {
                    routes.append(route)
                    break
                }
            }
        }

        return routes
    }

    private func updateRouteStack(_ navigationController: UINavigationController) {
        let newRouteStack = getCurrentRouteStack(from: navigationController)
        DCFScreenComponent.currentRouteStack = newRouteStack
        print("📍 DCFScreenComponent: Updated route stack to: \(newRouteStack)")
    }

    private func fireNavigationEvents(
        sourceContainer: ScreenContainer, targetContainer: ScreenContainer, action: String,
        animated: Bool
    ) {
        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDisappear",
            data: ["route": sourceContainer.route]
        )

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onDeactivate",
            data: ["route": sourceContainer.route]
        )

        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onAppear",
            data: ["route": targetContainer.route]
        )

        propagateEvent(
            on: targetContainer.contentView,
            eventName: "onActivate",
            data: ["route": targetContainer.route]
        )

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": action,
                "targetRoute": targetContainer.route,
                "animated": animated,
            ]
        )
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
            print(
                "⚠️ DCFScreenComponent: Unknown presentation style '\(screenContainer.presentationStyle)'"
            )
        }
    }

    private func storeConfigurations(_ screenContainer: ScreenContainer, props: [String: Any]) {
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        storeModalConfiguration(screenContainer, props: props)
        storePopoverConfiguration(screenContainer, props: props)
        storeOverlayConfiguration(screenContainer, props: props)
        storeSheetConfiguration(screenContainer, props: props)
        storeNavigationBarConfiguration(screenContainer, props: props)
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
        viewController.navigationController?.setNavigationBarHidden(
            hideNavigationBar, animated: false)

        let hideBackButton = props["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton

        if let backButtonTitle = props["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(
                title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }

        let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode =
                largeTitleDisplayMode ? .always : .never
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
            let height = props["preferredHeight"] as? CGFloat
        {
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

    private func configureModalPresentation(
        targetContainer: ScreenContainer, presentationStyle: String?
    ) {
        let viewController = targetContainer.viewController

        print("🎯 Configuring modal presentation for '\(targetContainer.route)'")

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
                        applyCustomDetents(
                            sheet: sheet, customDetents: customDetents, modalConfig: modalConfig)
                    } else if let detents = modalConfig["detents"] as? [String] {
                        print("🎯 Applying standard detents: \(detents)")
                        applyStandardDetents(
                            sheet: sheet, detents: detents, modalConfig: modalConfig)
                    } else {
                        print("🎯 Using default large detent")
                        sheet.detents = [.large()]
                        sheet.selectedDetentIdentifier = .large
                    }

                    sheet.prefersGrabberVisible = modalConfig["showDragIndicator"] as? Bool ?? true

                    if let cornerRadius = modalConfig["cornerRadius"] as? CGFloat,
                        #available(iOS 16.0, *)
                    {
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
    private func applyCustomDetents(
        sheet: UISheetPresentationController, customDetents: [[String: Any]],
        modalConfig: [String: Any]
    ) {
        var sheetDetents: [UISheetPresentationController.Detent] = []

        for customDetent in customDetents {
            if let height = customDetent["height"] as? Double {
                let identifier = customDetent["identifier"] as? String ?? "custom_\(height)"

                if #available(iOS 16.0, *) {
                    sheetDetents.append(
                        .custom(identifier: .init(identifier)) { context in
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
    private func applyStandardDetents(
        sheet: UISheetPresentationController, detents: [String], modalConfig: [String: Any]
    ) {
        var sheetDetents: [UISheetPresentationController.Detent] = []

        for detentString in detents {
            switch detentString.lowercased() {
            case "small":
                if #available(iOS 16.0, *) {
                    sheetDetents.append(
                        .custom(identifier: .init("small")) { context in
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

    @available(iOS 15.0, *)
    private func configureSheetDetents(
        sheet: UISheetPresentationController, for screenContainer: ScreenContainer
    ) {
        guard
            let sheetConfig = objc_getAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "sheetConfig".hashValue)!
            ) as? [String: Any]
        else {
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
                        detents.append(
                            .custom(identifier: .init("small")) { context in
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

    internal func configureScreenForPush(_ screenContainer: ScreenContainer) {
        guard
            let pushConfig = objc_getAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!
            ) as? [String: Any]
        else {
            print("⚠️ DCFScreenComponent: No push config found for route '\(screenContainer.route)'")
            return
        }

        print(
            "🔧 DCFScreenComponent: Configuring push screen '\(screenContainer.route)' with config keys: \(pushConfig.keys)"
        )

        let viewController = screenContainer.viewController

        if let title = pushConfig["title"] as? String {
            viewController.navigationItem.title = title
            print("✅ Set title: \(title)")
        }

        let hideBackButton = pushConfig["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton

        if let backButtonTitle = pushConfig["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(
                title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }

        let largeTitleDisplayMode = pushConfig["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode =
                largeTitleDisplayMode ? .always : .never
        }

        configureHeaderActions(for: viewController, pushConfig: pushConfig)
    }

    private func configureHeaderActions(
        for viewController: UIViewController, pushConfig: [String: Any]
    ) {
        print(
            "🎯 DCFScreenComponent: Configuring header actions for '\(viewController.title ?? "Unknown")'"
        )
        print("🎯 DCFScreenComponent: Push config keys: \(pushConfig.keys)")

        if let prefixActionsData = pushConfig["prefixActions"] as? [[String: Any]] {
            print("📝 Found \(prefixActionsData.count) prefix actions")
            print("📝 Prefix actions data: \(prefixActionsData)")

            let leftBarButtonItems = createBarButtonItems(
                from: prefixActionsData, for: viewController, position: .left)
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
            print("✅ Set \(leftBarButtonItems.count) left bar button items")
        } else {
            print("ℹ️ No prefix actions found in push config")
        }

        if let suffixActionsData = pushConfig["suffixActions"] as? [[String: Any]] {
            print("📝 Found \(suffixActionsData.count) suffix actions")
            print("📝 Suffix actions data: \(suffixActionsData)")

            let rightBarButtonItems = createBarButtonItems(
                from: suffixActionsData, for: viewController, position: .right)
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
            print("✅ Set \(rightBarButtonItems.count) right bar button items")
        } else {
            print("ℹ️ No suffix actions found in push config")
        }
    }

    internal enum BarButtonPosition {
        case left, right
    }

    internal func createBarButtonItems(
        from actionsData: [[String: Any]], for viewController: UIViewController,
        position: BarButtonPosition
    ) -> [UIBarButtonItem] {
        var barButtonItems: [UIBarButtonItem] = []

        for (index, actionData) in actionsData.enumerated() {
            if let barButtonItem = createBarButtonItem(
                from: actionData, for: viewController, position: position, index: index)
            {
                barButtonItems.append(barButtonItem)
            }
        }

        return barButtonItems
    }

    private func createBarButtonItem(
        from actionData: [String: Any], for viewController: UIViewController,
        position: BarButtonPosition, index: Int
    ) -> UIBarButtonItem? {
        let title = actionData["title"] as? String ?? ""
        let enabled = actionData["enabled"] as? Bool ?? true
        let actionId = actionData["actionId"] as? String ?? "action_\(position)_\(index)"

        print(
            "🔨 Creating bar button item - Title: '\(title)', ActionId: '\(actionId)', Enabled: \(enabled)"
        )

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
                let packageName = iconConfig["package"] as? String
            {
                let image = loadSVGForHeaderAction(
                    iconName: iconName, packageName: packageName, iconConfig: iconConfig)

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

    private func loadSVGForHeaderAction(
        iconName: String, packageName: String, iconConfig: [String: Any]
    ) -> UIImage? {
        guard
            let key = sharedFlutterViewController?.lookupKey(
                forAsset: "assets/icons/\(iconName).svg",
                fromPackage: packageName
            )
        else {
            print(
                "❌ DCFScreenComponent: Could not find asset key for \(iconName) in package \(packageName)"
            )
            return nil
        }

        let mainBundle = Bundle.main
        guard let path = mainBundle.path(forResource: key, ofType: nil), !path.isEmpty else {
            print(
                "❌ DCFScreenComponent: Could not find file path for \(iconName) in package \(packageName)"
            )
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

    private func processHeaderActionSVG(_ svgImage: SVGKImage, iconConfig: [String: Any])
        -> UIImage?
    {
        guard let uiImage = svgImage.uiImage else { return nil }

        if let tintColor = iconConfig["tintColor"] as? String,
            let color = ColorUtilities.color(fromHexString: tintColor)
        {
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

    internal func configureNavigationBarForTabScreen(
        _ viewController: UIViewController, props: [String: Any]
    ) {
        if let navigationBarTitle = props["navigationBarTitle"] as? String {
            viewController.navigationItem.title = navigationBarTitle
        }

        let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode =
                largeTitleDisplayMode ? .always : .never
        }

        let hideNavigationBar = props["hideNavigationBar"] as? Bool ?? false
        if hideNavigationBar {
            viewController.navigationController?.setNavigationBarHidden(
                hideNavigationBar, animated: false)
        }

        let hideBackButton = props["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton

        if let backButtonTitle = props["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(
                title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }

        configureHeaderActionsFromProps(for: viewController, props: props)
    }

    private func configureHeaderActionsFromProps(
        for viewController: UIViewController, props: [String: Any]
    ) {
        if let prefixActionsData = props["prefixActions"] as? [[String: Any]] {
            let leftBarButtonItems = createBarButtonItems(
                from: prefixActionsData, for: viewController, position: .left)
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
        }

        if let suffixActionsData = props["suffixActions"] as? [[String: Any]] {
            let rightBarButtonItems = createBarButtonItems(
                from: suffixActionsData, for: viewController, position: .right)
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
        }
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
            print("🎯 Extension: Stored push config for '\(screenContainer.route)': \(pushConfig)")
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

    private func storePopoverConfiguration(_ screenContainer: ScreenContainer, props: [String: Any])
    {
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

    private func storeOverlayConfiguration(_ screenContainer: ScreenContainer, props: [String: Any])
    {
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

    internal func storeNavigationBarConfiguration(
        _ screenContainer: ScreenContainer, props: [String: Any]
    ) {
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

    private func getCurrentActiveNavigationController() -> UINavigationController? {
        if let tabBarController = UIApplication.shared.windows.first?.rootViewController
            as? UITabBarController,
            let selectedNavController = tabBarController.selectedViewController
                as? UINavigationController
        {
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

    private func getTopmostViewController(from viewController: UIViewController) -> UIViewController
    {
        if let presentedViewController = viewController.presentedViewController {
            return getTopmostViewController(from: presentedViewController)
        } else if let tabBarController = viewController as? UITabBarController,
            let selectedViewController = tabBarController.selectedViewController
        {
            return getTopmostViewController(from: selectedViewController)
        } else if let navigationController = viewController as? UINavigationController,
            let topViewController = navigationController.topViewController
        {
            return getTopmostViewController(from: topViewController)
        } else {
            return viewController
        }
    }

    private func findNavigationController(in viewController: UIViewController)
        -> UINavigationController?
    {
        if let navController = viewController as? UINavigationController {
            return navController
        }

        if let tabBarController = viewController as? UITabBarController,
            let selectedViewController = tabBarController.selectedViewController
        {
            return findNavigationController(in: selectedViewController)
        }

        for child in viewController.children {
            if let navController = findNavigationController(in: child) {
                return navController
            }
        }

        return nil
    }

    private func findScreenContainer(for view: UIView) -> ScreenContainer? {
        for (_, container) in DCFScreenComponent.routeRegistry {
            if container.contentView == view {
                return container
            }
        }
        return nil
    }

    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        guard let screenContainer = findScreenContainer(for: view) else {
            print("❌ DCFScreenComponent: Could not find screen container for setChildren")
            return false
        }

        print(
            "📱 DCFScreenComponent: Setting \(childViews.count) children for route '\(screenContainer.route)'"
        )

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

    static var routeRegistry: [String: ScreenContainer] = [:]
    static var currentRouteStack: [String] = []

    static func getScreenContainer(route: String) -> ScreenContainer? {
        return routeRegistry[route]
    }

    static func getAllRoutes() -> [String] {
        return Array(routeRegistry.keys)
    }

    static func getCurrentRouteStack() -> [String] {
        return currentRouteStack
    }

    static func cleanup() {
        routeRegistry.removeAll()
        currentRouteStack.removeAll()
        print("🧹 DCFScreenComponent: Cleaned up all routes and navigation state")
    }
}

class ScreenContainer {
    let route: String
    let presentationStyle: String
    let viewController: UIViewController
    let contentView: UIView

    init(route: String, presentationStyle: String) {
        self.route = route
        self.presentationStyle = presentationStyle

        self.viewController = UIViewController()
        self.contentView = UIView()
        self.contentView.backgroundColor = UIColor.clear
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.viewController.view = contentView

        print("📱 ScreenContainer: Created '\(route)' with style '\(presentationStyle)'")
    }

    deinit {
        print("🗑️ ScreenContainer: Deallocated '\(route)' with style '\(presentationStyle)'")
    }
}

class DCFHeaderActionHandler: NSObject {
    static let shared = DCFHeaderActionHandler()

    private override init() {
        super.init()
    }

    @objc func headerActionPressed(_ sender: UIBarButtonItem) {
        print("🎯 DCFHeaderActionHandler: Header action button was pressed!")

        guard
            let actionData = objc_getAssociatedObject(
                sender,
                UnsafeRawPointer(bitPattern: "actionData".hashValue)!
            ) as? [String: Any],
            let viewController = objc_getAssociatedObject(
                sender,
                UnsafeRawPointer(bitPattern: "viewController".hashValue)!
            ) as? UIViewController
        else {
            print("❌ DCFHeaderActionHandler: No action data found for header action")
            return
        }

        let actionId = actionData["actionId"] as? String ?? "unknown_action"
        let title = actionData["title"] as? String ?? ""

        print("🎯 DCFHeaderActionHandler: Header action pressed - ID: \(actionId), Title: \(title)")

        var foundContainer = false
        for (_, container) in DCFScreenComponent.routeRegistry {
            if container.viewController == viewController {
                foundContainer = true
                print(
                    "📡 DCFHeaderActionHandler: Found container '\(container.route)' for view controller"
                )

                propagateEvent(
                    on: container.contentView,
                    eventName: "onHeaderActionPress",
                    data: [
                        "actionId": actionId,
                        "title": title,
                        "route": container.route,
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

extension DCFScreenComponent: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        print("🚨 NAVIGATION DELEGATE CALLED: didShow triggered!")

        let currentCount = navigationController.viewControllers.count
        let previousCount =
            objc_getAssociatedObject(
                navigationController, &DCFScreenComponent.previousViewControllerCountKey) as? Int
            ?? currentCount

        // Get the ACTUAL previous view controllers that were stored before this navigation
        let previousViewControllers =
            objc_getAssociatedObject(
                navigationController, &DCFScreenComponent.previousViewControllersKey)
            as? [UIViewController] ?? []

        print("🔍 STORAGE DEBUG: NavigationController = \(navigationController)")
        print(
            "🔍 STORAGE DEBUG: Retrieved previousViewControllers count = \(previousViewControllers.count)"
        )
        if !previousViewControllers.isEmpty {
            let routes = previousViewControllers.compactMap { vc in
                findScreenContainer(for: vc)?.route
            }
            print("🔍 STORAGE DEBUG: Retrieved routes = \(routes)")
        }

        print(
            "📍 Navigation Debug: currentCount=\(currentCount), previousCount=\(previousCount), isProgrammatic=\(DCFScreenComponent.isProgrammaticNavigation)"
        )

        objc_setAssociatedObject(
            navigationController, &DCFScreenComponent.previousViewControllerCountKey, currentCount,
            .OBJC_ASSOCIATION_RETAIN)

        let currentViewControllers = navigationController.viewControllers

        guard let targetContainer = findScreenContainer(for: viewController) else {
            print("⚠️ DCFScreenComponent: Could not find screen container for view controller")
            return
        }

        if currentCount < previousCount && !DCFScreenComponent.isProgrammaticNavigation {
            print("🎯 DCFScreenComponent: USER-INITIATED pop detected to '\(targetContainer.route)'")

            print(
                "🔍 DEBUG: previousViewControllers count=\(previousViewControllers.count), currentViewControllers count=\(currentViewControllers.count)"
            )

            let poppedViewControllers = previousViewControllers.filter {
                !currentViewControllers.contains($0)
            }

            print("🔥 DEBUG: Found \(poppedViewControllers.count) popped view controllers")

            for poppedViewController in poppedViewControllers {
                for (_, container) in DCFScreenComponent.routeRegistry {
                    if container.viewController == poppedViewController {
                        print("🧹 Sending navigation event for popped route: \(container.route)")
                        propagateEvent(
                            on: container.contentView,
                            eventName: "onNavigationEvent",
                            data: [
                                "action": "pop",
                                "targetRoute": targetContainer.route,
                                "animated": animated,
                                "userInitiated": true,
                                "screenRoute": container.route,
                            ]
                        )
                        print("🧹 Sent onNavigationEvent for popped route: \(container.route)")
                        break
                    }
                }
            }

            print("🔥 DEBUG: About to propagate events for user-initiated navigation to target")

            print("🔥 Sending navigation event to target route: \(targetContainer.route)")
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "pop",
                    "targetRoute": targetContainer.route,
                    "animated": animated,
                    "userInitiated": true,
                    "screenRoute": targetContainer.route,
                ]
            )

            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["route": targetContainer.route]
            )

            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onActivate",
                data: ["route": targetContainer.route]
            )
        }

        // Store current view controllers for the NEXT navigation event (after processing current one)
        let routes = currentViewControllers.compactMap { vc in
            findScreenContainer(for: vc)?.route
        }
        print(
            "🔍 STORAGE DEBUG: Storing currentViewControllers count = \(currentViewControllers.count)"
        )
        print("🔍 STORAGE DEBUG: Storing routes = \(routes)")
        print("🔍 STORAGE DEBUG: NavigationController for storage = \(navigationController)")

        objc_setAssociatedObject(
            navigationController, &DCFScreenComponent.previousViewControllersKey,
            currentViewControllers,
            .OBJC_ASSOCIATION_RETAIN)

        DCFScreenComponent.isProgrammaticNavigation = false
        print("✅ DCFScreenComponent: Navigation didShow completed for '\(targetContainer.route)'")
    }

    private func findScreenContainer(for viewController: UIViewController) -> ScreenContainer? {
        for (_, container) in DCFScreenComponent.routeRegistry {
            if container.viewController == viewController {
                return container
            }
        }
        return nil
    }
}

extension DCFScreenComponent: UIAdaptivePresentationControllerDelegate {

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        print("🎯 DCFScreenComponent: Modal will dismiss (user-initiated)")

        if let screenContainer = findScreenContainer(
            for: presentationController.presentedViewController)
        {
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onDisappear",
                data: ["route": screenContainer.route]
            )

            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onDeactivate",
                data: ["route": screenContainer.route]
            )
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("🎯 DCFScreenComponent: Modal did dismiss (user-initiated)")

        if let screenContainer = findScreenContainer(
            for: presentationController.presentedViewController)
        {
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "dismissModal",
                    "animated": true,
                    "userInitiated": true,
                ]
            )
        }
    }
}

extension DCFScreenComponent: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let navigationController = getCurrentActiveNavigationController() {
            return navigationController.viewControllers.count > 1
        }
        return true
    }
}

@available(iOS 15.0, *)
extension DCFScreenComponent: UISheetPresentationControllerDelegate {

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: UISheetPresentationController
    ) {
        print("🎯 DCFScreenComponent: Sheet detent changed")

        if let presentedViewController = sheetPresentationController.presentedViewController
            as? UIViewController,
            let screenContainer = findScreenContainer(for: presentedViewController)
        {

            let detentId: String
            if #available(iOS 16.0, *) {
                detentId =
                    sheetPresentationController.selectedDetentIdentifier?.rawValue ?? "unknown"
            } else {
                detentId = "detent_changed"
            }

            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onSheetDetentChange",
                data: [
                    "detentIdentifier": detentId
                ]
            )
        }
    }
}

extension DCFScreenComponent {

    static let delegateManager = DCFScreenComponent()

    static var isProgrammaticNavigation = false

    private static var previousViewControllersKey: UInt8 = 0
    private static var previousViewControllerCountKey: UInt8 = 0

    private func setupNavigationDelegate(_ navigationController: UINavigationController) {
        print("🔧 SETUP: setupNavigationDelegate called")
        print("🔧 SETUP: Current delegate = \(String(describing: navigationController.delegate))")
        print(
            "🔧 SETUP: Our delegate manager = \(String(describing: DCFScreenComponent.delegateManager))"
        )

        if navigationController.delegate !== DCFScreenComponent.delegateManager {
            navigationController.delegate = DCFScreenComponent.delegateManager
            print("🎯 DCFScreenComponent: Set navigation controller delegate")
        } else {
            print("🔧 SETUP: Delegate already set correctly")
        }

        if let interactivePopGestureRecognizer = navigationController
            .interactivePopGestureRecognizer
        {
            print("🔧 SETUP: Setting gesture recognizer delegate")
            interactivePopGestureRecognizer.delegate = DCFScreenComponent.delegateManager
        } else {
            print("🔧 SETUP: No interactive pop gesture recognizer found")
        }

        print("🔧 SETUP: Final delegate = \(String(describing: navigationController.delegate))")
    }

    private func setupModalDelegate(_ viewController: UIViewController) {
        if let presentationController = viewController.presentationController {
            presentationController.delegate = DCFScreenComponent.delegateManager
            print("🎯 DCFScreenComponent: Set modal presentation delegate")
        }

        if #available(iOS 15.0, *) {
            if let sheetController = viewController.sheetPresentationController {
                sheetController.delegate = DCFScreenComponent.delegateManager
                print("🎯 DCFScreenComponent: Set sheet presentation delegate")
            }
        }
    }

    private func navigateToRouteWithDelegates(
        _ targetRoute: String, animated: Bool, params: [String: Any]?,
        from sourceContainer: ScreenContainer
    ) {
        print("📱 DCFScreenComponent: Executing route navigation to '\(targetRoute)'")

        let routes = parseRoute(targetRoute)
        guard !routes.isEmpty else {
            print("❌ DCFScreenComponent: Invalid route '\(targetRoute)'")
            return
        }

        guard let navigationController = getCurrentActiveNavigationController() else {
            print("❌ DCFScreenComponent: No active navigation controller found for navigation")
            return
        }

        setupNavigationDelegate(navigationController)

        let currentRouteStack = getCurrentRouteStack(from: navigationController)
        let targetRouteStack = routes

        let commonPrefixLength = findCommonPrefixLength(currentRouteStack, targetRouteStack)

        if currentRouteStack.count > commonPrefixLength {
            let routesToPop = currentRouteStack.count - commonPrefixLength
            for _ in 0..<routesToPop {
                navigationController.popViewController(animated: false)
            }
        }

        let routesToPush = Array(targetRouteStack.dropFirst(commonPrefixLength))
        for (index, route) in routesToPush.enumerated() {
            guard
                let targetContainer = getOrCreateScreenContainer(
                    for: route, presentationStyle: "push")
            else {
                print("❌ DCFScreenComponent: Could not create container for route '\(route)'")
                continue
            }

            configureScreenForPush(targetContainer)

            let isLastRoute = index == routesToPush.count - 1
            if isLastRoute && params != nil {
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onReceiveParams",
                    data: ["params": params!, "sourceRoute": sourceContainer.route]
                )
            }

            DCFScreenComponent.isProgrammaticNavigation = true
            navigationController.pushViewController(
                targetContainer.viewController, animated: isLastRoute ? animated : false)
        }

        updateRouteStack(navigationController)

        print("✅ DCFScreenComponent: Successfully navigated to route '\(targetRoute)'")
    }

    private func presentModalRouteWithDelegates(
        _ targetRoute: String, animated: Bool, params: [String: Any]?, presentationStyle: String?,
        from sourceContainer: ScreenContainer
    ) {
        print("📱 DCFScreenComponent: Executing modal route presentation for '\(targetRoute)'")

        guard
            let targetContainer = getOrCreateScreenContainer(
                for: targetRoute, presentationStyle: "modal")
        else {
            print("❌ DCFScreenComponent: Could not create container for route '\(targetRoute)'")
            return
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        configureModalPresentation(
            targetContainer: targetContainer, presentationStyle: presentationStyle)

        setupModalDelegate(targetContainer.viewController)

        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "sourceRoute": sourceContainer.route]
            )
        }

        presentingViewController.present(targetContainer.viewController, animated: animated) {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["route": targetRoute]
            )

            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onActivate",
                data: ["route": targetRoute]
            )

            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentModalRoute",
                    "targetRoute": targetRoute,
                    "animated": animated,
                ]
            )
        }

        print("✅ DCFScreenComponent: Successfully presented modal route '\(targetRoute)'")
    }

    private func popCurrentRouteWithDelegates(
        animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer
    ) {
        DCFScreenComponent.isProgrammaticNavigation = true
        popCurrentRoute(animated: animated, result: result, from: sourceContainer)
    }

    private func dismissModalRouteWithDelegates(
        animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer
    ) {
        dismissModalRoute(animated: animated, result: result, from: sourceContainer)
    }
}

extension DCFScreenComponent {

    static func cleanupAllRoutes() {
        for (_, container) in routeRegistry {
            container.viewController.view = nil
            container.contentView.removeFromSuperview()
        }

        routeRegistry.removeAll()
        currentRouteStack.removeAll()

        print("🧹 DCFScreenComponent: Cleaned up all routes and containers")
    }

    static func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            cleanupUnusedRoutes()
        }
    }

    static func cleanupUnusedRoutes() {
        let activeViewControllers = getAllActiveViewControllers()
        var routesToRemove: [String] = []

        for (route, container) in routeRegistry {
            if !activeViewControllers.contains(container.viewController) {
                routesToRemove.append(route)
            }
        }

        for route in routesToRemove {
            print("🧹 DCFScreenComponent: Cleaning up unused route '\(route)'")
            routeRegistry.removeValue(forKey: route)
        }

        if routesToRemove.count > 0 {
            print("✅ DCFScreenComponent: Cleaned up \(routesToRemove.count) unused routes")
        }
    }

    private static func getAllActiveViewControllers() -> Set<UIViewController> {
        var activeControllers: Set<UIViewController> = []

        if let tabBarController = UIApplication.shared.windows.first?.rootViewController
            as? UITabBarController
        {
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

    private static func collectPresentedViewControllers(
        from viewController: UIViewController, into activeControllers: inout Set<UIViewController>
    ) {
        activeControllers.insert(viewController)

        if let presentedViewController = viewController.presentedViewController {
            collectPresentedViewControllers(from: presentedViewController, into: &activeControllers)
        }

        for child in viewController.children {
            collectPresentedViewControllers(from: child, into: &activeControllers)
        }
    }

    static func printRegisteredRoutes() {
        print("🎯 DCFScreenComponent: Registered routes:")
        for route in routeRegistry.keys.sorted() {
            print("  - \(route)")
        }
        print("🎯 Current route stack: \(currentRouteStack)")
    }

    static func getRouteStackInfo() -> [String: Any] {
        return [
            "registeredRoutes": Array(routeRegistry.keys),
            "currentRouteStack": currentRouteStack,
            "activeRouteCount": routeRegistry.count,
        ]
    }
}
