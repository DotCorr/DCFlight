/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import yoga

class YogaShadowTree {
    static let shared = YogaShadowTree()
    
    private var rootNode: YGNodeRef?
    internal var nodes = [String: YGNodeRef]()
    internal var nodeParents = [String: String]()
    private var nodeTypes = [String: String]()
    private var screenRoots = [String: YGNodeRef]()
    private var screenRootIds = Set<String>()
    
    private let syncQueue = DispatchQueue(label: "YogaShadowTree.sync", qos: .userInitiated)
    private var isLayoutCalculating = false
    private var isReconciling = false
    
    // ENHANCEMENT: Web defaults configuration
    private var useWebDefaults = false
    
    private init() {
        rootNode = YGNodeNew()
        
        if let root = rootNode {
            YGNodeStyleSetDirection(root, YGDirection.LTR)
            YGNodeStyleSetFlexDirection(root, YGFlexDirection.column)
            YGNodeStyleSetWidth(root, Float(UIScreen.main.bounds.width))
            YGNodeStyleSetHeight(root, Float(UIScreen.main.bounds.height))
            
            nodes["root"] = root
            nodeTypes["root"] = "View"
        }
    }
    
    func createNode(id: String, componentType: String) {
        syncQueue.sync {
            let node = YGNodeNew()
            
            if let node = node {
                // Apply default styles based on configuration
                applyDefaultNodeStyles(to: node)
                
                let context: [String: Any] = [
                    "nodeId": id,
                    "componentType": componentType,
                    "props": [:]
                ]
                YGNodeSetContext(node, Unmanaged.passRetained(context as NSDictionary).toOpaque())
                
                nodes[id] = node
                nodeTypes[id] = componentType
                
                setupMeasureFunction(nodeId: id, node: node)
            }
        }
    }
    
    func createScreenRoot(id: String, componentType: String) {
        syncQueue.sync {
            let screenRoot = YGNodeNew()
            
            if let screenRoot = screenRoot {
                YGNodeStyleSetDirection(screenRoot, YGDirection.LTR)
                YGNodeStyleSetFlexDirection(screenRoot, YGFlexDirection.column)
                YGNodeStyleSetWidth(screenRoot, Float(UIScreen.main.bounds.width))
                YGNodeStyleSetHeight(screenRoot, Float(UIScreen.main.bounds.height))
                YGNodeStyleSetPosition(screenRoot, YGEdge.left, 0)
                YGNodeStyleSetPosition(screenRoot, YGEdge.top, 0)
                YGNodeStyleSetPositionType(screenRoot, YGPositionType.absolute)
                
                let context: [String: Any] = [
                    "nodeId": id,
                    "componentType": componentType,
                    "props": [:]
                ]
                YGNodeSetContext(screenRoot, Unmanaged.passRetained(context as NSDictionary).toOpaque())
                
                nodes[id] = screenRoot
                screenRoots[id] = screenRoot
                screenRootIds.insert(id)
                nodeTypes[id] = componentType
            }
        }
    }
    
    private func setupMeasureFunction(nodeId: String, node: YGNodeRef) {
        let childCount = YGNodeGetChildCount(node)
        
        if childCount == 0 {
            YGNodeSetMeasureFunc(node) { (yogaNode, width, widthMode, height, heightMode) -> YGSize in
                guard let context = YGNodeGetContext(yogaNode),
                      let contextDict = Unmanaged<NSDictionary>.fromOpaque(context).takeUnretainedValue() as? [String: Any],
                      let nodeId = contextDict["nodeId"] as? String,
                      let componentType = contextDict["componentType"] as? String,
                      let view = DCFLayoutManager.shared.getView(withId: nodeId) else {
                    return YGSize(width: 0, height: 0)
                }
                
                let constraintSize = CGSize(
                    width: widthMode == YGMeasureMode.undefined ? CGFloat.greatestFiniteMagnitude : CGFloat(width),
                    height: heightMode == YGMeasureMode.undefined ? CGFloat.greatestFiniteMagnitude : CGFloat(height)
                )
                
                let props = contextDict["props"] as? [String: Any] ?? [:]
                
                guard let componentClass = DCFComponentRegistry.shared.getComponent(componentType) else {
                    return YGSize(width: Float(constraintSize.width), height: Float(constraintSize.height))
                }
                
                let componentInstance = componentClass.init()
                let intrinsicSize = componentInstance.getIntrinsicSize(view, forProps: props)
                
                let finalWidth = widthMode == YGMeasureMode.undefined ? intrinsicSize.width : min(intrinsicSize.width, constraintSize.width)
                let finalHeight = heightMode == YGMeasureMode.undefined ? intrinsicSize.height : min(intrinsicSize.height, constraintSize.height)
                
                return YGSize(width: Float(finalWidth), height: Float(finalHeight))
            }
        } else {
            YGNodeSetMeasureFunc(node, nil)
        }
    }
    
