/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * NEW: Uses DCFShadowView objects (React Native pattern) instead of dictionaries
 */

import UIKit
import yoga

/**
 * YogaShadowTree - Manages shadow view tree using DCFShadowView objects (React Native pattern)
 * 
 * This is a wrapper/adapter that maintains the same public interface as the old dictionary-based
 * implementation, but uses shadow view objects internally for better consistency with React Native.
 */
class YogaShadowTree {
    static let shared = YogaShadowTree()
    
    // MARK: - Shadow View Registry (React Native pattern)
    
    /// Shadow view registry: viewId -> DCFShadowView
    private var shadowViewRegistry: [Int: DCFShadowView] = [:]
    
    /// Root shadow view
    private var rootShadowView: DCFRootShadowView?
    
    /// Screen root shadow views: screenId -> DCFRootShadowView
    private var screenRootShadowViews: [Int: DCFRootShadowView] = [:]
    private var screenRootIds = Set<Int>()
    
    /// Component instances cache
    private var componentInstances: [String: DCFComponent] = [:]
    
    /// Node types: viewId -> componentType
    private var nodeTypes: [Int: String] = [:]
    
    // MARK: - Thread Safety
    
    private let syncQueue = DispatchQueue(label: "YogaShadowTree.sync", qos: .userInitiated)
    private let syncQueueKey = DispatchSpecificKey<String>()
    private var isLayoutCalculating = false
    private var isReconciling = false
    
    // MARK: - Legacy Compatibility (for migration)
    
    /// Legacy: nodes dictionary for backward compatibility during migration
    internal var nodes: [String: YGNodeRef] {
        var result: [String: YGNodeRef] = [:]
        syncQueue.sync {
            for (viewId, shadowView) in shadowViewRegistry {
                result[String(viewId)] = shadowView.yogaNode
            }
        }
        return result
    }
    
    /// Legacy: nodeParents dictionary for backward compatibility
    internal var nodeParents: [String: String] {
        var result: [String: String] = [:]
        syncQueue.sync {
            for (viewId, shadowView) in shadowViewRegistry {
                if let parent = shadowView.superview {
                    result[String(viewId)] = String(parent.viewId)
                }
            }
        }
        return result
    }
    
    // MARK: - Initialization
    
    private init() {
        // Setup queue-specific key for re-entrancy detection
        setupSyncQueueKey()
        
        // Create root shadow view
        let rootViewId = 0
        let rootShadowView = DCFRootShadowView(viewId: rootViewId)
        rootShadowView.viewName = "View"
        rootShadowView.availableSize = UIScreen.main.bounds.size
        
        // CRITICAL: Configure root shadow view's Yoga node with proper defaults
        // This ensures children are laid out correctly (vertically stacked)
        let rootYogaNode = rootShadowView.yogaNode
        YGNodeStyleSetFlexDirection(rootYogaNode, YGFlexDirection.column)
        YGNodeStyleSetDirection(rootYogaNode, YGDirection.LTR)
        YGNodeStyleSetFlexShrink(rootYogaNode, 0.0)
        
        self.rootShadowView = rootShadowView
        shadowViewRegistry[rootViewId] = rootShadowView
        nodeTypes[rootViewId] = "View"
    }
    
    // MARK: - Node Creation
    
    func createNode(id: String, componentType: String) {
        guard let viewId = Int(id) else { return }
        
        syncQueue.sync {
            // Check if already exists
            if shadowViewRegistry[viewId] != nil {
                return
            }
            
            let shadowView: DCFShadowView
            if componentType == "ScrollContentView" {
                shadowView = DCFScrollContentShadowView(viewId: viewId)
            } else {
                shadowView = DCFShadowView(viewId: viewId)
            }
            
            shadowView.viewName = componentType
            
            // Apply default styles
            applyDefaultNodeStyles(to: shadowView, componentType: componentType)
            
            // Setup measure function if needed
            setupMeasureFunction(shadowView: shadowView, componentType: componentType)
            
            shadowViewRegistry[viewId] = shadowView
            nodeTypes[viewId] = componentType
        }
    }
    
