/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/// Tab navigator component that creates and manages UITabBarController
class DCFTabNavigatorComponent: NSObject, DCFComponent {
    
    // Registry of active tab bar controllers
    static var tabNavigatorRegistry: [String: UITabBarController] = [:]
    
    // Track navigator state
    static var navigatorState: [String: TabNavigatorState] = [:]
    
    // CRITICAL FIX: Map navigatorId to placeholder view for event propagation
    static var placeholderViewRegistry: [String: UIView] = [:]
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let navigatorId = String(Date().timeIntervalSince1970)
        
        print("🔧 DCFTabNavigatorComponent: Creating tab navigator '\(navigatorId)'")
        
        // Create tab bar controller
        let tabBarController = createTabBarController(props: props)
        
        // Store in registry
        DCFTabNavigatorComponent.tabNavigatorRegistry[navigatorId] = tabBarController
        DCFTabNavigatorComponent.navigatorState[navigatorId] = TabNavigatorState(
            screens: props["screens"] as? [String] ?? [],
            selectedIndex: props["selectedIndex"] as? Int ?? 0
        )
        
        // Configure tab bar controller with screen containers
        configureTabBarController(tabBarController, props: props, navigatorId: navigatorId)
        
        // Install as root view controller or present
        replaceRoot(controller: tabBarController)
        
        // Create placeholder view for DCFlight to track
        let placeholderView = UIView()
        placeholderView.isHidden = true
        placeholderView.backgroundColor = UIColor.clear
        
        // Associate tab bar controller with placeholder
        objc_setAssociatedObject(
            placeholderView,
            UnsafeRawPointer(bitPattern: "tabBarController".hashValue)!,
            tabBarController,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        objc_setAssociatedObject(
            placeholderView,
            UnsafeRawPointer(bitPattern: "navigatorId".hashValue)!,
            navigatorId,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // CRITICAL FIX: Store placeholder view in registry for event propagation
        DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] = placeholderView
        
        // CRITICAL FIX: Manually set up event system like VDOM does
        setupEventSystemForView(placeholderView, props: props, viewId: navigatorId)
        
        return placeholderView
    }
    
