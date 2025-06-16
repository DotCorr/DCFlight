/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import Flutter

class DCFScreenUtilities {
    static let shared = DCFScreenUtilities()
    
    // Store the Flutter binary messenger
    private var flutterBinaryMessenger: FlutterBinaryMessenger?
    private var methodChannel: FlutterMethodChannel?
    
    private init() {
        // Method channel will be set up later when binary messenger is available
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    // Initialize with a binary messenger from the Flutter app delegate
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        self.flutterBinaryMessenger = binaryMessenger
        
        // Now create the method channel with the provided messenger
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.screen_dimensions",
            binaryMessenger: binaryMessenger
        )
        
        setupMethodChannel()
    }
    
    private func setupMethodChannel() {
        guard let methodChannel = methodChannel else { return }
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { 
                result(FlutterError(code: "UNAVAILABLE", 
                                   message: "Screen utilities not available", 
                                   details: nil))
                return
            }
            
            if call.method == "getScreenDimensions" {
                // Return current screen dimensions
                let bounds = UIScreen.main.bounds
                let safeAreaInsets = self.getSafeAreaInsets()
                result([
                    "width": bounds.width,
                    "height": bounds.height,
                    "scale": UIScreen.main.scale,
                    "statusBarHeight": UIApplication.shared.statusBarFrame.height,
                    "safeAreaTop": safeAreaInsets.top,
                    "safeAreaBottom": safeAreaInsets.bottom,
                    "safeAreaLeft": safeAreaInsets.left,
                    "safeAreaRight": safeAreaInsets.right
                ])
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("📱 Screen dimensions method channel set up successfully")
    }
    
    @objc private func orientationChanged() {
        guard let methodChannel = methodChannel else { return }
        
        // Allow a moment for the UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Post notification to Flutter about updated dimensions
            let bounds = UIScreen.main.bounds
            let safeAreaInsets = self.getSafeAreaInsets()
            methodChannel.invokeMethod("dimensionsChanged", arguments: [
                "width": bounds.width,
                "height": bounds.height,
                "scale": UIScreen.main.scale,
                "statusBarHeight": UIApplication.shared.statusBarFrame.height,
                "safeAreaTop": safeAreaInsets.top,
                "safeAreaBottom": safeAreaInsets.bottom,
                "safeAreaLeft": safeAreaInsets.left,
                "safeAreaRight": safeAreaInsets.right
            ])
            
            print("📱 Notified Flutter of screen dimension change: \(bounds.width)x\(bounds.height)")
        }
    }
    
    // Get current screen width
    var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    // Get current screen height
    var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    // Get safe area insets
    private func getSafeAreaInsets() -> UIEdgeInsets {
        if #available(iOS 11.0, *) {
            // Get the key window
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            
            return keyWindow?.safeAreaInsets ?? UIEdgeInsets.zero
        } else {
            // Fallback for iOS 10 and earlier
            return UIEdgeInsets.zero
        }
    }
}