    func addChildNode(parentId: String, childId: String, index: Int? = nil) {
        syncQueue.sync {
            guard let parentNode = nodes[parentId], let childNode = nodes[childId] else {
                return
            }
            
            if screenRootIds.contains(childId) {
                return
            }
            
            if let oldParentId = nodeParents[childId], let oldParentNode = nodes[oldParentId] {
                safeRemoveChildFromParent(parentNode: oldParentNode, childNode: childNode, childId: childId)
                setupMeasureFunction(nodeId: oldParentId, node: oldParentNode)
            }
            
            YGNodeSetMeasureFunc(parentNode, nil)
            
            if let index = index {
                let childCount = Int(YGNodeGetChildCount(parentNode))
                let safeIndex = min(max(0, index), childCount)
                YGNodeInsertChild(parentNode, childNode, Int(Int32(safeIndex)))
            } else {
                let childCount = Int(YGNodeGetChildCount(parentNode))
                YGNodeInsertChild(parentNode, childNode, Int(Int32(childCount)))
            }
            
            nodeParents[childId] = parentId
            
            // CRITICAL: Apply parent layout inheritance to child for cross-platform consistency
            applyParentLayoutInheritance(childNode: childNode, parentNode: parentNode, childId: childId)
            
            setupMeasureFunction(nodeId: childId, node: childNode)
        }
    }
    
    func removeNode(nodeId: String) {
        syncQueue.sync {
            isReconciling = true
            
            while isLayoutCalculating {
                usleep(1000)
            }
            
            guard let node = nodes[nodeId] else {
                isReconciling = false
                return
            }
            
            if screenRootIds.contains(nodeId) {
                screenRoots.removeValue(forKey: nodeId)
                screenRootIds.remove(nodeId)
            } else {
                if let parentId = nodeParents[nodeId], let parentNode = nodes[parentId] {
                    safeRemoveChildFromParent(parentNode: parentNode, childNode: node, childId: nodeId)
                    setupMeasureFunction(nodeId: parentId, node: parentNode)
                }
            }
            
            safeRemoveAllChildren(from: node, nodeId: nodeId)
            YGNodeFree(node)
            
            nodes.removeValue(forKey: nodeId)
            nodeParents.removeValue(forKey: nodeId)
            nodeTypes.removeValue(forKey: nodeId)
            
            isReconciling = false
        }
    }
    
    private func safeRemoveChildFromParent(parentNode: YGNodeRef, childNode: YGNodeRef, childId: String) {
        let childCount = YGNodeGetChildCount(parentNode)
        
        guard childCount > 0 else {
            return
        }
        
        for i in 0..<childCount {
            if let child = YGNodeGetChild(parentNode, i), child == childNode {
                YGNodeRemoveChild(parentNode, childNode)
                break
            }
        }
    }
    
    private func safeRemoveAllChildren(from node: YGNodeRef, nodeId: String) {
        var childCount = YGNodeGetChildCount(node)
        
        while childCount > 0 {
            let lastIndex = childCount - 1
            
            guard let childNode = YGNodeGetChild(node, lastIndex) else {
                break
            }
            
            YGNodeRemoveChild(node, childNode)
            
            let newChildCount = YGNodeGetChildCount(node)
            if newChildCount >= childCount {
                break
            }
            
            childCount = newChildCount
        }
    }
    
    func updateNodeLayoutProps(nodeId: String, props: [String: Any]) {
        guard let node = nodes[nodeId] else {
            return
        }
        
        if let context = YGNodeGetContext(node) {
            if var contextDict = Unmanaged<NSDictionary>.fromOpaque(context).takeUnretainedValue() as? [String: Any] {
                contextDict["props"] = props
                YGNodeSetContext(node, Unmanaged.passRetained(contextDict as NSDictionary).toOpaque())
            }
        }
        
        for (key, value) in props {
            applyLayoutProp(node: node, key: key, value: value)
        }
        
        validateNodeLayoutConfig(nodeId: nodeId)
    }
    
