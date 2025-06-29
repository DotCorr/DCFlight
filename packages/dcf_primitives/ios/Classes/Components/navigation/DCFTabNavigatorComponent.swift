/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight
import SVGKit

/// Tab navigator component that creates and manages UITabBarController
class DCFTabNavigatorComponent: NSObject, DCFComponent {
    
    // Registry of active tab bar controllers
    static var tabNavigatorRegistry: [String: UITabBarController] = [:]
    
    // Track navigator state
    static var navigatorState: [String: TabNavigatorState] = [:]
    
    // CRITICAL FIX: Map navigatorId to placeholder view for event propagation
    static var placeholderViewRegistry: [String: UIView] = [:]
    
    // CRITICAL FIX: Initialize SVGKit early to prevent timing issues
    static let svgKitInitialized: Bool = {
        // Force SVGKit initialization by creating a dummy SVG
        let dummySVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="1" height="1" xmlns="http://www.w3.org/2000/svg">
        <rect width="1" height="1" fill="transparent"/>
        </svg>
        """
        if let data = dummySVG.data(using: .utf8) {
            _ = SVGKImage(data: data)
        }
        return true
    }()
    
    required override init() {
        super.init()
        // Ensure SVGKit is initialized
        _ = DCFTabNavigatorComponent.svgKitInitialized
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
        
        // CRITICAL FIX: Configure tab bar controller asynchronously to allow icon loading
        DispatchQueue.main.async {
            self.configureTabBarController(tabBarController, props: props, navigatorId: navigatorId)
            
            // Install as root view controller after configuration
            replaceRoot(controller: tabBarController)
            
            // Fire initial events after everything is set up
            self.fireInitialEvents(navigatorId: navigatorId, props: props)
        }
        
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
                
                // CRITICAL FIX: Configure tab bar item with proper icon loading
                configureTabBarItemWithRetry(navController, screenContainer: screenContainer, index: index)
                
                viewControllers.append(navController)
            } else {
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
    }
    
    // CRITICAL FIX: New method to handle icon configuration with retry logic
    private func configureTabBarItemWithRetry(_ viewController: UIViewController, screenContainer: ScreenContainer, index: Int, retryCount: Int = 0) {
        // Get stored tab config from screen container
        guard let tabConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "tabConfig".hashValue)!
        ) as? [String: Any] else {
            // Fallback configuration
            setFallbackTabItem(viewController, index: index)
            return
        }
        
        // Configure basic properties first
        if let title = tabConfig["title"] as? String {
            viewController.tabBarItem.title = title
        }
        if let badge = tabConfig["badge"] as? String {
            viewController.tabBarItem.badgeValue = badge
        }
        let enabled = tabConfig["enabled"] as? Bool ?? true
        viewController.tabBarItem.isEnabled = enabled
        viewController.tabBarItem.tag = index
        
        // Handle icon configuration with retry logic
        if let iconConfig = tabConfig["icon"] as? [String: Any] {
            let success = configureTabIconSVG(for: viewController, iconConfig: iconConfig)
            
            // CRITICAL FIX: If SVG loading failed and we haven't retried too many times, retry after a delay
            if !success && retryCount < 3 {
                print("⚠️ DCFTabNavigatorComponent: SVG icon loading failed for tab \(index), retrying in 0.1s (attempt \(retryCount + 1))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.configureTabBarItemWithRetry(viewController, screenContainer: screenContainer, index: index, retryCount: retryCount + 1)
                }
            } else if !success {
                print("❌ DCFTabNavigatorComponent: Failed to load SVG icon for tab \(index) after \(retryCount) retries, using fallback")
                setFallbackTabItem(viewController, index: index)
            }
        } else if let iconString = tabConfig["icon"] as? String {
            // Backward compatibility - SF Symbol string
            viewController.tabBarItem.image = UIImage(systemName: iconString) ?? UIImage(systemName: "circle")
        } else {
            setFallbackTabItem(viewController, index: index)
        }
    }
    
    private func setFallbackTabItem(_ viewController: UIViewController, index: Int) {
        if viewController.tabBarItem.title == nil {
            viewController.tabBarItem.title = "Tab \(index)"
        }
        if viewController.tabBarItem.image == nil {
            viewController.tabBarItem.image = UIImage(systemName: "circle")
        }
    }

    // CRITICAL FIX: Enhanced SVG configuration with better error handling
    private func configureTabIconSVG(for viewController: UIViewController, iconConfig: [String: Any]) -> Bool {
        let iconType = iconConfig["type"] as? String ?? "sf"
        
        switch iconType {
        case "sf":
            // SF Symbol
            guard let symbolName = iconConfig["name"] as? String else {
                return false
            }
            viewController.tabBarItem.image = UIImage(systemName: symbolName) ?? UIImage(systemName: "circle")
            return true
            
        case "svg":
            // SVG from app bundle
            guard let assetPath = iconConfig["assetPath"] as? String else {
                return false
            }
            
            let key = sharedFlutterViewController?.lookupKey(forAsset: assetPath)
            let mainBundle = Bundle.main
            let path = mainBundle.path(forResource: key, ofType: nil)
            
            return loadSVGForTab(from: path ?? "", for: viewController, iconConfig: iconConfig)
            
        case "package":
            // SVG from package
            guard let iconName = iconConfig["name"] as? String,
                  let packageName = iconConfig["package"] as? String else {
                return false
            }
            
            guard let key = sharedFlutterViewController?.lookupKey(
                forAsset: "assets/icons/\(iconName).svg",
                fromPackage: packageName
            ) else {
                print("❌ DCFTabNavigatorComponent: Could not find asset key for \(iconName) in package \(packageName)")
                return false
            }
            
            let mainBundle = Bundle.main
            let path = mainBundle.path(forResource: key, ofType: nil)
            
            if path == nil || path!.isEmpty {
                print("❌ DCFTabNavigatorComponent: Could not find file path for \(iconName) in package \(packageName)")
                return false
            }
            
            return loadSVGForTab(from: path!, for: viewController, iconConfig: iconConfig)
            
        default:
            viewController.tabBarItem.image = UIImage(systemName: "circle")
            return false
        }
    }

    // CRITICAL FIX: Enhanced SVG loading with better error handling and caching
    private func loadSVGForTab(from path: String, for viewController: UIViewController, iconConfig: [String: Any]) -> Bool {
        guard !path.isEmpty else {
            print("❌ DCFTabNavigatorComponent: Empty path provided for SVG loading")
            return false
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ DCFTabNavigatorComponent: SVG file does not exist at path: \(path)")
            return false
        }
        
        // CRITICAL FIX: Add caching to prevent reloading the same SVG multiple times
        let cacheKey = path + "_tab_icon"
        if let cachedImage = DCFSvgComponent.getCachedImage(for: cacheKey) {
            applyCachedImageToTab(cachedImage, for: viewController, iconConfig: iconConfig)
            return true
        }
        
        // Load SVG using SVGKit with error handling
        guard let svgImage = SVGKImage(contentsOfFile: path) else {
            print("❌ DCFTabNavigatorComponent: Failed to load SVG from path: \(path)")
            return false
        }
        
        // Tab bar icons should be 25x25 points
        let iconSize = iconConfig["size"] as? CGFloat ?? 25.0
        let targetSize = CGSize(width: iconSize, height: iconSize)
        
        svgImage.size = targetSize
        
        guard let uiImage = svgImage.uiImage else {
            print("❌ DCFTabNavigatorComponent: Failed to convert SVG to UIImage")
            return false
        }
        
        // Cache the image for future use
        DCFSvgComponent.setCachedImage(svgImage, for: cacheKey)
        
        // Apply the image to the tab
        applyCachedImageToTab(svgImage, for: viewController, iconConfig: iconConfig)
        
        print("✅ DCFTabNavigatorComponent: Successfully loaded SVG icon from: \(path)")
        return true
    }
    
    private func applyCachedImageToTab(_ svgImage: SVGKImage, for viewController: UIViewController, iconConfig: [String: Any]) {
        guard let uiImage = svgImage.uiImage else { return }
        
        // Apply tint color if specified
        if let tintColor = iconConfig["tintColor"] as? String,
           let _ = ColorUtilities.color(fromHexString: tintColor) {
            viewController.tabBarItem.image = uiImage.withRenderingMode(.alwaysTemplate)
        } else {
            viewController.tabBarItem.image = uiImage.withRenderingMode(.alwaysOriginal)
        }
        
        // Handle selected image if different color specified
        if let selectedTintColor = iconConfig["selectedTintColor"] as? String,
           let selectedColor = ColorUtilities.color(fromHexString: selectedTintColor) {
            let selectedImage = createTintedTabImage(from: uiImage, color: selectedColor)
            viewController.tabBarItem.selectedImage = selectedImage?.withRenderingMode(.alwaysOriginal)
        }
    }

    private func createTintedTabImage(from image: UIImage, color: UIColor) -> UIImage? {
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
    
    // CRITICAL FIX: Separate method for firing initial events
    private func fireInitialEvents(navigatorId: String, props: [String: Any]) {
        let selectedIndex = props["selectedIndex"] as? Int ?? 0
        
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
        
        // Trigger initial screen activation for the selected tab
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
            
            // Fire tab change event on the correct view using propagateEvent
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
            
            // Update navigator state
            DCFTabNavigatorComponent.navigatorState[navigatorId]?.selectedIndex = selectedIndex
            
            // Trigger screen lifecycle events when tabs change
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
                        }
                    }
                }
            }
            
            // Fire tab navigator events using propagateEvent
            if let placeholderView = DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] {
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
            
            // Fire tab press event using propagateEvent
            if let placeholderView = DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] {
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
    }
    
    // MARK: - Cleanup
    
    /// Clean up resources for a navigator
    static func cleanup(navigatorId: String) {
        tabNavigatorRegistry.removeValue(forKey: navigatorId)
        navigatorState.removeValue(forKey: navigatorId)
        placeholderViewRegistry.removeValue(forKey: navigatorId)
    }
}

// MARK: - DCFSvgComponent Extension for Caching
extension DCFSvgComponent {
    private static var tabIconCache = [String: SVGKImage]()
    
    static func getCachedImage(for key: String) -> SVGKImage? {
        return tabIconCache[key]
    }
    
    static func setCachedImage(_ image: SVGKImage, for key: String) {
        tabIconCache[key] = image
    }
    
    static func clearTabIconCache() {
        tabIconCache.removeAll()
    }
}
