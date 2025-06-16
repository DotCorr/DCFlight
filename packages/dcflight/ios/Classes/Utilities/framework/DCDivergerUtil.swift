/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


//
//  DCDivergerUtil.swift
//  
//
//  Created by Tahiru Agbanwa on 4/15/25.
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

    }

    @objc private func orientationChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            YogaShadowTree.shared.calculateAndApplyLayout(width: screenWidth, height: screenHeight)
        }
    }
}


