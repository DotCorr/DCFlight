/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// DCDivergerUtil.swift
//
//
// Created by Tahiru Agbanwa on 4/15/25.
//

import Flutter

@objc public extension FlutterAppDelegate {
    func divergeToFlight() {
        let appDelegate = self as? DCFAppDelegate
        let flutterEngine = appDelegate?.flutterEngine ?? FlutterEngine(name: "main engine")
        
        if appDelegate?.flutterEngine == nil {
            flutterEngine.run(withEntrypoint: "main", libraryURI: nil)
        }
        
        let flutterVC = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        flutterEngine.viewController = flutterVC
        sharedFlutterViewController = flutterVC // ✅ Store globally
        
        // Initialize method channels
        DCMauiBridgeMethodChannel.shared.initialize(with: flutterEngine.binaryMessenger)
        DCMauiEventMethodHandler.shared.initialize(with: flutterEngine.binaryMessenger)
        DCMauiLayoutMethodHandler.shared.initialize(with: flutterEngine.binaryMessenger)

        // Set up the native root view
        let nativeRootVC = UIViewController()
        nativeRootVC.view.backgroundColor = .white
        nativeRootVC.title = "Root View (DCFlight)"
        self.window.rootViewController = nativeRootVC
        setupDCF(rootView: nativeRootVC.view, flutterEngine: flutterEngine)

        _ = DCFScreenUtilities.shared
    }

    private func setupDCF(rootView: UIView, flutterEngine: FlutterEngine) {
        DCMauiBridgeImpl.shared.registerView(rootView, withId: "root")
        DCFScreenUtilities.shared.initialize(with: flutterEngine.binaryMessenger)
        _ = YogaShadowTree.shared
        _ = DCFLayoutManager.shared

        // CRITICAL FIX: Set up comprehensive size change detection
        setupSizeChangeDetection()
        
        // CRITICAL FIX: Ensure correct initial window size after view hierarchy is set up
        DispatchQueue.main.async {
            self.updateInitialWindowSize()
        }
    }

    // CRITICAL FIX: Enhanced size change detection for all scenarios
    private func setupSizeChangeDetection() {
        // 1. Device orientation changes (iPhone/iPad rotation)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // 2. Window size changes (iPad multitasking, Split View, Slide Over)
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
        
        // 3. Application frame changes (covers various edge cases)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationFrameChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 4. CRITICAL: Set up KVO for window bounds changes (most reliable for iPad window resizing)
        // Delay this to ensure window is properly set up
        DispatchQueue.main.async {
            self.setupWindowBoundsObserver()
        }
        
        // 5. Set up cleanup for app lifecycle events (but not too aggressive)
        setupAppLifecycleObservers()
        
        print("✅ DCFlight: Comprehensive size change detection initialized")
    }
    
