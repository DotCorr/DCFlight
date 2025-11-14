
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
    var views = [Int: UIView]()
    
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
        
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        guard let viewId = viewId,
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
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        guard let viewId = viewId,
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
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        guard let viewId = viewId else {
            result(FlutterError(code: "DELETE_ERROR", message: "Invalid view ID", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.deleteView(viewId: viewId)
            result(success)
        }
    }
    
    private func handleDetachView(_ args: [String: Any], result: @escaping FlutterResult) {
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        guard let viewId = viewId else {
            result(FlutterError(code: "DETACH_ERROR", message: "Invalid view ID", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.detachView(childId: viewId)
            result(success)
        }
    }
    
    private func handleAttachView(_ args: [String: Any], result: @escaping FlutterResult) {
        let childId: Int?
        if let childIdInt = args["childId"] as? Int {
            childId = childIdInt
        } else if let childIdNum = args["childId"] as? NSNumber {
            childId = childIdNum.intValue
        } else {
            childId = nil
        }
        
        let parentId: Int?
        if let parentIdInt = args["parentId"] as? Int {
            parentId = parentIdInt
        } else if let parentIdNum = args["parentId"] as? NSNumber {
            parentId = parentIdNum.intValue
        } else {
            parentId = nil
        }
        
        guard let childId = childId,
              let parentId = parentId,
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
        let viewId: Int?
        if let viewIdInt = args["viewId"] as? Int {
            viewId = viewIdInt
        } else if let viewIdNum = args["viewId"] as? NSNumber {
            viewId = viewIdNum.intValue
        } else {
            viewId = nil
        }
        
        let childrenIds: [Int]?
        if let childrenIdsInt = args["childrenIds"] as? [Int] {
            childrenIds = childrenIdsInt
        } else if let childrenIdsNum = args["childrenIds"] as? [NSNumber] {
            childrenIds = childrenIdsNum.map { $0.intValue }
        } else {
            childrenIds = nil
        }
        
        guard let viewId = viewId,
              let childrenIds = childrenIds else {
            result(FlutterError(code: "CHILDREN_ERROR", message: "Invalid children parameters", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.setChildren(viewId: viewId, childrenIds: childrenIds)
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
    
    /// Cleanup all DCFlight native views and resources for hot restart.
    /// 
    /// This method performs cleanup in a specific order to prevent layout stacking:
    /// 1. Cancels all pending layout work to prevent stale calculations
    /// 2. Clears YogaShadowTree root children to prevent layout stacking
    /// 3. Cleans up all views through DCMauiBridgeImpl
    /// 4. Clears ViewRegistry, DCFLayoutManager, and local views dictionary
    private func cleanupNativeViews() {
        // Cancel layout timers first to prevent stale layout calculations
        DCFLayoutManager.shared.cancelAllPendingLayoutWork()
        
        // Clear YogaShadowTree root children to prevent stacking after hot restart
        YogaShadowTree.shared.clearAll()
        
        // Cleanup views through bridge implementation
        DCMauiBridgeImpl.shared.cleanupForHotRestart()
        
        // Clear all registries and dictionaries
        ViewRegistry.shared.clearAll()
        DCFLayoutManager.shared.clearAll()
        views.removeAll()
    }
    
    /// Helper to get a view by ID
    func getViewById(_ viewId: Int) -> UIView? {
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
            if viewId != 0 { // Don't remove root view from hierarchy
                viewInfo.view.removeFromSuperview()
            } else {
                let rootView = viewInfo.view
                for subview in rootView.subviews {
                    subview.removeFromSuperview()
                }
            }
        }
        
        let nonRootViews = registry.filter { $0.key != 0 }
        for (viewId, _) in nonRootViews {
            registry.removeValue(forKey: viewId)
        }
    }
}

extension YogaShadowTree {
    /// Clears all nodes from the shadow tree except the root node.
    /// 
    /// This method is used during hot restart cleanup to prevent layout stacking.
    /// It removes all non-root nodes, clears root node children, resets root dimensions
    /// to current window bounds, and clears all parent mappings.
    func clearAll() {
        // Remove all non-root nodes
        let nodeIds = Array(nodes.keys)
        for nodeId in nodeIds {
            if nodeId != "root" {
                removeNode(nodeId: nodeId)
            }
        }
        
        // Clear root node's children to prevent stacking after hot restart
        // The root node might still have old children attached, causing layout issues
        clearRootNodeChildren()
        
        // Reset root node dimensions to current window bounds
        let windowBounds: CGRect
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            windowBounds = window.bounds
        } else {
            windowBounds = UIScreen.main.bounds
        }
        resetRootNodeDimensions(width: Float(windowBounds.width), height: Float(windowBounds.height))
        
        // Clear all parent mappings
        nodeParents.removeAll()
    }
}

extension DCFLayoutManager {
    func clearAll() {
        let allViewIds = Array(viewRegistry.keys)
        for viewId in allViewIds {
            if viewId != 0 { // Preserve root view in layout manager
                cleanUp(viewId: viewId)
            }
        }
    }
}

