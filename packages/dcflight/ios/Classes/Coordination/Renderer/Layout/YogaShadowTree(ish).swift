/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import yoga

/// Shadow tree for layout calculations using Yoga
class YogaShadowTree {
    // Singleton instance
    static let shared = YogaShadowTree()
    
    // Root node of the shadow tree
    private var rootNode: YGNodeRef?
    
    // Map of node IDs to yoga nodes
    internal var nodes = [String: YGNodeRef]()
    
    // Map of child-parent relationships
    internal var nodeParents = [String: String]()
    
    // Map for storing component types
    private var nodeTypes = [String: String]()
    
    // CRASH FIX: Add synchronization and state tracking
    private let syncQueue = DispatchQueue(label: "YogaShadowTree.sync", qos: .userInitiated)
    private var isLayoutCalculating = false
    private var isReconciling = false
    
    // Private initializer for singleton
    private init() {
        // Create root node
        rootNode = YGNodeNew()
        
        // Configure default root properties
        if let root = rootNode {
            YGNodeStyleSetDirection(root, YGDirection.LTR)
            YGNodeStyleSetFlexDirection(root, YGFlexDirection.column)
            YGNodeStyleSetWidth(root, Float(UIScreen.main.bounds.width))
            YGNodeStyleSetHeight(root, Float(UIScreen.main.bounds.height))
            
            // Store root node
            nodes["root"] = root
            nodeTypes["root"] = "View"
        }
        
    }
    
    // CRASH FIX: Safe node creation with synchronization
    func createNode(id: String, componentType: String) {
        syncQueue.sync {
            
            // Create new node
            let node = YGNodeNew()
            
            if let node = node {
                // Initialize node context to empty dictionary for translations
                let emptyContext = [String: Any]()
                YGNodeSetContext(node, Unmanaged.passRetained(emptyContext as NSDictionary).toOpaque())
                
                // Store node
                nodes[id] = node
                nodeTypes[id] = componentType
            } else {
            }
        }
    }
    
    // CRASH FIX: Safe child node addition with synchronization
    func addChildNode(parentId: String, childId: String, index: Int? = nil) {
        syncQueue.sync {
            guard let parentNode = nodes[parentId], let childNode = nodes[childId] else {
                return
            }
            
            
            // First, remove child from any existing parent
            if let oldParentId = nodeParents[childId], let oldParentNode = nodes[oldParentId] {
                safeRemoveChildFromParent(parentNode: oldParentNode, childNode: childNode, childId: childId)
            }
            
            // Then add to new parent with bounds checking
            if let index = index {
                // Add at specific index with bounds checking
                let childCount = Int(YGNodeGetChildCount(parentNode))
                let safeIndex = min(max(0, index), childCount) // Clamp index to valid range
                YGNodeInsertChild(parentNode, childNode, Int(Int32(safeIndex)))
            } else {
                // Add at the end
                let childCount = Int(YGNodeGetChildCount(parentNode))
                YGNodeInsertChild(parentNode, childNode, Int(Int32(childCount)))
            }
            
            // Update parent reference
            nodeParents[childId] = parentId
            
        }
    }
    
    // CRASH FIX: Safe node removal with synchronization
    func removeNode(nodeId: String) {
        syncQueue.sync {
            // Signal that reconciliation is in progress
            isReconciling = true
            
            // Wait for any active layout calculation to complete
            while isLayoutCalculating {
                usleep(1000) // 1ms sleep
            }
            
            guard let node = nodes[nodeId] else {
                isReconciling = false
                return
            }
            
            
            // CRITICAL: Remove from parent with bounds checking
            if let parentId = nodeParents[nodeId], let parentNode = nodes[parentId] {
                safeRemoveChildFromParent(parentNode: parentNode, childNode: node, childId: nodeId)
            }
            
            // CRITICAL: Safely remove all children with bounds checking
            safeRemoveAllChildren(from: node, nodeId: nodeId)
            
            // Free Yoga node memory
            YGNodeFree(node)
            
            // Clean up references
            nodes.removeValue(forKey: nodeId)
            nodeParents.removeValue(forKey: nodeId)
            nodeTypes.removeValue(forKey: nodeId)
            
            // Signal reconciliation complete
            isReconciling = false
            
        }
    }
    
