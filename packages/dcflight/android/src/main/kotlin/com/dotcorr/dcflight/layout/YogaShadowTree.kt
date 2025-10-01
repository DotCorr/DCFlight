/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.content.Context
import android.content.res.Resources
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.View
import com.facebook.yoga.*
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.utils.DCFScreenUtilities
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min

/**
 * EXACT iOS YogaShadowTree port for Android
 * Matches iOS YogaShadowTree.swift behavior 1:1
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
    
    // Gap support now handled natively by Yoga 2.0+
    
    @Volatile
    private var isLayoutCalculating = false
    
    @Volatile
    private var isReconciling = false
    
    // ENHANCEMENT: Web defaults configuration
    private var useWebDefaults = false
    
    // CRITICAL FIX: Density scaling for cross-platform consistency
    private var densityScaleFactor: Float = 1.0f

    init {
        rootNode = YogaNodeFactory.create().apply {
            setDirection(YogaDirection.LTR)
            setFlexDirection(YogaFlexDirection.COLUMN)

            val displayMetrics = Resources.getSystem().displayMetrics
            setWidth(displayMetrics.widthPixels.toFloat())
            setHeight(displayMetrics.heightPixels.toFloat())
        }
        
        rootNode?.let { root ->
            nodes["root"] = root
            nodeTypes["root"] = "View"
        }
        
        Log.d(TAG, "Initializing YogaShadowTree")
        
        // CRITICAL FIX: Initialize density scale factor for cross-platform consistency
        updateDensityScaleFactor()
    }
    
    /**
     * CRITICAL FIX: Update density scale factor for cross-platform consistency
     * This ensures Android sizing matches iOS behavior
     */
    private fun updateDensityScaleFactor() {
        try {
            val displayMetrics = Resources.getSystem().displayMetrics
            densityScaleFactor = displayMetrics.density
            
            Log.d(TAG, "Density scale factor updated: $densityScaleFactor (density: ${displayMetrics.densityDpi} dpi)")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update density scale factor, using default 1.0", e)
            densityScaleFactor = 1.0f
        }
    }
    
    /**
     * CRITICAL FIX: Apply density scaling to match iOS behavior
     * iOS uses logical points that are automatically scaled by the system
     * Android needs manual scaling to achieve the same visual result
     */
    private fun applyDensityScaling(value: Float): Float {
        return value * densityScaleFactor
    }

    @Synchronized
    fun createNode(id: String, componentType: String) {
        val node = YogaNodeFactory.create()
        
        // Apply default styles based on configuration - MATCH iOS
        applyDefaultNodeStyles(node, componentType)
        
        val context = mapOf(
            "nodeId" to id,
            "componentType" to componentType,
            "props" to emptyMap<String, Any>()
        )
        
        nodes[id] = node
        nodeTypes[id] = componentType
        
        // Setup measure function like iOS
        setupMeasureFunction(id, node)
    }

    @Synchronized
    fun createScreenRoot(id: String, componentType: String) {
        val screenRoot = YogaNodeFactory.create().apply {
            setDirection(YogaDirection.LTR)
            setFlexDirection(YogaFlexDirection.COLUMN)
            
            val displayMetrics = Resources.getSystem().displayMetrics
            setWidth(displayMetrics.widthPixels.toFloat())
            setHeight(displayMetrics.heightPixels.toFloat())
            setPosition(YogaEdge.LEFT, 0f)
            setPosition(YogaEdge.TOP, 0f)
            setPositionType(YogaPositionType.ABSOLUTE)
        }
        
        val context = mapOf(
            "nodeId" to id,
            "componentType" to componentType,
            "props" to emptyMap<String, Any>()
        )
        
        nodes[id] = screenRoot
        screenRoots[id] = screenRoot
        screenRootIds.add(id)
        nodeTypes[id] = componentType
    }

    private fun setupMeasureFunction(nodeId: String, node: YogaNode) {
        val childCount = node.childCount
        
        if (childCount == 0) {
            // Set measure function for leaf nodes - MATCH iOS behavior
            node.setMeasureFunction { yogaNode, width, widthMode, height, heightMode ->
                val view = DCFLayoutManager.shared.getView(nodeId)
                val componentType = nodeTypes[nodeId] ?: "View"
                
                if (view != null) {
                    val constraintWidth = if (widthMode == YogaMeasureMode.UNDEFINED) {
                        Float.POSITIVE_INFINITY
                    } else {
                        width
                    }
                    
                    val constraintHeight = if (heightMode == YogaMeasureMode.UNDEFINED) {
                        Float.POSITIVE_INFINITY
                    } else {
                        height
                    }
                    
                    // Get intrinsic size from component - MATCH iOS getIntrinsicSize
                    val componentClass = DCFComponentRegistry.shared.getComponent(componentType)
                    val intrinsicSize = if (componentClass != null) {
                        val componentInstance = componentClass.newInstance()
                        componentInstance.getIntrinsicSize(view, emptyMap())
                    } else {
                        android.graphics.PointF(0f, 0f)
                    }
                    
                    val finalWidth = if (widthMode == YogaMeasureMode.UNDEFINED) {
                        intrinsicSize.x
                    } else {
                        kotlin.math.min(intrinsicSize.x, constraintWidth)
                    }
                    
                    val finalHeight = if (heightMode == YogaMeasureMode.UNDEFINED) {
                        intrinsicSize.y
                    } else {
                        kotlin.math.min(intrinsicSize.y, constraintHeight)
                    }
                    
                    YogaMeasureOutput.make(finalWidth, finalHeight)
                } else {
                    YogaMeasureOutput.make(0f, 0f)
                }
            }
        } else {
            node.setMeasureFunction(null)
        }
    }

    @Synchronized
    fun addChildNode(parentId: String, childId: String, index: Int? = null) {
        val parentNode = nodes[parentId]
        val childNode = nodes[childId]
        
        if (parentNode == null || childNode == null) {
            Log.w(TAG, "Cannot add child - parent or child node not found")
            return
        }
        
        if (screenRootIds.contains(childId)) {
            Log.d(TAG, "Skipping screen root child attachment")
            return
        }
        
        // Remove from old parent if exists - MATCH iOS
        nodeParents[childId]?.let { oldParentId ->
            nodes[oldParentId]?.let { oldParentNode ->
                safeRemoveChildFromParent(oldParentNode, childNode, childId)
                setupMeasureFunction(oldParentId, oldParentNode)
            }
        }
        
        // Clear parent's measure function - MATCH iOS
        parentNode.setMeasureFunction(null)
        
        // Add child at specified index
        val safeIndex = if (index != null) {
            kotlin.math.max(0, kotlin.math.min(index, parentNode.childCount))
        } else {
            parentNode.childCount
        }
        
        try {
            parentNode.addChildAt(childNode, safeIndex)
            nodeParents[childId] = parentId
            
            // CRITICAL: Apply parent layout inheritance to child for cross-platform consistency
            applyParentLayoutInheritance(childNode, parentNode, childId)
            
            setupMeasureFunction(childId, childNode)
            
            Log.d(TAG, "Added child: $childId to parent: $parentId at index: $safeIndex")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add child node", e)
        }
    }

    @Synchronized
    fun removeNode(nodeId: String) {
        isReconciling = true
        
        // Wait for layout calculation to finish
        while (isLayoutCalculating) {
            Thread.sleep(1)
        }
        
        val node = nodes[nodeId]
        if (node == null) {
            isReconciling = false
            return
        }
        
        // Handle screen roots
        if (screenRootIds.contains(nodeId)) {
            screenRoots.remove(nodeId)
            screenRootIds.remove(nodeId)
        } else {
            // Remove from parent
            nodeParents[nodeId]?.let { parentId ->
                nodes[parentId]?.let { parentNode ->
                    safeRemoveChildFromParent(parentNode, node, nodeId)
                    setupMeasureFunction(parentId, parentNode)
                }
            }
        }
        
        // Remove all children safely
        safeRemoveAllChildren(node, nodeId)
        
        // Clean up
        nodes.remove(nodeId)
        nodeParents.remove(nodeId)
        nodeTypes.remove(nodeId)
        
        isReconciling = false
        
        Log.d(TAG, "Removed node: $nodeId")
    }

    private fun safeRemoveChildFromParent(parentNode: YogaNode, childNode: YogaNode, childId: String) {
        val childCount = parentNode.childCount
        
        if (childCount == 0) return
        
        for (i in 0 until childCount) {
            try {
                if (parentNode.getChildAt(i) == childNode) {
                    parentNode.removeChildAt(i)
                    break
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error removing child at index $i", e)
                break
            }
        }
    }

    private fun safeRemoveAllChildren(node: YogaNode, nodeId: String) {
        var childCount = node.childCount
        
        while (childCount > 0) {
            val lastIndex = childCount - 1
            
            try {
                val childNode = node.getChildAt(lastIndex)
                node.removeChildAt(lastIndex)
                
                val newChildCount = node.childCount
                if (newChildCount >= childCount) {
                    break // Prevent infinite loop
                }
                
                childCount = newChildCount
                
            } catch (e: Exception) {
                Log.w(TAG, "Error removing children from $nodeId", e)
                break
            }
        }
    }

    fun updateNodeLayoutProps(nodeId: String, props: Map<String, Any?>) {
        val node = nodes[nodeId] ?: return
        
        // Apply layout properties
        props.filterValues { it != null }.forEach { (key, value) ->
            applyLayoutProp(node, key, value!!, nodeId)
        }
        
        validateNodeLayoutConfig(nodeId)
        
        Log.d(TAG, "Updated node layout props: $nodeId")
    }

    @Synchronized
    fun calculateAndApplyLayout(width: Float, height: Float): Boolean {
        if (isReconciling) {
            Log.d(TAG, "Layout calculation deferred - currently reconciling")
            return false
        }
        
        isLayoutCalculating = true
        
        try {
            val mainRoot = nodes["root"]
            if (mainRoot == null) {
                Log.e(TAG, "Root node not found")
                return false
            }
            
            // Update root dimensions
            mainRoot.setWidth(width)
            mainRoot.setHeight(height)
            
            // Calculate main layout
            try {
                mainRoot.calculateLayout(width, height)
                Log.d(TAG, "Main root layout calculated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to calculate main root layout", e)
                return false
            }
            
            // Calculate screen root layouts
            for ((screenId, screenRoot) in screenRoots) {
                screenRoot.setWidth(width)
                screenRoot.setHeight(height)
                
                try {
                    screenRoot.calculateLayout(width, height)
                    Log.d(TAG, "Screen root $screenId layout calculated successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to calculate screen root $screenId layout", e)
                    continue
                }
            }
            
            // FLASH SCREEN FIX: Apply layouts without making views visible yet
            val layoutsToApply = mutableListOf<Pair<String, Rect>>()
            for ((nodeId, _) in nodes) {
                val layout = getNodeLayout(nodeId)
                if (layout != null) {
                    layoutsToApply.add(Pair(nodeId, layout))
                }
            }
            
            // GAP SUPPORT: Now handled natively by Yoga 2.0+
            
            // Apply all layouts at once without making views visible
            applyLayoutsBatch(layoutsToApply)
            
            Log.d(TAG, "Layout calculation and application completed successfully")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Layout calculation failed", e)
            return false
            
        } finally {
            isLayoutCalculating = false
        }
    }

    @Synchronized
    fun updateScreenRootDimensions(width: Float, height: Float) {
        for ((screenId, screenRoot) in screenRoots) {
            screenRoot.setWidth(width)
            screenRoot.setHeight(height)
            Log.d(TAG, "Updated screen root dimensions: $screenId")
        }
    }

    /**
     * Calculate layout for all roots using current screen dimensions
     * This method is called during configuration changes like rotation
     */
    @Synchronized
    fun calculateLayoutForAllRoots() {
        Log.d(TAG, "Calculating layout for all roots")
        
        // Get current screen dimensions
        val displayMetrics = Resources.getSystem().displayMetrics
        val screenWidth = displayMetrics.widthPixels.toFloat()
        val screenHeight = displayMetrics.heightPixels.toFloat()
        
        // Update all screen root dimensions first
        updateScreenRootDimensions(screenWidth, screenHeight)
        
        // Calculate and apply layout with current dimensions
        val success = calculateAndApplyLayout(screenWidth, screenHeight)
        
        if (success) {
            Log.d(TAG, "✅ Layout calculated for all roots successfully")
        } else {
            Log.w(TAG, "⚠️ Layout calculation for all roots encountered issues")
        }
    }

    fun isScreenRoot(nodeId: String): Boolean {
        return screenRootIds.contains(nodeId)
    }

    fun getNodeLayout(nodeId: String): Rect? {
        val node = nodes[nodeId] ?: return null
        
        val left = node.layoutX
        val top = node.layoutY
        val width = node.layoutWidth
        val height = node.layoutHeight
        
        return Rect(left.toInt(), top.toInt(), (left + width).toInt(), (top + height).toInt())
    }

    private fun validateNodeLayoutConfig(nodeId: String) {
        val node = nodes[nodeId] ?: return
        
        // If node has children and undefined height, set auto height
        if (node.childCount > 0 && !node.height.unit.name.contains("POINT")) {
            node.setHeightAuto()
        }
    }

    // FLASH SCREEN FIX: Apply layouts in batch without making views visible
    private fun applyLayoutsBatch(layouts: List<Pair<String, Rect>>) {
        Handler(Looper.getMainLooper()).post {
            // Apply all layouts first without making views visible
            for ((viewId, frame) in layouts) {
                val view = DCFLayoutManager.shared.getView(viewId)
                if (view != null) {
                    val wasUserInteractionEnabled = view.isEnabled
                    
                    // Apply layout using layout manager without making visible
                    DCFLayoutManager.shared.applyLayoutWithoutVisibility(
                        viewId = viewId,
                        left = frame.left.toFloat(),
                        top = frame.top.toFloat(),
                        width = frame.width().toFloat(),
                        height = frame.height().toFloat()
                    )
                    
                    view.isEnabled = wasUserInteractionEnabled
                    view.requestLayout()
                }
            }
            
            // Now make all views visible at once after all layouts are applied
            for ((viewId, _) in layouts) {
                val view = DCFLayoutManager.shared.getView(viewId)
                if (view != null) {
                    view.visibility = View.VISIBLE
                    view.alpha = 1.0f
                }
            }
        }
    }

    // MATCH iOS applyLayoutToView exactly
    private fun applyLayoutToView(viewId: String, frame: Rect) {
        val view = DCFLayoutManager.shared.getView(viewId)
        val node = nodes[viewId]
        
        if (view == null || node == null) {
            return
        }
        
        var finalFrame = frame
        
        // Handle transforms like iOS (translateX, translateY, rotate, scale)
        // This would require storing transform context, but for now apply basic layout
        
        // Apply layout on main thread like iOS
        Handler(Looper.getMainLooper()).post {
            if (DCFLayoutManager.shared.getView(viewId) != null) {
                val wasUserInteractionEnabled = view.isEnabled
                
                // Apply layout using layout manager - MATCH iOS frame setting
                DCFLayoutManager.shared.applyLayout(
                    viewId = viewId,
                    left = finalFrame.left.toFloat(),
                    top = finalFrame.top.toFloat(),
                    width = finalFrame.width().toFloat(),
                    height = finalFrame.height().toFloat()
                )
                
                view.isEnabled = wasUserInteractionEnabled
                view.requestLayout()
            }
        }
    }

    // MATCH iOS applyWebDefaults
    @Synchronized
    fun applyWebDefaults() {
        useWebDefaults = true
        
        // Apply web defaults to root node
        rootNode?.let { root ->
            // Web default: flex-direction: row (instead of column)
            root.setFlexDirection(YogaFlexDirection.ROW)
            // Web default: align-content: stretch (instead of flex-start)
            root.setAlignContent(YogaAlign.STRETCH)
            // Web default: flex-shrink: 1 (instead of 0)
            root.setFlexShrink(1.0f)
            
            Log.d(TAG, "Applied web defaults to root node")
        }
        
        // Apply web defaults to all screen roots
        for ((_, screenRoot) in screenRoots) {
            screenRoot.setFlexDirection(YogaFlexDirection.ROW)
            screenRoot.setAlignContent(YogaAlign.STRETCH)
            screenRoot.setFlexShrink(1.0f)
        }
        
        Log.d(TAG, "Applied web defaults to ${screenRoots.size} screen roots")
    }

    // MATCH iOS applyDefaultNodeStyles
    private fun applyDefaultNodeStyles(node: YogaNode, nodeType: String) {
        if (useWebDefaults) {
            // Web defaults
            node.setFlexDirection(YogaFlexDirection.ROW)
            node.setAlignContent(YogaAlign.STRETCH)
            node.setFlexShrink(1.0f)
        } else {
            // Yoga native defaults
            node.setFlexDirection(YogaFlexDirection.COLUMN)
            node.setAlignContent(YogaAlign.FLEX_START)
            node.setFlexShrink(0.0f)
        }
    }


    // MATCH iOS applyParentLayoutInheritance EXACTLY
    private fun applyParentLayoutInheritance(childNode: YogaNode, parentNode: YogaNode, childId: String) {
        val nodeType = nodeTypes[childId] ?: return
        
        // Smart inheritance system - only apply to parent nodes that actually have children
        // This matches iOS behavior and avoids hardcoded node types
        val isParentWithChildren = childNode.childCount > 0
        
        // Only apply layout inheritance to nodes that are actually parent containers with children
        if (isParentWithChildren) {
            val childAlignItems = childNode.alignItems
            val childJustifyContent = childNode.justifyContent
            val childAlignContent = childNode.alignContent
            
            val parentAlignItems = parentNode.alignItems
            val parentJustifyContent = parentNode.justifyContent
            val parentAlignContent = parentNode.alignContent
            
            // Only inherit alignItems if child has default value and parent has non-default
            if (childAlignItems == YogaAlign.STRETCH && parentAlignItems != YogaAlign.STRETCH) {
                childNode.setAlignItems(parentAlignItems)
            }
            
            // Only inherit justifyContent if child has default value and parent has non-default
            if (childJustifyContent == YogaJustify.FLEX_START && parentJustifyContent != YogaJustify.FLEX_START) {
                childNode.setJustifyContent(parentJustifyContent)
            }
            
            // Only inherit alignContent if child has default value and parent has non-default
            if (childAlignContent == YogaAlign.FLEX_START && parentAlignContent != YogaAlign.FLEX_START) {
                childNode.setAlignContent(parentAlignContent)
            }
        }
    }

    // Layout property application - MATCH iOS exactly
    private fun applyLayoutProp(node: YogaNode, key: String, value: Any, nodeId: String) {
        when (key) {
            "width" -> {
                when (value) {
                    is Number -> {
                        // CRITICAL FIX: Apply density scaling to match iOS behavior
                        val scaledValue = applyDensityScaling(value.toFloat())
                        node.setWidth(scaledValue)
                    }
                    is String -> {
                        if (value.endsWith("%")) {
                            val percent = value.removeSuffix("%").toFloatOrNull()
                            if (percent != null) {
                                node.setWidthPercent(percent)
                            }
                        }
                    }
                }
            }
            "height" -> {
                when (value) {
                    is Number -> {
                        // CRITICAL FIX: Apply density scaling to match iOS behavior
                        val scaledValue = applyDensityScaling(value.toFloat())
                        node.setHeight(scaledValue)
                    }
                    is String -> {
                        if (value.endsWith("%")) {
                            val percent = value.removeSuffix("%").toFloatOrNull()
                            if (percent != null) {
                                node.setHeightPercent(percent)
                            }
                        }
                    }
                }
            }
            "flex" -> {
                if (value is Number) {
                    node.setFlex(value.toFloat())
                }
            }
            "flexDirection" -> {
                when (value as? String) {
                    "row" -> node.setFlexDirection(YogaFlexDirection.ROW)
                    "column" -> node.setFlexDirection(YogaFlexDirection.COLUMN)
                    "rowReverse" -> node.setFlexDirection(YogaFlexDirection.ROW_REVERSE)
                    "columnReverse" -> node.setFlexDirection(YogaFlexDirection.COLUMN_REVERSE)
                }
            }
            "flexWrap" -> {
                when (value as? String) {
                    "nowrap" -> node.setWrap(YogaWrap.NO_WRAP)
                    "wrap" -> node.setWrap(YogaWrap.WRAP)
                    "wrapReverse" -> node.setWrap(YogaWrap.WRAP_REVERSE)
                }
            }
            "gap" -> {
                // YOGA 2.0+ GAP SUPPORT: Use native gap API with density scaling
                if (value is Number) {
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setGap(YogaGutter.ALL, scaledValue)
                }
            }
            "rowGap" -> {
                // YOGA 2.0+ ROW GAP SUPPORT: Use native row gap API with density scaling
                if (value is Number) {
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setGap(YogaGutter.ROW, scaledValue)
                }
            }
            "columnGap" -> {
                // YOGA 2.0+ COLUMN GAP SUPPORT: Use native column gap API with density scaling
                if (value is Number) {
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setGap(YogaGutter.COLUMN, scaledValue)
                }
            }
            "justifyContent" -> {
                when (value as? String) {
                    "flexStart" -> node.setJustifyContent(YogaJustify.FLEX_START)
                    "center" -> node.setJustifyContent(YogaJustify.CENTER)
                    "flexEnd" -> node.setJustifyContent(YogaJustify.FLEX_END)
                    "spaceBetween" -> node.setJustifyContent(YogaJustify.SPACE_BETWEEN)
                    "spaceAround" -> node.setJustifyContent(YogaJustify.SPACE_AROUND)
                    "spaceEvenly" -> node.setJustifyContent(YogaJustify.SPACE_EVENLY)
                }
            }
            "alignItems" -> {
                when (value as? String) {
                    "auto" -> node.setAlignItems(YogaAlign.AUTO)
                    "flexStart" -> node.setAlignItems(YogaAlign.FLEX_START)
                    "center" -> node.setAlignItems(YogaAlign.CENTER)
                    "flexEnd" -> node.setAlignItems(YogaAlign.FLEX_END)
                    "stretch" -> node.setAlignItems(YogaAlign.STRETCH)
                    "baseline" -> node.setAlignItems(YogaAlign.BASELINE)
                }
            }
            "alignContent" -> {
                when (value as? String) {
                    "flexStart" -> node.setAlignContent(YogaAlign.FLEX_START)
                    "center" -> node.setAlignContent(YogaAlign.CENTER)
                    "flexEnd" -> node.setAlignContent(YogaAlign.FLEX_END)
                    "stretch" -> node.setAlignContent(YogaAlign.STRETCH)
                    "spaceBetween" -> node.setAlignContent(YogaAlign.SPACE_BETWEEN)
                    "spaceAround" -> node.setAlignContent(YogaAlign.SPACE_AROUND)
                }
            }
            "paddingTop" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPadding(YogaEdge.TOP, scaledValue)
                }
            }
            "paddingRight" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPadding(YogaEdge.RIGHT, scaledValue)
                }
            }
            "paddingBottom" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPadding(YogaEdge.BOTTOM, scaledValue)
                }
            }
            "paddingLeft" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPadding(YogaEdge.LEFT, scaledValue)
                }
            }
            "padding" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPadding(YogaEdge.ALL, scaledValue)
                }
            }
            "marginTop" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setMargin(YogaEdge.TOP, scaledValue)
                }
            }
            "marginRight" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setMargin(YogaEdge.RIGHT, scaledValue)
                }
            }
            "marginBottom" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setMargin(YogaEdge.BOTTOM, scaledValue)
                }
            }
            "marginLeft" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setMargin(YogaEdge.LEFT, scaledValue)
                }
            }
            "margin" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setMargin(YogaEdge.ALL, scaledValue)
                }
            }
            "position" -> {
                when (value as? String) {
                    "absolute" -> node.setPositionType(YogaPositionType.ABSOLUTE)
                    "relative" -> node.setPositionType(YogaPositionType.RELATIVE)
                }
            }
            "top" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPosition(YogaEdge.TOP, scaledValue)
                }
            }
            "right" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPosition(YogaEdge.RIGHT, scaledValue)
                }
            }
            "bottom" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPosition(YogaEdge.BOTTOM, scaledValue)
                }
            }
            "left" -> {
                if (value is Number) {
                    // CRITICAL FIX: Apply density scaling to match iOS behavior
                    val scaledValue = applyDensityScaling(value.toFloat())
                    node.setPosition(YogaEdge.LEFT, scaledValue)
                }
            }
            // Add more properties as needed matching iOS exactly
        }
    }

    // Gap support now handled natively by Yoga 2.0+ - no workaround needed

    fun clearAll() {
        nodes.clear()
        nodeParents.clear()
        nodeTypes.clear()
        screenRoots.clear()
        screenRootIds.clear()
        
        // CRITICAL: Recreate the root node after clearing
        // This prevents "Root node not found" errors during hot restart
        rootNode = YogaNodeFactory.create()
        rootNode?.let { root ->
            root.setDirection(YogaDirection.LTR)
            root.setFlexDirection(YogaFlexDirection.COLUMN)
            
            val displayMetrics = Resources.getSystem().displayMetrics
            root.setWidth(displayMetrics.widthPixels.toFloat())
            root.setHeight(displayMetrics.heightPixels.toFloat())
            
            nodes["root"] = root
            nodeTypes["root"] = "View"
        }
        
        Log.d(TAG, "YogaShadowTree cleared and root node recreated")
    }

    fun viewRegisteredWithShadowTree(viewId: String): Boolean {
        return nodes.containsKey(viewId)
    }
    
    /**
     * CRITICAL FIX: Refresh density scale factor when screen configuration changes
     * This ensures consistent scaling across device rotations and density changes
     */
    fun refreshDensityScaleFactor() {
        updateDensityScaleFactor()
        Log.d(TAG, "Density scale factor refreshed: $densityScaleFactor")
    }
}

