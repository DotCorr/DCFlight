/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import Flutter
import UIKit

/// Handles layout method channel interactions between Flutter and native code
public class DCMauiLayoutMethodHandler: NSObject {
    /// Singleton instance
    public static let shared = DCMauiLayoutMethodHandler()
    let frame = UIScreen.main.bounds;
    
    /// Method channel for layout operations
    var methodChannel: FlutterMethodChannel?
    
    /// Initialize with Flutter binary messenger
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        // Create method channel
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.layout",
            binaryMessenger: binaryMessenger
        )
        
        // Set up method handler
        methodChannel?.setMethodCallHandler(handleMethodCall)
        
    }
    
    /// Handle method calls from Flutter
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Handle methods - layout channel supports both incoming and outgoing messages
        switch call.method {
        case "getScreenDimensions":
            handleGetScreenDimensions(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // Get screen dimensions
    private func handleGetScreenDimensions(result: @escaping FlutterResult) {
        let bounds = UIScreen.main.bounds
        let dimensions = [
            "width": bounds.width,
            "height": bounds.height,
            "scale": UIScreen.main.scale,
            "statusBarHeight": UIApplication.shared.statusBarFrame.height
        ]
        
        result(dimensions)
    }
}
