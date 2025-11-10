
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Flutter
import UIKit

/// Handles bridge method channel interactions between Flutter and native code
class DCMauiBridgeMethodChannel: NSObject {
    /// Singleton instance
    static let shared = DCMauiBridgeMethodChannel()
    
    /// Method channel for bridge operations
    var methodChannel: FlutterMethodChannel?
    
    /// Hot restart detection channel
    var hotRestartChannel: FlutterMethodChannel?
    
    /// Static session token for hot restart detection - survives Dart hot restarts
    private static var sessionToken: String?
    
    /// Views dictionary for compatibility
    var views = [String: UIView]()
    
    func initialize() {
    }
    
    /// Initialize with Flutter binary messenger
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.bridge",
            binaryMessenger: binaryMessenger
        )
        
        hotRestartChannel = FlutterMethodChannel(
            name: "dcflight/hot_restart",
            binaryMessenger: binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler(handleMethodCall)
        hotRestartChannel?.setMethodCallHandler(handleHotRestartMethodCall)
        
    }
    
    /// Handle method calls from Flutter
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        let args = call.arguments as? [String: Any]
        
        switch call.method {
        case "initialize":
            handleInitialize(result: result)
            
        case "createView":
            if let args = args {
                handleCreateView(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "updateView":
            if let args = args {
                handleUpdateView(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "deleteView":
            if let args = args {
                handleDeleteView(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "attachView":
            if let args = args {
                handleAttachView(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "detachView":
            if let args = args {
                handleDetachView(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "setChildren":
            if let args = args {
                handleSetChildren(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "startBatchUpdate":
            handleStartBatchUpdate(result: result)
            
        case "commitBatchUpdate":
            if let args = args {
                handleCommitBatchUpdate(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        case "cancelBatchUpdate":
            handleCancelBatchUpdate(result: result)
            
        case "tunnel":
            if let args = args {
                handleTunnel(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }

     func handleTunnel(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let componentType = args["componentType"] as? String,
              let method = args["method"] as? String,
              let params = args["params"] as? [String: Any] else {
            result(FlutterError(code: "TUNNEL_ERROR", message: "Invalid tunnel parameters", details: nil))
            return
        }
        
        print("🚇 iOS Bridge: Tunneling \(method) to \(componentType)")
        
        DispatchQueue.main.async {
            guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
                result(FlutterError(code: "COMPONENT_NOT_FOUND", message: "Component \(componentType) not registered", details: nil))
                return
            }
            
            if let response = componentClass.handleTunnelMethod(method, params: params) {
                result(response)
            } else {
                result(FlutterError(code: "METHOD_NOT_FOUND", message: "Method \(method) not found on \(componentType)", details: nil))
            }
        }
    }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleInitialize(result: @escaping FlutterResult) {
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.initialize()
            result(success)
        }
    }
    
    private func handleCreateView(_ args: [String: Any], result: @escaping FlutterResult) {
        
        guard let viewId = args["viewId"] as? String,
              let viewType = args["viewType"] as? String,
              let props = args["props"] as? [String: Any] else {
            result(FlutterError(code: "CREATE_ERROR", message: "Invalid view creation parameters", details: nil))
            return
        }
        
        guard let propsData = try? JSONSerialization.data(withJSONObject: props),
              let propsJson = String(data: propsData, encoding: .utf8) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize props", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.createView(viewId: viewId, viewType: viewType, propsJson: propsJson)
            result(success)
        }
    }

    private func handleUpdateView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String,
              let props = args["props"] as? [String: Any] else {
            result(FlutterError(code: "UPDATE_ERROR", message: "Invalid view update parameters", details: nil))
            return
        }
        
        guard let propsData = try? JSONSerialization.data(withJSONObject: props),
              let propsJson = String(data: propsData, encoding: .utf8) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize props", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.updateView(viewId: viewId, propsJson: propsJson)
            result(success)
        }
    }
    
    private func handleDeleteView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String else {
            result(FlutterError(code: "DELETE_ERROR", message: "Invalid view ID", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.deleteView(viewId: viewId)
            result(success)
        }
    }
    
    private func handleDetachView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String else {
            result(FlutterError(code: "DETACH_ERROR", message: "Invalid view ID", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.detachView(childId: viewId)
            result(success)
        }
    }
    
    private func handleAttachView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let childId = args["childId"] as? String,
              let parentId = args["parentId"] as? String,
              let index = args["index"] as? Int else {
            result(FlutterError(code: "ATTACH_ERROR", message: "Invalid view attachment parameters", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.attachView(childId: childId, parentId: parentId, index: index)
            result(success)
        }
    }
    
    private func handleSetChildren(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String,
              let childrenIds = args["childrenIds"] as? [String] else {
            result(FlutterError(code: "CHILDREN_ERROR", message: "Invalid children parameters", details: nil))
            return
        }
        
        guard let childrenData = try? JSONSerialization.data(withJSONObject: childrenIds),
              let childrenJson = String(data: childrenData, encoding: .utf8) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize children", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.setChildren(viewId: viewId, childrenJson: childrenJson)
            result(success)
        }
    }
    
    private func handleStartBatchUpdate(result: @escaping FlutterResult) {
        let success = DCMauiBridgeImpl.shared.startBatchUpdate()
        result(success)
    }
    
    private func handleCommitBatchUpdate(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let updates = args["updates"] as? [[String: Any]] else {
            result(FlutterError(code: "BATCH_ERROR", message: "Invalid batch update parameters", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.commitBatchUpdate(updates: updates)
            result(success)
        }
    }
    
    private func handleCancelBatchUpdate(result: @escaping FlutterResult) {
        let success = DCMauiBridgeImpl.shared.cancelBatchUpdate()
        result(success)
    }
    
    /// Handle hot restart detection method calls
    func handleHotRestartMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch call.method {
        case "getSessionToken":
            result(DCMauiBridgeMethodChannel.sessionToken)
            
        case "createSessionToken":
            let token = "dcf_session_\(Date().timeIntervalSince1970)"
            DCMauiBridgeMethodChannel.sessionToken = token
            result(token)
            
        case "cleanupViews":
            cleanupNativeViews()
            result(nil)
            
        case "clearSessionToken":
            DCMauiBridgeMethodChannel.sessionToken = nil
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Cleanup all DCFlight native views and resources
    private func cleanupNativeViews() {
        
        DCMauiBridgeImpl.shared.cleanupForHotRestart()
        
        ViewRegistry.shared.clearAll()
        
        YogaShadowTree.shared.clearAll()
        
        DCFLayoutManager.shared.clearAll()
        
        // CRITICAL: After hot restart cleanup, ensure root view frame is set and layout is recalculated
        // This prevents white screen on iOS during hot restart
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootView = DCMauiBridgeImpl.shared.views["root"] {
            // Set root view frame to window bounds
            rootView.frame = window.bounds
            rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            // Recalculate layout synchronously to prevent white screen
            let windowBounds = window.bounds
            print("🎯 DCFlight: Hot restart - Setting root view frame and recalculating layout: \(windowBounds.width)x\(windowBounds.height)")
            DCFScreenUtilities.shared.updateScreenDimensions(width: windowBounds.width, height: windowBounds.height)
            YogaShadowTree.shared.calculateAndApplyLayout(width: windowBounds.width, height: windowBounds.height)
        }
        
    }
    
    /// Helper to get a view by ID
    func getViewById(_ viewId: String) -> UIView? {
        if let view = views[viewId] {
            return view
        }
        
        if let view = DCMauiBridgeImpl.shared.views[viewId] {
            return view
        }
        
        return ViewRegistry.shared.getView(id: viewId)
    }
}

extension ViewRegistry {
    func clearAll() {
        for (viewId, viewInfo) in registry {
            if viewId != "root" { // Don't remove root view from hierarchy
                viewInfo.view.removeFromSuperview()
            } else {
                let rootView = viewInfo.view
                for subview in rootView.subviews {
                    subview.removeFromSuperview()
                }
            }
        }
        
        let nonRootViews = registry.filter { $0.key != "root" }
        for (viewId, _) in nonRootViews {
            registry.removeValue(forKey: viewId)
        }
    }
}

extension YogaShadowTree {
    func clearAll() {
        let nodeIds = Array(nodes.keys)
        for nodeId in nodeIds {
            if nodeId != "root" { // Don't remove root node
                removeNode(nodeId: nodeId)
            }
        }
    }
}

extension DCFLayoutManager {
    func clearAll() {
        let allViewIds = Array(viewRegistry.keys)
        for viewId in allViewIds {
            if viewId != "root" { // Preserve root view in layout manager
                cleanUp(viewId: viewId)
            }
        }
    }
}

