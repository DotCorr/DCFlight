/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


import Flutter

@objc public extension FlutterAppDelegate {
    func divergeToFlight() {
        let appDelegate = self as? DCFAppDelegate
        let flutterEngine = appDelegate?.flutterEngine ?? FlutterEngine(name: "main engine")
        
        if appDelegate?.flutterEngine == nil {
            flutterEngine.run(withEntrypoint: "main", libraryURI: nil)
        }
        
        // CRITICAL: Register all plugins with our custom engine
        // GeneratedPluginRegistrant.register(with: self) is called in AppDelegate,
        // but we need to ensure plugins are registered with our custom engine, not default
        // Use Objective-C runtime to call GeneratedPluginRegistrant.registerWithRegistry: with our engine
        if let registrantClass = NSClassFromString("GeneratedPluginRegistrant") as? NSObject.Type {
            if registrantClass.responds(to: Selector("registerWithRegistry:")) {
                registrantClass.perform(Selector("registerWithRegistry:"), with: flutterEngine)
                print("✅ DCDivergerUtil: Registered all plugins with custom FlutterEngine")
            }
        } else {
            print("⚠️ DCDivergerUtil: GeneratedPluginRegistrant not found (plugins may already be registered)")
        }
        
        let nativeRootVC = UIViewController()
        nativeRootVC.view.backgroundColor = .white
        nativeRootVC.title = "Root View (DCFlight)"
        
        // CRITICAL: Disable automatic safe area adjustments
        // We want the root view to fill the entire window starting from (0,0)
        if #available(iOS 11.0, *) {
            nativeRootVC.view.insetsLayoutMarginsFromSafeArea = false
        }
        nativeRootVC.automaticallyAdjustsScrollViewInsets = false
        
        guard let window = self.window else {
            print("❌ DCFlight: No window available to set rootViewController")
            return
        }
        window.rootViewController = nativeRootVC
        setupDCF(rootView: nativeRootVC.view, flutterEngine: flutterEngine)

        _ = DCFScreenUtilities.shared
    }

    private func setupDCF(rootView: UIView, flutterEngine: FlutterEngine) {
        // Ensure root view is visible
        rootView.isHidden = false
        rootView.alpha = 1.0
        
        // CRITICAL: Set root view frame to fill window bounds immediately
        // This ensures children are positioned correctly from the start
        // Use window.bounds (not safe area) to fill entire screen from (0,0)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            // CRITICAL: Set frame to window.bounds (not safeAreaLayoutGuide)
            // This ensures root view starts at (0,0) and fills entire window
            rootView.frame = CGRect(x: 0, y: 0, width: window.bounds.width, height: window.bounds.height)
            rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            print("✅ DCDivergerUtil: Root view frame set to window.bounds: \(rootView.frame)")
        } else {
            let screenBounds = UIScreen.main.bounds
            rootView.frame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)
            rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            print("✅ DCDivergerUtil: Root view frame set to screen.bounds: \(rootView.frame)")
        }
        
        DCFlightNative.shared.registerView(rootView, withId: 0)
        DCFScreenUtilities.shared.initialize(with: flutterEngine.binaryMessenger)
        _ = YogaShadowTree.shared
        _ = DCFLayoutManager.shared
        runInternalModules()
        setupSizeChangeDetection()
        
        // Set initial screen dimensions (layout will be calculated after views are created in commitBatchUpdate)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let windowBounds = window.bounds
            print("🎯 DCFlight: Setting initial window size: \(windowBounds.width)x\(windowBounds.height)")
            DCFScreenUtilities.shared.updateScreenDimensions(width: windowBounds.width, height: windowBounds.height)
        }
        
        // Schedule async update as fallback
        DispatchQueue.main.async {
            self.updateInitialWindowSize()
        }
    }

    private func setupSizeChangeDetection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowSizeChanged),
                name: UIScene.didActivateNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowSizeChanged),
                name: UIScene.willDeactivateNotification,
                object: nil
            )
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationFrameChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        DispatchQueue.main.async {
            self.setupWindowBoundsObserver()
        }
        
        setupAppLifecycleObservers()
        
        print("✅ DCFlight: Comprehensive size change detection initialized")
    }
    
    private func setupWindowBoundsObserver() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("⚠️ DCFlight: Could not find window for bounds observation")
            return
        }
        
        if let existingWindow = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!) as? UIWindow {
            if existingWindow == window {
                print("✅ DCFlight: Window bounds observer already set up for this window")
                return
            } else {
                print("🔄 DCFlight: Removing observer from old window")
                existingWindow.removeObserver(self, forKeyPath: "bounds")
                existingWindow.removeObserver(self, forKeyPath: "frame")
            }
        }
        
        objc_setAssociatedObject(
            self,
            UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!,
            window,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        do {
            window.addObserver(
                self,
                forKeyPath: "bounds",
                options: [.new, .old],
                context: nil
            )
            
            window.addObserver(
                self,
                forKeyPath: "frame",
                options: [.new, .old],
                context: nil
            )
            
            print("✅ DCFlight: Window bounds observer added for real-time resize detection")
        } catch {
            print("❌ DCFlight: Failed to add window bounds observer: \(error)")
        }
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanup),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reinitializeIfNeeded),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds" || keyPath == "frame" {
            if let window = object as? UIWindow {
                let oldValue = change?[.oldKey] as? NSValue
                let newValue = change?[.newKey] as? NSValue
                
                let oldRect = oldValue?.cgRectValue ?? .zero
                let newRect = newValue?.cgRectValue ?? .zero
                
                if oldRect.size != newRect.size {
                    print("🔄 DCFlight: Window size changed from \(oldRect.size) to \(newRect.size)")
                    windowSizeChangedInternal(newSize: newRect.size)
                } else {
                    print("🔍 DCFlight: Window position changed but size remained the same")
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    @objc private func orientationChanged() {
        print("🔄 DCFlight: Device orientation changed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.recalculateLayout(reason: "orientation change")
        }
    }
    
    @objc private func windowSizeChanged() {
        print("🔄 DCFlight: Window scene state changed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.recalculateLayout(reason: "window scene change")
        }
    }
    
    @objc private func applicationFrameChanged() {
        print("🔄 DCFlight: Application frame changed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.recalculateLayout(reason: "application frame change")
        }
    }
    
    private func windowSizeChangedInternal(newSize: CGSize) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.recalculateLayoutWithSize(newSize, reason: "window resize")
        }
    }
    
    private func recalculateLayout(reason: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ DCFlight: Could not find window for layout recalculation")
            return
        }
        
        let screenWidth = window.bounds.width
        let screenHeight = window.bounds.height
        
        print("🎯 DCFlight: Recalculating layout due to \(reason) - Size: \(screenWidth)x\(screenHeight)")
        
        DCFScreenUtilities.shared.updateScreenDimensions(width: screenWidth, height: screenHeight)
        
        YogaShadowTree.shared.calculateAndApplyLayout(width: screenWidth, height: screenHeight)
    }
    
    private func recalculateLayoutWithSize(_ size: CGSize, reason: String) {
        print("🎯 DCFlight: Recalculating layout due to \(reason) - Size: \(size.width)x\(size.height)")
        
        DCFScreenUtilities.shared.updateScreenDimensions(width: size.width, height: size.height)
        
        YogaShadowTree.shared.calculateAndApplyLayout(width: size.width, height: size.height)
    }
    
    @objc private func cleanup() {
        NotificationCenter.default.removeObserver(self)
        
        if let window = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!) as? UIWindow {
            window.removeObserver(self, forKeyPath: "bounds")
            window.removeObserver(self, forKeyPath: "frame")
            
            objc_setAssociatedObject(
                self,
                UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        
        print("✅ DCFlight: Window size detection cleanup completed")
    }
    
    @objc private func reinitializeIfNeeded() {
        let hasWindowObserver = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!) != nil
        
        if !hasWindowObserver {
            print("⚠️ DCFlight: Window observer lost, re-initializing...")
            setupWindowBoundsObserver()
        }
    }
    
    private func updateInitialWindowSize() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("⚠️ DCFlight: Could not find window for initial size update")
            return
        }
        
        let windowBounds = window.bounds
        print("🎯 DCFlight: Initial window size detected: \(windowBounds.width)x\(windowBounds.height)")
        
        DCFScreenUtilities.shared.updateScreenDimensions(width: windowBounds.width, height: windowBounds.height)
        YogaShadowTree.shared.calculateAndApplyLayout(width: windowBounds.width, height: windowBounds.height)
    }
}