    func calculateAndApplyLayout(width: CGFloat, height: CGFloat) -> Bool {
        return syncQueue.sync {
            
            if isReconciling {
                return false
            }
            
            isLayoutCalculating = true
            defer { isLayoutCalculating = false }
            
            guard let mainRoot = nodes["root"] else {
                return false
            }
            
            YGNodeStyleSetWidth(mainRoot, Float(width))
            YGNodeStyleSetHeight(mainRoot, Float(height))
            
            do {
                try {
                    YGNodeCalculateLayout(mainRoot, Float(width), Float(height), YGDirection.LTR)
                }()
            } catch {
                return false
            }
            
            for (screenId, screenRoot) in screenRoots {
                YGNodeStyleSetWidth(screenRoot, Float(width))
                YGNodeStyleSetHeight(screenRoot, Float(height))
                
                do {
                    try {
                        YGNodeCalculateLayout(screenRoot, Float(width), Float(height), YGDirection.LTR)
                    }()
                } catch {
                    continue
                }
            }
            
            for (nodeId, _) in nodes {
                if let layout = getNodeLayout(nodeId: nodeId) {
                    applyLayoutToView(viewId: nodeId, frame: layout)
                }
            }
            
            return true
        }
    }
    
    func updateScreenRootDimensions(width: CGFloat, height: CGFloat) {
        syncQueue.sync {
            for (screenId, screenRoot) in screenRoots {
                YGNodeStyleSetWidth(screenRoot, Float(width))
                YGNodeStyleSetHeight(screenRoot, Float(height))
            }
        }
    }
    
    func isScreenRoot(_ nodeId: String) -> Bool {
        return screenRootIds.contains(nodeId)
    }
    
    func getNodeLayout(nodeId: String) -> CGRect? {
        guard let node = nodes[nodeId] else { return nil }
        
        let left = CGFloat(YGNodeLayoutGetLeft(node))
        let top = CGFloat(YGNodeLayoutGetTop(node))
        let width = CGFloat(YGNodeLayoutGetWidth(node))
        let height = CGFloat(YGNodeLayoutGetHeight(node))
        
        return CGRect(x: left, y: top, width: width, height: height)
    }
    
