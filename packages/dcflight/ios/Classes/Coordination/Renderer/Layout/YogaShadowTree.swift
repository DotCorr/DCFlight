/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * Uses DCFShadowView objects for shadow view tree management
 */

import UIKit
import yoga

/**
 * YogaShadowTree - Manages shadow view tree using DCFShadowView objects
 * 
 * This manages the shadow view hierarchy and coordinates with Yoga layout engine
 * to calculate and apply layout to views.
 */
class YogaShadowTree {
    static let shared = YogaShadowTree()
    
    // MARK: - Shadow View Registry
    
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
            } else if componentType == "Text" {
                // Text components require specialized shadow view for custom measurement.
                // Text size depends on content and available width, and must account for padding.
                // Other components use standard measurement (fixed size, intrinsic size, or child-based).
                shadowView = DCFTextShadowView(viewId: viewId)
            } else {
                shadowView = DCFShadowView(viewId: viewId)
            }
            
            shadowView.viewName = componentType
            
            // Apply default styles
            applyDefaultNodeStyles(to: shadowView, componentType: componentType)
            
            // Setup measure function if needed (Text has its own, so skip for Text)
            if componentType != "Text" {
                setupMeasureFunction(shadowView: shadowView, componentType: componentType)
            }
            
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
                oldParent.removeSubview(childShadowView)
                // Re-setup measure function for old parent (might be able to have measure function now)
                setupMeasureFunction(shadowView: oldParent, componentType: nodeTypes[oldParent.viewId] ?? "View")
            }
            
            // CRITICAL: Remove measure function from parent before adding child
            // Yoga rule: Nodes with measure functions cannot have children
            let parentYogaNode = parentShadowView.yogaNode
            if YGNodeHasMeasureFunc(parentYogaNode) {
                YGNodeSetMeasureFunc(parentYogaNode, nil)
            }
            
            // Add to new parent using shadow view's insertSubview method
            let insertIndex = index ?? parentShadowView.subviews.count
            parentShadowView.insertSubview(childShadowView, atIndex: insertIndex)
            
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
                parent.removeSubview(shadowView)
            }
            
            // Remove all children
            let children = shadowView.subviews
            for child in children {
                shadowView.removeSubview(child)
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
            return
        }
        
        syncQueue.sync {
            let yogaNode = shadowView.yogaNode
            var changedProps: [String] = []
            
            
            // All props (layout and text) are set through the same mechanism
            // For Text components, handle text props first
            if let textShadowView = shadowView as? DCFTextShadowView {
                // Extract text props and set them (equivalent to generated setters)
                let textProps = ["content", "fontSize", "fontWeight", "fontFamily", "letterSpacing",
                                "lineHeight", "numberOfLines", "textAlign", "textColor", "primaryColor"]
                let textPropsDict = props.filter { textProps.contains($0.key) }
                
                if !textPropsDict.isEmpty {
                    textShadowView.updateTextProps(textPropsDict)
                    changedProps.append(contentsOf: textPropsDict.keys)
                }
            }
            
            // Apply layout props and track which ones changed
            for (key, value) in props {
                // Skip text props as they're handled above
                let textProps = ["content", "fontSize", "fontWeight", "fontFamily", "letterSpacing",
                                "lineHeight", "numberOfLines", "textAlign", "textColor", "primaryColor"]
                if textProps.contains(key) {
                    continue
                }
                
                let changed = applyLayoutProp(shadowView: shadowView, node: yogaNode, key: key, value: value)
                if changed {
                    changedProps.append(key)
                }
            }
            
            // Process meta props (margin/padding/border) via didSetProps.
            // Meta properties are composite properties that affect multiple edges.
            if !changedProps.isEmpty {
                shadowView.didSetProps(changedProps)
            }
        }
    }
    
    // MARK: - Layout Calculation
    
    func calculateAndApplyLayout(width: CGFloat, height: CGFloat) -> Bool {
        let result = syncQueue.sync { () -> (Bool, Set<DCFShadowView>, Int, Int) in
            if isReconciling {
                return (false, Set<DCFShadowView>(), 0, 0)
            }
            
            isLayoutCalculating = true
            defer { isLayoutCalculating = false }
            
            guard let rootShadowView = rootShadowView else {
                return (false, Set<DCFShadowView>(), 0, 0)
            }
            
            // Update root available size
               // Set availableSize and let Yoga calculate layout naturally
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
                        rootView.frame = rootFrame
                        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    }
                }
            }
            
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
                let children = root.subviews
                for child in children {
                    root.removeSubview(child)
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
                let children = root.subviews
                for child in children {
                    root.removeSubview(child)
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
    
    func getShadowView(for viewId: Int) -> DCFShadowView? {
        // Check if we're already on the sync queue to avoid deadlock
        if DispatchQueue.getSpecific(key: syncQueueKey) != nil {
            // Already on sync queue, access directly
            return shadowViewRegistry[viewId]
        } else {
            // Not on sync queue, use sync
            return syncQueue.sync {
                return shadowViewRegistry[viewId]
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
        
        // Text components have their own measure function set in DCFTextShadowView.init
        // Don't overwrite it
        if shadowView is DCFTextShadowView {
            return
        }
        
        // For leaf nodes (no children), components can use intrinsic content size
        // The intrinsicContentSize property's didSet will automatically set the measure function
        // when components set it via getIntrinsicSize
        if childCount == 0 {
            // Measure function will be set automatically when intrinsicContentSize is set
            // by the component's getIntrinsicSize method
        } else {
            // Nodes with children cannot have measure functions
            YGNodeSetMeasureFunc(yogaNode, nil)
        }
    }
    
    private func applyDefaultNodeStyles(to shadowView: DCFShadowView, componentType: String) {
        let yogaNode = shadowView.yogaNode
        
        // Only set flexDirection based on useWebDefaults
        // Don't set justify-content, align-items, or align-content by default
        // Yoga's defaults handle undefined dimensions automatically
        if useWebDefaults {
            YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.row)
            YGNodeStyleSetFlexShrink(yogaNode, 1.0)
        } else {
            // Default: column direction, no flex shrink
            YGNodeStyleSetFlexDirection(yogaNode, YGFlexDirection.column)
            YGNodeStyleSetFlexShrink(yogaNode, 0.0)
        }
        
        // Don't set justify-content or align-items - let Yoga use defaults
        // This allows components to inherit proper sizing behavior automatically
    }
    
    // MARK: - Layout Property Application
    
    private func applyLayoutProp(shadowView: DCFShadowView, node: YGNodeRef, key: String, value: Any) -> Bool {
        switch key {
        case "width":
            if let width = parseDimension(value) {
                YGNodeStyleSetWidth(node, width)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetWidthPercent(node, percentValue)
                return true
            }
            return false
        case "height":
            if let height = parseDimension(value) {
                YGNodeStyleSetHeight(node, height)
                print("🔍 YogaShadowTree: Applied height=\(height) to node")
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetHeightPercent(node, percentValue)
                print("🔍 YogaShadowTree: Applied height=\(percentValue)% to node")
                return true
            }
            return false
        case "flex":
            if let flex = parseDimension(value) {
                YGNodeStyleSetFlex(node, flex)
                return true
            }
            return false
        case "flexDirection":
            if let direction = value as? String {
                switch direction {
                case "row":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.row)
                    return true
                case "column":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.column)
                    return true
                case "rowReverse":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.rowReverse)
                    return true
                case "columnReverse":
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.columnReverse)
                    return true
                default:
                    break
                }
            }
            return false
        case "flexWrap":
            if let wrap = value as? String {
                switch wrap {
                case "nowrap":
                    YGNodeStyleSetFlexWrap(node, YGWrap.noWrap)
                    return true
                case "wrap":
                    YGNodeStyleSetFlexWrap(node, YGWrap.wrap)
                    return true
                case "wrapReverse":
                    YGNodeStyleSetFlexWrap(node, YGWrap.wrapReverse)
                    return true
                default:
                    break
                }
            }
            return false
        case "flexGrow":
            if let grow = parseDimension(value) {
                YGNodeStyleSetFlexGrow(node, grow)
                return true
            }
            return false
        case "flexShrink":
            if let shrink = parseDimension(value) {
                YGNodeStyleSetFlexShrink(node, shrink)
                return true
            }
            return false
        case "flexBasis":
            if let basis = parseDimension(value) {
                YGNodeStyleSetFlexBasis(node, basis)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetFlexBasisPercent(node, percentValue)
                return true
            }
            return false
        case "display":
            if let display = value as? String {
                switch display {
                case "flex":
                    YGNodeStyleSetDisplay(node, YGDisplay.flex)
                    return true
                case "none":
                    YGNodeStyleSetDisplay(node, YGDisplay.none)
                    return true
                default:
                    break
                }
            }
            return false
        case "overflow":
            if let overflow = value as? String {
                switch overflow {
                case "visible":
                    YGNodeStyleSetOverflow(node, YGOverflow.visible)
                    return true
                case "hidden":
                    YGNodeStyleSetOverflow(node, YGOverflow.hidden)
                    return true
                case "scroll":
                    YGNodeStyleSetOverflow(node, YGOverflow.scroll)
                    return true
                default:
                    break
                }
            }
            return false
        case "minWidth":
            if let minWidth = parseDimension(value) {
                YGNodeStyleSetMinWidth(node, minWidth)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMinWidthPercent(node, percentValue)
                return true
            }
            return false
        case "maxWidth":
            if let maxWidth = parseDimension(value) {
                YGNodeStyleSetMaxWidth(node, maxWidth)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMaxWidthPercent(node, percentValue)
                return true
            }
            return false
        case "minHeight":
            if let minHeight = parseDimension(value) {
                YGNodeStyleSetMinHeight(node, minHeight)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMinHeightPercent(node, percentValue)
                return true
            }
            return false
        case "maxHeight":
            if let maxHeight = parseDimension(value) {
                YGNodeStyleSetMaxHeight(node, maxHeight)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMaxHeightPercent(node, percentValue)
                return true
            }
            return false
        case "margin":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.all, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.all, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "marginTop":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.top, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.top, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "marginRight":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.right, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.right, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "marginBottom":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.bottom, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.bottom, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "marginLeft":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.left, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.left, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "marginHorizontal":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.horizontal, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.horizontal, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "marginVertical":
            if let margin = parseDimension(value) {
                shadowView.storeMetaProp(.vertical, value: YGValue(value: margin, unit: .point), type: .margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.vertical, value: YGValue(value: percentValue, unit: .percent), type: .margin)
            }
            return true
        case "padding":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.all, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.all, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "paddingTop":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.top, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.top, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "paddingRight":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.right, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.right, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "paddingBottom":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.bottom, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.bottom, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "paddingLeft":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.left, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.left, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "paddingHorizontal":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.horizontal, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.horizontal, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "paddingVertical":
            if let padding = parseDimension(value) {
                shadowView.storeMetaProp(.vertical, value: YGValue(value: padding, unit: .point), type: .padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                shadowView.storeMetaProp(.vertical, value: YGValue(value: percentValue, unit: .percent), type: .padding)
            }
            return true
        case "justifyContent":
            if let justify = value as? String {
                switch justify {
                case "flexStart":
                    YGNodeStyleSetJustifyContent(node, YGJustify.flexStart)
                    return true
                case "center":
                    YGNodeStyleSetJustifyContent(node, YGJustify.center)
                    return true
                case "flexEnd":
                    YGNodeStyleSetJustifyContent(node, YGJustify.flexEnd)
                    return true
                case "spaceBetween":
                    YGNodeStyleSetJustifyContent(node, YGJustify.spaceBetween)
                    return true
                case "spaceAround":
                    YGNodeStyleSetJustifyContent(node, YGJustify.spaceAround)
                    return true
                case "spaceEvenly":
                    YGNodeStyleSetJustifyContent(node, YGJustify.spaceEvenly)
                    return true
                default:
                    break
                }
            }
            return false
        case "alignItems":
            if let align = value as? String {
                switch align {
                case "flexStart":
                    YGNodeStyleSetAlignItems(node, YGAlign.flexStart)
                    return true
                case "center":
                    YGNodeStyleSetAlignItems(node, YGAlign.center)
                    return true
                case "flexEnd":
                    YGNodeStyleSetAlignItems(node, YGAlign.flexEnd)
                    return true
                case "stretch":
                    YGNodeStyleSetAlignItems(node, YGAlign.stretch)
                    return true
                case "baseline":
                    YGNodeStyleSetAlignItems(node, YGAlign.baseline)
                    return true
                default:
                    break
                }
            }
            return false
        case "alignSelf":
            if let align = value as? String {
                switch align {
                case "auto":
                    YGNodeStyleSetAlignSelf(node, YGAlign.auto)
                    return true
                case "flexStart":
                    YGNodeStyleSetAlignSelf(node, YGAlign.flexStart)
                    return true
                case "center":
                    YGNodeStyleSetAlignSelf(node, YGAlign.center)
                    return true
                case "flexEnd":
                    YGNodeStyleSetAlignSelf(node, YGAlign.flexEnd)
                    return true
                case "stretch":
                    YGNodeStyleSetAlignSelf(node, YGAlign.stretch)
                    return true
                case "baseline":
                    YGNodeStyleSetAlignSelf(node, YGAlign.baseline)
                    return true
                default:
                    break
                }
            }
            return false
        case "alignContent":
            if let align = value as? String {
                switch align {
                case "flexStart":
                    YGNodeStyleSetAlignContent(node, YGAlign.flexStart)
                    return true
                case "center":
                    YGNodeStyleSetAlignContent(node, YGAlign.center)
                    return true
                case "flexEnd":
                    YGNodeStyleSetAlignContent(node, YGAlign.flexEnd)
                    return true
                case "stretch":
                    YGNodeStyleSetAlignContent(node, YGAlign.stretch)
                    return true
                case "spaceBetween":
                    YGNodeStyleSetAlignContent(node, YGAlign.spaceBetween)
                    return true
                case "spaceAround":
                    YGNodeStyleSetAlignContent(node, YGAlign.spaceAround)
                    return true
                default:
                    break
                }
            }
            return false
        case "position":
            if let position = value as? String {
                switch position {
                case "relative":
                    YGNodeStyleSetPositionType(node, YGPositionType.relative)
                    return true
                case "absolute":
                    YGNodeStyleSetPositionType(node, YGPositionType.absolute)
                    return true
                default:
                    break
                }
            }
            return false
        case "top":
            if let top = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.top, top)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.top, percentValue)
                return true
            }
            return false
        case "right":
            if let right = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.right, right)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.right, percentValue)
                return true
            }
            return false
        case "bottom":
            if let bottom = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.bottom, bottom)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.bottom, percentValue)
                return true
            }
            return false
        case "left":
            if let left = parseDimension(value) {
                YGNodeStyleSetPosition(node, YGEdge.left, left)
                return true
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.left, percentValue)
                return true
            }
            return false
        case "aspectRatio":
            if let ratio = parseDimension(value) {
                YGNodeStyleSetAspectRatio(node, ratio)
                return true
            }
            return false
        case "gap":
            if let gap = parseDimension(value) {
                YGNodeStyleSetGap(node, YGGutter.all, gap)
                return true
            }
            return false
        case "rowGap":
            if let rowGap = parseDimension(value) {
                YGNodeStyleSetGap(node, YGGutter.row, rowGap)
                return true
            }
            return false
        case "columnGap":
            if let columnGap = parseDimension(value) {
                YGNodeStyleSetGap(node, YGGutter.column, columnGap)
                return true
            }
            return false
        case "direction", "zIndex":
            // These are handled but don't need special processing
            return true
        case "borderWidth":
            // Store border width as meta prop
            if let borderWidth = parseDimension(value) {
                shadowView.storeMetaProp(.all, value: YGValue(value: borderWidth, unit: .point), type: .border)
                return true
            }
            return false
        case "borderTopWidth":
            if let borderWidth = parseDimension(value) {
                shadowView.storeMetaProp(.top, value: YGValue(value: borderWidth, unit: .point), type: .border)
                return true
            }
            return false
        case "borderRightWidth":
            if let borderWidth = parseDimension(value) {
                shadowView.storeMetaProp(.right, value: YGValue(value: borderWidth, unit: .point), type: .border)
                return true
            }
            return false
        case "borderBottomWidth":
            if let borderWidth = parseDimension(value) {
                shadowView.storeMetaProp(.bottom, value: YGValue(value: borderWidth, unit: .point), type: .border)
                return true
            }
            return false
        case "borderLeftWidth":
            if let borderWidth = parseDimension(value) {
                shadowView.storeMetaProp(.left, value: YGValue(value: borderWidth, unit: .point), type: .border)
                return true
            }
            return false
        default:
            return false
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
    
    // MARK: - Text Node Invalidation
    
    /**
     * Invalidate all text nodes to force re-measurement with new font scale
     * Called when system font size changes
     */
    func invalidateAllTextNodes() {
        syncQueue.sync {
            var textNodeCount = 0
            for (_, shadowView) in shadowViewRegistry {
                if let textShadowView = shadowView as? DCFTextShadowView {
                    // Clear cached text storage and mark as dirty
                    textShadowView.dirtyText()
                    textNodeCount += 1
                }
            }
            print("📝 YogaShadowTree: Marked \(textNodeCount) text nodes as dirty for font scale change")
        }
    }
}

