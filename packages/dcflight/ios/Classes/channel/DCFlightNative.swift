/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Foundation

/// Native implementation for iOS view operations.
/// Called directly via FFI from Dart (no MethodChannel).
@objc public class DCFlightNative: NSObject {
    
    @objc public static let shared = DCFlightNative()
    
    internal var views = [Int: UIView]()
    
    private var viewHierarchy = [String: [String]]() // parent ID -> child IDs (String for YogaShadowTree)
    private var childToParent = [String: String]() // child ID -> parent ID (String for YogaShadowTree)
    
    private override init() {
        super.init()
    }
    
    
    /// Register a pre-existing view with the bridge
    @objc func registerView(_ view: UIView, withId viewId: Int) {
        views[viewId] = view
        ViewRegistry.shared.registerView(view, id: viewId, type: "View")
        DCFLayoutManager.shared.registerView(view, withId: viewId)
    }
    
    /// Initialize the framework
    @objc public func initialize() -> Bool {
        print("🔄 DCFlightNative: initialize() called")
        
        if let rootView = views[0] {
            print("✅ DCFlightNative: Root view found (viewId: 0)")
            if YogaShadowTree.shared.nodes["0"] == nil {
                YogaShadowTree.shared.createNode(id: "0", componentType: "View")
                print("✅ DCFlightNative: Created root node in YogaShadowTree")
            } else {
                print("✅ DCFlightNative: Root node already exists in YogaShadowTree")
            }
        } else {
            print("⚠️ DCFlightNative: No root view found (viewId: 0) - this is OK if root will be created later")
        }
        
        print("✅ DCFlightNative: initialize() completed successfully")
        return true
    }
    