    private func validateNodeLayoutConfig(nodeId: String) {
        guard let node = nodes[nodeId] else { return }
        
        if YGNodeGetChildCount(node) > 0 &&
           YGNodeStyleGetHeight(node).unit == YGUnit.undefined {
            YGNodeStyleSetHeightAuto(node)
        }
    }
    
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
                case "static":
                    // ENHANCEMENT: Static position support
                    // Static behaves like relative but ignores insets and doesn't form containing blocks
                    YGNodeStyleSetPositionType(node, YGPositionType.static)
                    // Mark this node as static for special handling
                    updateNodeTransformContext(node: node, key: "positionType", value: "static")
                default:
                    break
                }
            }
        case "left":
            // ENHANCEMENT: Static position ignores insets
            if !isStaticPositioned(node: node) {
                if let left = convertToFloat(value) {
                    YGNodeStyleSetPosition(node, YGEdge.left, left)
                } else if let strValue = value as? String, strValue.hasSuffix("%"),
                         let percentValue = Float(strValue.dropLast()) {
                    YGNodeStyleSetPositionPercent(node, YGEdge.left, percentValue)
                }
            }
        case "top":
            // ENHANCEMENT: Static position ignores insets
            if !isStaticPositioned(node: node) {
                if let top = convertToFloat(value) {
                    YGNodeStyleSetPosition(node, YGEdge.top, top)
                } else if let strValue = value as? String, strValue.hasSuffix("%"),
                         let percentValue = Float(strValue.dropLast()) {
                    YGNodeStyleSetPositionPercent(node, YGEdge.top, percentValue)
                }
            }
        case "right":
            // ENHANCEMENT: Static position ignores insets
            if !isStaticPositioned(node: node) {
                if let right = convertToFloat(value) {
                    YGNodeStyleSetPosition(node, YGEdge.right, right)
                } else if let strValue = value as? String, strValue.hasSuffix("%"),
                         let percentValue = Float(strValue.dropLast()) {
                    YGNodeStyleSetPositionPercent(node, YGEdge.right, percentValue)
                }
            }
        case "bottom":
            // ENHANCEMENT: Static position ignores insets
            if !isStaticPositioned(node: node) {
                if let bottom = convertToFloat(value) {
                    YGNodeStyleSetPosition(node, YGEdge.bottom, bottom)
                } else if let strValue = value as? String, strValue.hasSuffix("%"),
                         let percentValue = Float(strValue.dropLast()) {
                    YGNodeStyleSetPositionPercent(node, YGEdge.bottom, percentValue)
                }
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
    
    private func updateNodeTransformContext(node: YGNodeRef, key: String, value: Any) {
        var contextDict: [String: Any] = [:]
        
        if let existingContextPtr = YGNodeGetContext(node) {
            if let existingContext = Unmanaged<NSDictionary>.fromOpaque(existingContextPtr).takeUnretainedValue() as? [String: Any] {
                contextDict = existingContext
            }
        }
        
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
            if let floatValue = value as? Float {
                contextDict[key] = floatValue
            }
        }
        
        if let existingContextPtr = YGNodeGetContext(node) {
            Unmanaged<NSDictionary>.fromOpaque(existingContextPtr).release()
                }
                
                YGNodeSetContext(node, Unmanaged.passRetained(contextDict as NSDictionary).toOpaque())
            }
            
            func setCustomMeasureFunction(nodeId: String, measureFunc: @escaping YGMeasureFunc) {
                guard let node = nodes[nodeId] else { return }
                
                if YGNodeGetChildCount(node) == 0 {
                    YGNodeSetMeasureFunc(node, measureFunc)
                }
            }
            
            private func applyLayoutToView(viewId: String, frame: CGRect) {
                guard let view = DCFLayoutManager.shared.getView(withId: viewId),
                      let node = nodes[viewId] else {
                    return
                }
                
                var finalFrame = frame
                
                if let contextPtr = YGNodeGetContext(node),
                   let contextDict = Unmanaged<NSDictionary>.fromOpaque(contextPtr).takeUnretainedValue() as? [String: Any] {
                    
                    var transform = CGAffineTransform.identity
                    var translationX: CGFloat = 0
                    var translationY: CGFloat = 0
                    
                    if let translateX = contextDict["translateX"] as? Float {
                        translationX += CGFloat(translateX)
                    }
                    
                    if let translateXPercent = contextDict["translateXPercent"] as? Float {
                        let parentWidth = finalFrame.width
                        translationX += CGFloat(translateXPercent * Float(parentWidth) / 100.0)
                    }
                    
                    if let translateY = contextDict["translateY"] as? Float {
                        translationY += CGFloat(translateY)
                    }
                    
                    if let translateYPercent = contextDict["translateYPercent"] as? Float {
                        let parentHeight = finalFrame.height
                        translationY += CGFloat(translateYPercent * Float(parentHeight) / 100.0)
                    }
                    
                    finalFrame.origin.x += translationX
                    finalFrame.origin.y += translationY
                    
                    var hasTransform = false
                    
                    let centerX = finalFrame.width / 2.0
                    let centerY = finalFrame.height / 2.0
                    
                    transform = transform.translatedBy(x: centerX, y: centerY)
                    
                    if let rotation = contextDict["rotate"] as? Float {
                        transform = transform.rotated(by: CGFloat(rotation))
                        hasTransform = true
                    }
                    
                    if let scale = contextDict["scale"] as? Float {
                        transform = transform.scaledBy(x: CGFloat(scale), y: CGFloat(scale))
                        hasTransform = true
                    } else {
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
                    
                    transform = transform.translatedBy(x: -centerX, y: -centerY)
                    
                    if hasTransform {
                        DispatchQueue.main.async {
                            guard let view = DCFLayoutManager.shared.getView(withId: viewId),
                                  view.superview != nil || view.window != nil else {
                                return
                            }
                            view.transform = transform
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    guard let view = DCFLayoutManager.shared.getView(withId: viewId) else {
                        return
                    }
                    
                    guard view.superview != nil || view.window != nil,
                          view.layer != nil,
                          !view.isEqual(nil) else {
                        return
                    }
                    
                    guard finalFrame.width.isFinite && finalFrame.height.isFinite &&
                          finalFrame.origin.x.isFinite && finalFrame.origin.y.isFinite else {
                        return
                    }
                    
                    let wasUserInteractionEnabled = view.isUserInteractionEnabled
                    
                    DCFLayoutManager.shared.applyLayout(
                        to: viewId,
                        left: finalFrame.origin.x,
                        top: finalFrame.origin.y,
                        width: finalFrame.width,
                        height: finalFrame.height
                    )
                    
                    view.isUserInteractionEnabled = wasUserInteractionEnabled
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                }
            }
            
            // MARK: - Web Defaults Support
            
            /// Apply web defaults for cross-platform compatibility
            /// Web defaults: flex-direction: row, align-content: stretch, flex-shrink: 1
            func applyWebDefaults() {
                syncQueue.sync {
                    useWebDefaults = true
                    
                    // Apply web defaults to root node
                    if let root = rootNode {
                        // Web default: flex-direction: row (instead of column)
                        YGNodeStyleSetFlexDirection(root, YGFlexDirection.row)
                        // Web default: align-content: stretch (instead of flex-start)
                        YGNodeStyleSetAlignContent(root, YGAlign.stretch)
                        // Web default: flex-shrink: 1 (instead of 0)
                        YGNodeStyleSetFlexShrink(root, 1.0)
                        
                        print("✅ YogaShadowTree: Applied web defaults to root node")
                    }
                    
                    // Apply web defaults to all screen roots
                    for (_, screenRoot) in screenRoots {
                        YGNodeStyleSetFlexDirection(screenRoot, YGFlexDirection.row)
                        YGNodeStyleSetAlignContent(screenRoot, YGAlign.stretch) 
                        YGNodeStyleSetFlexShrink(screenRoot, 1.0)
                    }
                    
                    print("✅ YogaShadowTree: Applied web defaults to \(screenRoots.count) screen roots")
                }
            }
            
            /// Apply default node styles based on configuration
            private func applyDefaultNodeStyles(to node: YGNodeRef) {
                if useWebDefaults {
                    // Web defaults
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.row)
                    YGNodeStyleSetAlignContent(node, YGAlign.stretch)
                    YGNodeStyleSetFlexShrink(node, 1.0)
                    // Note: position defaults to relative (not static) for compatibility
                } else {
                    // Yoga native defaults
                    YGNodeStyleSetFlexDirection(node, YGFlexDirection.column)
                    YGNodeStyleSetAlignContent(node, YGAlign.flexStart)
                    YGNodeStyleSetFlexShrink(node, 0.0)
                }
            }
            
            /// Check if a node is positioned as static
            private func isStaticPositioned(node: YGNodeRef) -> Bool {
                guard let context = YGNodeGetContext(node),
                      let contextDict = Unmanaged<NSDictionary>.fromOpaque(context).takeUnretainedValue() as? [String: Any],
                      let positionType = contextDict["positionType"] as? String else {
                    return false
                }
                return positionType == "static"
            }
            
            /// Apply layout inheritance from parent to child node
            /// This ensures cross-platform layout consistency between iOS and Android
            private func applyParentLayoutInheritance(childNode: YGNodeRef, parentNode: YGNodeRef, childId: String) {
                guard let childType = nodeTypes[childId] else { return }
                
                // Generic inheritance for all components - only if not explicitly set
                let childAlignItems = YGNodeStyleGetAlignItems(childNode)
                let childJustifyContent = YGNodeStyleGetJustifyContent(childNode)
                let childAlignContent = YGNodeStyleGetAlignContent(childNode)
                
                let parentAlignItems = YGNodeStyleGetAlignItems(parentNode)
                let parentJustifyContent = YGNodeStyleGetJustifyContent(parentNode)
                let parentAlignContent = YGNodeStyleGetAlignContent(parentNode)
                
                // Inherit alignItems if child has default value and parent has non-default
                if childAlignItems == YGAlign.stretch && parentAlignItems != YGAlign.stretch {
                    YGNodeStyleSetAlignItems(childNode, parentAlignItems)
                    print("🔄 INHERIT: Child \(childId) inherited alignItems=\(parentAlignItems) from parent")
                }
                
                // Inherit justifyContent if child has default value and parent has non-default
                if childJustifyContent == YGJustify.flexStart && parentJustifyContent != YGJustify.flexStart {
                    YGNodeStyleSetJustifyContent(childNode, parentJustifyContent)
                    print("🔄 INHERIT: Child \(childId) inherited justifyContent=\(parentJustifyContent) from parent")
                }
                
                // Inherit alignContent if child has default value and parent has non-default
                if childAlignContent == YGAlign.flexStart && parentAlignContent != YGAlign.flexStart {
                    YGNodeStyleSetAlignContent(childNode, parentAlignContent)
                    print("🔄 INHERIT: Child \(childId) inherited alignContent=\(parentAlignContent) from parent")
                }
                
                // Apply alignSelf for proper centering when parent centers children
                if parentAlignItems == YGAlign.center {
                    YGNodeStyleSetAlignSelf(childNode, YGAlign.center)
                    print("🔄 INHERIT: Child \(childId) set alignSelf=center to match parent centering")
                }
            }
            
            deinit {
                for (_, node) in nodes {
                    YGNodeFree(node)
                }
                
                for (_, screenRoot) in screenRoots {
                    YGNodeFree(screenRoot)
                }
            }
        }
