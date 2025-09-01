/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.graphics.RectF
import android.util.Log
import com.facebook.yoga.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write
import kotlin.math.max
import kotlin.math.min

/**
 * Manages the Yoga layout tree for DCFlight components
 */
class YogaShadowTree private constructor() {

    companion object {
        private const val TAG = "YogaShadowTree"

        @JvmField
        val shared = YogaShadowTree()
    }

    private var rootNode: YogaNode? = null
    internal val nodes = ConcurrentHashMap<String, YogaNode>()
    internal val nodeParents = ConcurrentHashMap<String, String>()
    private val nodeTypes = ConcurrentHashMap<String, String>()
    private val screenRoots = ConcurrentHashMap<String, YogaNode>()
    private val screenRootIds = mutableSetOf<String>()

    private val syncLock = ReentrantReadWriteLock()

    @Volatile
    private var isLayoutCalculating = false

    @Volatile
    private var isReconciling = false

    private var useWebDefaults = false

    init {
        rootNode = YogaNodeFactory.create()

        rootNode?.let { root ->
            root.setDirection(YogaDirection.LTR)
            root.setFlexDirection(YogaFlexDirection.COLUMN)

            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            root.setWidth(displayMetrics.widthPixels.toFloat())
            root.setHeight(displayMetrics.heightPixels.toFloat())

            nodes["root"] = root
            nodeTypes["root"] = "View"
        }
    }

    fun hasNode(nodeId: String): Boolean = nodes.containsKey(nodeId)

    fun initialize() {
        Log.d(TAG, "Initializing YogaShadowTree")
    }

    fun cleanup() {
        Log.d(TAG, "Cleaning up YogaShadowTree")
        syncLock.write {
            nodes.values.forEach { node ->
                node.reset()
            }
            nodes.clear()
            nodeParents.clear()
            nodeTypes.clear()
            screenRoots.clear()
            screenRootIds.clear()

            rootNode = YogaNodeFactory.create()
            rootNode?.let { root ->
                root.setDirection(YogaDirection.LTR)
                root.setFlexDirection(YogaFlexDirection.COLUMN)

                val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
                root.setWidth(displayMetrics.widthPixels.toFloat())
                root.setHeight(displayMetrics.heightPixels.toFloat())

                nodes["root"] = root
                nodeTypes["root"] = "View"
            }
        }
    }