    /// Create a view with properties
    @objc public func createView(viewId: Int, viewType: String, propsJson: String) -> Bool {
        
        // 🔥 CRITICAL FIX: Match Android behavior - check if view already exists
        // During hot reload, views are preserved but Dart may try to "create" them again
        // If view exists and is in hierarchy, update it instead of creating a new one
        if let existingView = ViewRegistry.shared.getView(id: viewId) {
            // Check if view is actually in the hierarchy - if not, delete and recreate
            if existingView.superview == nil {
                deleteView(viewId: viewId)
            } else {
                // View exists and is in hierarchy - update it instead of creating
                return updateView(viewId: viewId, propsJson: propsJson)
            }
        }
        
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
    @objc public func updateView(viewId: Int, propsJson: String) -> Bool {
        
        guard let propsData = propsJson.data(using: .utf8),
              let props = try? JSONSerialization.jsonObject(with: propsData, options: []) as? [String: Any] else {
            return false
        }
        
        return DCFViewManager.shared.updateView(viewId: viewId, props: props)
    }
    
    /// Delete a view
    @objc public func deleteView(viewId: Int) -> Bool {
        // 🔥 CRITICAL FIX: Stop animations before deleting to prevent freeze
        if let view = views[viewId] {
            // Stop animations for ReanimatedView components using runtime check
            // This avoids direct dependency on dcf_reanimated module
            if view.responds(to: Selector(("stopPureAnimation"))) {
                view.perform(Selector(("stopPureAnimation")))
                print("🛑 Stopped animation for ReanimatedView \(viewId) before deletion")
            }
        }
        
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
    private func deleteChildrenRecursively(parentId: Int) {
        let parentIdStr = String(parentId)
        guard let children = viewHierarchy[parentIdStr], !children.isEmpty else {
            return
        }
        
        
        let childrenCopy = children
        
        for childIdStr in childrenCopy {
            if let childId = Int(childIdStr) {
                deleteChildrenRecursively(parentId: childId)
                
                if let childView = self.views[childId] {
                    childView.removeFromSuperview()
                    
                    self.views.removeValue(forKey: childId)
                    ViewRegistry.shared.removeView(id: childId)
                    YogaShadowTree.shared.removeNode(nodeId: childIdStr)
                    DCFLayoutManager.shared.unregisterView(withId: childId)
                    
                }
            }
            
            childToParent.removeValue(forKey: childIdStr)
        }
        
        viewHierarchy[parentIdStr] = []
    }
    
    /// Clean up any orphaned children if parent is no longer in registry
    private func cleanupOrphanedChildren(parentId: Int) {
        let parentIdStr = String(parentId)
        guard let children = viewHierarchy[parentIdStr], !children.isEmpty else {
            return
        }
        
        
        let childrenCopy = children
        
        for childIdStr in childrenCopy {
            if let childId = Int(childIdStr) {
                deleteChildrenRecursively(parentId: childId)
                
                if let childView = self.views[childId] {
                    childView.removeFromSuperview()
                    self.views.removeValue(forKey: childId)
                }
                ViewRegistry.shared.removeView(id: childId)
                YogaShadowTree.shared.removeNode(nodeId: childIdStr)
                DCFLayoutManager.shared.unregisterView(withId: childId)
                
                
            }
            childToParent.removeValue(forKey: childIdStr)
        }
        
        viewHierarchy.removeValue(forKey: parentIdStr)
    }
    
    /// Attach a child view to a parent view
    @objc public func attachView(childId: Int, parentId: Int, index: Int) -> Bool {
        
        let success = DCFViewManager.shared.attachView(childId: childId, parentId: parentId, index: index)
        
        if success {
            let parentIdStr = String(parentId)
            let childIdStr = String(childId)
            if viewHierarchy[parentIdStr] == nil {
                viewHierarchy[parentIdStr] = []
            }
            
            if let currentParent = childToParent[childIdStr] {
                viewHierarchy[currentParent]?.removeAll { $0 == childIdStr }
            }
            
            if !viewHierarchy[parentIdStr]!.contains(childIdStr) {
                viewHierarchy[parentIdStr]!.append(childIdStr)
            }
            
            childToParent[childIdStr] = parentIdStr
        }
        
        return success
    }
    
    /// Set all children for a view
    @objc public func setChildren(viewId: Int, childrenIds: [Int]) -> Bool {
        
        guard let parentView = self.views[viewId] else {
            print("❌ setChildren: Parent view not found for viewId=\(viewId)")
            return false
        }
        
        print("🔍 setChildren: Checking for custom implementation - viewId=\(viewId), childrenIds.count=\(childrenIds.count), viewType=\(type(of: parentView))")
        
        //  Check if component has custom setChildren implementation
        if let viewInfo = ViewRegistry.shared.getViewInfo(id: viewId) {
            print("🔍 setChildren: Found viewInfo for viewId=\(viewId), type=\(viewInfo.type)")
            
            if let componentType = DCFComponentRegistry.shared.getComponentType(for: viewInfo.type) {
                print("🔍 setChildren: Found componentType for '\(viewInfo.type)'")
                
                // Get component instance from view (stored during createView)
                let componentInstanceKey = UnsafeRawPointer(bitPattern: "componentInstance".hashValue)!
                let componentInstance = objc_getAssociatedObject(parentView, componentInstanceKey) as? DCFComponent
                
                print("🔍 setChildren: Retrieving component instance - key=\(componentInstanceKey), found=\(componentInstance != nil), viewType=\(type(of: parentView))")
                
                if let componentInstance = componentInstance {
                    print("✅ setChildren: Found component instance for '\(viewInfo.type)'")
                    
                    // Get child views
                    let childViews = childrenIds.compactMap { self.views[$0] }
                    
                    print("📦 setChildren: Component '\(viewInfo.type)' has custom setChildren, routing \(childViews.count) children")
                    
                    // Call component's setChildren if it exists
                    if componentInstance.setChildren(parentView, childViews: childViews, viewId: String(viewId)) {
                        print("✅ setChildren: Component '\(viewInfo.type)' handled children routing")
                        // Update hierarchy tracking
                        let viewIdStr = String(viewId)
                        let childrenIdsStr = childrenIds.map { String($0) }
                        viewHierarchy[viewIdStr] = childrenIdsStr
                        for childIdStr in childrenIdsStr {
                            childToParent[childIdStr] = viewIdStr
                        }
                        
                        // Update layout manager
                        for (index, childId) in childrenIds.enumerated() {
                            DCFLayoutManager.shared.addChildNode(parentId: viewId, childId: childId, index: index)
                        }
                        
                        return true
                    } else {
                        print("❌ setChildren: Component '\(viewInfo.type)' setChildren returned false")
                    }
                } else {
                    print("❌ setChildren: Component instance not found on view for '\(viewInfo.type)'")
                }
            } else {
                print("❌ setChildren: Component type not found for '\(viewInfo.type)'")
            }
        } else {
            print("❌ setChildren: ViewInfo not found for viewId=\(viewId)")
        }
        
        // Fallback to normal implementation
        print("⚠️ setChildren: Falling back to normal implementation for viewId=\(viewId)")
        return setChildrenNormally(parentView: parentView, viewId: viewId, childrenIds: childrenIds)
    }
    
    /// Handle children for normal (non-present) components
    private func setChildrenNormally(parentView: UIView, viewId: Int, childrenIds: [Int]) -> Bool {
        let viewIdStr = String(viewId)
        let childrenIdsStr = childrenIds.map { String($0) }
        let oldChildren = viewHierarchy[viewIdStr] ?? []
        for oldChildIdStr in oldChildren {
            if !childrenIdsStr.contains(oldChildIdStr) {
                childToParent.removeValue(forKey: oldChildIdStr)
            }
        }
        
        viewHierarchy[viewIdStr] = childrenIdsStr
        
        for childIdStr in childrenIdsStr {
            childToParent[childIdStr] = viewIdStr
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
    @objc public func detachView(childId: Int) -> Bool {
        
        guard let childView = self.views[childId] else {
            return false
        }
        
        childView.removeFromSuperview()
        
        let childIdStr = String(childId)
        if let parentIdStr = childToParent[childIdStr] {
            viewHierarchy[parentIdStr]?.removeAll(where: { $0 == childIdStr })
        }
        childToParent.removeValue(forKey: childIdStr)
        
        
        return true
    }
    
    
    /// Extract layout properties from props dictionary
    private func extractLayoutProps(from props: [String: Any]) -> [String: Any] {
        let layoutPropKeys = SupportedLayoutsProps.supportedLayoutProps
        return props.filter { layoutPropKeys.contains($0.key) }
    }
    
    /// Clean up hierarchy references for a view
    private func cleanupHierarchyReferences(viewId: Int) {
        let viewIdStr = String(viewId)
        if let parentIdStr = childToParent[viewIdStr] {
            viewHierarchy[parentIdStr]?.removeAll(where: { $0 == viewIdStr })
        }
        
        childToParent.removeValue(forKey: viewIdStr)
        
        viewHierarchy.removeValue(forKey: viewIdStr)
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
    
    
    /// Cleans up all views except the root view for hot restart.
    /// 
    /// Removes all non-root views from the view hierarchy, clears root view's subviews,
    /// and resets all hierarchy tracking dictionaries. The root view is preserved.
    @objc public func cleanupForHotRestart() {
        print("🔥 DCFlightNative: Starting hot restart cleanup")

        // CRITICAL: Cancel all pending layout work first
        DCFLayoutManager.shared.cancelAllPendingLayoutWork()
        print("🔥 DCFlightNative: Layout manager cancelled pending work")

        // CRITICAL: Clear Yoga shadow tree (except root)
        YogaShadowTree.shared.clearAll()
        print("🔥 DCFlightNative: YogaShadowTree cleared")

        // CRITICAL: Clear view registry (except root) - same pattern as Android
        // Save root view info, clear all, then restore root
        let rootViewInfo = ViewRegistry.shared.registry[0]
        let allViewIds = Array(ViewRegistry.shared.registry.keys)
        for viewId in allViewIds {
            ViewRegistry.shared.removeView(id: viewId)
        }
        // Restore root view if it existed
        if let rootInfo = rootViewInfo {
            ViewRegistry.shared.registry[0] = rootInfo
            print("🔥 DCFlightNative: Preserved root view during cleanup")
        }
        print("🔥 DCFlightNative: ViewRegistry cleared (except root) - removed \(allViewIds.count - (rootViewInfo != nil ? 1 : 0)) views")

        // CRITICAL: Also clear DCFLayoutManager's view registry
        // DCFLayoutManager maintains its own view registry that needs to be cleared
        let layoutManagerViewIds = Array(DCFLayoutManager.shared.viewRegistry.keys)
        for viewId in layoutManagerViewIds {
            if viewId != 0 { // Keep root view
                DCFLayoutManager.shared.unregisterView(withId: viewId)
            }
        }
        print("🔥 DCFlightNative: DCFLayoutManager view registry cleared (except root) - removed \(layoutManagerViewIds.count - (layoutManagerViewIds.contains(0) ? 1 : 0)) views")

        // Remove all non-root views from superview
        let nonRootViews = views.filter { $0.key != 0 }
        print("🔥 DCFlightNative: Removing \(nonRootViews.count) non-root views from superview")
        for (viewId, view) in nonRootViews {
            view.removeFromSuperview()
            views.removeValue(forKey: viewId)
        }
        print("🔥 DCFlightNative: Removed all non-root views from superview")

        // Clear root view's subviews
        if let rootView = views[0] {
            let subviewCount = rootView.subviews.count
            print("🔥 DCFlightNative: Clearing \(subviewCount) subviews from root view")
            for subview in rootView.subviews {
                subview.removeFromSuperview()
            }
            print("🔥 DCFlightNative: Cleared all subviews from root view")
        } else {
            print("⚠️ DCFlightNative: Root view (id: 0) not found in views dictionary")
        }

        // Clear hierarchy tracking
        let nonRootHierarchy = viewHierarchy.filter { $0.key != "0" }
        for (parentId, _) in nonRootHierarchy {
            viewHierarchy.removeValue(forKey: parentId)
        }

        let nonRootChildMappings = childToParent.filter { $0.value != "0" && $0.key != "0" }
        for (childId, _) in nonRootChildMappings {
            childToParent.removeValue(forKey: childId)
        }

        viewHierarchy["0"] = []

        print("✅ DCFlightNative: Hot restart cleanup completed")
    }
    
    /// Force all views to be visible (used after hot reload)
    /// This ensures views are visible even if layout calculation had issues
    @objc public func forceAllViewsVisible() {
        DCFLayoutManager.shared.forceAllViewsVisible()
    }
    
    /// Start a batch update (no-op on iOS, kept for compatibility)
    @objc public func startBatchUpdate() -> Bool {
        return true
    }
    
    /// Commits a batch of operations atomically with optimized processing.
    /// 
    /// This method accepts pre-serialized JSON strings to eliminate native JSON parsing overhead.
    /// Operations are separated into create, update, attach, and event registration phases,
    /// then executed in order.
    /// 
    /// - Parameter updates: Array of operation dictionaries containing view operations
    /// - Returns: `true` if all operations succeeded, `false` otherwise
    @objc public func commitBatchUpdate(updates: [[String: Any]]) -> Bool {
        // Separate pre-serialized JSON operations from legacy Map operations
        var deleteOps: [Int] = []
        var createOps: [(viewId: Int, viewType: String, propsJson: String)] = []
        var updateOps: [(viewId: Int, propsJson: String)] = []
        var attachOps: [(childId: Int, parentId: Int, index: Int)] = []
        var eventOps: [(viewId: Int, eventTypes: [String])] = []
        
        // Parse phase - collect all operations
        for operation in updates {
            guard let operationType = operation["operation"] as? String else {
                continue
            }
            
            switch operationType {
            case "deleteView":
                let viewId: Int?
                if let viewIdInt = operation["viewId"] as? Int {
                    viewId = viewIdInt
                } else if let viewIdNum = operation["viewId"] as? NSNumber {
                    viewId = viewIdNum.intValue
                } else if let viewIdStr = operation["viewId"] as? String {
                    viewId = Int(viewIdStr)
                } else {
                    viewId = nil
                }
                
                if let viewId = viewId {
                    print("🗑️ iOS_BATCH: Parsed deleteView operation for viewId: \(viewId)")
                    deleteOps.append(viewId)
                }
                
            case "createView":
                let viewId: Int?
                if let viewIdInt = operation["viewId"] as? Int {
                    viewId = viewIdInt
                } else if let viewIdNum = operation["viewId"] as? NSNumber {
                    viewId = viewIdNum.intValue
                } else if let viewIdStr = operation["viewId"] as? String {
                    viewId = Int(viewIdStr)
                } else {
                    viewId = nil
                }
                
                if let viewId = viewId,
                   let viewType = operation["viewType"] as? String {
                    // Check for pre-serialized JSON first (optimized path)
                    if let propsJson = operation["propsJson"] as? String {
                        createOps.append((viewId, viewType, propsJson))
                    } else if let props = operation["props"] as? [String: Any] {
                        // Legacy fallback: serialize on native side
                        guard let propsData = try? JSONSerialization.data(withJSONObject: props),
                              let propsJson = String(data: propsData, encoding: .utf8) else {
                            continue
                        }
                        createOps.append((viewId, viewType, propsJson))
                    }
                }
                
            case "updateView":
                let viewId: Int?
                if let viewIdInt = operation["viewId"] as? Int {
                    viewId = viewIdInt
                } else if let viewIdNum = operation["viewId"] as? NSNumber {
                    viewId = viewIdNum.intValue
                } else if let viewIdStr = operation["viewId"] as? String {
                    viewId = Int(viewIdStr)
                } else {
                    viewId = nil
                }
                
                if let viewId = viewId {
                    // Check for pre-serialized JSON first (optimized path)
                    if let propsJson = operation["propsJson"] as? String {
                        updateOps.append((viewId, propsJson))
                    } else if let props = operation["props"] as? [String: Any] {
                        // Legacy fallback: serialize on native side
                        guard let propsData = try? JSONSerialization.data(withJSONObject: props),
                              let propsJson = String(data: propsData, encoding: .utf8) else {
                            continue
                        }
                        updateOps.append((viewId, propsJson))
                    }
                }
                
            case "attachView":
                let childId: Int?
                if let childIdInt = operation["childId"] as? Int {
                    childId = childIdInt
                } else if let childIdNum = operation["childId"] as? NSNumber {
                    childId = childIdNum.intValue
                } else if let childIdStr = operation["childId"] as? String {
                    childId = Int(childIdStr)
                } else {
                    childId = nil
                }
                
                let parentId: Int?
                if let parentIdInt = operation["parentId"] as? Int {
                    parentId = parentIdInt
                } else if let parentIdNum = operation["parentId"] as? NSNumber {
                    parentId = parentIdNum.intValue
                } else if let parentIdStr = operation["parentId"] as? String {
                    parentId = Int(parentIdStr)
                } else {
                    parentId = nil
                }
                
                if let childId = childId,
                   let parentId = parentId,
                   let index = operation["index"] as? Int {
                    attachOps.append((childId, parentId, index))
                }
                
            case "addEventListeners":
                let viewId: Int?
                if let viewIdInt = operation["viewId"] as? Int {
                    viewId = viewIdInt
                } else if let viewIdNum = operation["viewId"] as? NSNumber {
                    viewId = viewIdNum.intValue
                } else if let viewIdStr = operation["viewId"] as? String {
                    viewId = Int(viewIdStr)
                } else {
                    viewId = nil
                }
                
                if let viewId = viewId,
                   let eventTypes = operation["eventTypes"] as? [String] {
                    eventOps.append((viewId, eventTypes))
                }
                
            default:
                // Unknown operation type - skip
                continue
            }
        }
        
        // Execute phase - process all operations with minimal overhead
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // 🔧 FIX: Delete phase - remove from layout tree FIRST, before creating new views
            // This prevents both old and new views from being in the layout tree simultaneously,
            // which causes the "imaginary margin" / layout shift issue
            if !deleteOps.isEmpty {
                let deleteStartTime = CFAbsoluteTimeGetCurrent()
                var viewsToRemove: [UIView] = []
                
                // Collect all views to remove (parent + children) without removing from superview yet
                func collectViewsToRemove(parentId: Int) {
                    if let view = views[parentId] {
                        viewsToRemove.append(view)
                    }
                    let parentIdStr = String(parentId)
                    if let children = viewHierarchy[parentIdStr] {
                        for childIdStr in children {
                            if let childId = Int(childIdStr) {
                                collectViewsToRemove(parentId: childId)
                            }
                        }
                    }
                }
                
                for viewId in deleteOps {
                    print("🗑️ iOS_BATCH: Processing delete for viewId=\(viewId)")
                    collectViewsToRemove(parentId: viewId)
                    
                    // 🔧 CRITICAL: Remove from layout tree FIRST (before creates)
                    // This ensures old view is not in layout tree when new view is added
                    print("🗑️ iOS_BATCH: Removing viewId=\(viewId) from layout tree (BEFORE creates)")
                    YogaShadowTree.shared.removeNode(nodeId: String(viewId))
                    
                    // Remove from registry (but keep in hierarchy for now)
                    if !DCFViewManager.shared.deleteView(viewId: viewId) {
                        print("❌ Failed to delete view \(viewId)")
                        return false
                    }
                    
                    // Clean up tracking recursively
                    func cleanupTrackingRecursively(parentId: Int) {
                        let parentIdStr = String(parentId)
                        if let children = viewHierarchy[parentIdStr] {
                            for childIdStr in children {
                                if let childId = Int(childIdStr) {
                                    // Remove child from layout tree too
                                    YogaShadowTree.shared.removeNode(nodeId: childIdStr)
                                    ViewRegistry.shared.removeView(id: childId)
                                    DCFLayoutManager.shared.unregisterView(withId: childId)
                                    cleanupTrackingRecursively(parentId: childId)
                                }
                            }
                        }
                        viewHierarchy[parentIdStr] = []
                    }
                    cleanupTrackingRecursively(parentId: viewId)
                    views.removeValue(forKey: viewId)
                    cleanupHierarchyReferences(viewId: viewId)
                }
                
                let deleteTime = (CFAbsoluteTimeGetCurrent() - deleteStartTime) * 1000
                print("🗑️ iOS_BATCH_TIMING: Delete phase completed in \(String(format: "%.2f", deleteTime))ms (\(deleteOps.count) views)")
                
                // Store viewsToRemove for later removal from superview
                // We'll remove them after creates are done
                for view in viewsToRemove {
                    view.removeFromSuperview()
                }
                print("✅ iOS_BATCH: All \(viewsToRemove.count) old views removed from superview")
            }
            
            let createStartTime = CFAbsoluteTimeGetCurrent()
            
            // Create all views (props are already JSON strings - no serialization needed!)
            // Old views are already removed from layout tree, so layout will only calculate with new views
            for op in createOps {
                if !createView(viewId: op.viewId, viewType: op.viewType, propsJson: op.propsJson) {
                    print("❌ Failed to create view \(op.viewId)")
                    return false
                }
            }
            
            let createTime = (CFAbsoluteTimeGetCurrent() - createStartTime) * 1000
            print("� iOS_BATCH_TIMING: Create phase completed in \(String(format: "%.2f", createTime))ms (\(createOps.count) views)")
            
            let updateStartTime = CFAbsoluteTimeGetCurrent()
            
            // Update all views (props are already JSON strings - no serialization needed!)
            for op in updateOps {
                if !updateView(viewId: op.viewId, propsJson: op.propsJson) {
                    print("❌ Failed to update view \(op.viewId)")
                    return false
                }
            }
            
            let updateTime = (CFAbsoluteTimeGetCurrent() - updateStartTime) * 1000
            print("� iOS_BATCH_TIMING: Update phase completed in \(String(format: "%.2f", updateTime))ms (\(updateOps.count) views)")
            
            let attachStartTime = CFAbsoluteTimeGetCurrent()
            
            // Attach all views to hierarchy
            for op in attachOps {
                if !attachView(childId: op.childId, parentId: op.parentId, index: op.index) {
                    print("❌ Failed to attach \(op.childId) to \(op.parentId)")
                    return false
                }
            }
            
            let attachTime = (CFAbsoluteTimeGetCurrent() - attachStartTime) * 1000
            print("� iOS_BATCH_TIMING: Attach phase completed in \(String(format: "%.2f", attachTime))ms (\(attachOps.count) attachments)")
            
            let eventsStartTime = CFAbsoluteTimeGetCurrent()
            
            // Register all event listeners
            for op in eventOps {
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(viewId: op.viewId, eventTypes: op.eventTypes)
            }
            
            let eventsTime = (CFAbsoluteTimeGetCurrent() - eventsStartTime) * 1000
            print("📊 iOS_BATCH_TIMING: Events phase completed in \(String(format: "%.2f", eventsTime))ms (\(eventOps.count) registrations)")
            
            let layoutStartTime = CFAbsoluteTimeGetCurrent()
            
            print("🔥 iOS_BATCH_COMMIT: Triggering layout calculation")
            DCFLayoutManager.shared.calculateLayoutNow()
            
            let layoutTime = (CFAbsoluteTimeGetCurrent() - layoutStartTime) * 1000
            print("� iOS_BATCH_TIMING: Layout phase completed in \(String(format: "%.2f", layoutTime))ms")
            
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("📊 iOS_BATCH_TIMING: ✅ TOTAL BATCH COMMIT TIME: \(String(format: "%.2f", totalTime))ms for \(updates.count) operations")
            print("🔥 iOS_BATCH_COMMIT: Successfully committed all operations atomically")
            
            return true
        } catch {
            print("❌ iOS_BATCH_COMMIT: Failed during atomic commit: \(error)")
            return false
        }
    }
    
    /// Cancel a batch update (no-op on iOS, kept for compatibility)
    @objc public func cancelBatchUpdate() -> Bool {
        return true
    }
    
    /// Handle tunnel method calls from Dart to native components
    /// - Parameters:
    ///   - componentType: Type of component to call the method on
    ///   - method: Method name to call
    ///   - params: Parameters for the method call
    /// - Returns: Result of the method call, or nil if it failed
    @objc public func handleTunnelMethod(componentType: String, method: String, params: [String: Any]) -> Any? {
        guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
            print("❌ DCFlightNative: Component \(componentType) not registered")
            return nil
        }
        
        print("✅ DCFlightNative: Found component class for \(componentType). Dispatching \(method)...")
        
        if let response = componentClass.handleTunnelMethod(method, params: params) {
            print("✅ DCFlightNative: \(method) handled successfully")
            return response
        } else {
            print("⚠️ DCFlightNative: Method \(method) not handled by \(componentType)")
            return nil
        }
    }
    
    /// Add event listeners to a view (FFI access)
    /// - Parameters:
    ///   - viewId: Unique identifier for the view
    ///   - eventTypes: Array of event types to listen for
    /// - Returns: true if listeners were added successfully, false otherwise
    @objc public func addEventListeners(viewId: Int, eventTypes: [String]) -> Bool {
        var view: UIView? = ViewRegistry.shared.getView(id: viewId)
        
        if view == nil {
            view = DCFLayoutManager.shared.getView(withId: viewId)
        }
        
        guard let foundView = view else {
            print("⚠️ DCFlightNative: View \(viewId) not found for event listener registration")
            return false
        }
        
        return DCMauiEventMethodHandler.shared.addEventListenersForBatch(viewId: viewId, eventTypes: eventTypes)
    }
    
    /// Remove event listeners from a view (FFI access)
    /// - Parameters:
    ///   - viewId: Unique identifier for the view
    ///   - eventTypes: Array of event types to remove
    /// - Returns: true if listeners were removed successfully, false otherwise
    @objc public func removeEventListeners(viewId: Int, eventTypes: [String]) -> Bool {
        return DCMauiEventMethodHandler.shared.removeEventListeners(viewId: viewId, eventTypes: eventTypes)
    }
}


