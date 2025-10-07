/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Foundation

/// Bridge between Dart FFI and native Swift/Objective-C code
/// Simplified version that focuses on core view operations
@objc class DCMauiBridgeImpl: NSObject {
    
    @objc static let shared = DCMauiBridgeImpl()
    
    internal var views = [String: UIView]()
    
    private var viewHierarchy = [String: [String]]() // parent ID -> child IDs
    private var childToParent = [String: String]() // child ID -> parent ID
    
    private override init() {
        super.init()
    }
    
    
    /// Register a pre-existing view with the bridge
    @objc func registerView(_ view: UIView, withId viewId: String) {
        views[viewId] = view
        ViewRegistry.shared.registerView(view, id: viewId, type: "View")
        DCFLayoutManager.shared.registerView(view, withId: viewId)
    }
    
    /// Initialize the framework
    @objc func initialize() -> Bool {
        
        if let rootView = views["root"] {
            
            if YogaShadowTree.shared.nodes["root"] == nil {
                YogaShadowTree.shared.createNode(id: "root", componentType: "View")
            }
        } else {
        }
        
        return true
    }
    
    /// Create a view with properties
    @objc func createView(viewId: String, viewType: String, propsJson: String) -> Bool {
        
        guard let propsData = propsJson.data(using: .utf8),
              let props = try? JSONSerialization.jsonObject(with: propsData, options: []) as? [String: Any] else {
            return false
        }
        
        
        let success = DCFViewManager.shared.createView(viewId: viewId, viewType: viewType, props: props)
        
        if success, let view = ViewRegistry.shared.getView(id: viewId) {
            views[viewId] = view
        } else if success {
        }
        
        return success
    }
    
    /// Update a view's properties
    @objc func updateView(viewId: String, propsJson: String) -> Bool {
        
        guard let propsData = propsJson.data(using: .utf8),
              let props = try? JSONSerialization.jsonObject(with: propsData, options: []) as? [String: Any] else {
            return false
        }
        
        return DCFViewManager.shared.updateView(viewId: viewId, props: props)
    }
    
    /// Delete a view
    @objc func deleteView(viewId: String) -> Bool {
        
        let success = DCFViewManager.shared.deleteView(viewId: viewId)
        
        if success {
            deleteChildrenRecursively(parentId: viewId)
            
            if let view = views[viewId] {
                view.removeFromSuperview()
                views.removeValue(forKey: viewId)
            }
            
            cleanupHierarchyReferences(viewId: viewId)
        }
        
        return success
    }
    
    /// Recursively delete all children of a view
    private func deleteChildrenRecursively(parentId: String) {
        guard let children = viewHierarchy[parentId], !children.isEmpty else {
            return
        }
        
        
        let childrenCopy = children
        
        for childId in childrenCopy {
            deleteChildrenRecursively(parentId: childId)
            
            if let childView = self.views[childId] {
                childView.removeFromSuperview()
                
                self.views.removeValue(forKey: childId)
                ViewRegistry.shared.removeView(id: childId)
                YogaShadowTree.shared.removeNode(nodeId: childId)
                DCFLayoutManager.shared.unregisterView(withId: childId)
                
            }
            
            childToParent.removeValue(forKey: childId)
        }
        
        viewHierarchy[parentId] = []
    }
    
    /// Clean up any orphaned children if parent is no longer in registry
    private func cleanupOrphanedChildren(parentId: String) {
        guard let children = viewHierarchy[parentId], !children.isEmpty else {
            return
        }
        
        
        let childrenCopy = children
        
        for childId in childrenCopy {
            deleteChildrenRecursively(parentId: childId)
            
            if let childView = self.views[childId] {
                childView.removeFromSuperview()
                self.views.removeValue(forKey: childId)
            }
            ViewRegistry.shared.removeView(id: childId)
            YogaShadowTree.shared.removeNode(nodeId: childId)
            DCFLayoutManager.shared.unregisterView(withId: childId)
            
            
            childToParent.removeValue(forKey: childId)
        }
        
        viewHierarchy.removeValue(forKey: parentId)
    }
    