public func replaceRoot(controller: UIViewController) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
        print("❌ No window found for root replacement")
        return
    }
    
    if let existingRoot = window.rootViewController {
        for child in existingRoot.children {
            if let navController = child as? UINavigationController {
                navController.setViewControllers([], animated: false)
                if navController.navigationBar.superview != nil {
                    navController.navigationBar.removeFromSuperview()
                }
                navController.delegate = nil
            }
            
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
    
    window.rootViewController = controller
}

public func addTabBarToRoot(controller: UITabBarController) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let rootViewController = window.rootViewController else {
        print("❌ No existing root view controller found")
        return
    }
    
    cleanupExistingTabControllers(from: rootViewController)
    
    rootViewController.addChild(controller)
    rootViewController.view.addSubview(controller.view)
    
    controller.view.frame = rootViewController.view.bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    controller.didMove(toParent: rootViewController)
    
    print("✅ Tab bar controller added with cleanup")
}

private func cleanupExistingTabControllers(from rootViewController: UIViewController) {
    var removedCount = 0
    for child in rootViewController.children {
        if let existingTabController = child as? UITabBarController {
            
            if let viewControllers = existingTabController.viewControllers {
                for viewController in viewControllers {
                    if let navController = viewController as? UINavigationController {
                        navController.setViewControllers([], animated: false)
                        
                        if navController.navigationBar.superview != nil {
                            navController.navigationBar.removeFromSuperview()
                        }
                        
                        navController.delegate = nil
                    }
                }
                
                existingTabController.setViewControllers([], animated: false)
            }
            
            existingTabController.delegate = nil
            
            existingTabController.willMove(toParent: nil)
            existingTabController.view.removeFromSuperview()
            existingTabController.removeFromParent()
            
            removedCount += 1
        }
    }
    
    if removedCount > 0 {
        print("✅ Cleaned up \(removedCount) existing tab controller(s)")
    }
}



internal func runInternalModules(){
    FrameworkComponentsReg.registerComponents()
}