    fun calculateLayout(nodeId: String): Map<String, Float>? {
        return syncLock.read {
            val node = nodes[nodeId] ?: return null

            if (isLayoutCalculating) {
                return null
            }

            isLayoutCalculating = true

            try {
                node.calculateLayout(YogaConstants.UNDEFINED, YogaConstants.UNDEFINED)

                mapOf(
                    "left" to node.layoutX,
                    "top" to node.layoutY,
                    "width" to node.layoutWidth,
                    "height" to node.layoutHeight
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to calculate layout for node: $nodeId", e)
                null
            } finally {
                isLayoutCalculating = false
            }
        }
    }

    fun calculateAndApplyLayout(width: Float, height: Float): Boolean {
        return syncLock.write {
            if (isReconciling) {
                return false
            }

            isLayoutCalculating = true
            try {
                val mainRoot = nodes["root"] ?: return false
                mainRoot.calculateLayout(width, height)
                
                // Apply calculated layout to actual views (like iOS does)
                applyCalculatedLayoutToViews()
                
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to calculate layout", e)
                false
            } finally {
                isLayoutCalculating = false
            }
        }
    }
    
    /**
     * Apply calculated Yoga layout to actual Android views
     * This matches iOS YogaShadowTree.applyLayoutToView behavior
     */
    private fun applyCalculatedLayoutToViews() {
        try {
            // Apply layout for all nodes with calculated positions
            for ((nodeId, node) in nodes) {
                val left = node.layoutX
                val top = node.layoutY 
                val width = node.layoutWidth
                val height = node.layoutHeight
                
                // Apply to actual view through layout manager
                DCFLayoutManager.shared.applyLayout(
                    viewId = nodeId,
                    left = left,
                    top = top, 
                    width = width,
                    height = height
                )
                
                Log.d(TAG, "Applied layout to $nodeId: ($left,$top) ${width}x$height")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply calculated layouts to views", e)
        }
    }

    fun createNode(nodeId: String, nodeType: String, props: Map<String, Any?>): Boolean {
        return syncLock.write {
            try {
                if (nodes.containsKey(nodeId)) {
                    Log.w(TAG, "Node $nodeId already exists, updating instead")
                    return updateNode(nodeId, props)
                }

                val node = YogaNodeFactory.create()
                configureNodeDefaults(node, nodeType)
                applyNodeProps(node, props)

                nodes[nodeId] = node
                nodeTypes[nodeId] = nodeType

                if (isScreenRoot(nodeType, props)) {
                    screenRoots[nodeId] = node
                    screenRootIds.add(nodeId)
                }

                Log.d(TAG, "Created node: $nodeId of type: $nodeType")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create node: $nodeId", e)
                false
            }
        }
    }

    fun createNode(id: String, componentType: String) {
        createNode(id, componentType, emptyMap())
    }

    fun createScreenRoot(id: String, componentType: String) {
        syncLock.write {
            val screenRoot = YogaNodeFactory.create()

            screenRoot.setDirection(YogaDirection.LTR)
            screenRoot.setFlexDirection(YogaFlexDirection.COLUMN)

            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            screenRoot.setWidth(displayMetrics.widthPixels.toFloat())
            screenRoot.setHeight(displayMetrics.heightPixels.toFloat())
            screenRoot.setPosition(YogaEdge.LEFT, 0f)
            screenRoot.setPosition(YogaEdge.TOP, 0f)
            screenRoot.setPositionType(YogaPositionType.ABSOLUTE)

            nodes[id] = screenRoot
            screenRoots[id] = screenRoot
            screenRootIds.add(id)
            nodeTypes[id] = componentType
        }
    }

    fun updateNode(nodeId: String, props: Map<String, Any?>): Boolean {
        return syncLock.write {
            try {
                val node = nodes[nodeId] ?: return false
                applyNodeProps(node, props)
                Log.d(TAG, "Updated node: $nodeId")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update node: $nodeId", e)
                false
            }
        }
    }

    fun updateNodeLayoutProps(nodeId: String, props: Map<String, Any?>) {
        val node = nodes[nodeId] ?: return
        applyNodeProps(node, props)
    }

    fun updateScreenRootDimensions(nodeId: String, width: Float, height: Float) {
        val node = nodes[nodeId] ?: return
        if (screenRootIds.contains(nodeId)) {
            node.setWidth(width)
            node.setHeight(height)
        }
    }

    fun removeNode(nodeId: String): Boolean {
        return syncLock.write {
            try {
                val node = nodes.remove(nodeId) ?: return false
                
                nodeParents.remove(nodeId)
                nodeTypes.remove(nodeId)
                screenRoots.remove(nodeId)
                screenRootIds.remove(nodeId)

                removeFromParent(nodeId)
                node.reset()

                Log.d(TAG, "Removed node: $nodeId")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove node: $nodeId", e)
                false
            }
        }
    }

    fun addChildNode(parentId: String, childId: String, index: Int? = null) {
        syncLock.write {
            val parentNode = nodes[parentId]
            val childNode = nodes[childId]
            
            if (parentNode == null || childNode == null) {
                return@write
            }

            if (screenRootIds.contains(childId)) {
                return@write
            }

            removeFromParent(childId)

            if (index != null && index >= 0 && index <= parentNode.childCount) {
                parentNode.addChildAt(childNode, index)
            } else {
                parentNode.addChildAt(childNode, parentNode.childCount)
            }

            nodeParents[childId] = parentId
        }
    }

    fun attachChild(childId: String, parentId: String, index: Int): Boolean {
        return syncLock.write {
            try {
                val childNode = nodes[childId] ?: return false
                val parentNode = nodes[parentId] ?: return false

                removeFromParent(childId)

                if (index >= 0 && index <= parentNode.childCount) {
                    parentNode.addChildAt(childNode, index)
                } else {
                    parentNode.addChildAt(childNode, parentNode.childCount)
                }

                nodeParents[childId] = parentId

                Log.d(TAG, "Attached child: $childId to parent: $parentId at index: $index")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to attach child: $childId to parent: $parentId", e)
                false
            }
        }
    }

    fun detachChild(childId: String): Boolean {
        return syncLock.write {
            try {
                removeFromParent(childId)
                nodeParents.remove(childId)
                Log.d(TAG, "Detached child: $childId")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to detach child: $childId", e)
                false
            }
        }
    }

    fun setChildren(parentId: String, childrenIds: List<String>): Boolean {
        return syncLock.write {
            try {
                val parentNode = nodes[parentId] ?: return false

                while (parentNode.childCount > 0) {
                    val child = parentNode.getChildAt(0)
                    parentNode.removeChildAt(0)
                }

                childrenIds.forEach { childId ->
                    val childNode = nodes[childId]
                    if (childNode != null) {
                        parentNode.addChildAt(childNode, parentNode.childCount)
                        nodeParents[childId] = parentId
                    }
                }

                Log.d(TAG, "Set children for parent: $parentId")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set children for parent: $parentId", e)
                false
            }
        }
    }

    fun applyWebDefaults() {
        useWebDefaults = true
        rootNode?.let { root ->
            root.setFlexDirection(YogaFlexDirection.ROW)
            root.setAlignContent(YogaAlign.STRETCH)
        }
    }

    fun isScreenRoot(nodeId: String): Boolean {
        return screenRootIds.contains(nodeId)
    }

    fun clearAll() {
        syncLock.write {
            nodes.values.forEach { it.reset() }
            nodes.clear()
            nodeParents.clear()
            nodeTypes.clear()
            screenRoots.clear()
            screenRootIds.clear()
        }
    }

    fun viewRegisteredWithShadowTree(viewId: String): Boolean {
        return nodes.containsKey(viewId)
    }

    private fun configureNodeDefaults(node: YogaNode, nodeType: String) {
        node.setDirection(YogaDirection.LTR)
        
        if (useWebDefaults) {
            node.setFlexDirection(YogaFlexDirection.ROW)
            node.setAlignContent(YogaAlign.STRETCH)
            node.setFlexShrink(1f)
        } else {
            node.setFlexDirection(YogaFlexDirection.COLUMN)
        }

        when (nodeType.lowercase()) {
            "scrollview" -> {
                node.setOverflow(YogaOverflow.SCROLL)
            }
            "text" -> {
                node.setFlexShrink(0f)
            }
        }
    }

    private fun applyNodeProps(node: YogaNode, props: Map<String, Any?>) {
        props.forEach { (key, value) ->
            when (key) {
                "width" -> setDimension(node, YogaEdge.ALL, value, true)
                "height" -> setDimension(node, YogaEdge.ALL, value, false)
                "minWidth" -> setMinDimension(node, value, true)
                "maxWidth" -> setMaxDimension(node, value, true)
                "minHeight" -> setMinDimension(node, value, false)
                "maxHeight" -> setMaxDimension(node, value, false)
                
                "margin" -> setMargin(node, YogaEdge.ALL, value)
                "marginTop" -> setMargin(node, YogaEdge.TOP, value)
                "marginRight" -> setMargin(node, YogaEdge.RIGHT, value)
                "marginBottom" -> setMargin(node, YogaEdge.BOTTOM, value)
                "marginLeft" -> setMargin(node, YogaEdge.LEFT, value)
                "marginHorizontal" -> {
                    setMargin(node, YogaEdge.LEFT, value)
                    setMargin(node, YogaEdge.RIGHT, value)
                }
                "marginVertical" -> {
                    setMargin(node, YogaEdge.TOP, value)
                    setMargin(node, YogaEdge.BOTTOM, value)
                }
                
                "padding" -> setPadding(node, YogaEdge.ALL, value)
                "paddingTop" -> setPadding(node, YogaEdge.TOP, value)
                "paddingRight" -> setPadding(node, YogaEdge.RIGHT, value)
                "paddingBottom" -> setPadding(node, YogaEdge.BOTTOM, value)
                "paddingLeft" -> setPadding(node, YogaEdge.LEFT, value)
                "paddingHorizontal" -> {
                    setPadding(node, YogaEdge.LEFT, value)
                    setPadding(node, YogaEdge.RIGHT, value)
                }
                "paddingVertical" -> {
                    setPadding(node, YogaEdge.TOP, value)
                    setPadding(node, YogaEdge.BOTTOM, value)
                }
                
                "left" -> setPosition(node, YogaEdge.LEFT, value)
                "top" -> setPosition(node, YogaEdge.TOP, value)
                "right" -> setPosition(node, YogaEdge.RIGHT, value)
                "bottom" -> setPosition(node, YogaEdge.BOTTOM, value)
                
                "position" -> setPositionType(node, value)
                "flexDirection" -> setFlexDirection(node, value)
                "justifyContent" -> setJustifyContent(node, value)
                "alignItems" -> setAlignItems(node, value)
                "alignSelf" -> setAlignSelf(node, value)
                "alignContent" -> setAlignContent(node, value)
                "flexWrap" -> setFlexWrap(node, value)
                "flex" -> setFlex(node, value)
                "flexGrow" -> setFlexGrow(node, value)
                "flexShrink" -> setFlexShrink(node, value)
                "flexBasis" -> setFlexBasis(node, value)
                "display" -> setDisplay(node, value)
                "overflow" -> setOverflow(node, value)
                "direction" -> setDirection(node, value)
                "aspectRatio" -> setAspectRatio(node, value)
            }
        }
    }

    private fun setDimension(node: YogaNode, edge: YogaEdge, value: Any?, isWidth: Boolean) {
        when (value) {
            is Number -> {
                if (isWidth) node.setWidth(value.toFloat()) else node.setHeight(value.toFloat())
            }
            is String -> {
                when (value) {
                    "auto" -> if (isWidth) node.setWidthAuto() else node.setHeightAuto()
                    else -> {
                        val numericValue = parsePercentage(value)
                        if (numericValue != null) {
                            if (isWidth) node.setWidthPercent(numericValue) else node.setHeightPercent(numericValue)
                        }
                    }
                }
            }
        }
    }

    private fun setMinDimension(node: YogaNode, value: Any?, isWidth: Boolean) {
        when (value) {
            is Number -> if (isWidth) node.setMinWidth(value.toFloat()) else node.setMinHeight(value.toFloat())
        }
    }

    private fun setMaxDimension(node: YogaNode, value: Any?, isWidth: Boolean) {
        when (value) {
            is Number -> if (isWidth) node.setMaxWidth(value.toFloat()) else node.setMaxHeight(value.toFloat())
        }
    }

    private fun setMargin(node: YogaNode, edge: YogaEdge, value: Any?) {
        when (value) {
            is Number -> node.setMargin(edge, value.toFloat())
            is String -> {
                when (value) {
                    "auto" -> node.setMarginAuto(edge)
                    else -> {
                        val percentage = parsePercentage(value)
                        if (percentage != null) {
                            node.setMarginPercent(edge, percentage)
                        }
                    }
                }
            }
        }
    }

    private fun setPadding(node: YogaNode, edge: YogaEdge, value: Any?) {
        when (value) {
            is Number -> node.setPadding(edge, value.toFloat())
            is String -> {
                val percentage = parsePercentage(value)
                if (percentage != null) {
                    node.setPaddingPercent(edge, percentage)
                }
            }
        }
    }

    private fun setPosition(node: YogaNode, edge: YogaEdge, value: Any?) {
        when (value) {
            is Number -> node.setPosition(edge, value.toFloat())
            is String -> {
                val percentage = parsePercentage(value)
                if (percentage != null) {
                    node.setPositionPercent(edge, percentage)
                }
            }
        }
    }

    private fun setPositionType(node: YogaNode, value: Any?) {
        when (value as? String) {
            "absolute" -> node.setPositionType(YogaPositionType.ABSOLUTE)
            "relative" -> node.setPositionType(YogaPositionType.RELATIVE)
        }
    }

    private fun setFlexDirection(node: YogaNode, value: Any?) {
        when (value as? String) {
            "row" -> node.setFlexDirection(YogaFlexDirection.ROW)
            "column" -> node.setFlexDirection(YogaFlexDirection.COLUMN)
            "row-reverse" -> node.setFlexDirection(YogaFlexDirection.ROW_REVERSE)
            "column-reverse" -> node.setFlexDirection(YogaFlexDirection.COLUMN_REVERSE)
        }
    }

    private fun setJustifyContent(node: YogaNode, value: Any?) {
        when (value as? String) {
            "flex-start" -> node.setJustifyContent(YogaJustify.FLEX_START)
            "center" -> node.setJustifyContent(YogaJustify.CENTER)
            "flex-end" -> node.setJustifyContent(YogaJustify.FLEX_END)
            "space-between" -> node.setJustifyContent(YogaJustify.SPACE_BETWEEN)
            "space-around" -> node.setJustifyContent(YogaJustify.SPACE_AROUND)
            "space-evenly" -> node.setJustifyContent(YogaJustify.SPACE_EVENLY)
        }
    }

    private fun setAlignItems(node: YogaNode, value: Any?) {
        when (value as? String) {
            "flex-start" -> node.setAlignItems(YogaAlign.FLEX_START)
            "center" -> node.setAlignItems(YogaAlign.CENTER)
            "flex-end" -> node.setAlignItems(YogaAlign.FLEX_END)
            "stretch" -> node.setAlignItems(YogaAlign.STRETCH)
            "baseline" -> node.setAlignItems(YogaAlign.BASELINE)
        }
    }

    private fun setAlignSelf(node: YogaNode, value: Any?) {
        when (value as? String) {
            "auto" -> node.setAlignSelf(YogaAlign.AUTO)
            "flex-start" -> node.setAlignSelf(YogaAlign.FLEX_START)
            "center" -> node.setAlignSelf(YogaAlign.CENTER)
            "flex-end" -> node.setAlignSelf(YogaAlign.FLEX_END)
            "stretch" -> node.setAlignSelf(YogaAlign.STRETCH)
            "baseline" -> node.setAlignSelf(YogaAlign.BASELINE)
        }
    }

    private fun setAlignContent(node: YogaNode, value: Any?) {
        when (value as? String) {
            "flex-start" -> node.setAlignContent(YogaAlign.FLEX_START)
            "center" -> node.setAlignContent(YogaAlign.CENTER)
            "flex-end" -> node.setAlignContent(YogaAlign.FLEX_END)
            "stretch" -> node.setAlignContent(YogaAlign.STRETCH)
            "space-between" -> node.setAlignContent(YogaAlign.SPACE_BETWEEN)
            "space-around" -> node.setAlignContent(YogaAlign.SPACE_AROUND)
        }
    }

    private fun setFlexWrap(node: YogaNode, value: Any?) {
        when (value as? String) {
            "nowrap" -> node.setWrap(YogaWrap.NO_WRAP)
            "wrap" -> node.setWrap(YogaWrap.WRAP)
            "wrap-reverse" -> node.setWrap(YogaWrap.WRAP_REVERSE)
        }
    }

    private fun setFlex(node: YogaNode, value: Any?) {
        when (value) {
            is Number -> node.setFlex(value.toFloat())
        }
    }

    private fun setFlexGrow(node: YogaNode, value: Any?) {
        when (value) {
            is Number -> node.setFlexGrow(value.toFloat())
        }
    }

    private fun setFlexShrink(node: YogaNode, value: Any?) {
        when (value) {
            is Number -> node.setFlexShrink(value.toFloat())
        }
    }

    private fun setFlexBasis(node: YogaNode, value: Any?) {
        when (value) {
            is Number -> node.setFlexBasis(value.toFloat())
            is String -> {
                when (value) {
                    "auto" -> node.setFlexBasisAuto()
                    else -> {
                        val percentage = parsePercentage(value)
                        if (percentage != null) {
                            node.setFlexBasisPercent(percentage)
                        }
                    }
                }
            }
        }
    }

    private fun setDisplay(node: YogaNode, value: Any?) {
        when (value as? String) {
            "flex" -> node.setDisplay(YogaDisplay.FLEX)
            "none" -> node.setDisplay(YogaDisplay.NONE)
        }
    }

    private fun setOverflow(node: YogaNode, value: Any?) {
        when (value as? String) {
            "visible" -> node.setOverflow(YogaOverflow.VISIBLE)
            "hidden" -> node.setOverflow(YogaOverflow.HIDDEN)
            "scroll" -> node.setOverflow(YogaOverflow.SCROLL)
        }
    }

    private fun setDirection(node: YogaNode, value: Any?) {
        when (value as? String) {
            "ltr" -> node.setDirection(YogaDirection.LTR)
            "rtl" -> node.setDirection(YogaDirection.RTL)
            "inherit" -> node.setDirection(YogaDirection.INHERIT)
        }
    }

    private fun setAspectRatio(node: YogaNode, value: Any?) {
        when (value) {
            is Number -> node.setAspectRatio(value.toFloat())
        }
    }

    private fun parsePercentage(value: String): Float? {
        return if (value.endsWith("%")) {
            value.removeSuffix("%").toFloatOrNull()
        } else {
            value.toFloatOrNull()
        }
    }

    private fun removeFromParent(childId: String) {
        val parentId = nodeParents[childId] ?: return
        val parentNode = nodes[parentId] ?: return
        val childNode = nodes[childId] ?: return

        try {
            for (i in 0 until parentNode.childCount) {
                if (parentNode.getChildAt(i) == childNode) {
                    parentNode.removeChildAt(i)
                    break
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to remove child from parent: $e")
        }
    }

    private fun isScreenRoot(nodeType: String, props: Map<String, Any?>): Boolean {
        return nodeType == "Screen" || props.containsKey("presentationStyle")
    }
}