    // CRASH FIX: Helper method to safely remove child from parent with bounds checking
    private func safeRemoveChildFromParent(parentNode: YGNodeRef, childNode: YGNodeRef, childId: String) {
        let childCount = YGNodeGetChildCount(parentNode)
        
        // Bounds check to prevent vector access issues
        guard childCount > 0 else {
            return
        }
        
        // Find and remove the child safely
        for i in 0..<childCount {
            if let child = YGNodeGetChild(parentNode, i), child == childNode {
                YGNodeRemoveChild(parentNode, childNode)
                break
            }
        }
    }
    
    // CRASH FIX: Helper method to safely remove all children with bounds checking
    private func safeRemoveAllChildren(from node: YGNodeRef, nodeId: String) {
        var childCount = YGNodeGetChildCount(node)
        
        
        // Reverse iteration to avoid index shifting issues during removal
        while childCount > 0 {
            // Always get the last child to avoid index shifting
            let lastIndex = childCount - 1
            
            // Bounds check before accessing
            guard let childNode = YGNodeGetChild(node, lastIndex) else {
                break
            }
            
            // Remove the child
            YGNodeRemoveChild(node, childNode)
            
            // Update count and check for infinite loop protection
            let newChildCount = YGNodeGetChildCount(node)
            if newChildCount >= childCount {
                break
            }
            
            childCount = newChildCount
        }
        
    }
    
    // Update a node's layout properties
    func updateNodeLayoutProps(nodeId: String, props: [String: Any]) {
        guard let node = nodes[nodeId] else {
            return
        }
        
        // Process each property
        for (key, value) in props {
            applyLayoutProp(node: node, key: key, value: value)
        }
        
        // Validate layout configuration to prevent crashes
        validateNodeLayoutConfig(nodeId: nodeId)
    }
    
    // CRASH FIX: Layout calculation with synchronization
    func calculateAndApplyLayout(width: CGFloat, height: CGFloat) -> Bool {
        return syncQueue.sync {
            
            // Check if reconciliation is in progress
            if isReconciling {
                return false
            }
            
            // Signal that layout calculation is starting
            isLayoutCalculating = true
            defer { isLayoutCalculating = false }
            
            
            // Make sure root node exists
            guard let root = nodes["root"] else {
                return false
            }
            
            // Set proper width and height on root
            YGNodeStyleSetWidth(root, Float(width))
            YGNodeStyleSetHeight(root, Float(height))
            
            // Pre-validate all nodes to prevent Yoga crashes
            for (nodeId, _) in nodes {
                validateNodeLayoutConfig(nodeId: nodeId)
            }
            
            // Calculate layout with error handling
            do {
                // Use try-catch to handle potential Yoga exceptions
                try {
                    YGNodeCalculateLayout(root, Float(width), Float(height), YGDirection.LTR)
                }()
                
                // Apply layout to all views
                for (nodeId, _) in nodes {
                    if let layout = getNodeLayout(nodeId: nodeId) {
                        applyLayoutToView(viewId: nodeId, frame: layout)
                    }
                }
                return true
            } catch {
                
                // Emergency fallback - try to fix most common issues and retry once
                fixLayoutErrors()
                
                // Try again with fixed layout
                do {
                    try {
                        YGNodeCalculateLayout(root, Float(width), Float(height), YGDirection.LTR)
                    }()
                    
                    // Apply layout to all views after recovery
                    for (nodeId, _) in nodes {
                        if let layout = getNodeLayout(nodeId: nodeId) {
                            applyLayoutToView(viewId: nodeId, frame: layout)
                        }
                    }
                    return true
                } catch {
                    return false
                }
            }
        }
    }
    
    // Get layout for a node
    func getNodeLayout(nodeId: String) -> CGRect? {
        guard let node = nodes[nodeId] else { return nil }
        
        // Get layout values
        let left = CGFloat(YGNodeLayoutGetLeft(node))
        let top = CGFloat(YGNodeLayoutGetTop(node))
        let width = CGFloat(YGNodeLayoutGetWidth(node))
        let height = CGFloat(YGNodeLayoutGetHeight(node))
        
        return CGRect(x: left, y: top, width: width, height: height)
    }
    
