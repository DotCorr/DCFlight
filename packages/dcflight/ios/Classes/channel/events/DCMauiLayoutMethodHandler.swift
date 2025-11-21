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
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.layout",
            binaryMessenger: binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler(handleMethodCall)
        
    }
    
    /// Handle method calls from Flutter
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getScreenDimensions":
            handleGetScreenDimensions(result: result)
            
        case "setUseWebDefaults":
            handleSetUseWebDefaults(call: call, result: result)
            
        case "setLayoutAnimationEnabled":
            handleSetLayoutAnimationEnabled(call: call, result: result)
            
        case "getLayoutAnimationEnabled":
            handleGetLayoutAnimationEnabled(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
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
    
    private func handleSetLayoutAnimationEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "ARGS_ERROR",
                message: "setLayoutAnimationEnabled requires 'enabled' boolean parameter",
                details: nil
            ))
            return
        }
        
        let duration = (args["duration"] as? NSNumber)?.doubleValue ?? 0.3
        
        DispatchQueue.main.async {
            DCFLayoutManager.shared.layoutAnimationEnabled = enabled
            if enabled {
                DCFLayoutManager.shared.layoutAnimationDuration = duration
            }
            result(true)
        }
    }
    
    private func handleGetLayoutAnimationEnabled(result: @escaping FlutterResult) {
        result([
            "enabled": DCFLayoutManager.shared.layoutAnimationEnabled,
            "duration": DCFLayoutManager.shared.layoutAnimationDuration
        ])
    }
    
    private func handleSetUseWebDefaults(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                              message: "setUseWebDefaults requires 'enabled' boolean parameter", 
                              details: nil))
            return
        }
        
        DCFLayoutManager.shared.setUseWebDefaults(enabled)
        result(true)
    }
}