    func createScreenRoot(id: String, componentType: String) {
        guard let viewId = Int(id) else { return }
        
        syncQueue.sync {
            // Check if already exists
            if shadowViewRegistry[viewId] != nil {
                return
            }
            
            let screenRoot = DCFRootShadowView(viewId: viewId)
            screenRoot.viewName = componentType
            screenRoot.availableSize = UIScreen.main.bounds.size
            screenRoot.baseDirection = .LTR
            
            // Apply screen root styles
            let yogaNode = screenRoot.yogaNode
            YGNodeStyleSetDirection(yogaNode, YGDirection.LTR)
            YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.column)
            YGNodeStyleSetWidth(yogaNode, Float(UIScreen.main.bounds.width))
            YGNodeStyleSetHeight(yogaNode, Float(UIScreen.main.bounds.height))
            YGNodeStyleSetPosition(yogaNode, YGEdge.left, 0)
            YGNodeStyleSetPosition(yogaNode, YGEdge.top, 0)
            YGNodeStyleSetPositionType(yogaNode, YGPositionType.absolute)
            
            shadowViewRegistry[viewId] = screenRoot
            screenRootShadowViews[viewId] = screenRoot
            screenRootIds.insert(viewId)
            nodeTypes[viewId] = componentType
        }
    }
    
    // MARK: - Child Management
    
    func addChildNode(parentId: String, childId: String, index: Int? = nil) {
        guard let parentViewId = Int(parentId),
              let childViewId = Int(childId) else {
            return
        }
        
        syncQueue.sync {
            guard let parentShadowView = shadowViewRegistry[parentViewId],
                  let childShadowView = shadowViewRegistry[childViewId] else {
                return
            }
            
            // Skip if child is a screen root
            if screenRootIds.contains(childViewId) {
                return
            }
            
            // Remove from old parent if exists
            if let oldParent = childShadowView.superview {
                oldParent.removeReactSubview(childShadowView)
                // Re-setup measure function for old parent (might be able to have measure function now)
                setupMeasureFunction(shadowView: oldParent, componentType: nodeTypes[oldParent.viewId] ?? "View")
            }
            
            // CRITICAL: Remove measure function from parent before adding child
            // Yoga rule: Nodes with measure functions cannot have children
            let parentYogaNode = parentShadowView.yogaNode
            if YGNodeHasMeasureFunc(parentYogaNode) {
                YGNodeSetMeasureFunc(parentYogaNode, nil)
            }
            
            // Add to new parent using shadow view's insertReactSubview (React Native pattern)
            let insertIndex = index ?? parentShadowView.reactSubviews.count
            parentShadowView.insertReactSubview(childShadowView, atIndex: insertIndex)
            
            // Setup measure function for child (only if it has no children)
            setupMeasureFunction(shadowView: childShadowView, componentType: nodeTypes[childViewId] ?? "View")
        }
    }
    
    func removeNode(nodeId: String) {
        guard let viewId = Int(nodeId) else { return }
        
        syncQueue.sync {
            isReconciling = true
            defer { isReconciling = false }
            
            while isLayoutCalculating {
                usleep(1000)
            }
            
            guard let shadowView = shadowViewRegistry[viewId] else {
                return
            }
            
            // Remove from parent if exists
            if let parent = shadowView.superview {
                parent.removeReactSubview(shadowView)
            }
            
            // Remove all children
            let children = shadowView.reactSubviews
            for child in children {
                shadowView.removeReactSubview(child)
            }
            
            // Remove from registries
            shadowViewRegistry.removeValue(forKey: viewId)
            nodeTypes.removeValue(forKey: viewId)
            
            if screenRootIds.contains(viewId) {
                screenRootShadowViews.removeValue(forKey: viewId)
                screenRootIds.remove(viewId)
            }
        }
    }
    
    // MARK: - Layout Properties
    
    func updateNodeLayoutProps(nodeId: String, props: [String: Any]) {
        guard let viewId = Int(nodeId),
              let shadowView = shadowViewRegistry[viewId] else {
            print("⚠️ YogaShadowTree: updateNodeLayoutProps - viewId=\(nodeId) not found")
            return
        }
        
        syncQueue.sync {
            let yogaNode = shadowView.yogaNode
            
            print("🔍 YogaShadowTree: updateNodeLayoutProps for viewId=\(nodeId), props=\(props)")
            for (key, value) in props {
                applyLayoutProp(node: yogaNode, key: key, value: value)
            }
        }
    }
    
    // MARK: - Layout Calculation
    
    func calculateAndApplyLayout(width: CGFloat, height: CGFloat) -> Bool {
        let result = syncQueue.sync { () -> (Bool, Set<DCFShadowView>, Int, Int) in
            if isReconciling {
                print("⚠️ YogaShadowTree: Layout calculation blocked - reconciliation in progress")
                return (false, Set<DCFShadowView>(), 0, 0)
            }
            
            isLayoutCalculating = true
            defer { isLayoutCalculating = false }
            
            guard let rootShadowView = rootShadowView else {
                print("❌ YogaShadowTree: Root shadow view not found")
                return (false, Set<DCFShadowView>(), 0, 0)
            }
            
            // Update root available size
            // React Native pattern: Just set availableSize and let Yoga calculate layout naturally
            // DO NOT set explicit width/height/position on root node - Yoga handles this
            rootShadowView.availableSize = CGSize(width: width, height: height)
            
            // CRITICAL: Set root view frame BEFORE layout calculation
            // This ensures children are positioned correctly relative to the root view
            // We need to do this on main thread, but we're in sync queue, so we'll do it after
            // But we need to ensure root view frame is set before children are positioned
            // So we'll set it synchronously if we're on main thread, otherwise queue it
            
            // Calculate layout using shadow view's collectViewsWithUpdatedFrames
            let viewsWithNewFrame = rootShadowView.collectViewsWithUpdatedFrames()
            
            // Apply layout to all screen roots
            var appliedCount = 0
            for (_, screenRoot) in screenRootShadowViews {
                screenRoot.availableSize = CGSize(width: width, height: height)
                let screenViewsWithNewFrame = screenRoot.collectViewsWithUpdatedFrames()
                for shadowView in screenViewsWithNewFrame {
                    DCFLayoutManager.shared.applyLayout(
                        to: shadowView.viewId,
                        left: shadowView.frame.origin.x,
                        top: shadowView.frame.origin.y,
                        width: shadowView.frame.size.width,
                        height: shadowView.frame.size.height
                    )
                    appliedCount += 1
                }
            }
            
            // Apply frames to actual UIViews (excluding root view which we set below)
            for shadowView in viewsWithNewFrame {
                // Skip root view (viewId=0) - we set it explicitly below
                if shadowView.viewId == 0 {
                    continue
                }
                
                // DEBUG: Log first few children to diagnose positioning issues
                if shadowView.viewId <= 3 {
                    print("🔍 YogaShadowTree: viewId=\(shadowView.viewId) frame=\(shadowView.frame)")
                }
                
                DCFLayoutManager.shared.applyLayout(
                    to: shadowView.viewId,
                    left: shadowView.frame.origin.x,
                    top: shadowView.frame.origin.y,
                    width: shadowView.frame.size.width,
                    height: shadowView.frame.size.height
                )
                appliedCount += 1
            }
            
            let totalViews = shadowViewRegistry.count
            return (true, viewsWithNewFrame, appliedCount, totalViews)
        }
        
        let (success, viewsWithNewFrame, appliedCount, totalViews) = result
        
        if success {
            // CRITICAL: Verify and set root view frame AFTER layout calculation
            // This ensures root view frame is correct even if it was reset during layout
            DispatchQueue.main.async {
                if let rootView = DCFLayoutManager.shared.getView(withId: 0) {
                    let rootFrame = CGRect(x: 0, y: 0, width: width, height: height)
                    if !rootView.frame.equalTo(rootFrame) {
                        print("⚠️ YogaShadowTree: Root view frame was incorrect after layout: \(rootView.frame), correcting to \(rootFrame)")
                        rootView.frame = rootFrame
                        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    }
                    print("✅ YogaShadowTree: Root view (0) verified at \(rootView.frame)")
                }
            }
            
            print("✅ YogaShadowTree: Applied layout to \(appliedCount) views out of \(totalViews) shadow views")
        }
        
        return success
    }
    
    // MARK: - Screen Root Management
    
    func isScreenRoot(_ nodeId: String) -> Bool {
        guard let viewId = Int(nodeId) else { return false }
        return syncQueue.sync {
            screenRootIds.contains(viewId)
        }
    }
    
    func updateScreenRootDimensions(width: CGFloat, height: CGFloat) {
        syncQueue.sync {
            for (_, screenRoot) in screenRootShadowViews {
                screenRoot.availableSize = CGSize(width: width, height: height)
            }
        }
    }
    
    // MARK: - Cleanup
    
    func resetFlags() {
        syncQueue.sync {
            isReconciling = false
            isLayoutCalculating = false
        }
    }
    
    func clearAllMappings() {
        syncQueue.sync {
            // Remove all children from root
            if let root = rootShadowView {
                let children = root.reactSubviews
                for child in children {
                    root.removeReactSubview(child)
                }
            }
            
            // Clear screen roots
            screenRootShadowViews.removeAll()
            screenRootIds.removeAll()
        }
    }
    
    func clearAll() {
        syncQueue.sync {
            isReconciling = true
            
            while isLayoutCalculating {
                usleep(1000)
            }
            
            // Remove all children from root
            if let root = rootShadowView {
                let children = root.reactSubviews
                for child in children {
                    root.removeReactSubview(child)
                }
            }
            
            // Clear all shadow views except root
            let allViewIds = shadowViewRegistry.keys.filter { $0 != 0 }
            for viewId in allViewIds {
                shadowViewRegistry.removeValue(forKey: viewId)
            }
            
            // Clear screen roots
            screenRootShadowViews.removeAll()
            screenRootIds.removeAll()
            nodeTypes.removeAll()
            
            isReconciling = false
            isLayoutCalculating = false
        }
    }
    
    // MARK: - Web Defaults
    
    func applyWebDefaults() {
        syncQueue.sync {
            useWebDefaults = true
            
            if let root = rootShadowView {
                let yogaNode = root.yogaNode
                YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.row)
                YGNodeStyleSetAlignContent(yogaNode, YGAlign.stretch)
                YGNodeStyleSetFlexShrink(yogaNode, 1.0)
            }
            
            for (_, screenRoot) in screenRootShadowViews {
                let yogaNode = screenRoot.yogaNode
                YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.row)
                YGNodeStyleSetAlignContent(yogaNode, YGAlign.stretch)
                YGNodeStyleSetFlexShrink(yogaNode, 1.0)
            }
        }
    }
    
    private var useWebDefaults = false
    
    // MARK: - Helper Methods
    
    func getComponentInstance(for componentType: String) -> DCFComponent? {
        // Check if we're already on the sync queue to avoid deadlock
        if DispatchQueue.getSpecific(key: syncQueueKey) != nil {
            // Already on sync queue, access directly
            if let cached = componentInstances[componentType] {
                return cached
            }
            
            guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
                return nil
            }
            
            let instance = componentClass.init()
            componentInstances[componentType] = instance
            return instance
        } else {
            // Not on sync queue, use sync
            return syncQueue.sync {
                if let cached = componentInstances[componentType] {
                    return cached
                }
                
                guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
                    return nil
                }
                
                let instance = componentClass.init()
                componentInstances[componentType] = instance
                return instance
            }
        }
    }
    
    func getComponentType(for viewId: Int) -> String? {
        // Check if we're already on the sync queue to avoid deadlock
        if DispatchQueue.getSpecific(key: syncQueueKey) != nil {
            // Already on sync queue, access directly
            return nodeTypes[viewId]
        } else {
            // Not on sync queue, use sync
            return syncQueue.sync {
                return nodeTypes[viewId]
            }
        }
    }
    
    // MARK: - Queue-specific key for re-entrancy detection
    
    private func setupSyncQueueKey() {
        syncQueue.setSpecific(key: syncQueueKey, value: "YogaShadowTree.syncQueue")
    }
    
    private func setupMeasureFunction(shadowView: DCFShadowView, componentType: String) {
        let yogaNode = shadowView.yogaNode
        let childCount = YGNodeGetChildCount(yogaNode)
        
        if childCount == 0 {
            YGNodeSetMeasureFunc(yogaNode) { (yogaNode, width, widthMode, height, heightMode) -> YGSize in
                guard let context = YGNodeGetContext(yogaNode) else {
                    return YGSize(width: 0, height: 0)
                }
                
                let shadowView = Unmanaged<DCFShadowView>.fromOpaque(context).takeUnretainedValue()
                let viewId = shadowView.viewId
                
                guard let view = DCFLayoutManager.shared.getView(withId: viewId),
                      let componentType = YogaShadowTree.shared.nodeTypes[viewId] else {
                    return YGSize(width: 0, height: 0)
                }
                
                let constraintSize = CGSize(
                    width: widthMode == YGMeasureMode.undefined ? CGFloat.greatestFiniteMagnitude : CGFloat(width),
                    height: heightMode == YGMeasureMode.undefined ? CGFloat.greatestFiniteMagnitude : CGFloat(height)
                )
                
                guard let componentInstance = YogaShadowTree.shared.getComponentInstance(for: componentType) else {
                    return YGSize(width: Float(constraintSize.width), height: Float(constraintSize.height))
                }
                
                var intrinsicSize = CGSize.zero
                if Thread.isMainThread {
                    intrinsicSize = componentInstance.getIntrinsicSize(view, forProps: [:])
                } else {
                    DispatchQueue.main.sync {
                        intrinsicSize = componentInstance.getIntrinsicSize(view, forProps: [:])
                    }
                }
                
                let finalWidth = widthMode == YGMeasureMode.undefined ? intrinsicSize.width : min(intrinsicSize.width, constraintSize.width)
                let finalHeight = heightMode == YGMeasureMode.undefined ? intrinsicSize.height : min(intrinsicSize.height, constraintSize.height)
                
                return YGSize(width: Float(finalWidth), height: Float(finalHeight))
            }
        } else {
            YGNodeSetMeasureFunc(yogaNode, nil)
        }
    }
    
    private func applyDefaultNodeStyles(to shadowView: DCFShadowView, componentType: String) {
        let yogaNode = shadowView.yogaNode
        
        // Match React Native: Only set flexDirection based on useWebDefaults
        // React Native doesn't set justify-content, align-items, or align-content by default
        // Yoga's defaults handle undefined dimensions automatically
        if useWebDefaults {
            YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.row)
            YGNodeStyleSetFlexShrink(yogaNode, 1.0)
        } else {
            // React Native default: column direction, no flex shrink
            YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.column)
            YGNodeStyleSetFlexShrink(yogaNode, 0.0)
        }
        
        // Don't set justify-content or align-items - let Yoga use defaults
        // This allows components to inherit proper sizing behavior automatically
    }
    
    // MARK: - Layout Property Application
    
    private func applyLayoutProp(node: YGNodeRef, key: String, value: Any) {
        switch key {
        case "width":
            if let width = parseDimension(value) {
                YGNodeStyleSetWidth(node, width)
                print("🔍 YogaShadowTree: Applied width=\(width) to node")
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetWidthPercent(node, percentValue)
                print("🔍 YogaShadowTree: Applied width=\(percentValue)% to node")
            }
        case "height":
            if let height = parseDimension(value) {
                YGNodeStyleSetHeight(node, height)
                print("🔍 YogaShadowTree: Applied height=\(height) to node")
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetHeightPercent(node, percentValue)
                print("🔍 YogaShadowTree: Applied height=\(percentValue)% to node")
            }
        case "flex":
            if let flex = parseDimension(value) {
                YGNodeStyleSetFlex(node, flex)
            }
        case "flexDirection":
            if let direction = value as? String {
                switch direction {
                case "row":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.row)
                case "column":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.column)
                case "rowReverse":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.rowReverse)
                case "columnReverse":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.columnReverse)
                default:
                    break
                }
            }
        case "flexWrap":
            if let wrap = value as? String {
                switch wrap {
                case "nowrap":
                    YGNodeStyleSetFlexWrap(node, YGWrap.noWrap)
                case "wrap":
                    YGNodeStyleSetFlexWrap(node, YGWrap.wrap)
                case "wrapReverse":
                    YGNodeStyleSetFlexWrap(node, YGWrap.wrapReverse)
                default:
                    break
                }
            }
        case "flexGrow":
            if let grow = parseDimension(value) {
                YGNodeStyleSetFlexGrow(node, grow)
            }
        case "flexShrink":
            if let shrink = parseDimension(value) {
                YGNodeStyleSetFlexShrink(node, shrink)
            }
        case "flexBasis":
            if let basis = parseDimension(value) {
                YGNodeStyleSetFlexBasis(node, basis)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetFlexBasisPercent(node, percentValue)
            }
        case "display":
            if let display = value as? String {
                switch display {
                case "flex":
                    YGNodeStyleSetDisplay(node, YGDisplay.flex)
                case "none":
                    YGNodeStyleSetDisplay(node, YGDisplay.none)
                default:
                    break
                }
            }
        case "overflow":
            if let overflow = value as? String {
                switch overflow {
                case "visible":
                    YGNodeStyleSetOverflow(node, YGOverflow.visible)
                case "hidden":
                    YGNodeStyleSetOverflow(node, YGOverflow.hidden)
                case "scroll":
                    YGNodeStyleSetOverflow(node, YGOverflow.scroll)
                default:
                    break
                }
            }
        case "minWidth":
            if let minWidth = parseDimension(value) {
                YGNodeStyleSetMinWidth(node, minWidth)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMinWidthPercent(node, percentValue)
            }
        case "maxWidth":
            if let maxWidth = parseDimension(value) {
                YGNodeStyleSetMaxWidth(node, maxWidth)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMaxWidthPercent(node, percentValue)
            }
        case "minHeight":
            if let minHeight = parseDimension(value) {
                YGNodeStyleSetMinHeight(node, minHeight)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMinHeightPercent(node, percentValue)
            }
        case "maxHeight":
            if let maxHeight = parseDimension(value) {
                YGNodeStyleSetMaxHeight(node, maxHeight)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMaxHeightPercent(node, percentValue)
            }
        case "margin":
            if let margin = parseDimension(value) {
                YGNodeStyleSetMargin(node, YGEdge.all, margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.all, percentValue)
            }
        case "marginTop":
            if let margin = parseDimension(value) {
                YGNodeStyleSetMargin(node, YGEdge.top, margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.top, percentValue)
            }
        case "marginRight":
            if let margin = parseDimension(value) {
                YGNodeStyleSetMargin(node, YGEdge.right, margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.right, percentValue)
            }
        case "marginBottom":
            if let margin = parseDimension(value) {
                YGNodeStyleSetMargin(node, YGEdge.bottom, margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.bottom, percentValue)
            }
        case "marginLeft":
            if let margin = parseDimension(value) {
                YGNodeStyleSetMargin(node, YGEdge.left, margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.left, percentValue)
            }
        case "padding":
            if let padding = parseDimension(value) {
                YGNodeStyleSetPadding(node, YGEdge.all, padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.all, percentValue)
            }
        case "paddingTop":
            if let padding = parseDimension(value) {
                YGNodeStyleSetPadding(node, YGEdge.top, padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.top, percentValue)
            }
        case "paddingRight":
            if let padding = parseDimension(value) {
                YGNodeStyleSetPadding(node, YGEdge.right, padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.right, percentValue)
            }
        case "paddingBottom":
            if let padding = parseDimension(value) {
                YGNodeStyleSetPadding(node, YGEdge.bottom, padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.bottom, percentValue)
            }
        case "paddingLeft":
            if let padding = parseDimension(value) {
                YGNodeStyleSetPadding(node, YGEdge.left, padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.left, percentValue)
            }
        case "justifyContent":
            if let justify = value as? String {
                switch justify {
                case "flexStart":
                    YGNodeStyleSetJustifyContent(node, YGJustify.flexStart)
                case "center":
                    YGNodeStyleSetJustifyContent(node, YGJustify.center)
                case "flexEnd":
                    YGNodeStyleSetJustifyContent(node, YGJustify.flexEnd)
                case "spaceBetween":
                    YGNodeStyleSetJustifyContent(node, YGJustify.spaceBetween)
                case "spaceAround":
                    YGNodeStyleSetJustifyContent(node, YGJustify.spaceAround)
                case "spaceEvenly":
                    YGNodeStyleSetJustifyContent(node, YGJustify.spaceEvenly)
                default:
                    break
                }
            }
        case "alignItems":
            if let align = value as? String {
                switch align {
                case "flexStart":
                    YGNodeStyleSetAlignItems(node, YGAlign.flexStart)
                case "center":
                    YGNodeStyleSetAlignItems(node, YGAlign.center)
                case "flexEnd":
                    YGNodeStyleSetAlignItems(node, YGAlign.flexEnd)
                case "stretch":
                    YGNodeStyleSetAlignItems(node, YGAlign.stretch)
                case "baseline":
                    YGNodeStyleSetAlignItems(node, YGAlign.baseline)
                default:
                    break
                }
            }
        case "alignSelf":
            if let align = value as? String {
                switch align {
                case "auto":
                    YGNodeStyleSetAlignSelf(node, YGAlign.auto)
                case "flexStart":
                    YGNodeStyleSetAlignSelf(node, YGAlign.flexStart)
                case "center":
                    YGNodeStyleSetAlignSelf(node, YGAlign.center)
                case "flexEnd":
                    YGNodeStyleSetAlignSelf(node, YGAlign.flexEnd)
                case "stretch":
                    YGNodeStyleSetAlignSelf(node, YGAlign.stretch)
                case "baseline":
                    YGNodeStyleSetAlignSelf(node, YGAlign.baseline)
                default:
                    break
                }
            }
        case "alignContent":
            if let align = value as? String {
                switch align {
                case "flexStart":
                    YGNodeStyleSetAlignContent(node, YGAlign.flexStart)
                case "center":
                    YGNodeStyleSetAlignContent(node, YGAlign.center)
                case "flexEnd":
                    YGNodeStyleSetAlignContent(node, YGAlign.flexEnd)
                case "stretch":
                    YGNodeStyleSetAlignContent(node, YGAlign.stretch)
                case "spaceBetween":
                    YGNodeStyleSetAlignContent(node, YGAlign.spaceBetween)
                case "spaceAround":
                    YGNodeStyleSetAlignContent(node, YGAlign.spaceAround)
                default:
                    break
                }
            }
        case "position":
            if let position = value as? String {
                switch position {
                case "relative":
                    YGNodeStyleSetPositionType(node, YGPositionType.relative)
                case "absolute":
                    YGNodeStyleSetPositionType(node, YGPositionType.absolute)
                default:
                    break
                }
            }
        case "top":
            if let top = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.top, top)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.top, percentValue)
            }
        case "right":
            if let right = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.right, right)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.right, percentValue)
            }
        case "bottom":
            if let bottom = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.bottom, bottom)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.bottom, percentValue)
            }
        case "left":
            if let left = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.left, left)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.left, percentValue)
            }
        case "aspectRatio":
            if let ratio = parseDimension(value) {
                YGNodeStyleSetAspectRatio(node, ratio)
            }
        default:
            break
        }
    }
    
    private func parseDimension(_ value: Any) -> Float? {
        if let num = value as? Float {
            return num
        } else if let num = value as? Double {
            return Float(num)
        } else if let num = value as? Int {
            return Float(num)
        } else if let num = value as? CGFloat {
            return Float(num)
        }
        return nil
    }
}

