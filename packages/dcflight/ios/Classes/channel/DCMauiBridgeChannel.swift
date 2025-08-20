
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
        // Create method channel
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.bridge",
            binaryMessenger: binaryMessenger
        )
        
        // Create hot restart detection channel
        hotRestartChannel = FlutterMethodChannel(
            name: "dcflight/hot_restart",
            binaryMessenger: binaryMessenger
        )
        
        // Set up method handlers
        methodChannel?.setMethodCallHandler(handleMethodCall)
        hotRestartChannel?.setMethodCallHandler(handleHotRestartMethodCall)
        
    }
    
    /// Handle method calls from Flutter
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        // Get the arguments
        let args = call.arguments as? [String: Any]
        
        // Handle methods
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
            
        case "commitBatchUpdate":
            if let args = args {
                handleCommitBatchUpdate(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }
            
        // REMOVED: callComponentMethod - replaced with prop-based commands
        // Components now handle imperative operations through command props
        // Some calls don't need to involve VDOM, use tunnel
        case "tunnel":
            if let args = args {
                handleTunnel(args, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Arguments cannot be null", details: nil))
            }

    // Universal tunnel handler
     func handleTunnel(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let componentType = args["componentType"] as? String,
              let method = args["method"] as? String,
              let params = args["params"] as? [String: Any] else {
            result(FlutterError(code: "TUNNEL_ERROR", message: "Invalid tunnel parameters", details: nil))
            return
        }
        
        print("🚇 iOS Bridge: Tunneling \(method) to \(componentType)")
        
        // Execute on main thread
        DispatchQueue.main.async {
            // ✅ Use component registry to find component class
            guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
                result(FlutterError(code: "COMPONENT_NOT_FOUND", message: "Component \(componentType) not registered", details: nil))
                return
            }
            
            // ✅ Call tunnel method on component class
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
    
    // Initialize the bridge
    private func handleInitialize(result: @escaping FlutterResult) {
        
        // Execute on main thread
        DispatchQueue.main.async {
            // Initialize components and systems
            let success = DCMauiBridgeImpl.shared.initialize()
            result(success)
        }
    }
    
    // Create a view
    private func handleCreateView(_ args: [String: Any], result: @escaping FlutterResult) {
        
        guard let viewId = args["viewId"] as? String,
              let viewType = args["viewType"] as? String,
              let props = args["props"] as? [String: Any] else {
            result(FlutterError(code: "CREATE_ERROR", message: "Invalid view creation parameters", details: nil))
            return
        }
        
        // Convert props to JSON
        guard let propsData = try? JSONSerialization.data(withJSONObject: props),
              let propsJson = String(data: propsData, encoding: .utf8) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize props", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.createView(viewId: viewId, viewType: viewType, propsJson: propsJson)
            result(success)
        }
    }

    // Update a view
    private func handleUpdateView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String,
              let props = args["props"] as? [String: Any] else {
            result(FlutterError(code: "UPDATE_ERROR", message: "Invalid view update parameters", details: nil))
            return
        }
        
        // Convert props to JSON
        guard let propsData = try? JSONSerialization.data(withJSONObject: props),
              let propsJson = String(data: propsData, encoding: .utf8) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize props", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.updateView(viewId: viewId, propsJson: propsJson)
            result(success)
        }
    }
    
    // Delete a view
    private func handleDeleteView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String else {
            result(FlutterError(code: "DELETE_ERROR", message: "Invalid view ID", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.deleteView(viewId: viewId)
            result(success)
        }
    }
    
    // Detach a view (new method)
    private func handleDetachView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String else {
            result(FlutterError(code: "DETACH_ERROR", message: "Invalid view ID", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.detachView(childId: viewId)
            result(success)
        }
    }
    
    // Attach a view to a parent
    private func handleAttachView(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let childId = args["childId"] as? String,
              let parentId = args["parentId"] as? String,
              let index = args["index"] as? Int else {
            result(FlutterError(code: "ATTACH_ERROR", message: "Invalid view attachment parameters", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.attachView(childId: childId, parentId: parentId, index: index)
            result(success)
        }
    }
    
    // Set children for a view
    private func handleSetChildren(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let viewId = args["viewId"] as? String,
              let childrenIds = args["childrenIds"] as? [String] else {
            result(FlutterError(code: "CHILDREN_ERROR", message: "Invalid children parameters", details: nil))
            return
        }
        
        // Convert children to JSON
        guard let childrenData = try? JSONSerialization.data(withJSONObject: childrenIds),
              let childrenJson = String(data: childrenData, encoding: .utf8) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize children", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            let success = DCMauiBridgeImpl.shared.setChildren(viewId: viewId, childrenJson: childrenJson)
            result(success)
        }
    }
    
    // Handle batch updates
    private func handleCommitBatchUpdate(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let updates = args["updates"] as? [[String: Any]] else {
            result(FlutterError(code: "BATCH_ERROR", message: "Invalid batch update parameters", details: nil))
            return
        }
        
        // Execute on main thread
        DispatchQueue.main.async {
            var allSucceeded = true
            
            for update in updates {
                if let operation = update["operation"] as? String {
                    switch operation {
                    case "createView":
                        if let viewId = update["viewId"] as? String,
                           let viewType = update["viewType"] as? String,
                           let props = update["props"] as? [String: Any],
                           let propsData = try? JSONSerialization.data(withJSONObject: props),
                           let propsJson = String(data: propsData, encoding: .utf8) {
                            let success = DCMauiBridgeImpl.shared.createView(viewId: viewId, viewType: viewType, propsJson: propsJson)
                            if !success {
                                allSucceeded = false
                            }
                        }
                    case "updateView":
                        if let viewId = update["viewId"] as? String,
                           let props = update["props"] as? [String: Any],
                           let propsData = try? JSONSerialization.data(withJSONObject: props),
                           let propsJson = String(data: propsData, encoding: .utf8) {
                            let success = DCMauiBridgeImpl.shared.updateView(viewId: viewId, propsJson: propsJson)
                            if !success {
                                allSucceeded = false
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            result(allSucceeded)
        }
    }
    
    /// Handle hot restart detection method calls
    func handleHotRestartMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch call.method {
        case "getSessionToken":
            result(DCMauiBridgeMethodChannel.sessionToken)
            
        case "createSessionToken":
            // Create a new session token with timestamp
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
        
        // Clean up DCMauiBridgeImpl views (preserves root)
        DCMauiBridgeImpl.shared.cleanupForHotRestart()
        
        // Clear the view registry (preserves root)
        ViewRegistry.shared.clearAll()
        
        // Reset Yoga shadow tree (preserves root)
        YogaShadowTree.shared.clearAll()
        
        // Reset layout manager (preserves root)
        DCFLayoutManager.shared.clearAll()
        
    }
    
    /// Helper to get a view by ID
    func getViewById(_ viewId: String) -> UIView? {
        // First try our local views dictionary
        if let view = views[viewId] {
            return view
        }
        
        // Then try DCMauiFFIBridge's views
        if let view = DCMauiBridgeImpl.shared.views[viewId] {
            return view
        }
        
        // Finally try ViewRegistry
        return ViewRegistry.shared.getView(id: viewId)
    }
}

// MARK: - Registry Extensions for Cleanup
extension ViewRegistry {
    func clearAll() {
        // Remove all views from their superviews EXCEPT the root view
        for (viewId, viewInfo) in registry {
            if viewId != "root" { // Don't remove root view from hierarchy
                viewInfo.view.removeFromSuperview()
            } else {
                // Clear only the children of the root view, not the root itself
                let rootView = viewInfo.view
                for subview in rootView.subviews {
                    subview.removeFromSuperview()
                }
            }
        }
        
        // Clear the registry EXCEPT for the root view
        let nonRootViews = registry.filter { $0.key != "root" }
        for (viewId, _) in nonRootViews {
            registry.removeValue(forKey: viewId)
        }
    }
}

extension YogaShadowTree {
    func clearAll() {
        // Use existing removeNode method for each node to ensure proper cleanup
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
        // Clear all view registrations using existing methods EXCEPT root
        let allViewIds = Array(viewRegistry.keys)
        for viewId in allViewIds {
            if viewId != "root" { // Preserve root view in layout manager
                cleanUp(viewId: viewId)
            }
        }
    }
}