    /// Attach a child view to a parent view
    @objc func attachView(childId: String, parentId: String, index: Int) -> Bool {
        
        let success = DCFViewManager.shared.attachView(childId: childId, parentId: parentId, index: index)
        
        if success {
            if viewHierarchy[parentId] == nil {
                viewHierarchy[parentId] = []
            }
            
            if let currentParent = childToParent[childId] {
                viewHierarchy[currentParent]?.removeAll { $0 == childId }
            }
            
            if !viewHierarchy[parentId]!.contains(childId) {
                viewHierarchy[parentId]!.append(childId)
            }
            
            childToParent[childId] = parentId
        }
        
        return success
    }
    
    /// Set all children for a view
    @objc func setChildren(viewId: String, childrenJson: String) -> Bool {
        
        guard let childrenData = childrenJson.data(using: .utf8),
              let childrenIds = try? JSONSerialization.jsonObject(with: childrenData, options: []) as? [String] else {
            return false
        }
        
        guard let parentView = self.views[viewId] else {
            return false
        }
        
        return setChildrenNormally(parentView: parentView, viewId: viewId, childrenIds: childrenIds)
    }
    
    /// Handle children for normal (non-present) components
    private func setChildrenNormally(parentView: UIView, viewId: String, childrenIds: [String]) -> Bool {
        let oldChildren = viewHierarchy[viewId] ?? []
        for oldChildId in oldChildren {
            if !childrenIds.contains(oldChildId) {
                childToParent.removeValue(forKey: oldChildId)
            }
        }
        
        viewHierarchy[viewId] = childrenIds
        
        for childId in childrenIds {
            childToParent[childId] = viewId
        }
        
        for subview in parentView.subviews {
            subview.removeFromSuperview()
        }
        
        for (index, childId) in childrenIds.enumerated() {
            if let childView = self.views[childId] {
                parentView.insertSubview(childView, at: index)
                
                DCFLayoutManager.shared.addChildNode(parentId: viewId, childId: childId, index: index)
            }
        }
        
        return true
    }
    
    
    /// Detach a view from its parent
    @objc func detachView(childId: String) -> Bool {
        
        guard let childView = self.views[childId] else {
            return false
        }
        
        childView.removeFromSuperview()
        
        if let parentId = childToParent[childId] {
            viewHierarchy[parentId]?.removeAll(where: { $0 == childId })
        }
        childToParent.removeValue(forKey: childId)
        
        
        return true
    }
    
    
    /// Extract layout properties from props dictionary
    private func extractLayoutProps(from props: [String: Any]) -> [String: Any] {
        let layoutPropKeys = SupportedLayoutsProps.supportedLayoutProps
        return props.filter { layoutPropKeys.contains($0.key) }
    }
    
    /// Clean up hierarchy references for a view
    private func cleanupHierarchyReferences(viewId: String) {
        if let parentId = childToParent[viewId] {
            viewHierarchy[parentId]?.removeAll(where: { $0 == viewId })
        }
        
        childToParent.removeValue(forKey: viewId)
        
        viewHierarchy.removeValue(forKey: viewId)
    }
    
    @objc func getChildrenIds(viewId: String) -> [String] {
        return viewHierarchy[viewId] ?? []
    }
    
    @objc func getParentId(childId: String) -> String? {
        return childToParent[childId]
    }
    
    @objc func printHierarchy() {
        for (parentId, childrenIds) in viewHierarchy {
        }
    }
    
    
    /// Clean up all views except root view for hot restart
    @objc func cleanupForHotRestart() {
        
        let nonRootViews = views.filter { $0.key != "root" }
        for (viewId, view) in nonRootViews {
            view.removeFromSuperview()
            views.removeValue(forKey: viewId)
        }
        
        if let rootView = views["root"] {
            for subview in rootView.subviews {
                subview.removeFromSuperview()
            }
        }
        
        let nonRootHierarchy = viewHierarchy.filter { $0.key != "root" }
        for (parentId, _) in nonRootHierarchy {
            viewHierarchy.removeValue(forKey: parentId)
        }
        
        let nonRootChildMappings = childToParent.filter { $0.value != "root" && $0.key != "root" }
        for (childId, _) in nonRootChildMappings {
            childToParent.removeValue(forKey: childId)
        }
        
        viewHierarchy["root"] = []
        
    }
    
    
    /// Start a batch update (no-op on iOS, kept for compatibility)
    @objc func startBatchUpdate() -> Bool {
        print("🔥 iOS_BRIDGE: startBatchUpdate called")
        return true
    }
    