    // CRITICAL FIX: KVO-based window bounds observer for real-time window resizing
    private func setupWindowBoundsObserver() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("⚠️ DCFlight: Could not find window for bounds observation")
            return
        }
        
        // Check if we already have an observer set up
        if let existingWindow = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!) as? UIWindow {
            if existingWindow == window {
                print("✅ DCFlight: Window bounds observer already set up for this window")
                return
            } else {
                // Different window, remove old observer
                print("🔄 DCFlight: Removing observer from old window")
                existingWindow.removeObserver(self, forKeyPath: "bounds")
                existingWindow.removeObserver(self, forKeyPath: "frame")
            }
        }
        
        // Store reference to window for observation
        objc_setAssociatedObject(
            self,
            UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!,
            window,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Add KVO observer for bounds changes
        do {
            window.addObserver(
                self,
                forKeyPath: "bounds",
                options: [.new, .old],
                context: nil
            )
            
            // Also observe frame changes as backup
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
    
    // CRITICAL FIX: Set up app lifecycle observers for cleanup
    private func setupAppLifecycleObservers() {
        // Only clean up when app actually terminates, not when it goes to background
        // Background cleanup was too aggressive and removed observers during normal use
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanup),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Also set up re-initialization when app becomes active (in case observers were lost)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reinitializeIfNeeded),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // CRITICAL FIX: KVO callback for window bounds/frame changes
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds" || keyPath == "frame" {
            if let window = object as? UIWindow {
                // Get old and new values to check if size actually changed
                let oldValue = change?[.oldKey] as? NSValue
                let newValue = change?[.newKey] as? NSValue
                
                let oldRect = oldValue?.cgRectValue ?? .zero
                let newRect = newValue?.cgRectValue ?? .zero
                
                // Only trigger layout if size actually changed (not just position)
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
    
    // Internal method for immediate window size changes (from KVO)
    private func windowSizeChangedInternal(newSize: CGSize) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.recalculateLayoutWithSize(newSize, reason: "window resize")
        }
    }
    
    // CRITICAL FIX: Centralized layout recalculation with size detection
    private func recalculateLayout(reason: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ DCFlight: Could not find window for layout recalculation")
            return
        }
        
        let screenWidth = window.bounds.width
        let screenHeight = window.bounds.height
        
        print("🎯 DCFlight: Recalculating layout due to \(reason) - Size: \(screenWidth)x\(screenHeight)")
        
        // Update screen utilities first
        DCFScreenUtilities.shared.updateScreenDimensions(width: screenWidth, height: screenHeight)
        
        // Then recalculate Yoga layout
        YogaShadowTree.shared.calculateAndApplyLayout(width: screenWidth, height: screenHeight)
    }
    
    // Overloaded method for when we already know the new size
    private func recalculateLayoutWithSize(_ size: CGSize, reason: String) {
        print("🎯 DCFlight: Recalculating layout due to \(reason) - Size: \(size.width)x\(size.height)")
        
        // Update screen utilities first
        DCFScreenUtilities.shared.updateScreenDimensions(width: size.width, height: size.height)
        
        // Then recalculate Yoga layout
        YogaShadowTree.shared.calculateAndApplyLayout(width: size.width, height: size.height)
    }
    
    // CRITICAL FIX: Cleanup method (called when app goes to background or terminates)
    @objc private func cleanup() {
        NotificationCenter.default.removeObserver(self)
        
        // Remove KVO observers
        if let window = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!) as? UIWindow {
            window.removeObserver(self, forKeyPath: "bounds")
            window.removeObserver(self, forKeyPath: "frame")
            
            // Clear the associated object
            objc_setAssociatedObject(
                self,
                UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        
        print("✅ DCFlight: Window size detection cleanup completed")
    }
    
    // CRITICAL FIX: Re-initialize window observers if they were lost
    @objc private func reinitializeIfNeeded() {
        // Check if we still have a window observer
        let hasWindowObserver = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "observedWindow".hashValue)!) != nil
        
        if !hasWindowObserver {
            print("⚠️ DCFlight: Window observer lost, re-initializing...")
            setupWindowBoundsObserver()
        }
    }
    
    // CRITICAL FIX: Update initial window size after everything is set up
    private func updateInitialWindowSize() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("⚠️ DCFlight: Could not find window for initial size update")
            return
        }
        
        // Get the actual window bounds (not screen bounds)
        let windowBounds = window.bounds
        print("🎯 DCFlight: Initial window size detected: \(windowBounds.width)x\(windowBounds.height)")
        
        // Force update screen utilities and layout with correct window size
        DCFScreenUtilities.shared.updateScreenDimensions(width: windowBounds.width, height: windowBounds.height)
        YogaShadowTree.shared.calculateAndApplyLayout(width: windowBounds.width, height: windowBounds.height)
    }
}

public func replaceRoot(controller: UIViewController) {
    // Get the current root view controller
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
        print("❌ DCFTabNavigatorComponent: Could not find window to install tab bar controller")
        return
    }
    
    controller.title = "Root Replacement"
    
    // Replace root view controller
    DispatchQueue.main.async {
        window.rootViewController = controller
        window.makeKeyAndVisible()
        print("✅ DCFTabNavigatorComponent: Installed tab bar controller as root")
        
        // CRITICAL FIX: Update window size after root controller is installed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let actualBounds = window.bounds
            print("🎯 DCFlight: Final window size after root installation: \(actualBounds.width)x\(actualBounds.height)")
            
            DCFScreenUtilities.shared.updateScreenDimensions(width: actualBounds.width, height: actualBounds.height)
            YogaShadowTree.shared.calculateAndApplyLayout(width: actualBounds.width, height: actualBounds.height)
        }
    }
}