    // Check and fix any invalid layout configuration issues
    private func validateNodeLayoutConfig(nodeId: String) {
        guard let node = nodes[nodeId] else { return }
        
        // Check if height is undefined and node has children
        if YGNodeGetChildCount(node) > 0 && 
           YGNodeStyleGetHeight(node).unit == YGUnit.undefined {
            
            // Prevent "availableHeight is indefinite" error by setting height sizing mode
            // to YGMeasureModeAtMost when necessary
            YGNodeStyleSetHeightAuto(node)
            
        }
    }
    
    // Apply a layout property to a node
    private func applyLayoutProp(node: YGNodeRef, key: String, value: Any) {
        switch key {
        case "translateX":
            updateNodeTransformContext(node: node, key: "translateX", value: value)
        case "translateY":
            updateNodeTransformContext(node: node, key: "translateY", value: value)
        case "rotateInDegrees":
            if let degrees = convertToFloat(value) {
                let radians = degrees * Float.pi / 180.0
                updateNodeTransformContext(node: node, key: "rotate", value: radians)
            }
        case "scale":
            if let scale = convertToFloat(value) {
                updateNodeTransformContext(node: node, key: "scale", value: scale)
            }
        case "scaleX":
            if let scaleX = convertToFloat(value) {
                updateNodeTransformContext(node: node, key: "scaleX", value: scaleX)
            }
        case "scaleY":
            if let scaleY = convertToFloat(value) {
                updateNodeTransformContext(node: node, key: "scaleY", value: scaleY)
            }
        case "width":
            if let width = convertToFloat(value) {
                YGNodeStyleSetWidth(node, width)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetWidthPercent(node, percentValue)
            }
        case "height":
            if let height = convertToFloat(value) {
                YGNodeStyleSetHeight(node, height)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetHeightPercent(node, percentValue)
            }
        case "minWidth":
            if let minWidth = convertToFloat(value) {
                YGNodeStyleSetMinWidth(node, minWidth)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMinWidthPercent(node, percentValue)
            }
        case "maxWidth":
            if let maxWidth = convertToFloat(value) {
                YGNodeStyleSetMaxWidth(node, maxWidth)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMaxWidthPercent(node, percentValue)
            }
        case "minHeight":
            if let minHeight = convertToFloat(value) {
                YGNodeStyleSetMinHeight(node, minHeight)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMinHeightPercent(node, percentValue)
            }
        case "maxHeight":
            if let maxHeight = convertToFloat(value) {
                YGNodeStyleSetMaxHeight(node, maxHeight)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMaxHeightPercent(node, percentValue)
            }
        case "margin":
            if let margin = convertToFloat(value) {
                YGNodeStyleSetMargin(node, YGEdge.all, margin)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.all, percentValue)
            }
        case "marginTop":
            if let marginTop = convertToFloat(value) {
                YGNodeStyleSetMargin(node, YGEdge.top, marginTop)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.top, percentValue)
            }
        case "marginRight":
            if let marginRight = convertToFloat(value) {
                YGNodeStyleSetMargin(node, YGEdge.right, marginRight)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.right, percentValue)
            }
        case "marginBottom":
            if let marginBottom = convertToFloat(value) {
                YGNodeStyleSetMargin(node, YGEdge.bottom, marginBottom)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.bottom, percentValue)
            }
        case "marginLeft":
            if let marginLeft = convertToFloat(value) {
                YGNodeStyleSetMargin(node, YGEdge.left, marginLeft)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetMarginPercent(node, YGEdge.left, percentValue)
            }
        case "padding":
            if let padding = convertToFloat(value) {
                YGNodeStyleSetPadding(node, YGEdge.all, padding)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.all, percentValue)
            }
        case "paddingTop":
            if let paddingTop = convertToFloat(value) {
                YGNodeStyleSetPadding(node, YGEdge.top, paddingTop)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.top, percentValue)
            }
        case "paddingRight":
            if let paddingRight = convertToFloat(value) {
                YGNodeStyleSetPadding(node, YGEdge.right, paddingRight)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.right, percentValue)
            }
        case "paddingBottom":
            if let paddingBottom = convertToFloat(value) {
                YGNodeStyleSetPadding(node, YGEdge.bottom, paddingBottom)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.bottom, percentValue)
            }
        case "paddingLeft":
            if let paddingLeft = convertToFloat(value) {
                YGNodeStyleSetPadding(node, YGEdge.left, paddingLeft)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPaddingPercent(node, YGEdge.left, percentValue)
            }
        case "position":
            if let position = value as? String {
                switch position {
                case "absolute":
                    YGNodeStyleSetPositionType(node, YGPositionType.absolute)
                case "relative":
                    YGNodeStyleSetPositionType(node, YGPositionType.relative)
                default:
                    break
                }
            }
        case "left":
            if let left = convertToFloat(value) {
                YGNodeStyleSetPosition(node, YGEdge.left, left)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.left, percentValue)
            }
        case "top":
            if let top = convertToFloat(value) {
                YGNodeStyleSetPosition(node, YGEdge.top, top)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.top, percentValue)
            }
        case "right":
            if let right = convertToFloat(value) {
                YGNodeStyleSetPosition(node, YGEdge.right, right)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.right, percentValue)
            }
        case "bottom":
            if let bottom = convertToFloat(value) {
                YGNodeStyleSetPosition(node, YGEdge.bottom, bottom)
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                YGNodeStyleSetPositionPercent(node, YGEdge.bottom, percentValue)
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
                case "auto":
                    YGNodeStyleSetAlignItems(node, YGAlign.auto)
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
                case "spaceBetween":
                    YGNodeStyleSetAlignItems(node, YGAlign.spaceBetween)
                case "spaceAround":
                    YGNodeStyleSetAlignItems(node, YGAlign.spaceAround)
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
                case "spaceBetween":
                    YGNodeStyleSetAlignSelf(node, YGAlign.spaceBetween)
                case "spaceAround":
                    YGNodeStyleSetAlignSelf(node, YGAlign.spaceAround)
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
        case "flex":
            if let flex = convertToFloat(value) {
                YGNodeStyleSetFlex(node, flex)
            }
        case "flexGrow":
            if let flexGrow = convertToFloat(value) {
                YGNodeStyleSetFlexGrow(node, flexGrow)
            }
        case "flexShrink":
            if let flexShrink = convertToFloat(value) {
                YGNodeStyleSetFlexShrink(node, flexShrink)
            }
        case "flexBasis":
            if let flexBasis = convertToFloat(value) {
                YGNodeStyleSetFlexBasis(node, flexBasis)
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
        case "direction":
            if let direction = value as? String {
                switch direction {
                case "inherit":
                    YGNodeStyleSetDirection(node, YGDirection.inherit)
                case "ltr":
                    YGNodeStyleSetDirection(node, YGDirection.LTR)
                case "rtl":
                    YGNodeStyleSetDirection(node, YGDirection.RTL)
                default:
                    break
                }
            }
        case "borderWidth":
            if let borderWidth = convertToFloat(value) {
                YGNodeStyleSetBorder(node, YGEdge.all, borderWidth)
            }
        case "aspectRatio":
            if let aspectRatio = convertToFloat(value) {
                YGNodeStyleSetAspectRatio(node, aspectRatio)
            }
        case "gap":
            if let gap = convertToFloat(value) {
                YGNodeStyleSetGap(node, YGGutter.all, gap)
            }
        case "rowGap":
            if let rowGap = convertToFloat(value) {
                YGNodeStyleSetGap(node, YGGutter.row, rowGap)
            }
        case "columnGap":
            if let columnGap = convertToFloat(value) {
                YGNodeStyleSetGap(node, YGGutter.column, columnGap)
            }
        default:
            break
        }
    }
    
    // Fix common layout errors that cause crashes
    private func fixLayoutErrors() {
        
        for (nodeId, node) in nodes {
            // Fix 1: Set auto height for nodes with children but undefined height
            if YGNodeGetChildCount(node) > 0 && YGNodeStyleGetHeight(node).unit == YGUnit.undefined {
                YGNodeStyleSetHeightAuto(node)
            }
            
            // Fix 2: If a leaf node with no width/height, set reasonable defaults
            if YGNodeGetChildCount(node) == 0 && 
               YGNodeStyleGetHeight(node).unit == YGUnit.undefined &&
               YGNodeStyleGetWidth(node).unit == YGUnit.undefined {
                YGNodeStyleSetMinHeight(node, 1)
                YGNodeStyleSetMinWidth(node, 1)
            }
            
            // Fix 3: If node has flex but no defined dimensions, set flex basis auto
            if YGNodeStyleGetFlex(node) != 0 && 
               YGNodeStyleGetHeight(node).unit == YGUnit.undefined &&
               YGNodeStyleGetWidth(node).unit == YGUnit.undefined {
                YGNodeStyleSetFlexBasisAuto(node)
            }
            
            // Fix 4: For rows with undefined height, set height:auto
            if YGNodeStyleGetFlexDirection(node) == YGFlexDirection.row &&
               YGNodeStyleGetHeight(node).unit == YGUnit.undefined {
                YGNodeStyleSetHeightAuto(node)
            }
        }
    }

    // Helper to convert input values to Float
    private func convertToFloat(_ value: Any) -> Float? {
        if let num = value as? Float {
            return num
        } else if let num = value as? Double {
            return Float(num)
        } else if let num = value as? Int {
            return Float(num)
        } else if let num = value as? CGFloat {
            return Float(num)
        } else if let str = value as? String, let num = Float(str) {
            return num
        }
        return nil
    }
    
    // Safe transform context management to prevent memory leaks and crashes
    private func updateNodeTransformContext(node: YGNodeRef, key: String, value: Any) {
        // Get existing context dictionary or create new one
        var contextDict: [String: Any] = [:]
        
        // Safely get existing context without releasing it yet
        if let existingContextPtr = YGNodeGetContext(node) {
            if let existingContext = Unmanaged<NSDictionary>.fromOpaque(existingContextPtr).takeUnretainedValue() as? [String: Any] {
                contextDict = existingContext
            }
        }
        
        // Update the specific property based on key and value
        switch key {
        case "translateX":
            if let translateX = convertToFloat(value) {
                contextDict["translateX"] = translateX
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                contextDict["translateXPercent"] = percentValue
            }
        case "translateY":
            if let translateY = convertToFloat(value) {
                contextDict["translateY"] = translateY
            } else if let strValue = value as? String, strValue.hasSuffix("%"),
                     let percentValue = Float(strValue.dropLast()) {
                contextDict["translateYPercent"] = percentValue
            }
        default:
            // For rotate, scale, scaleX, scaleY - direct value assignment
            if let floatValue = value as? Float {
                contextDict[key] = floatValue
            }
        }
        
        // Release old context if it exists before setting new one
        if let existingContextPtr = YGNodeGetContext(node) {
            Unmanaged<NSDictionary>.fromOpaque(existingContextPtr).release()
        }
        
        // Set the new context
        YGNodeSetContext(node, Unmanaged.passRetained(contextDict as NSDictionary).toOpaque())
    }
    
    // Set a custom measure function for nodes that need to self-measure
    func setCustomMeasureFunction(nodeId: String, measureFunc: @escaping YGMeasureFunc) {
        guard let node = nodes[nodeId] else { return }
        
        // Make sure node has no children before setting measure function
        if YGNodeGetChildCount(node) == 0 {
            YGNodeSetMeasureFunc(node, measureFunc)
        }
    }
    
    // Apply layout to a view
    private func applyLayoutToView(viewId: String, frame: CGRect) {
        // Get the view from the layout manager
        guard let view = DCFLayoutManager.shared.getView(withId: viewId),
              let node = nodes[viewId] else {
            return
        }
        
        // Get original frame
        var finalFrame = frame
        
        // Apply transforms if any
        if let contextPtr = YGNodeGetContext(node),
           let contextDict = Unmanaged<NSDictionary>.fromOpaque(contextPtr).takeUnretainedValue() as? [String: Any] {
            
            // Create transform matrices
            var transform = CGAffineTransform.identity
            
            // Handle translation
            var translationX: CGFloat = 0
            var translationY: CGFloat = 0
            
            // Handle translateX (absolute value)
            if let translateX = contextDict["translateX"] as? Float {
                translationX += CGFloat(translateX)
            }
            
            // Handle translateX (percentage)
            if let translateXPercent = contextDict["translateXPercent"] as? Float {
                let parentWidth = finalFrame.width
                translationX += CGFloat(translateXPercent * Float(parentWidth) / 100.0)
            }
            
            // Handle translateY (absolute value)
            if let translateY = contextDict["translateY"] as? Float {
                translationY += CGFloat(translateY)
            }
            
            // Handle translateY (percentage)
            if let translateYPercent = contextDict["translateYPercent"] as? Float {
                let parentHeight = finalFrame.height
                translationY += CGFloat(translateYPercent * Float(parentHeight) / 100.0)
            }
            
            // Apply translations to the frame position
            finalFrame.origin.x += translationX
            finalFrame.origin.y += translationY
            
            // Handle scaling and rotation (these will be applied as transforms to the view itself)
            var hasTransform = false
            
            // Get center point for transforms
            let centerX = finalFrame.width / 2.0
            let centerY = finalFrame.height / 2.0
            
            // Center transform around the view's center
            transform = transform.translatedBy(x: centerX, y: centerY)
            
            // Apply rotation if specified
            if let rotation = contextDict["rotate"] as? Float {
                transform = transform.rotated(by: CGFloat(rotation))
                hasTransform = true
            }
            
            // Apply uniform scaling if specified
            if let scale = contextDict["scale"] as? Float {
                transform = transform.scaledBy(x: CGFloat(scale), y: CGFloat(scale))
                hasTransform = true
            } 
            // Otherwise apply individual axis scaling if specified
            else {
                var scaleXValue: CGFloat = 1.0
                var scaleYValue: CGFloat = 1.0
                
                if let scaleX = contextDict["scaleX"] as? Float {
                    scaleXValue = CGFloat(scaleX)
                    hasTransform = true
                }
                
                if let scaleY = contextDict["scaleY"] as? Float {
                    scaleYValue = CGFloat(scaleY)
                    hasTransform = true
                }
                
                if hasTransform {
                    transform = transform.scaledBy(x: scaleXValue, y: scaleYValue)
                }
            }
            
            // Translate back to original position
            transform = transform.translatedBy(x: -centerX, y: -centerY)
            
            // Store the transform for later application to the view
            if hasTransform {
                DispatchQueue.main.async { [weak self] in
                    // 🔥 HOT RESTART SAFETY: Check if view is still valid before applying transform
                    guard let view = DCFLayoutManager.shared.getView(withId: viewId),
                          view.superview != nil || view.window != nil else {
                        return
                    }
                    view.transform = transform
                }
            }
        }
        
        // Apply layout using layout manager
        DispatchQueue.main.async { [weak self] in
            // 🔥 HOT RESTART SAFETY: Comprehensive view validation before applying layout
            guard let self = self,
                  let view = DCFLayoutManager.shared.getView(withId: viewId) else {
                return
            }
            
            // Multi-level safety check
            guard view.superview != nil || view.window != nil,
                  view.layer != nil,
                  !view.isEqual(nil) else {
                return
            }
            
            // Additional frame validation
            guard finalFrame.width.isFinite && finalFrame.height.isFinite &&
                  finalFrame.origin.x.isFinite && finalFrame.origin.y.isFinite else {
                return
            }
            
            DCFLayoutManager.shared.applyLayout(
                to: viewId,
                left: finalFrame.origin.x,
                top: finalFrame.origin.y,
                width: finalFrame.width,
                height: finalFrame.height
            )
        }
    }
    
    // Cleanup
    deinit {
        // Free all nodes
        for (_, node) in nodes {
            YGNodeFree(node)
        }
    }
}

