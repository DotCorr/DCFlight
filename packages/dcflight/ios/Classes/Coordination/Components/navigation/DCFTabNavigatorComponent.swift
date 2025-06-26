/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// Tab navigator component that creates and manages UITabBarController
class DCFTabNavigatorComponent: NSObject, DCFComponent {
    
    // Registry of active tab bar controllers
    static var tabNavigatorRegistry: [String: UITabBarController] = [:]
    
    // Track navigator state
    static var navigatorState: [String: TabNavigatorState] = [:]
    
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
        
        return placeholderView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let navigatorId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "navigatorId".hashValue)!) as? String,
              let tabBarController = DCFTabNavigatorComponent.tabNavigatorRegistry[navigatorId] else {
            print("❌ DCFTabNavigatorComponent: Tab bar controller not found for update")
            return false
        }
        
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
        
        // Set delegate for tab change events
        tabBarController.delegate = TabBarControllerDelegate(navigatorId: navigatorId)
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
            
            // Fire tab change event
            propagateEvent(
                on: view,
                eventName: "onTabChange",
                data: [
                    "selectedIndex": selectedIndex,
                    "previousIndex": previousIndex
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
            
            // Find the placeholder view to fire event
            if let placeholderView = findPlaceholderView(for: navigatorId) {
                propagateEvent(
                    on: placeholderView,
                    eventName: "onTabChange",
                    data: [
                        "selectedIndex": selectedIndex,
                        "userInitiated": true
                    ]
                )
            }
        }
        
        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            let selectedIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? 0
            
            // Fire tab press event
            if let placeholderView = findPlaceholderView(for: navigatorId) {
                propagateEvent(
                    on: placeholderView,
                    eventName: "onTabPress",
                    data: [
                        "selectedIndex": selectedIndex
                    ]
                )
            }
            
            return true
        }
        
        private func findPlaceholderView(for navigatorId: String) -> UIView? {
            // This is a simplified approach - in a real implementation,
            // we'd need to maintain a mapping of navigatorId to placeholder view
            return nil
        }
    }
    
}
