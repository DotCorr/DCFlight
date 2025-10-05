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
    
    // Singleton instance
    @objc static let shared = DCMauiBridgeImpl()
    
    // Dictionary to hold view references
    internal var views = [String: UIView]()
    
    // Track parent-child relationships for proper cleanup
    private var viewHierarchy = [String: [String]]() // parent ID -> child IDs
    private var childToParent = [String: String]() // child ID -> parent ID
    
    // Private initializer for singleton
    private override init() {
        super.init()
    }
    
    // MARK: - Public Registration Methods
    
    /// Register a pre-existing view with the bridge
    @objc func registerView(_ view: UIView, withId viewId: String) {
        views[viewId] = view
        ViewRegistry.shared.registerView(view, id: viewId, type: "View")
        DCFLayoutManager.shared.registerView(view, withId: viewId)
    }
    
    /// Initialize the framework
    @objc func initialize() -> Bool {
        
        // Check if root view exists already
        if let rootView = views["root"] {
            
            // Ensure the root view is registered with the shadow tree
            if YogaShadowTree.shared.nodes["root"] == nil {
                YogaShadowTree.shared.createNode(id: "root", componentType: "View")
            }
        } else {
        }
        
        return true
    }
    
    /// Create a view with properties
    @objc func createView(viewId: String, viewType: String, propsJson: String) -> Bool {
        
        // Parse props JSON
        guard let propsData = propsJson.data(using: .utf8),
              let props = try? JSONSerialization.jsonObject(with: propsData, options: []) as? [String: Any] else {
            return false
        }
        
        
        // Use the unified view manager for creation
        let success = DCFViewManager.shared.createView(viewId: viewId, viewType: viewType, props: props)
        
        // Also store in our local registry for compatibility
        if success, let view = ViewRegistry.shared.getView(id: viewId) {
            views[viewId] = view
        } else if success {
        }
        
        return success
    }
    
    /// Update a view's properties
    @objc func updateView(viewId: String, propsJson: String) -> Bool {
        
        // Parse props JSON
        guard let propsData = propsJson.data(using: .utf8),
              let props = try? JSONSerialization.jsonObject(with: propsData, options: []) as? [String: Any] else {
            return false
        }
        
        // Use the unified view manager for updates
        return DCFViewManager.shared.updateView(viewId: viewId, props: props)
    }
    
    /// Delete a view
    @objc func deleteView(viewId: String) -> Bool {
        
        // Use the unified view manager for deletion
        let success = DCFViewManager.shared.deleteView(viewId: viewId)
        
        // Also clean up from our local registry
        if success {
            // First, recursively delete all children
            deleteChildrenRecursively(parentId: viewId)
            
            // Remove from local view registry
            if let view = views[viewId] {
                view.removeFromSuperview()
                views.removeValue(forKey: viewId)
            }
            
            // Clean up hierarchy tracking
            cleanupHierarchyReferences(viewId: viewId)
        }
        
        return success
    }
    
    /// Recursively delete all children of a view
    private func deleteChildrenRecursively(parentId: String) {
        // Get children for this parent
        guard let children = viewHierarchy[parentId], !children.isEmpty else {
            return
        }
        
        
        // Make a copy to avoid modification during iteration
        let childrenCopy = children
        
        // Process each child
        for childId in childrenCopy {
            // Recursively delete grandchildren first
            deleteChildrenRecursively(parentId: childId)
            
            // Now delete the child view
            if let childView = self.views[childId] {
                childView.removeFromSuperview()
                
                // Remove from registries
                self.views.removeValue(forKey: childId)
                ViewRegistry.shared.removeView(id: childId)
                YogaShadowTree.shared.removeNode(nodeId: childId)
                DCFLayoutManager.shared.unregisterView(withId: childId)
                
            }
            
            // Update tracking
            childToParent.removeValue(forKey: childId)
        }
        
        // Clear the children array for this parent
        viewHierarchy[parentId] = []
    }
    
    /// Clean up any orphaned children if parent is no longer in registry
    private func cleanupOrphanedChildren(parentId: String) {
        // Check if we have children records for this parent
        guard let children = viewHierarchy[parentId], !children.isEmpty else {
            return
        }
        
        
        // Make a copy to avoid modification during iteration
        let childrenCopy = children
        
        // Process each child
        for childId in childrenCopy {
            // Recursively delete grandchildren first
            deleteChildrenRecursively(parentId: childId)
            
            // Now delete the child view from registries
            if let childView = self.views[childId] {
                childView.removeFromSuperview()
                self.views.removeValue(forKey: childId)
            }
            ViewRegistry.shared.removeView(id: childId)
            YogaShadowTree.shared.removeNode(nodeId: childId)
            DCFLayoutManager.shared.unregisterView(withId: childId)
            
            
            // Update tracking
            childToParent.removeValue(forKey: childId)
        }
        
        // Remove the parent from hierarchy tracking
        viewHierarchy.removeValue(forKey: parentId)
    }
    
    /// Attach a child view to a parent view
    @objc func attachView(childId: String, parentId: String, index: Int) -> Bool {
        
        // Use the unified view manager for attachment
        let success = DCFViewManager.shared.attachView(childId: childId, parentId: parentId, index: index)
        
        // Update our local hierarchy tracking for compatibility
        if success {
            if viewHierarchy[parentId] == nil {
                viewHierarchy[parentId] = []
            }
            
            // Remove from current parent if exists
            if let currentParent = childToParent[childId] {
                viewHierarchy[currentParent]?.removeAll { $0 == childId }
            }
            
            // Add to new parent
            if !viewHierarchy[parentId]!.contains(childId) {
                viewHierarchy[parentId]!.append(childId)
            }
            
            childToParent[childId] = parentId
        }
        
        return success
    }
    
    /// Set all children for a view
    @objc func setChildren(viewId: String, childrenJson: String) -> Bool {
        
        // Parse children JSON
        guard let childrenData = childrenJson.data(using: .utf8),
              let childrenIds = try? JSONSerialization.jsonObject(with: childrenData, options: []) as? [String] else {
            return false
        }
        
        // Get the parent view
        guard let parentView = self.views[viewId] else {
            return false
        }
        
        // Handle children normally for all components
        return setChildrenNormally(parentView: parentView, viewId: viewId, childrenIds: childrenIds)
    }
    
    /// Handle children for normal (non-present) components
    private func setChildrenNormally(parentView: UIView, viewId: String, childrenIds: [String]) -> Bool {
        // Remove all existing children from tracking that are not in new list
        let oldChildren = viewHierarchy[viewId] ?? []
        for oldChildId in oldChildren {
            if !childrenIds.contains(oldChildId) {
                childToParent.removeValue(forKey: oldChildId)
            }
        }
        
        // Reset children array
        viewHierarchy[viewId] = childrenIds
        
        // Update child->parent mapping
        for childId in childrenIds {
            childToParent[childId] = viewId
        }
        
        // Remove all existing subviews
        for subview in parentView.subviews {
            subview.removeFromSuperview()
        }
        
        // Add children in order
        for (index, childId) in childrenIds.enumerated() {
            if let childView = self.views[childId] {
                parentView.insertSubview(childView, at: index)
                
                // Update shadow tree
                DCFLayoutManager.shared.addChildNode(parentId: viewId, childId: childId, index: index)
            }
        }
        
        return true
    }
    
    // REMOVED: updateViewLayout and calculateLayout methods
    // Layout is now handled automatically by DCFLayoutManager when layout props change
    
    /// Detach a view from its parent
    @objc func detachView(childId: String) -> Bool {
        
        guard let childView = self.views[childId] else {
            return false
        }
        
        // Remove view from its parent
        childView.removeFromSuperview()
        
        // Update parent-child tracking
        if let parentId = childToParent[childId] {
            viewHierarchy[parentId]?.removeAll(where: { $0 == childId })
        }
        childToParent.removeValue(forKey: childId)
        
        // Note: We don't remove from views or other registries since we're just detaching
        
        return true
    }
    
    // MARK: - Helper Methods
    
    /// Extract layout properties from props dictionary
    private func extractLayoutProps(from props: [String: Any]) -> [String: Any] {
        let layoutPropKeys = SupportedLayoutsProps.supportedLayoutProps
        return props.filter { layoutPropKeys.contains($0.key) }
    }
    
    /// Clean up hierarchy references for a view
    private func cleanupHierarchyReferences(viewId: String) {
        // Remove from parent's children list
        if let parentId = childToParent[viewId] {
            viewHierarchy[parentId]?.removeAll(where: { $0 == viewId })
        }
        
        // Remove from child->parent mapping
        childToParent.removeValue(forKey: viewId)
        
        // Remove from parent->children mapping
        viewHierarchy.removeValue(forKey: viewId)
    }
    
    // Get children of a view
    @objc func getChildrenIds(viewId: String) -> [String] {
        return viewHierarchy[viewId] ?? []
    }
    
    // Get parent of a view
    @objc func getParentId(childId: String) -> String? {
        return childToParent[childId]
    }
    
    // Print hierarchy for debugging
    @objc func printHierarchy() {
        for (parentId, childrenIds) in viewHierarchy {
        }
    }
    
    // MARK: - Hot Restart Support
    
    /// Clean up all views except root view for hot restart
    @objc func cleanupForHotRestart() {
        
        // Remove all non-root views from registry
        let nonRootViews = views.filter { $0.key != "root" }
        for (viewId, view) in nonRootViews {
            view.removeFromSuperview()
            views.removeValue(forKey: viewId)
        }
        
        // Clear root view's children but preserve root
        if let rootView = views["root"] {
            for subview in rootView.subviews {
                subview.removeFromSuperview()
            }
        }
        
        // Clear hierarchy tracking except for root
        let nonRootHierarchy = viewHierarchy.filter { $0.key != "root" }
        for (parentId, _) in nonRootHierarchy {
            viewHierarchy.removeValue(forKey: parentId)
        }
        
        // Clear child-to-parent mappings for non-root views
        let nonRootChildMappings = childToParent.filter { $0.value != "root" && $0.key != "root" }
        for (childId, _) in nonRootChildMappings {
            childToParent.removeValue(forKey: childId)
        }
        
        // Reset root's children list but keep root entry
        viewHierarchy["root"] = []
        
    }
    
    // MARK: - Batch Update Support (React-like atomic rendering)
    
    /// Start a batch update (no-op on iOS, kept for compatibility)
    @objc func startBatchUpdate() -> Bool {
        print("🔥 iOS_BRIDGE: startBatchUpdate called")
        return true
    }
    
    /// Commit a batch of operations atomically
    @objc func commitBatchUpdate(updates: [[String: Any]]) -> Bool {
        NSLog("🚨🚨🚨 iOS_BRIDGE: COMMIT BATCH UPDATE CALLED WITH %d UPDATES", updates.count)
        print("🔥 iOS_BRIDGE: commitBatchUpdate called with \(updates.count) updates")
        
        // Collect operations by type
        var createOps: [(viewId: String, viewType: String, props: [String: Any])] = []
        var updateOps: [(viewId: String, props: [String: Any])] = []
        var attachOps: [(childId: String, parentId: String, index: Int)] = []
        var eventOps: [(viewId: String, eventTypes: [String])] = []
        
        // Phase 1: Parse all operations
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
        
        // Phase 2: Execute all operations atomically
        do {
            // 1. Create all views first
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
            
            // 2. Update all view props
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
            
            // 3. Attach all views to build tree structure
            for op in attachOps {
                print("🔥 iOS_BATCH_COMMIT: Attaching \(op.childId) to \(op.parentId)")
                if !attachView(childId: op.childId, parentId: op.parentId, index: op.index) {
                    print("❌ Failed to attach \(op.childId) to \(op.parentId)")
                    return false
                }
            }
            
            // 4. Register event listeners AFTER all views exist
            for op in eventOps {
                print("🔥 iOS_BATCH_COMMIT: Registering event listeners for \(op.viewId)")
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(viewId: op.viewId, eventTypes: op.eventTypes)
            }
            
            // 5. REACT-LIKE: Layout calculation happens ONCE for entire tree
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


