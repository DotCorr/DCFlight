/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import dcflight
import SVGKit

class DCFTabNavigatorComponent: NSObject, DCFComponent {
    
    static var tabNavigatorRegistry: [String: UITabBarController] = [:]
    static var navigatorState: [String: TabNavigatorState] = [:]
    static var placeholderViewRegistry: [String: UIView] = [:]
    
    static let svgKitInitialized: Bool = {
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
        _ = DCFTabNavigatorComponent.svgKitInitialized
    }
    
    func createView(props: [String: Any]) -> UIView {
        let navigatorId = String(Date().timeIntervalSince1970)
        
        print("🔧 DCFTabNavigatorComponent: Creating tab navigator '\(navigatorId)'")
        
        let tabBarController = createTabBarController(props: props)
        
        DCFTabNavigatorComponent.tabNavigatorRegistry[navigatorId] = tabBarController
        DCFTabNavigatorComponent.navigatorState[navigatorId] = TabNavigatorState(
            routes: props["screens"] as? [String] ?? [],
            selectedIndex: props["selectedIndex"] as? Int ?? 0
        )
        
        DispatchQueue.main.async {
            self.configureTabBarController(tabBarController, props: props, navigatorId: navigatorId)
            
            replaceRoot(controller: tabBarController)
            self.fireInitialEvents(navigatorId: navigatorId, props: props)
        }
        
        let placeholderView = UIView()
        placeholderView.isHidden = true
        placeholderView.backgroundColor = UIColor.clear
        
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
        
        DCFTabNavigatorComponent.placeholderViewRegistry[navigatorId] = placeholderView
      
        return placeholderView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let navigatorId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "navigatorId".hashValue)!) as? String,
              let tabBarController = DCFTabNavigatorComponent.tabNavigatorRegistry[navigatorId] else {
            print("❌ DCFTabNavigatorComponent: Tab bar controller not found for update")
            return false
        }
        
        if let selectedIndex = props["selectedIndex"] as? Int {
            updateSelectedTab(tabBarController, selectedIndex: selectedIndex, navigatorId: navigatorId, view: view)
        }
        
        updateTabBarStyle(tabBarController, props: props)
        
        let isHidden = props["isHidden"] as? Bool ?? false
        tabBarController.tabBar.isHidden = isHidden
        
        return true
    }
    
    private func createTabBarController(props: [String: Any]) -> UITabBarController {
        let tabBarController = UITabBarController()
        configureTabBarAppearance(tabBarController, props: props)
        return tabBarController
    }
    
    private func configureTabBarController(_ tabBarController: UITabBarController, props: [String: Any], navigatorId: String) {
        guard let routes = props["screens"] as? [String] else {
            print("❌ DCFTabNavigatorComponent: No routes provided")
            return
        }
        
        print("📱 DCFTabNavigatorComponent: Configuring tab bar with \(routes.count) routes")
        
        var viewControllers: [UIViewController] = []
        
        for (index, route) in routes.enumerated() {
            if let screenContainer = DCFScreenComponent.getScreenContainer(route: route) {
                let navController = UINavigationController()
                
                let needsLargeTitles = checkIfScreenNeedsLargeTitles(screenContainer: screenContainer)
                
                if #available(iOS 11.0, *) {
                    navController.navigationBar.prefersLargeTitles = needsLargeTitles
                }
                
                screenContainer.viewController.view = screenContainer.contentView
                screenContainer.contentView.frame = UIScreen.main.bounds
                screenContainer.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                navController.setViewControllers([screenContainer.viewController], animated: false)
                
                configureTabBarItemWithRetry(navController, screenContainer: screenContainer, index: index)
                
                viewControllers.append(navController)
                
                print("✅ DCFTabNavigatorComponent: Added route '\(route)' at index \(index)")
            } else {
                print("⚠️ DCFTabNavigatorComponent: Route '\(route)' not found, creating placeholder")
                let placeholderVC = UIViewController()
                placeholderVC.view.backgroundColor = UIColor.systemBackground
                placeholderVC.title = "Screen \(index)"
                placeholderVC.tabBarItem = UITabBarItem(title: "Tab \(index)", image: UIImage(systemName: "circle"), tag: index)
                
                let navController = UINavigationController(rootViewController: placeholderVC)
                viewControllers.append(navController)
            }
        }
        
        tabBarController.setViewControllers(viewControllers, animated: false)
        
        let selectedIndex = props["selectedIndex"] as? Int ?? 0
        if selectedIndex >= 0 && selectedIndex < viewControllers.count {
            tabBarController.selectedIndex = selectedIndex
        }
        
        let delegate = TabBarControllerDelegate(navigatorId: navigatorId)
        tabBarController.delegate = delegate
        
        objc_setAssociatedObject(
            tabBarController,
            UnsafeRawPointer(bitPattern: "tabBarDelegate".hashValue)!,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        print("🎯 DCFTabNavigatorComponent: Tab bar configuration complete")
    }

    static func cleanupAllTabNavigators() {
        for (_, tabController) in tabNavigatorRegistry {
            if let viewControllers = tabController.viewControllers {
                for viewController in viewControllers {
                    if let navController = viewController as? UINavigationController {
                        navController.setViewControllers([], animated: false)
                        if navController.navigationBar.superview != nil {
                            navController.navigationBar.removeFromSuperview()
                        }
                        navController.delegate = nil
                    }
                }
            }
            
            tabController.setViewControllers([], animated: false)
            tabController.delegate = nil
        }
        
        tabNavigatorRegistry.removeAll()
        navigatorState.removeAll()
        placeholderViewRegistry.removeAll()
    }
    
    private func configureTabBarItemWithRetry(_ viewController: UIViewController, screenContainer: ScreenContainer, index: Int, retryCount: Int = 0) {
        guard let tabConfig = objc_getAssociatedObject(
            screenContainer.viewController,
            UnsafeRawPointer(bitPattern: "tabConfig".hashValue)!
        ) as? [String: Any] else {
            setFallbackTabItem(viewController, index: index)
            return
        }
        
        if let title = tabConfig["title"] as? String {
            viewController.tabBarItem.title = title
        }
        if let badge = tabConfig["badge"] as? String {
            viewController.tabBarItem.badgeValue = badge
        }
        let enabled = tabConfig["enabled"] as? Bool ?? true
        viewController.tabBarItem.isEnabled = enabled
        viewController.tabBarItem.tag = index
        
        if let iconConfig = tabConfig["icon"] as? [String: Any] {
            let success = configureTabIconSVG(for: viewController, iconConfig: iconConfig)
            
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

    private func configureTabIconSVG(for viewController: UIViewController, iconConfig: [String: Any]) -> Bool {
        let iconType = iconConfig["type"] as? String ?? "sf"
        
        switch iconType {
        case "sf":
            guard let symbolName = iconConfig["name"] as? String else {
                return false
            }
            viewController.tabBarItem.image = UIImage(systemName: symbolName) ?? UIImage(systemName: "circle")
            return true
            
        case "svg":
            guard let assetPath = iconConfig["assetPath"] as? String else {
                return false
            }
            
            let key = sharedFlutterViewController?.lookupKey(forAsset: assetPath)
            let mainBundle = Bundle.main
            let path = mainBundle.path(forResource: key, ofType: nil)
            
            return loadSVGForTab(from: path ?? "", for: viewController, iconConfig: iconConfig)
            
        case "package":
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

    private func loadSVGForTab(from path: String, for viewController: UIViewController, iconConfig: [String: Any]) -> Bool {
        guard !path.isEmpty else {
            print("❌ DCFTabNavigatorComponent: Empty path provided for SVG loading")
            return false
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ DCFTabNavigatorComponent: SVG file does not exist at path: \(path)")
            return false
        }
        
        let cacheKey = path + "_tab_icon"
        if let cachedImage = DCFTabNavigatorComponent.getCachedImage(for: cacheKey) {
            applyCachedImageToTab(cachedImage, for: viewController, iconConfig: iconConfig)
            return true
        }
        
        guard let svgImage = SVGKImage(contentsOfFile: path) else {
            print("❌ DCFTabNavigatorComponent: Failed to load SVG from path: \(path)")
            return false
        }
        
        let iconSize = iconConfig["size"] as? CGFloat ?? 25.0
        let targetSize = CGSize(width: iconSize, height: iconSize)
        
        svgImage.size = targetSize
        
        DCFTabNavigatorComponent.setCachedImage(svgImage, for: cacheKey)
        
        applyCachedImageToTab(svgImage, for: viewController, iconConfig: iconConfig)
        
        print("✅ DCFTabNavigatorComponent: Successfully loaded SVG icon from: \(path)")
        return true
    }
    
    private func applyCachedImageToTab(_ svgImage: SVGKImage, for viewController: UIViewController, iconConfig: [String: Any]) {
        guard let uiImage = svgImage.uiImage else { return }
        
        if let tintColor = iconConfig["tintColor"] as? String,
           let _ = ColorUtilities.color(fromHexString: tintColor) {
            viewController.tabBarItem.image = uiImage.withRenderingMode(.alwaysTemplate)
        } else {
            viewController.tabBarItem.image = uiImage.withRenderingMode(.alwaysOriginal)
        }
        
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
        
        if let backgroundColorString = props["backgroundColor"] as? String {
            tabBar.backgroundColor = ColorUtilities.color(fromHexString: backgroundColorString)
        }
        
        if let selectedTintColorString = props["selectedTintColor"] as? String {
            tabBar.tintColor = ColorUtilities.color(fromHexString: selectedTintColorString)
        }
        
        if let unselectedTintColorString = props["unselectedTintColor"] as? String {
            tabBar.unselectedItemTintColor = ColorUtilities.color(fromHexString: unselectedTintColorString)
        }
        
        let translucent = props["translucent"] as? Bool ?? true
        tabBar.isTranslucent = translucent
        
        let position = props["position"] as? String ?? "bottom"
        if position != "bottom" {
            print("⚠️ DCFTabNavigatorComponent: Only 'bottom' position is supported for tab bar on iOS")
        }
        
        let showLabels = props["showLabels"] as? Bool ?? true
        let showIcons = props["showIcons"] as? Bool ?? true
        
        if !showLabels || !showIcons {
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
        
        if let routes = DCFTabNavigatorComponent.navigatorState[navigatorId]?.routes,
           selectedIndex < routes.count {
            let initialRoute = routes[selectedIndex]
            if let screenContainer = DCFScreenComponent.getScreenContainer(route: initialRoute) {
                propagateEvent(
                    on: screenContainer.contentView,
                    eventName: "onAppear",
                    data: ["route": initialRoute]
                )
                propagateEvent(
                    on: screenContainer.contentView,
                    eventName: "onActivate",
                    data: ["route": initialRoute]
                )
            }
        }
    }
    
    private func updateSelectedTab(_ tabBarController: UITabBarController, selectedIndex: Int, navigatorId: String, view: UIView) {
        guard selectedIndex >= 0 && selectedIndex < (tabBarController.viewControllers?.count ?? 0) else {
            print("❌ DCFTabNavigatorComponent: Invalid selected index \(selectedIndex)")
            return
        }
        
        let previousIndex = tabBarController.selectedIndex
        if previousIndex != selectedIndex {
            print("🔄 DCFTabNavigatorComponent: Changing tab from \(previousIndex) to \(selectedIndex)")
            
            tabBarController.selectedIndex = selectedIndex
            
            DCFTabNavigatorComponent.navigatorState[navigatorId]?.selectedIndex = selectedIndex
            
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
    
    class TabNavigatorState {
        var routes: [String]
        var selectedIndex: Int
        
        init(routes: [String], selectedIndex: Int) {
            self.routes = routes
            self.selectedIndex = selectedIndex
        }
    }
    
    class TabBarControllerDelegate: NSObject, UITabBarControllerDelegate {
        let navigatorId: String
        
        init(navigatorId: String) {
            self.navigatorId = navigatorId
            super.init()
        }
        
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let selectedIndex = tabBarController.selectedIndex
            
            DCFTabNavigatorComponent.navigatorState[navigatorId]?.selectedIndex = selectedIndex
            
            if let routes = DCFTabNavigatorComponent.navigatorState[navigatorId]?.routes {
                for (index, route) in routes.enumerated() {
                    if let screenContainer = DCFScreenComponent.getScreenContainer(route: route) {
                        let contentFrame = screenContainer.contentView.frame
                        let childCount = screenContainer.contentView.subviews.count
                        print("🔍 TAB DEBUG: Route '\(route)' at index \(index) - frame: \(contentFrame), children: \(childCount)")
                        
                        if index == selectedIndex {
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onAppear",
                                data: ["route": route]
                            )
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onActivate",
                                data: ["route": route]
                            )
                        } else {
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onDisappear",
                                data: ["route": route]
                            )
                            propagateEvent(
                                on: screenContainer.contentView,
                                eventName: "onDeactivate",
                                data: ["route": route]
                            )
                        }
                    }
                }
            }
            
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
    
    static func cleanup(navigatorId: String) {
        tabNavigatorRegistry.removeValue(forKey: navigatorId)
        navigatorState.removeValue(forKey: navigatorId)
        placeholderViewRegistry.removeValue(forKey: navigatorId)
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

private func checkIfScreenNeedsLargeTitles(screenContainer: ScreenContainer) -> Bool {
    guard let navBarConfig = objc_getAssociatedObject(
        screenContainer.viewController,
        UnsafeRawPointer(bitPattern: "navigationBarConfig".hashValue)!
    ) as? [String: Any] else {
        return false
    }
    
    return navBarConfig["largeTitleDisplayMode"] as? Bool ?? false
}

extension DCFTabNavigatorComponent {
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