    /// Manually set up the event system for a view (like VDOM does)
    private func setupEventSystemForView(_ view: UIView, props: [String: Any], viewId: String) {
        // CRITICAL FIX: Extract event types from _eventType_ prefixed props (DCFlight format)
        let eventTypes = props.keys.compactMap { key -> String? in
            if key.hasPrefix("_eventType_") {
                // Convert "_eventType_onTabChange" to "onTabChange"
                return String(key.dropFirst("_eventType_".count))
            }
            return nil
        }
        
        print("🔧 DCFTabNavigatorComponent: Found props keys: \(Array(props.keys))")
        print("🔧 DCFTabNavigatorComponent: Extracted event types for '\(viewId)': \(eventTypes)")
        
        if !eventTypes.isEmpty {
            print("🔧 DCFTabNavigatorComponent: Setting up event system for '\(viewId)' with events: \(eventTypes)")
            
            // Store viewId on the view (required for propagateEvent)
            objc_setAssociatedObject(
                view,
                UnsafeRawPointer(bitPattern: "viewId".hashValue)!,
                viewId,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            
            // Store event types on the view (required for propagateEvent)
            objc_setAssociatedObject(
                view,
                UnsafeRawPointer(bitPattern: "eventTypes".hashValue)!,
                eventTypes,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            
            // FIXED: Use the global propagateEvent system instead of DCMauiEventMethodHandler
            // Store the event callback for the global system to use (same pattern as other components)
            let eventCallback: (String, String, [String: Any]) -> Void = { (viewId, eventType, eventData) in
                // The propagateEvent function will handle sending to Dart automatically
                // No need to manually call DCMauiEventMethodHandler here
                print("✅ DCFTabNavigatorComponent: Event '\(eventType)' fired on view '\(viewId)' with data: \(eventData)")
            }
            
            objc_setAssociatedObject(
                view,
                UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!,
                eventCallback,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            
            print("✅ DCFTabNavigatorComponent: Event system set up for '\(viewId)' with viewId and \(eventTypes.count) event types")
        } else {
            print("⚠️ DCFTabNavigatorComponent: No event types found for '\(viewId)' in props: \(Array(props.keys))")
        }
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let navigatorId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "navigatorId".hashValue)!) as? String,
              let tabBarController = DCFTabNavigatorComponent.tabNavigatorRegistry[navigatorId] else {
            print("❌ DCFTabNavigatorComponent: Tab bar controller not found for update")
            return false
        }
        
        // CRITICAL FIX: Re-setup event system on every update in case events changed
        setupEventSystemForView(view, props: props, viewId: navigatorId)
        
        // Update selected tab
        if let selectedIndex = props["selectedIndex"] as? Int {
            updateSelectedTab(tabBarController, selectedIndex: selectedIndex, navigatorId: navigatorId, view: view)
        }
        
        // Update tab bar style
        updateTabBarStyle(tabBarController, props: props)
        
        // Update visibility
        let isHidden = props["isHidden"] as? Bool ?? false
        tabBarController.tabBar.isHidden = isHidden
        
        return true
    }
    
    // MARK: - Tab Bar Controller Creation
    
    private func createTabBarController(props: [String: Any]) -> UITabBarController {
        let tabBarController = UITabBarController()
        
        // Configure tab bar appearance
        configureTabBarAppearance(tabBarController, props: props)
        
        return tabBarController
    }
    
    private func configureTabBarController(_ tabBarController: UITabBarController, props: [String: Any], navigatorId: String) {
        guard let screens = props["screens"] as? [String] else {
            print("❌ DCFTabNavigatorComponent: No screens provided")
            return
        }
        
        print("📱 DCFTabNavigatorComponent: Configuring tab bar with \(screens.count) screens")
        
        var viewControllers: [UIViewController] = []
        
        for (index, screenName) in screens.enumerated() {
            if let screenContainer = DCFScreenComponent.getScreenContainer(name: screenName) {
                // Wrap screen view controller in navigation controller for consistency
                let navController = UINavigationController(rootViewController: screenContainer.viewController)
                
                // Configure tab bar item from screen properties
                configureTabBarItem(navController, screenContainer: screenContainer, index: index)
                
                viewControllers.append(navController)
                print("  ✅ Added screen '\(screenName)' to tab \(index)")
            } else {
                print("  ❌ Screen container not found for '\(screenName)'")
                
                // Create placeholder view controller for missing screen
                let placeholderVC = UIViewController()
                placeholderVC.view.backgroundColor = UIColor.systemBackground
                placeholderVC.title = "Screen \(index)"
                placeholderVC.tabBarItem = UITabBarItem(title: "Tab \(index)", image: UIImage(systemName: "circle"), tag: index)
                
                let navController = UINavigationController(rootViewController: placeholderVC)
                viewControllers.append(navController)
            }
        }
        
        tabBarController.viewControllers = viewControllers
        
        // Set initial selected index
        let selectedIndex = props["selectedIndex"] as? Int ?? 0
        if selectedIndex >= 0 && selectedIndex < viewControllers.count {
            tabBarController.selectedIndex = selectedIndex
        }
        
        // CRITICAL FIX: Set delegate with proper reference to navigatorId
        let delegate = TabBarControllerDelegate(navigatorId: navigatorId)
        tabBarController.delegate = delegate
        
        // CRITICAL FIX: Store delegate to prevent deallocation
        objc_setAssociatedObject(
            tabBarController,
            UnsafeRawPointer(bitPattern: "tabBarDelegate".hashValue)!,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // CRITICAL FIX: Fire initial onAppear event
        DispatchQueue.main.async {
            if let placeholderView = DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] {
                propagateEvent(
                    on: placeholderView,
                    eventName: "onAppear",
                    data: [
                        "navigatorId": navigatorId,
                        "selectedIndex": selectedIndex
                    ]
                )
            }
            
            // CRITICAL FIX: Trigger initial screen activation for the selected tab
            if let screens = DCFTabNavigatorComponent.navigatorState[navigatorId]?.screens,
               selectedIndex < screens.count {
                let initialScreenName = screens[selectedIndex]
                if let screenContainer = DCFScreenComponent.getScreenContainer(name: initialScreenName) {
                    screenContainer.isActive = true
                    propagateEvent(
                        on: screenContainer.contentView,
                        eventName: "onAppear",
                        data: ["screenName": initialScreenName]
                    )
                    propagateEvent(
                        on: screenContainer.contentView,
                        eventName: "onActivate",
                        data: ["screenName": initialScreenName]
                    )
                    print("✅ Initially activated screen: \(initialScreenName)")
                }
            }
        }
    }
    
    private func configureTabBarItem(_ viewController: UIViewController, screenContainer: ScreenContainer, index: Int) {
        // Tab bar item should already be configured by DCFScreenComponent
        // This is a fallback configuration
        if viewController.tabBarItem.title == nil {
            viewController.tabBarItem.title = "Tab \(index)"
        }
        
        if viewController.tabBarItem.image == nil {
            viewController.tabBarItem.image = UIImage(systemName: "circle")
        }
        
        viewController.tabBarItem.tag = index
    }
    
    private func configureTabBarAppearance(_ tabBarController: UITabBarController, props: [String: Any]) {
        let tabBar = tabBarController.tabBar
        
        // Background color
        if let backgroundColorString = props["backgroundColor"] as? String {
            tabBar.backgroundColor = ColorUtilities.color(fromHexString: backgroundColorString)
        }
        
        // Tint colors
        if let selectedTintColorString = props["selectedTintColor"] as? String {
            tabBar.tintColor = ColorUtilities.color(fromHexString: selectedTintColorString)
        }
        
        if let unselectedTintColorString = props["unselectedTintColor"] as? String {
            tabBar.unselectedItemTintColor = ColorUtilities.color(fromHexString: unselectedTintColorString)
        }
        
        // Translucency
        let translucent = props["translucent"] as? Bool ?? true
        tabBar.isTranslucent = translucent
        
        // Position (only bottom is supported on iOS for UITabBarController)
        let position = props["position"] as? String ?? "bottom"
        if position != "bottom" {
            print("⚠️ DCFTabNavigatorComponent: Only 'bottom' position is supported for tab bar on iOS")
        }
        
        // Show/hide labels and icons
        let showLabels = props["showLabels"] as? Bool ?? true
        let showIcons = props["showIcons"] as? Bool ?? true
        
        if !showLabels || !showIcons {
            // Configure tab bar items to hide labels or icons
            for item in tabBar.items ?? [] {
                if !showLabels {
                    item.title = nil
                }
                if !showIcons {
                    item.image = nil
                    item.selectedImage = nil
                }
            }
        }
    }
    
    // MARK: - Tab Updates
    
    private func updateSelectedTab(_ tabBarController: UITabBarController, selectedIndex: Int, navigatorId: String, view: UIView) {
        guard selectedIndex >= 0 && selectedIndex < (tabBarController.viewControllers?.count ?? 0) else {
            print("❌ DCFTabNavigatorComponent: Invalid selected index \(selectedIndex)")
            return
        }
        
        let previousIndex = tabBarController.selectedIndex
        if previousIndex != selectedIndex {
            print("🔄 DCFTabNavigatorComponent: Changing tab from \(previousIndex) to \(selectedIndex)")
            
            tabBarController.selectedIndex = selectedIndex
            
            // Update navigator state
            DCFTabNavigatorComponent.navigatorState[navigatorId]?.selectedIndex = selectedIndex
            
            // CRITICAL FIX: Fire tab change event on the correct view using propagateEvent
            propagateEvent(
                on: view,
                eventName: "onTabChange",
                data: [
                    "selectedIndex": selectedIndex,
                    "previousIndex": previousIndex,
                    "programmatic": true
                ]
            )
        }
    }
    
    private func updateTabBarStyle(_ tabBarController: UITabBarController, props: [String: Any]) {
        configureTabBarAppearance(tabBarController, props: props)
    }
    
    // MARK: - Helper Classes
    
    /// State tracking for tab navigator
    class TabNavigatorState {
        var screens: [String]
        var selectedIndex: Int
        
        init(screens: [String], selectedIndex: Int) {
            self.screens = screens
            self.selectedIndex = selectedIndex
        }
    }
    
    /// Delegate to handle tab bar controller events
    class TabBarControllerDelegate: NSObject, UITabBarControllerDelegate {
        let navigatorId: String
        
        init(navigatorId: String) {
            self.navigatorId = navigatorId
            super.init()
        }
        
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let selectedIndex = tabBarController.selectedIndex
            
            print("📱 TabBarControllerDelegate: User selected tab \(selectedIndex)")
            
            // Update navigator state
            DCFTabNavigatorComponent.navigatorState[navigatorId]?.selectedIndex = selectedIndex
            
            // CRITICAL FIX: Trigger screen lifecycle events when tabs change
            if let screens = DCFTabNavigatorComponent.navigatorState[navigatorId]?.screens {
                // Fire onDisappear/onDeactivate for all other screens
                for (index, screenName) in screens.enumerated() {
                    if let screenContainer = DCFScreenComponent.getScreenContainer(name: screenName) {
                        if index == selectedIndex {
                            // Activate the selected screen
                            screenContainer.isActive = true
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onAppear",
                                data: ["screenName": screenName]
                            )
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onActivate",
                                data: ["screenName": screenName]
                            )
                            print("✅ Activated screen: \(screenName)")
                        } else {
                            // Deactivate other screens
                            screenContainer.isActive = false
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onDisappear",
                                data: ["screenName": screenName]
                            )
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onDeactivate",
                                data: ["screenName": screenName]
                            )
                            print("✅ Deactivated screen: \(screenName)")
                        }
                    }
                }
            }
            
            // Fire tab navigator events using propagateEvent (FIXED)
            if let placeholderView = DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] {
                propagateEvent(
                    on: placeholderView,
                    eventName: "onTabChange",
                    data: [
                        "selectedIndex": selectedIndex,
                        "userInitiated": true
                    ]
                )
                print("✅ TabBarControllerDelegate: Fired onTabChange event for tab \(selectedIndex)")
            }
        }
        
        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            let selectedIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? 0
            
            print("👆 TabBarControllerDelegate: Tab pressed at index \(selectedIndex)")
            
            // Fire tab press event using propagateEvent (FIXED)
            if let placeholderView = DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] {
                propagateEvent(
                    on: placeholderView,
                    eventName: "onTabPress",
                    data: [
                        "selectedIndex": selectedIndex
                    ]
                )
                print("✅ TabBarControllerDelegate: Fired onTabPress event for tab \(selectedIndex)")
            }
            
            return true
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up resources for a navigator
    static func cleanup(navigatorId: String) {
        tabNavigatorRegistry.removeValue(forKey: navigatorId)
        navigatorState.removeValue(forKey: navigatorId)
        placeholderViewRegistry.removeValue(forKey: navigatorId)
    }
}
