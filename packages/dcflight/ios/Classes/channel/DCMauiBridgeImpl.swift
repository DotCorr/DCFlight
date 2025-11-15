/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Foundation

/// Bridge between Dart FFI and native Swift/Objective-C code
@objc class DCMauiBridgeImpl: NSObject {
    
    @objc static let shared = DCMauiBridgeImpl()
    
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
    @objc func initialize() -> Bool {
        
        if let rootView = views[0] {
            
            if YogaShadowTree.shared.nodes["0"] == nil {
                YogaShadowTree.shared.createNode(id: "0", componentType: "View")
            }
        } else {
        }
        
        return true
    }
    
    /// Create a view with properties
    @objc func createView(viewId: Int, viewType: String, propsJson: String) -> Bool {
        
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
    @objc func updateView(viewId: Int, propsJson: String) -> Bool {
        
        guard let propsData = propsJson.data(using: .utf8),
              let props = try? JSONSerialization.jsonObject(with: propsData, options: []) as? [String: Any] else {
            return false
        }
        
        return DCFViewManager.shared.updateView(viewId: viewId, props: props)
    }
    
    /// Delete a view
    @objc func deleteView(viewId: Int) -> Bool {
        
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
    @objc func attachView(childId: Int, parentId: Int, index: Int) -> Bool {
        
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
    @objc func setChildren(viewId: Int, childrenIds: [Int]) -> Bool {
        
        guard let parentView = self.views[viewId] else {
            return false
        }
        
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
    @objc func detachView(childId: Int) -> Bool {
        
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
    @objc func cleanupForHotRestart() {
        // Remove all non-root views from superview
        let nonRootViews = views.filter { $0.key != 0 }
        for (viewId, view) in nonRootViews {
            view.removeFromSuperview()
            views.removeValue(forKey: viewId)
        }
        
        // Clear root view's subviews
        if let rootView = views[0] {
            for subview in rootView.subviews {
                subview.removeFromSuperview()
            }
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
    }
    
    
    /// Start a batch update (no-op on iOS, kept for compatibility)
    @objc func startBatchUpdate() -> Bool {
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
    @objc func commitBatchUpdate(updates: [[String: Any]]) -> Bool {
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
            print("📊 iOS_BATCH: Processing batch - deletes: \(deleteOps.count), creates: \(createOps.count), updates: \(updateOps.count), attaches: \(attachOps.count)")
            
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
    @objc func cancelBatchUpdate() -> Bool {
        return true
    }
}


