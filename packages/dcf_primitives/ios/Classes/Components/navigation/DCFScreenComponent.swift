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

        let contextKey = createContextKey(screenName: screenName, presentationStyle: presentationStyle)

        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[contextKey] {
            screenContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing screen container for '\(contextKey)'")
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[contextKey] = screenContainer

            // 🎯 FIXED: Register screen's intended presentation style
            DCFScreenComponent.screenPresentationRegistry[screenName] = presentationStyle
            print("✅ DCFScreenComponent: Created new screen container for '\(contextKey)' and registered presentation style '\(presentationStyle)'")
        }

        configureScreen(screenContainer, props: props)
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        storeModalConfiguration(screenContainer, props: props)
        storePopoverConfiguration(screenContainer, props: props)
        storeOverlayConfiguration(screenContainer, props: props)
        storeSheetConfiguration(screenContainer, props: props)
        storeDrawerConfiguration(screenContainer, props: props)
        storeSplitViewConfiguration(screenContainer, props: props)

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

        let contextKey = createContextKey(screenName: screenName, presentationStyle: presentationStyle)

        let screenContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[contextKey] {
            screenContainer = existing
        } else {
            screenContainer = ScreenContainer(name: screenName, presentationStyle: presentationStyle)
            DCFScreenComponent.screenRegistry[contextKey] = screenContainer
            DCFScreenComponent.screenPresentationRegistry[screenName] = presentationStyle
            print("✅ DCFScreenComponent: Created new screen container for '\(contextKey)' during update")

            configureScreen(screenContainer, props: props)
        }

        return updateExistingScreen(screenContainer, view: view, props: props)
    }

    private func createContextKey(screenName: String, presentationStyle: String) -> String {
        switch presentationStyle {
        case "tab":
            return "tab_\(screenName)"
        case "push":
            let existingPushKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("push_\(screenName)_") }
            if let existingKey = existingPushKeys.first {
                return existingKey
            }
            return "push_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "modal":
            let existingModalKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("modal_\(screenName)_") }
            if let existingKey = existingModalKeys.first {
                return existingKey
            }
            return "modal_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "sheet":
            let existingSheetKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("sheet_\(screenName)_") }
            if let existingKey = existingSheetKeys.first {
                return existingKey
            }
            return "sheet_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "popover":
            let existingPopoverKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("popover_\(screenName)_") }
            if let existingKey = existingPopoverKeys.first {
                return existingKey
            }
            return "popover_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "overlay":
            let existingOverlayKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("overlay_\(screenName)_") }
            if let existingKey = existingOverlayKeys.first {
                return existingKey
            }
            return "overlay_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "drawer":
            let existingDrawerKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("drawer_\(screenName)_") }
            if let existingKey = existingDrawerKeys.first {
                return existingKey
            }
            return "drawer_\(screenName)_\(UUID().uuidString.prefix(8))"
        case "splitView":
            let existingSplitKeys = DCFScreenComponent.screenRegistry.keys.filter { $0.hasPrefix("splitView_\(screenName)_") }
            if let existingKey = existingSplitKeys.first {
                return existingKey
            }
            return "splitView_\(screenName)_\(UUID().uuidString.prefix(8))"
        default:
            return "unknown_\(screenName)_\(UUID().uuidString.prefix(8))"
        }
    }

    private func updateExistingScreen(_ screenContainer: ScreenContainer, view: UIView, props: [String: Any]) -> Bool {
        storeTabConfiguration(screenContainer, props: props)
        storePushConfiguration(screenContainer, props: props)
        storeModalConfiguration(screenContainer, props: props)
        storePopoverConfiguration(screenContainer, props: props)
        storeOverlayConfiguration(screenContainer, props: props)
        storeSheetConfiguration(screenContainer, props: props)
        storeDrawerConfiguration(screenContainer, props: props)
        storeSplitViewConfiguration(screenContainer, props: props)
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
                smartNavigateTo(targetScreenName, method: .push, animated: animated, params: params, from: screenContainer)
            }
        }

        if let modalData = commandData["presentModal"] as? [String: Any] {
            if let targetScreenName = modalData["screenName"] as? String {
                let animated = modalData["animated"] as? Bool ?? true
                let params = modalData["params"] as? [String: Any]
                let presentationStyle = modalData["presentationStyle"] as? String
                smartNavigateTo(targetScreenName, method: .modal, animated: animated, params: params, presentationStyle: presentationStyle, from: screenContainer)
            }
        }

        if let sheetData = commandData["presentSheet"] as? [String: Any] {
            if let targetScreenName = sheetData["screenName"] as? String {
                let animated = sheetData["animated"] as? Bool ?? true
                let params = sheetData["params"] as? [String: Any]
                smartNavigateTo(targetScreenName, method: .sheet, animated: animated, params: params, from: screenContainer)
            }
        }

        if let popoverData = commandData["presentPopover"] as? [String: Any] {
            if let targetScreenName = popoverData["screenName"] as? String {
                let animated = popoverData["animated"] as? Bool ?? true
                let params = popoverData["params"] as? [String: Any]
                let sourceViewId = popoverData["sourceViewId"] as? String
                smartNavigateTo(targetScreenName, method: .popover, animated: animated, params: params, sourceViewId: sourceViewId, from: screenContainer)
            }
        }

        if let overlayData = commandData["presentOverlay"] as? [String: Any] {
            if let targetScreenName = overlayData["screenName"] as? String {
                let animated = overlayData["animated"] as? Bool ?? true
                let params = overlayData["params"] as? [String: Any]
                smartNavigateTo(targetScreenName, method: .overlay, animated: animated, params: params, from: screenContainer)
            }
        }

        if let drawerData = commandData["presentDrawer"] as? [String: Any] {
            if let targetScreenName = drawerData["screenName"] as? String {
                let animated = drawerData["animated"] as? Bool ?? true
                let params = drawerData["params"] as? [String: Any]
                let direction = drawerData["direction"] as? String
                smartNavigateTo(targetScreenName, method: .drawer, animated: animated, params: params, drawerDirection: direction, from: screenContainer)
            }
        }

        if let splitData = commandData["presentSplitView"] as? [String: Any] {
            if let targetScreenName = splitData["screenName"] as? String {
                let animated = splitData["animated"] as? Bool ?? true
                let params = splitData["params"] as? [String: Any]
                smartNavigateTo(targetScreenName, method: .splitView, animated: animated, params: params, from: screenContainer)
            }
        }

        // Handle other navigation commands (pop, dismiss, etc.)
        handleStandardNavigationCommands(commandData: commandData, from: screenContainer)
    }

    // 🎯 ENHANCED: Smart navigation with all presentation styles
    private func smartNavigateTo(
        _ targetScreenName: String,
        method requestedMethod: NavigationMethod,
        animated: Bool,
        params: [String: Any]? = nil,
        presentationStyle: String? = nil,
        sourceViewId: String? = nil,
        drawerDirection: String? = nil,
        from sourceContainer: ScreenContainer
    ) {
        print("🧠 DCFScreenComponent: Smart navigation to '\(targetScreenName)' - requested: \(requestedMethod)")

        // 1. Determine the target screen's registered presentation style
        guard let registeredPresentationStyle = DCFScreenComponent.screenPresentationRegistry[targetScreenName] else {
            print("⚠️ DCFScreenComponent: Screen '\(targetScreenName)' not registered - using requested method \(requestedMethod)")
            executeNavigationMethod(requestedMethod, to: targetScreenName, animated: animated, params: params, presentationStyle: presentationStyle, sourceViewId: sourceViewId, drawerDirection: drawerDirection, from: sourceContainer)
            return
        }

        print("🎯 DCFScreenComponent: Screen '\(targetScreenName)' is registered as '\(registeredPresentationStyle)'")

        // 2. Determine the appropriate navigation method based on registered style
        let appropriateMethod = determineAppropriateMethod(for: registeredPresentationStyle)

        // 3. Log the smart decision
        if appropriateMethod != requestedMethod {
            print("🔄 DCFScreenComponent: Smart navigation override - requested '\(requestedMethod)' but using '\(appropriateMethod)' for '\(registeredPresentationStyle)' screen")
        } else {
            print("✅ DCFScreenComponent: Smart navigation - requested method matches registered style")
        }

        // 4. Execute the appropriate navigation method
        executeNavigationMethod(appropriateMethod, to: targetScreenName, animated: animated, params: params, presentationStyle: presentationStyle, sourceViewId: sourceViewId, drawerDirection: drawerDirection, from: sourceContainer)
    }

    private func determineAppropriateMethod(for presentationStyle: String) -> NavigationMethod {
        switch presentationStyle {
        case "tab":
            return .switchTab
        case "push":
            return .push
        case "modal":
            return .modal
        case "sheet":
            return .sheet
        case "popover":
            return .popover
        case "overlay":
            return .overlay
        case "drawer":
            return .drawer
        case "splitView":
            return .splitView
        default:
            return .push // Default fallback
        }
    }

    private func executeNavigationMethod(
        _ method: NavigationMethod,
        to targetScreenName: String,
        animated: Bool,
        params: [String: Any]?,
        presentationStyle: String? = nil,
        sourceViewId: String? = nil,
        drawerDirection: String? = nil,
        from sourceContainer: ScreenContainer
    ) {
        switch method {
        case .switchTab:
            switchToTabScreen(targetScreenName, params: params, from: sourceContainer, animated: animated)
        case .push:
            pushToScreen(targetScreenName, animated: animated, params: params, from: sourceContainer)
        case .modal:
            presentModalScreen(targetScreenName, animated: animated, params: params, presentationStyle: presentationStyle, from: sourceContainer)
        case .sheet:
            presentSheetScreen(targetScreenName, animated: animated, params: params, from: sourceContainer)
        case .popover:
            presentPopoverScreen(targetScreenName, animated: animated, params: params, sourceViewId: sourceViewId, from: sourceContainer)
        case .overlay:
            presentOverlayScreen(targetScreenName, animated: animated, params: params, from: sourceContainer)
        case .drawer:
            presentDrawerScreen(targetScreenName, animated: animated, params: params, direction: drawerDirection, from: sourceContainer)
        case .splitView:
            presentSplitViewScreen(targetScreenName, animated: animated, params: params, from: sourceContainer)
        }
    }

    // MARK: - Navigation Method Implementations

    private func pushToScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing push navigation to '\(screenName)'")

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

        // 🎯 CRITICAL FIX: ALWAYS configure modal presentation
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

    private func configureModalPresentation(targetContainer: ScreenContainer, presentationStyle: String?) {
        let viewController = targetContainer.viewController
        
        print("🎯 Configuring modal presentation for '\(targetContainer.name)'")
        
        // Set default presentation style
        if #available(iOS 13.0, *) {
            viewController.modalPresentationStyle = .pageSheet
        } else {
            viewController.modalPresentationStyle = .formSheet
        }
        
        // 🎯 ALWAYS configure sheet presentation if available
        if #available(iOS 15.0, *) {
            if let sheet = viewController.sheetPresentationController {
                // Get stored modal config
                if let modalConfig = objc_getAssociatedObject(
                    targetContainer.viewController,
                    UnsafeRawPointer(bitPattern: "modalConfig".hashValue)!
                ) as? [String: Any] {
                    print("🎯 Found modal config: \(modalConfig)")
                    
                    // Check for customDetents first
                    if let customDetents = modalConfig["customDetents"] as? [[String: Any]] {
                        print("🎯 Applying custom detents: \(customDetents)")
                        applyCustomDetents(sheet: sheet, customDetents: customDetents, modalConfig: modalConfig)
                    }
                    // Check for standard detents
                    else if let detents = modalConfig["detents"] as? [String] {
                        print("🎯 Applying standard detents: \(detents)")
                        applyStandardDetents(sheet: sheet, detents: detents, modalConfig: modalConfig)
                    }
                    // No detents specified - use default
                    else {
                        print("🎯 Using default large detent")
                        sheet.detents = [.large()]
                        sheet.selectedDetentIdentifier = .large
                    }
                    
                    // Apply other modal config
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
        
        // Handle presentation style override
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

    // 🎯 NEW: Apply custom detents
    @available(iOS 15.0, *)
    private func applyCustomDetents(sheet: UISheetPresentationController, customDetents: [[String: Any]], modalConfig: [String: Any]) {
        var sheetDetents: [UISheetPresentationController.Detent] = []
        
        for customDetent in customDetents {
            if let height = customDetent["height"] as? Double {
                let identifier = customDetent["identifier"] as? String ?? "custom_\(height)"
                
                if #available(iOS 16.0, *) {
                    sheetDetents.append(.custom(identifier: .init(identifier)) { context in
                        if height <= 1.0 {
                            // Percentage
                            return context.maximumDetentValue * height
                        } else {
                            // Fixed points
                            return height
                        }
                    })
                } else {
                    // iOS 15 fallback
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
            } else {
                // Fallback on earlier versions
            }
        }
    }

    // 🎯 NEW: Apply standard detents
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
            } else {
                // Fallback on earlier versions
            }
        }
    }
    // 🎯 NEW: Sheet presentation using iOS 15+ bottom sheet
    private func presentSheetScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing sheet presentation for '\(screenName)'")

        let sheetContextKey = createContextKey(screenName: screenName, presentationStyle: "sheet")

        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[sheetContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing sheet container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "sheet")
            DCFScreenComponent.screenRegistry[sheetContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new sheet container for '\(screenName)'")
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found for sheet")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        // Configure as bottom sheet
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

        let popoverContextKey = createContextKey(screenName: screenName, presentationStyle: "popover")

        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[popoverContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing popover container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "popover")
            DCFScreenComponent.screenRegistry[popoverContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new popover container for '\(screenName)'")
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found for popover")
            return
        }

        targetContainer.contentView.isHidden = false
        targetContainer.contentView.alpha = 1.0
        targetContainer.contentView.backgroundColor = UIColor.systemBackground

        // Configure as popover
        targetContainer.viewController.modalPresentationStyle = .popover

        if let popoverController = targetContainer.viewController.popoverPresentationController {
            // Configure popover from stored config
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

    // 🎯 FIXED: Proper overlay presentation
    private func presentOverlayScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing overlay presentation for '\(screenName)'")

        let overlayContextKey = createContextKey(screenName: screenName, presentationStyle: "overlay")

        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[overlayContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing overlay container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "overlay")
            DCFScreenComponent.screenRegistry[overlayContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new overlay container for '\(screenName)'")
        }

        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("❌ DCFScreenComponent: No root view controller found for overlay")
            return
        }

        // 🎯 FIXED: Apply overlay configuration from stored props
        let overlayView = targetContainer.contentView
        overlayView.isHidden = false
        overlayView.alpha = 0.0

        // Apply overlay configuration
        configureOverlayView(overlayView, for: targetContainer)

        // Add overlay to the top of the view hierarchy
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

        // Animate overlay appearance
        if animated {
            UIView.animate(withDuration: 0.3) {
                overlayView.alpha = 1.0
            } completion: { _ in
                propagateEvent(
                    on: sourceContainer.contentView,
                    eventName: "onNavigationEvent",
                    data: [
                        "action": "presentOverlay",
                        "targetScreen": screenName,
                        "animated": animated
                    ]
                )

                // 🎯 FIXED: Fire onAppear event on the overlay itself
                propagateEvent(
                    on: targetContainer.contentView,
                    eventName: "onAppear",
                    data: ["screenName": screenName]
                )
            }
        } else {
            overlayView.alpha = 1.0
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentOverlay",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )

            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenName]
            )
        }

        print("✅ DCFScreenComponent: Successfully presented overlay container for '\(screenName)'")
    }

    // 🎯 NEW: Native drawer presentation
    private func presentDrawerScreen(_ screenName: String, animated: Bool, params: [String: Any]?, direction: String?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing drawer presentation for '\(screenName)'")

        let drawerContextKey = createContextKey(screenName: screenName, presentationStyle: "drawer")

        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[drawerContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing drawer container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "drawer")
            DCFScreenComponent.screenRegistry[drawerContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new drawer container for '\(screenName)'")
        }

        // Use native side menu implementation
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("❌ DCFScreenComponent: No root view controller found for drawer")
            return
        }

        presentNativeDrawer(targetContainer, direction: direction ?? "left", animated: animated, from: rootViewController)

        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }

        propagateEvent(
            on: sourceContainer.contentView,
            eventName: "onNavigationEvent",
            data: [
                "action": "presentDrawer",
                "targetScreen": screenName,
                "animated": animated
            ]
        )

        print("✅ DCFScreenComponent: Successfully presented drawer container for '\(screenName)'")
    }

    private func presentSplitViewScreen(_ screenName: String, animated: Bool, params: [String: Any]?, from sourceContainer: ScreenContainer) {
        print("📱 DCFScreenComponent: Executing split view presentation for '\(screenName)'")

        let splitContextKey = createContextKey(screenName: screenName, presentationStyle: "splitView")

        let targetContainer: ScreenContainer
        if let existing = DCFScreenComponent.screenRegistry[splitContextKey] {
            targetContainer = existing
            print("♻️ DCFScreenComponent: Reusing existing split view container for '\(screenName)'")
        } else {
            targetContainer = ScreenContainer(name: screenName, presentationStyle: "splitView")
            DCFScreenComponent.screenRegistry[splitContextKey] = targetContainer
            print("✅ DCFScreenComponent: Created new split view container for '\(screenName)'")
        }

        guard let presentingViewController = getCurrentPresentingViewController() else {
            print("❌ DCFScreenComponent: No suitable presenting view controller found for split view")
            return
        }

        // Get split view configuration
        let splitConfig = objc_getAssociatedObject(
            targetContainer.viewController,
            UnsafeRawPointer(bitPattern: "splitViewConfig".hashValue)!
        ) as? [String: Any] ?? [:]

        let useThreePaneLayout = splitConfig["useThreePaneLayout"] as? Bool ?? false
        
        if useThreePaneLayout {
            presentThreePaneSplitView(screenName: screenName, targetContainer: targetContainer, splitConfig: splitConfig, presentingViewController: presentingViewController, animated: animated, params: params, sourceContainer: sourceContainer)
        } else {
            presentTwoPaneSplitView(screenName: screenName, targetContainer: targetContainer, splitConfig: splitConfig, presentingViewController: presentingViewController, animated: animated, params: params, sourceContainer: sourceContainer)
        }
    }

    // MARK: - 3-Pane Split View Implementation
    private func presentThreePaneSplitView(
        screenName: String,
        targetContainer: ScreenContainer,
        splitConfig: [String: Any],
        presentingViewController: UIViewController,
        animated: Bool,
        params: [String: Any]?,
        sourceContainer: ScreenContainer
    ) {
        print("🎯 Creating 3-pane split view: Sidebar | Content | Inspector")
        
        // Create containers for each pane
        let sidebarContainer = ScreenContainer(name: "\(screenName)_sidebar", presentationStyle: "splitView_sidebar")
        let inspectorContainer = ScreenContainer(name: "\(screenName)_inspector", presentationStyle: "splitView_inspector")
        
        // Register containers
        DCFScreenComponent.screenRegistry["\(screenName)_sidebar"] = sidebarContainer
        DCFScreenComponent.screenRegistry["\(screenName)_inspector"] = inspectorContainer
        
        // Create view controllers for each pane
        let sidebarVC = createSidebarViewController(container: sidebarContainer, config: splitConfig)
        let contentVC = createContentViewController(container: targetContainer)
        let inspectorVC = createInspectorViewController(container: inspectorContainer, config: splitConfig)
        
        // Wrap in navigation controllers
        let sidebarNavController = UINavigationController(rootViewController: sidebarVC)
        let contentNavController = UINavigationController(rootViewController: contentVC)
        let inspectorNavController = UINavigationController(rootViewController: inspectorVC)
        
        // 🎯 CREATE 3-PANE SPLIT VIEW CONTROLLER
        if #available(iOS 14.0, *) {
            // Use new 3-column split view controller
            let splitViewController = UISplitViewController(style: .tripleColumn)
            splitViewController.setViewController(sidebarNavController, for: .primary)
            splitViewController.setViewController(contentNavController, for: .secondary)
            splitViewController.setViewController(inspectorNavController, for: .supplementary)
            
            configureThreePaneSplitViewController(splitViewController, config: splitConfig)
            presentSplitViewController(splitViewController, from: presentingViewController, animated: animated, params: params, sourceContainer: sourceContainer, targetContainer: targetContainer, screenName: screenName)
            
        } else {
            // Fallback for iOS 13 and below - create nested split views
            let primarySplitVC = UISplitViewController()
            primarySplitVC.viewControllers = [sidebarNavController, contentNavController]
            primarySplitVC.preferredDisplayMode = .oneBesideSecondary
            
            let secondarySplitVC = UISplitViewController()
            secondarySplitVC.viewControllers = [primarySplitVC, inspectorNavController]
            secondarySplitVC.preferredDisplayMode = .oneBesideSecondary
            
            configureLegacyThreePaneSplitViewController(secondarySplitVC, config: splitConfig)
            presentSplitViewController(secondarySplitVC, from: presentingViewController, animated: animated, params: params, sourceContainer: sourceContainer, targetContainer: targetContainer, screenName: screenName)
        }
        
        // Store references for later use
        objc_setAssociatedObject(targetContainer.viewController, UnsafeRawPointer(bitPattern: "sidebarContainer".hashValue)!, sidebarContainer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(targetContainer.viewController, UnsafeRawPointer(bitPattern: "inspectorContainer".hashValue)!, inspectorContainer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - 2-Pane Split View Implementation
    private func presentTwoPaneSplitView(
        screenName: String,
        targetContainer: ScreenContainer,
        splitConfig: [String: Any],
        presentingViewController: UIViewController,
        animated: Bool,
        params: [String: Any]?,
        sourceContainer: ScreenContainer
    ) {
        print("🎯 Creating 2-pane split view: Master | Detail")
        
        // Create master container
        let masterContainer = ScreenContainer(name: "\(screenName)_master", presentationStyle: "splitView_master")
        DCFScreenComponent.screenRegistry["\(screenName)_master"] = masterContainer
        
        // Create view controllers
        let masterVC = createMasterViewController(container: masterContainer, config: splitConfig)
        let detailVC = createContentViewController(container: targetContainer)
        
        // Wrap in navigation controllers
        let masterNavController = UINavigationController(rootViewController: masterVC)
        let detailNavController = UINavigationController(rootViewController: detailVC)
        
        // Create split view controller
        let splitViewController = UISplitViewController()
        splitViewController.viewControllers = [masterNavController, detailNavController]
        
        configureTwoPaneSplitViewController(splitViewController, config: splitConfig)
        presentSplitViewController(splitViewController, from: presentingViewController, animated: animated, params: params, sourceContainer: sourceContainer, targetContainer: targetContainer, screenName: screenName)
        
        // Store reference
        objc_setAssociatedObject(targetContainer.viewController, UnsafeRawPointer(bitPattern: "masterContainer".hashValue)!, masterContainer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - View Controller Creation Methods

    private func createSidebarViewController(container: ScreenContainer, config: [String: Any]) -> UIViewController {
        let sidebarVC = UIViewController()
        sidebarVC.title = config["sidebarTitle"] as? String ?? "Sidebar"
        sidebarVC.view.backgroundColor = UIColor.systemGroupedBackground
        
        setupContainerView(container: container, parentView: sidebarVC.view)
        return sidebarVC
    }

    private func createContentViewController(container: ScreenContainer) -> UIViewController {
        let contentVC = UIViewController()
        contentVC.title = container.name
        contentVC.view.backgroundColor = UIColor.systemBackground
        
        setupContainerView(container: container, parentView: contentVC.view)
        return contentVC
    }

    private func createInspectorViewController(container: ScreenContainer, config: [String: Any]) -> UIViewController {
        let inspectorVC = UIViewController()
        inspectorVC.title = config["inspectorTitle"] as? String ?? "Inspector"
        inspectorVC.view.backgroundColor = UIColor.systemGroupedBackground
        
        setupContainerView(container: container, parentView: inspectorVC.view)
        return inspectorVC
    }

    private func createMasterViewController(container: ScreenContainer, config: [String: Any]) -> UIViewController {
        let masterVC = UIViewController()
        masterVC.title = config["sidebarTitle"] as? String ?? "Master"
        masterVC.view.backgroundColor = UIColor.systemGroupedBackground
        
        setupContainerView(container: container, parentView: masterVC.view)
        return masterVC
    }

    private func setupContainerView(container: ScreenContainer, parentView: UIView) {
        container.contentView.isHidden = false
        container.contentView.alpha = 1.0
        container.contentView.frame = parentView.bounds
        container.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.contentView.backgroundColor = UIColor.clear
        parentView.addSubview(container.contentView)
    }

    // MARK: - Split View Configuration Methods

    @available(iOS 14.0, *)
    private func configureThreePaneSplitViewController(_ splitViewController: UISplitViewController, config: [String: Any]) {
        // Configure display mode
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        
        // Configure column widths
        if let primaryWidth = config["primaryColumnWidth"] as? CGFloat {
            splitViewController.preferredPrimaryColumnWidth = primaryWidth
        }
        
        if let supplementaryWidth = config["supplementaryColumnWidth"] as? CGFloat {
            splitViewController.preferredSupplementaryColumnWidth = supplementaryWidth
        }
        
        // Configure behavior (with version check)
        splitViewController.primaryBackgroundStyle = .sidebar
        
        // Only set displayModeButtonVisibility if available (iOS 14.5+)
        if #available(iOS 14.5, *) {
            splitViewController.displayModeButtonVisibility = .automatic
        }
        
        print("✅ Configured 3-pane split view")
    }

    private func configureLegacyThreePaneSplitViewController(_ splitViewController: UISplitViewController, config: [String: Any]) {
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        
        if let supplementaryWidth = config["supplementaryColumnWidth"] as? CGFloat {
            splitViewController.preferredPrimaryColumnWidthFraction = supplementaryWidth / UIScreen.main.bounds.width
        }
        
        print("✅ Configured legacy 3-pane split view")
    }

    private func configureTwoPaneSplitViewController(_ splitViewController: UISplitViewController, config: [String: Any]) {
        // Apply display mode
        if let displayMode = config["displayMode"] as? String {
            switch displayMode.lowercased() {
            case "automatic":
                splitViewController.preferredDisplayMode = .automatic
            case "secondaryonly":
                splitViewController.preferredDisplayMode = .secondaryOnly
            case "onebesidesecondary":
                splitViewController.preferredDisplayMode = .oneBesideSecondary
            case "primaryoverlay":
                splitViewController.preferredDisplayMode = .primaryOverlay
            case "primaryhidden":
                splitViewController.preferredDisplayMode = .primaryHidden
            default:
                splitViewController.preferredDisplayMode = .oneBesideSecondary
            }
        }

        // Apply primary column width
        if let primaryColumnWidth = config["primaryColumnWidth"] as? CGFloat {
            if #available(iOS 14.0, *) {
                splitViewController.preferredPrimaryColumnWidth = primaryColumnWidth
            } else {
                splitViewController.preferredPrimaryColumnWidthFraction = primaryColumnWidth / UIScreen.main.bounds.width
            }
        }
        
        print("✅ Configured 2-pane split view")
    }

    // MARK: - Common Presentation Method
    private func presentSplitViewController(
        _ splitViewController: UISplitViewController,
        from presentingViewController: UIViewController,
        animated: Bool,
        params: [String: Any]?,
        sourceContainer: ScreenContainer,
        targetContainer: ScreenContainer,
        screenName: String
    ) {
        if let params = params {
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onReceiveParams",
                data: ["params": params, "source": sourceContainer.name]
            )
        }

        presentingViewController.present(splitViewController, animated: animated) {
            propagateEvent(
                on: sourceContainer.contentView,
                eventName: "onNavigationEvent",
                data: [
                    "action": "presentSplitView",
                    "targetScreen": screenName,
                    "animated": animated
                ]
            )
            
            propagateEvent(
                on: targetContainer.contentView,
                eventName: "onAppear",
                data: ["screenName": screenName]
            )
        }

        print("✅ Successfully presented split view for '\(screenName)'")
    }

    // MARK: - Enhanced setChildren for Split View Support
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        guard let screenContainer = findScreenContainer(for: view) else {
            print("❌ DCFScreenComponent: Could not find screen container for setChildren")
            return false
        }

        // Handle special split view containers
        if screenContainer.name.hasSuffix("_sidebar") {
            print("🏠 Setting sidebar children for '\(screenContainer.name)'")
            return setSplitViewChildren(screenContainer, childViews: childViews, type: "sidebar")
        } else if screenContainer.name.hasSuffix("_inspector") {
            print("🔍 Setting inspector children for '\(screenContainer.name)'")
            return setSplitViewChildren(screenContainer, childViews: childViews, type: "inspector")
        } else if screenContainer.name.hasSuffix("_master") {
            print("🎯 Setting master children for '\(screenContainer.name)'")
            return setSplitViewChildren(screenContainer, childViews: childViews, type: "master")
        }

        // Handle regular content
        print("📱 Setting \(childViews.count) children for screen '\(screenContainer.name)'")
        
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
        
        return true
    }

    private func setSplitViewChildren(_ container: ScreenContainer, childViews: [UIView], type: String) -> Bool {
        print("🎯 Setting \(childViews.count) \(type) children")
        
        container.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        for childView in childViews {
            container.contentView.addSubview(childView)
            childView.frame = container.contentView.bounds
            childView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            childView.isHidden = false
            childView.alpha = 1.0
        }
        
        container.contentView.setNeedsLayout()
        container.contentView.layoutIfNeeded()
        
        return true
    }

                        private func switchToTabScreen(_ screenName: String, params: [String: Any]?, from sourceContainer: ScreenContainer, animated: Bool) {
                            let tabContextKey = "tab_\(screenName)"
                            guard let tabContainer = DCFScreenComponent.screenRegistry[tabContextKey] else {
                                print("❌ DCFScreenComponent: Tab screen '\(screenName)' not found")
                                return
                            }

                            guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController else {
                                print("❌ DCFScreenComponent: No tab bar controller found")
                                return
                            }

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

                            tabBarController.selectedIndex = foundTabIndex

                            if let params = params {
                                propagateEvent(
                                    on: tabContainer.contentView,
                                    eventName: "onReceiveParams",
                                    data: ["params": params, "source": sourceContainer.name]
                                )
                            }

                            propagateEvent(
                                on: sourceContainer.contentView,
                                eventName: "onNavigationEvent",
                                data: [
                                    "action": "switchToTab",
                                    "targetScreen": screenName,
                                    "animated": animated
                                ]
                            )

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

                        // MARK: - Configuration Methods

                        private func configureOverlayView(_ overlayView: UIView, for screenContainer: ScreenContainer) {
                            guard let overlayConfig = objc_getAssociatedObject(
                                screenContainer.viewController,
                                UnsafeRawPointer(bitPattern: "overlayConfig".hashValue)!
                            ) as? [String: Any] else {
                                // Default overlay configuration
                                overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                                return
                            }

                            // Apply background color
                            if let backgroundColorString = overlayConfig["overlayBackgroundColor"] as? String {
                                if let color = ColorUtilities.color(fromHexString: backgroundColorString) {
                                    overlayView.backgroundColor = color
                                }
                            } else {
                                overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                            }

                            // Apply dismiss on tap
                            let dismissOnTap = overlayConfig["dismissOnTap"] as? Bool ?? true
                            if dismissOnTap {
                                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayBackgroundTapped(_:)))
                                overlayView.addGestureRecognizer(tapGesture)

                                // Store reference to container for dismissal
                                objc_setAssociatedObject(
                                    tapGesture,
                                    UnsafeRawPointer(bitPattern: "screenContainer".hashValue)!,
                                    screenContainer,
                                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                                )
                            }

                            // Apply interaction blocking
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
                                // Default popover configuration
                                popoverController.sourceView = presentingViewController.view
                                popoverController.sourceRect = CGRect(x: presentingViewController.view.bounds.midX, y: presentingViewController.view.bounds.midY, width: 0, height: 0)
                                popoverController.permittedArrowDirections = .any
                                return
                            }

                            // Apply preferred size
                            if let width = popoverConfig["preferredWidth"] as? CGFloat,
                               let height = popoverConfig["preferredHeight"] as? CGFloat {
                                screenContainer.viewController.preferredContentSize = CGSize(width: width, height: height)
                            }

                            // Apply arrow directions
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

                            // Default source view if not specified
                            popoverController.sourceView = presentingViewController.view
                            popoverController.sourceRect = CGRect(x: presentingViewController.view.bounds.midX, y: presentingViewController.view.bounds.midY, width: 0, height: 0)
                        }

                        @available(iOS 15.0, *)
                        private func configureSheetDetents(sheet: UISheetPresentationController, for screenContainer: ScreenContainer) {
                            guard let sheetConfig = objc_getAssociatedObject(
                                screenContainer.viewController,
                                UnsafeRawPointer(bitPattern: "sheetConfig".hashValue)!
                            ) as? [String: Any] else {
                                // Default sheet configuration
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

                        private func presentNativeDrawer(_ drawerContainer: ScreenContainer, direction: String, animated: Bool, from presentingViewController: UIViewController) {
                            let drawerView = drawerContainer.contentView
                            drawerView.backgroundColor = UIColor.systemBackground

                            // Calculate drawer frame based on direction
                            let screenBounds = presentingViewController.view.bounds
                            var drawerFrame: CGRect
                            let drawerWidth: CGFloat = 280 // Default drawer width

                            switch direction.lowercased() {
                            case "left":
                                drawerFrame = CGRect(x: -drawerWidth, y: 0, width: drawerWidth, height: screenBounds.height)
                            case "right":
                                drawerFrame = CGRect(x: screenBounds.width, y: 0, width: drawerWidth, height: screenBounds.height)
                            case "top":
                                drawerFrame = CGRect(x: 0, y: -screenBounds.height * 0.6, width: screenBounds.width, height: screenBounds.height * 0.6)
                            case "bottom":
                                drawerFrame = CGRect(x: 0, y: screenBounds.height, width: screenBounds.width, height: screenBounds.height * 0.6)
                            default:
                                drawerFrame = CGRect(x: -drawerWidth, y: 0, width: drawerWidth, height: screenBounds.height)
                            }

                            drawerView.frame = drawerFrame
                            presentingViewController.view.addSubview(drawerView)

                            // Animate drawer in
                            var finalFrame = drawerFrame
                            switch direction.lowercased() {
                            case "left":
                                finalFrame.origin.x = 0
                            case "right":
                                finalFrame.origin.x = screenBounds.width - drawerWidth
                            case "top":
                                finalFrame.origin.y = 0
                            case "bottom":
                                finalFrame.origin.y = screenBounds.height - finalFrame.height
                            default:
                                finalFrame.origin.x = 0
                            }

                            if animated {
                                UIView.animate(withDuration: 0.3) {
                                    drawerView.frame = finalFrame
                                }
                            } else {
                                drawerView.frame = finalFrame
                            }
                        }

                        // MARK: - Standard Navigation Commands

                        private func handleStandardNavigationCommands(commandData: [String: Any], from sourceContainer: ScreenContainer) {
                            if let popData = commandData["pop"] as? [String: Any] {
                                let animated = popData["animated"] as? Bool ?? true
                                let result = popData["result"] as? [String: Any]
                                popCurrentScreen(animated: animated, result: result, from: sourceContainer)
                            }

                            if let popToData = commandData["popTo"] as? [String: Any] {
                                if let targetScreenName = popToData["screenName"] as? String {
                                    let animated = popToData["animated"] as? Bool ?? true
                                    popToScreen(targetScreenName, animated: animated, from: sourceContainer)
                                }
                            }

                            if let popToRootData = commandData["popToRoot"] as? [String: Any] {
                                let animated = popToRootData["animated"] as? Bool ?? true
                                popToRootScreen(animated: animated, from: sourceContainer)
                            }

                            if let replaceData = commandData["replaceWith"] as? [String: Any] {
                                if let targetScreenName = replaceData["screenName"] as? String {
                                    let animated = replaceData["animated"] as? Bool ?? true
                                    let params = replaceData["params"] as? [String: Any]
                                    replaceCurrentScreen(with: targetScreenName, animated: animated, params: params, from: sourceContainer)
                                }
                            }

                            if let dismissData = commandData["dismissModal"] as? [String: Any] {
                                let animated = dismissData["animated"] as? Bool ?? true
                                let result = dismissData["result"] as? [String: Any]
                                dismissModalScreen(animated: animated, result: result, from: sourceContainer)
                            }

                            if let dismissSheetData = commandData["dismissSheet"] as? [String: Any] {
                                let animated = dismissSheetData["animated"] as? Bool ?? true
                                let result = dismissSheetData["result"] as? [String: Any]
                                dismissSheetScreen(animated: animated, result: result, from: sourceContainer)
                            }

                            if let dismissPopoverData = commandData["dismissPopover"] as? [String: Any] {
                                let animated = dismissPopoverData["animated"] as? Bool ?? true
                                let result = dismissPopoverData["result"] as? [String: Any]
                                dismissPopoverScreen(animated: animated, result: result, from: sourceContainer)
                            }

                            if let dismissOverlayData = commandData["dismissOverlay"] as? [String: Any] {
                                let animated = dismissOverlayData["animated"] as? Bool ?? true
                                let result = dismissOverlayData["result"] as? [String: Any]
                                dismissOverlayScreen(animated: animated, result: result, from: sourceContainer)
                            }

                            if let dismissDrawerData = commandData["dismissDrawer"] as? [String: Any] {
                                let animated = dismissDrawerData["animated"] as? Bool ?? true
                                let result = dismissDrawerData["result"] as? [String: Any]
                                dismissDrawerScreen(animated: animated, result: result, from: sourceContainer)
                            }
                        }

                        // MARK: - Dismiss Methods

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

                            let replaceContextKey = createContextKey(screenName: screenName, presentationStyle: "push")
                            let targetContainer: ScreenContainer
                            if let existing = DCFScreenComponent.screenRegistry[replaceContextKey] {
                                targetContainer = existing
                            } else {
                                targetContainer = ScreenContainer(name: screenName, presentationStyle: "push")
                                DCFScreenComponent.screenRegistry[replaceContextKey] = targetContainer
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

                        private func dismissSheetScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
                            if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
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
                                        "action": "dismissSheet",
                                        "animated": animated
                                    ]
                                )
                            }

                            print("✅ DCFScreenComponent: Dismissed sheet '\(sourceContainer.name)'")
                        }

                        private func dismissPopoverScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
                            if let result = result, let presentingViewController = sourceContainer.viewController.presentingViewController {
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
                                        "action": "dismissPopover",
                                        "animated": animated
                                    ]
                                )
                            }

                            print("✅ DCFScreenComponent: Dismissed popover '\(sourceContainer.name)'")
                        }

                        private func dismissOverlayScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
                            if let result = result {
                                // Find the parent container that presented this overlay
                                for (_, container) in DCFScreenComponent.screenRegistry {
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

                        private func dismissDrawerScreen(animated: Bool, result: [String: Any]?, from sourceContainer: ScreenContainer) {
                            if let result = result {
                                for (_, container) in DCFScreenComponent.screenRegistry {
                                    if container.presentationStyle != "drawer" {
                                        propagateEvent(
                                            on: container.contentView,
                                            eventName: "onReceiveParams",
                                            data: ["result": result, "source": sourceContainer.name]
                                        )
                                        break
                                    }
                                }
                            }

                            let drawerView = sourceContainer.contentView
                            let currentFrame = drawerView.frame
                            var dismissFrame = currentFrame

                            // Determine dismiss direction based on current position
                            if currentFrame.origin.x <= 10 {
                                // Left drawer
                                dismissFrame.origin.x = -currentFrame.width
                            } else if currentFrame.origin.x >= drawerView.superview!.bounds.width - currentFrame.width - 10 {
                                // Right drawer
                                dismissFrame.origin.x = drawerView.superview!.bounds.width
                            } else if currentFrame.origin.y <= 10 {
                                // Top drawer
                                dismissFrame.origin.y = -currentFrame.height
                            } else {
                                // Bottom drawer
                                dismissFrame.origin.y = drawerView.superview!.bounds.height
                            }

                            if animated {
                                UIView.animate(withDuration: 0.3, animations: {
                                    drawerView.frame = dismissFrame
                                }) { _ in
                                    drawerView.removeFromSuperview()
                                    propagateEvent(
                                        on: sourceContainer.contentView,
                                        eventName: "onNavigationEvent",
                                        data: [
                                            "action": "dismissDrawer",
                                            "animated": animated
                                        ]
                                    )
                                }
                            } else {
                                drawerView.removeFromSuperview()
                                propagateEvent(
                                    on: sourceContainer.contentView,
                                    eventName: "onNavigationEvent",
                                    data: [
                                        "action": "dismissDrawer",
                                        "animated": animated
                                    ]
                                )
                            }

                            print("✅ DCFScreenComponent: Dismissed drawer '\(sourceContainer.name)'")
                        }

                        // MARK: - Helper Methods

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
                        // MARK: - Configuration Storage Methods

                        private func storeTabConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
                            var tabConfig: [String: Any] = [:]

                            if let tabConfigData = props["tabConfig"] as? [String: Any] {
                                tabConfig = tabConfigData
                            } else {
                                // 🎯 FIXED: Properly extract tab config from individual props
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
                                        // Extract modal config from individual props
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

                                    // Extract popover config from props
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

                                    // Extract overlay config from props
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

                                    // Extract sheet config from props
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

                                private func storeDrawerConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
                                    var drawerConfig: [String: Any] = [:]

                                    // Extract drawer config from props
                                    if let direction = props["direction"] as? String {
                                        drawerConfig["direction"] = direction
                                    }

                                    if let width = props["drawerWidth"] as? CGFloat {
                                        drawerConfig["drawerWidth"] = width
                                    }

                                    if let height = props["drawerHeight"] as? CGFloat {
                                        drawerConfig["drawerHeight"] = height
                                    }

                                    if !drawerConfig.isEmpty {
                                        objc_setAssociatedObject(
                                            screenContainer.viewController,
                                            UnsafeRawPointer(bitPattern: "drawerConfig".hashValue)!,
                                            drawerConfig,
                                            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                                        )
                                    }
                                }

                                private func storeSplitViewConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
                                    var splitViewConfig: [String: Any] = [:]

                                    // Extract split view config from props
                                    if let displayMode = props["displayMode"] as? String {
                                        splitViewConfig["displayMode"] = displayMode
                                    }

                                    if let primaryColumnWidth = props["primaryColumnWidth"] as? CGFloat {
                                        splitViewConfig["primaryColumnWidth"] = primaryColumnWidth
                                    }

                                    if !splitViewConfig.isEmpty {
                                        objc_setAssociatedObject(
                                            screenContainer.viewController,
                                            UnsafeRawPointer(bitPattern: "splitViewConfig".hashValue)!,
                                            splitViewConfig,
                                            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                                        )
                                    }
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
                                    case "drawer":
                                        configureDrawerScreen(screenContainer, props: props)
                                    case "splitView":
                                        configureSplitViewScreen(screenContainer, props: props)
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

                                    // Sheet-specific configuration will be applied during presentation
                                }

                                private func configurePopoverScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
                                    let viewController = screenContainer.viewController

                                    if let title = props["title"] as? String {
                                        viewController.navigationItem.title = title
                                    }

                                    // Set preferred content size for popover
                                    if let width = props["preferredWidth"] as? CGFloat,
                                       let height = props["preferredHeight"] as? CGFloat {
                                        viewController.preferredContentSize = CGSize(width: width, height: height)
                                    } else {
                                        viewController.preferredContentSize = CGSize(width: 320, height: 480) // Default size
                                    }
                                }

                                private func configureOverlayScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
                                    let viewController = screenContainer.viewController

                                    if let title = props["title"] as? String {
                                        viewController.navigationItem.title = title
                                    }

                                    // Overlay-specific configuration will be applied during presentation
                                }

                                private func configureDrawerScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
                                    let viewController = screenContainer.viewController

                                    if let title = props["title"] as? String {
                                        viewController.navigationItem.title = title
                                    }

                                    // Drawer-specific configuration will be applied during presentation
                                }

                                private func configureSplitViewScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
                                    let viewController = screenContainer.viewController

                                    if let title = props["title"] as? String {
                                        viewController.navigationItem.title = title
                                    }

                                    // Split view-specific configuration will be applied during presentation
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
                                    let tabKey = "tab_\(name)"
                                    if let tabContainer = screenRegistry[tabKey] {
                                        return tabContainer
                                    }

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

                            // 🎯 NAVIGATION METHOD ENUM: All possible navigation methods
                            enum NavigationMethod: String, CaseIterable {
                                case push = "push"
                                case modal = "modal"
                                case sheet = "sheet"
                                case popover = "popover"
                                case overlay = "overlay"
                                case drawer = "drawer"
                                case splitView = "splitView"
                                case switchTab = "switchTab"

                                var description: String {
                                    return self.rawValue
                                }
                            }

                            // 🎯 SCREEN CONTAINER: Clean implementation
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
                                // 🎯 Registry to track each screen's intended presentation style
                                static var screenPresentationRegistry: [String: String] = [:]
                                static var currentNavigationController: UINavigationController? = nil

                                static func startPeriodicCleanup() {
                                    Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                                        cleanupUnusedContainers()
                                    }
                                }

                                // 🎯 DEBUG: Helper to see what's registered
                                static func printRegisteredScreens() {
                                    print("🎯 DCFScreenComponent: Registered screens:")
                                    for (screenName, presentationStyle) in screenPresentationRegistry {
                                        print("  - \(screenName): \(presentationStyle)")
                                    }
                                }
                            }