    /// Commit a batch of operations atomically
    @objc func commitBatchUpdate(updates: [[String: Any]]) -> Bool {
        NSLog("🚨🚨🚨 iOS_BRIDGE: COMMIT BATCH UPDATE CALLED WITH %d UPDATES", updates.count)
        print("🔥 iOS_BRIDGE: commitBatchUpdate called with \(updates.count) updates")
        
        var createOps: [(viewId: String, viewType: String, props: [String: Any])] = []
        var updateOps: [(viewId: String, props: [String: Any])] = []
        var attachOps: [(childId: String, parentId: String, index: Int)] = []
        var eventOps: [(viewId: String, eventTypes: [String])] = []
        
        for operation in updates {
            guard let operationType = operation["operation"] as? String else {
                continue
            }
            
            switch operationType {
            case "createView":
                if let viewId = operation["viewId"] as? String,
                   let viewType = operation["viewType"] as? String,
                   let props = operation["props"] as? [String: Any] {
                    createOps.append((viewId, viewType, props))
                }
                
            case "updateView":
                if let viewId = operation["viewId"] as? String,
                   let props = operation["props"] as? [String: Any] {
                    updateOps.append((viewId, props))
                }
                
            case "attachView":
                if let childId = operation["childId"] as? String,
                   let parentId = operation["parentId"] as? String,
                   let index = operation["index"] as? Int {
                    attachOps.append((childId, parentId, index))
                }
                
            case "addEventListeners":
                if let viewId = operation["viewId"] as? String,
                   let eventTypes = operation["eventTypes"] as? [String] {
                    eventOps.append((viewId, eventTypes))
                }
                
            default:
                print("🔥 iOS_BRIDGE: Unknown operation type: \(operationType)")
            }
        }
        
        print("🔥 iOS_BRIDGE: Collected \(createOps.count) creates, \(updateOps.count) updates, \(attachOps.count) attaches, \(eventOps.count) event registrations")
        
        do {
            for op in createOps {
                print("🔥 iOS_BATCH_COMMIT: Creating \(op.viewId)")
                guard let propsData = try? JSONSerialization.data(withJSONObject: op.props),
                      let propsJson = String(data: propsData, encoding: .utf8) else {
                    print("❌ Failed to serialize props for \(op.viewId)")
                    return false
                }
                if !createView(viewId: op.viewId, viewType: op.viewType, propsJson: propsJson) {
                    print("❌ Failed to create view \(op.viewId)")
                    return false
                }
            }
            
            for op in updateOps {
                print("🔥 iOS_BATCH_COMMIT: Updating \(op.viewId)")
                guard let propsData = try? JSONSerialization.data(withJSONObject: op.props),
                      let propsJson = String(data: propsData, encoding: .utf8) else {
                    print("❌ Failed to serialize props for \(op.viewId)")
                    return false
                }
                if !updateView(viewId: op.viewId, propsJson: propsJson) {
                    print("❌ Failed to update view \(op.viewId)")
                    return false
                }
            }
            
            for op in attachOps {
                print("🔥 iOS_BATCH_COMMIT: Attaching \(op.childId) to \(op.parentId)")
                if !attachView(childId: op.childId, parentId: op.parentId, index: op.index) {
                    print("❌ Failed to attach \(op.childId) to \(op.parentId)")
                    return false
                }
            }
            
            for op in eventOps {
                print("🔥 iOS_BATCH_COMMIT: Registering event listeners for \(op.viewId)")
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(viewId: op.viewId, eventTypes: op.eventTypes)
            }
            
            print("🔥 iOS_BATCH_COMMIT: Triggering layout calculation")
            DCFLayoutManager.shared.calculateLayoutNow()
            print("🔥 iOS_BATCH_COMMIT: Layout calculation completed")
            
            print("🔥 iOS_BATCH_COMMIT: Successfully committed all operations atomically")
            return true
        } catch {
            print("❌ iOS_BATCH_COMMIT: Failed during atomic commit: \(error)")
            return false
        }
    }
    
    /// Cancel a batch update (no-op on iOS, kept for compatibility)
    @objc func cancelBatchUpdate() -> Bool {
        return true
    }
}


