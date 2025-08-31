/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.graphics.RectF
import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.facebook.yoga.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write
import kotlin.math.max
import kotlin.math.min

/**
 * Manages the Yoga layout tree for DCFlight components
 * Following iOS YogaShadowTree implementation exactly
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

    // Web defaults configuration
    private var useWebDefaults = false

    init {
        rootNode = YogaNodeFactory.create()

        rootNode?.let { root ->
            root.setDirection(YogaDirection.LTR)
            root.setFlexDirection(YogaFlexDirection.COLUMN)

            // Get screen dimensions
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            root.setWidth(displayMetrics.widthPixels.toFloat())
            root.setHeight(displayMetrics.heightPixels.toFloat())

            nodes["root"] = root
            nodeTypes["root"] = "View"
        }
    }

    fun hasNode(nodeId: String): Boolean = nodes.containsKey(nodeId)

    fun createNode(id: String, componentType: String, props: Map<String, Any?> = emptyMap()) {
        syncLock.write {
            val node = YogaNodeFactory.create()

            // Apply default styles based on configuration
            applyDefaultNodeStyles(node)

            // Store context data
            val context = NodeContext(
                nodeId = id,
                componentType = componentType,
                props = props.toMutableMap()
            )
            node.data = context

            nodes[id] = node
            nodeTypes[id] = componentType

            setupMeasureFunction(id, node)
        }
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

            val context = NodeContext(
                nodeId = id,
                componentType = componentType,
                props = mutableMapOf()
            )
            screenRoot.data = context

            nodes[id] = screenRoot
            screenRoots[id] = screenRoot
            screenRootIds.add(id)
            nodeTypes[id] = componentType
        }
    }

    private fun setupMeasureFunction(nodeId: String, node: YogaNode) {
        val childCount = node.childCount

        if (childCount == 0) {
            node.setMeasureFunction { yogaNode, width, widthMode, height, heightMode ->
                val context = yogaNode.data as? NodeContext ?: return@setMeasureFunction YogaMeasureOutput.make(0f, 0f)
                val view =
                    DCFLayoutManager.shared.getView(context.nodeId) ?: return@setMeasureFunction YogaMeasureOutput.make(
                        0f,
                        0f
                    )

                val constraintWidth = if (widthMode == YogaMeasureMode.UNDEFINED) Float.MAX_VALUE else width
                val constraintHeight = if (heightMode == YogaMeasureMode.UNDEFINED) Float.MAX_VALUE else height

                val componentType = context.componentType
                val componentInstance = DCFComponentRegistry.shared.createComponentInstance(componentType)
                    ?: return@setMeasureFunction YogaMeasureOutput.make(constraintWidth, constraintHeight)

                val intrinsicSize = componentInstance.getIntrinsicSize(view, context.props)

                val finalWidth = if (widthMode == YogaMeasureMode.UNDEFINED) intrinsicSize.width else min(
                    intrinsicSize.width,
                    constraintWidth
                )
                val finalHeight = if (heightMode == YogaMeasureMode.UNDEFINED) intrinsicSize.height else min(
                    intrinsicSize.height,
                    constraintHeight
                )

                YogaMeasureOutput.make(finalWidth, finalHeight)
            }
        } else {
            node.setMeasureFunction(null)
        }
    }

    fun addChildNode(parentId: String, childId: String, index: Int? = null) {
        syncLock.write {
            val parentNode = nodes[parentId]
            val childNode = nodes[childId]

            if (parentNode == null || childNode == null) {
                Log.w(TAG, "Cannot add child: parent or child node not found")
                return
            }

            if (screenRootIds.contains(childId)) {
                Log.w(TAG, "Cannot add screen root as child")
                return
            }

            // Remove from old parent if exists
            nodeParents[childId]?.let { oldParentId ->
                nodes[oldParentId]?.let { oldParentNode ->
                    safeRemoveChildFromParent(oldParentNode, childNode, childId)
                    setupMeasureFunction(oldParentId, oldParentNode)
                }
            }

            // Clear measure function on parent when adding children
            parentNode.setMeasureFunction(null)

            // Add to new parent
            if (index != null) {
                val childCount = parentNode.childCount
                val safeIndex = max(0, min(index, childCount))
                parentNode.addChildAt(childNode, safeIndex)
            } else {
                parentNode.addChildAt(childNode, parentNode.childCount)
            }

            nodeParents[childId] = parentId

            setupMeasureFunction(childId, childNode)
        }
    }

    fun removeNode(nodeId: String) {
        syncLock.write {
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

            if (screenRootIds.contains(nodeId)) {
                screenRoots.remove(nodeId)
                screenRootIds.remove(nodeId)
            } else {
                nodeParents[nodeId]?.let { parentId ->
                    nodes[parentId]?.let { parentNode ->
                        safeRemoveChildFromParent(parentNode, node, nodeId)
                        setupMeasureFunction(parentId, parentNode)
                    }
                }
            }

            safeRemoveAllChildren(node, nodeId)

            nodes.remove(nodeId)
            nodeParents.remove(nodeId)
            nodeTypes.remove(nodeId)

            isReconciling = false
        }
    }

    private fun safeRemoveChildFromParent(parentNode: YogaNode, childNode: YogaNode, childId: String) {
        val childCount = parentNode.childCount

        if (childCount <= 0) return

        for (i in 0 until childCount) {
            val child = parentNode.getChildAt(i)
            if (child == childNode) {
                parentNode.removeChildAt(i)
                break
            }
        }
    }

    private fun safeRemoveAllChildren(node: YogaNode, nodeId: String) {
        var childCount = node.childCount

        while (childCount > 0) {
            val lastIndex = childCount - 1
            val childNode = node.getChildAt(lastIndex)

            if (childNode != null) {
                node.removeChildAt(lastIndex)
            }

            val newChildCount = node.childCount
            if (newChildCount >= childCount) {
                break
            }

            childCount = newChildCount
        }
    }

    fun updateNodeLayoutProps(nodeId: String, props: Map<String, Any?>) {
        val node = nodes[nodeId] ?: return

        // Update context props
        val context = node.data as? NodeContext
        context?.props?.putAll(props)

        // Apply layout properties
        props.forEach { (key, value) ->
            applyLayoutProp(node, key, value)
        }

        validateNodeLayoutConfig(nodeId)
    }

    fun calculateAndApplyLayout(width: Float, height: Float): Boolean {
        return syncLock.write {
            if (isReconciling) {
                return false
            }

            isLayoutCalculating = true
            try {
                val mainRoot = nodes["root"] ?: return false

                mainRoot.setWidth(width)
                mainRoot.setHeight(height)

                mainRoot.calculateLayout(width, height)

                // Calculate for screen roots
                screenRoots.forEach { (_, screenRoot) ->
                    screenRoot.setWidth(width)
                    screenRoot.setHeight(height)
                    screenRoot.calculateLayout(width, height)
                }

                // Apply layout to views
                nodes.forEach { (nodeId, node) ->
                    getNodeLayout(nodeId)?.let { layout ->
                        applyLayoutToView(nodeId, layout)
                    }
                }

                true
            } catch (e: Exception) {
                Log.e(TAG, "Layout calculation failed", e)
                false
            } finally {
                isLayoutCalculating = false
            }
        }
    }

    fun updateScreenRootDimensions(width: Float, height: Float) {
        syncLock.write {
            screenRoots.forEach { (_, screenRoot) ->
                screenRoot.setWidth(width)
                screenRoot.setHeight(height)
            }
        }
    }

    fun isScreenRoot(nodeId: String): Boolean = screenRootIds.contains(nodeId)

    fun getNodeLayout(nodeId: String): RectF? {
        val node = nodes[nodeId] ?: return null

        val left = node.layoutX
        val top = node.layoutY
        val width = node.layoutWidth
        val height = node.layoutHeight

        return RectF(left, top, left + width, top + height)
    }

    private fun validateNodeLayoutConfig(nodeId: String) {
        val node = nodes[nodeId] ?: return

        if (node.childCount > 0 && !node.hasNewLayout()) {
            node.setHeightAuto()
        }
    }

    private fun applyLayoutProp(node: YogaNode, key: String, value: Any?) {
        when (key) {
            "translateX" -> updateNodeTransformContext(node, "translateX", value)
            "translateY" -> updateNodeTransformContext(node, "translateY", value)
            "rotateInDegrees" -> {
                val degrees = convertToFloat(value)
                if (degrees != null) {
                    val radians = degrees * Math.PI.toFloat() / 180f
                    updateNodeTransformContext(node, "rotate", radians)
                }
            }

            "scale" -> convertToFloat(value)?.let { updateNodeTransformContext(node, "scale", it) }
            "scaleX" -> convertToFloat(value)?.let { updateNodeTransformContext(node, "scaleX", it) }
            "scaleY" -> convertToFloat(value)?.let { updateNodeTransformContext(node, "scaleY", it) }

            "width" -> {
                convertToFloat(value)?.let { node.setWidth(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setWidthPercent(it) }
                        }
                    }
            }

            "height" -> {
                convertToFloat(value)?.let { node.setHeight(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setHeightPercent(it) }
                        }
                    }
            }

            "minWidth" -> {
                convertToFloat(value)?.let { node.setMinWidth(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setMinWidthPercent(it) }
                        }
                    }
            }

            "maxWidth" -> {
                convertToFloat(value)?.let { node.setMaxWidth(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setMaxWidthPercent(it) }
                        }
                    }
            }

            "minHeight" -> {
                convertToFloat(value)?.let { node.setMinHeight(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setMinHeightPercent(it) }
                        }
                    }
            }

            "maxHeight" -> {
                convertToFloat(value)?.let { node.setMaxHeight(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setMaxHeightPercent(it) }
                        }
                    }
            }

            // Margin properties
            "margin" -> applyEdgeValue(node, YogaEdge.ALL, value) { n, e, v -> n.setMargin(e, v) }
            "marginTop" -> applyEdgeValue(node, YogaEdge.TOP, value) { n, e, v -> n.setMargin(e, v) }
            "marginRight" -> applyEdgeValue(node, YogaEdge.RIGHT, value) { n, e, v -> n.setMargin(e, v) }
            "marginBottom" -> applyEdgeValue(node, YogaEdge.BOTTOM, value) { n, e, v -> n.setMargin(e, v) }
            "marginLeft" -> applyEdgeValue(node, YogaEdge.LEFT, value) { n, e, v -> n.setMargin(e, v) }

            // Padding properties
            "padding" -> applyEdgeValue(node, YogaEdge.ALL, value) { n, e, v -> n.setPadding(e, v) }
            "paddingTop" -> applyEdgeValue(node, YogaEdge.TOP, value) { n, e, v -> n.setPadding(e, v) }
            "paddingRight" -> applyEdgeValue(node, YogaEdge.RIGHT, value) { n, e, v -> n.setPadding(e, v) }
            "paddingBottom" -> applyEdgeValue(node, YogaEdge.BOTTOM, value) { n, e, v -> n.setPadding(e, v) }
            "paddingLeft" -> applyEdgeValue(node, YogaEdge.LEFT, value) { n, e, v -> n.setPadding(e, v) }

            // Position
            "position" -> {
                when (value as? String) {
                    "absolute" -> node.setPositionType(YogaPositionType.ABSOLUTE)
                    "relative" -> node.setPositionType(YogaPositionType.RELATIVE)
                    "static" -> {
                        node.setPositionType(YogaPositionType.RELATIVE) // Android Yoga doesn't have static
                        updateNodeTransformContext(node, "positionType", "static")
                    }
                }
            }

            // Position edges
            "left" -> if (!isStaticPositioned(node)) {
                applyEdgeValue(node, YogaEdge.LEFT, value) { n, e, v -> n.setPosition(e, v) }
            }

            "top" -> if (!isStaticPositioned(node)) {
                applyEdgeValue(node, YogaEdge.TOP, value) { n, e, v -> n.setPosition(e, v) }
            }

            "right" -> if (!isStaticPositioned(node)) {
                applyEdgeValue(node, YogaEdge.RIGHT, value) { n, e, v -> n.setPosition(e, v) }
            }

            "bottom" -> if (!isStaticPositioned(node)) {
                applyEdgeValue(node, YogaEdge.BOTTOM, value) { n, e, v -> n.setPosition(e, v) }
            }

            // Flexbox properties
            "flexDirection" -> {
                when (value as? String) {
                    "row" -> node.setFlexDirection(YogaFlexDirection.ROW)
                    "column" -> node.setFlexDirection(YogaFlexDirection.COLUMN)
                    "rowReverse" -> node.setFlexDirection(YogaFlexDirection.ROW_REVERSE)
                    "columnReverse" -> node.setFlexDirection(YogaFlexDirection.COLUMN_REVERSE)
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
                    "spaceBetween" -> node.setAlignItems(YogaAlign.SPACE_BETWEEN)
                    "spaceAround" -> node.setAlignItems(YogaAlign.SPACE_AROUND)
                }
            }

            "alignSelf" -> {
                when (value as? String) {
                    "auto" -> node.setAlignSelf(YogaAlign.AUTO)
                    "flexStart" -> node.setAlignSelf(YogaAlign.FLEX_START)
                    "center" -> node.setAlignSelf(YogaAlign.CENTER)
                    "flexEnd" -> node.setAlignSelf(YogaAlign.FLEX_END)
                    "stretch" -> node.setAlignSelf(YogaAlign.STRETCH)
                    "baseline" -> node.setAlignSelf(YogaAlign.BASELINE)
                    "spaceBetween" -> node.setAlignSelf(YogaAlign.SPACE_BETWEEN)
                    "spaceAround" -> node.setAlignSelf(YogaAlign.SPACE_AROUND)
                }
            }

            "flexWrap" -> {
                when (value as? String) {
                    "nowrap" -> node.setWrap(YogaWrap.NO_WRAP)
                    "wrap" -> node.setWrap(YogaWrap.WRAP)
                    "wrapReverse" -> node.setWrap(YogaWrap.WRAP_REVERSE)
                }
            }

            "flex" -> convertToFloat(value)?.let { node.setFlex(it) }
            "flexGrow" -> convertToFloat(value)?.let { node.setFlexGrow(it) }
            "flexShrink" -> convertToFloat(value)?.let { node.setFlexShrink(it) }
            "flexBasis" -> {
                convertToFloat(value)?.let { node.setFlexBasis(it) }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { node.setFlexBasisPercent(it) }
                        }
                    }
            }

            // Display and overflow
            "display" -> {
                when (value as? String) {
                    "flex" -> node.setDisplay(YogaDisplay.FLEX)
                    "none" -> node.setDisplay(YogaDisplay.NONE)
                }
            }

            "overflow" -> {
                when (value as? String) {
                    "visible" -> node.setOverflow(YogaOverflow.VISIBLE)
                    "hidden" -> node.setOverflow(YogaOverflow.HIDDEN)
                    "scroll" -> node.setOverflow(YogaOverflow.SCROLL)
                }
            }

            // Direction
            "direction" -> {
                when (value as? String) {
                    "inherit" -> node.setDirection(YogaDirection.INHERIT)
                    "ltr" -> node.setDirection(YogaDirection.LTR)
                    "rtl" -> node.setDirection(YogaDirection.RTL)
                }
            }

            // Border and aspect ratio
            "borderWidth" -> convertToFloat(value)?.let { node.setBorder(YogaEdge.ALL, it) }
            "aspectRatio" -> convertToFloat(value)?.let { node.setAspectRatio(it) }

            // Gap (for Android Yoga that supports it)
            "gap" -> convertToFloat(value)?.let { /* Gap not yet supported in Android Yoga */ }
            "rowGap" -> convertToFloat(value)?.let { /* Gap not yet supported in Android Yoga */ }
            "columnGap" -> convertToFloat(value)?.let { /* Gap not yet supported in Android Yoga */ }
        }
    }

    private fun applyEdgeValue(
        node: YogaNode,
        edge: YogaEdge,
        value: Any?,
        setter: (YogaNode, YogaEdge, Float) -> Unit
    ) {
        convertToFloat(value)?.let { setter(node, edge, it) }
            ?: (value as? String)?.let { str ->
                if (str.endsWith("%")) {
                    str.dropLast(1).toFloatOrNull()?.let {
                        when (edge) {
                            YogaEdge.ALL -> {
                                setter(node, YogaEdge.LEFT, it)
                                setter(node, YogaEdge.TOP, it)
                                setter(node, YogaEdge.RIGHT, it)
                                setter(node, YogaEdge.BOTTOM, it)
                            }

                            else -> setter(node, edge, it)
                        }
                    }
                }
            }
    }

    private fun convertToFloat(value: Any?): Float? {
        return when (value) {
            is Float -> value
            is Double -> value.toFloat()
            is Int -> value.toFloat()
            is Long -> value.toFloat()
            is String -> value.toFloatOrNull()
            else -> null
        }
    }

    private fun updateNodeTransformContext(node: YogaNode, key: String, value: Any?) {
        val context = node.data as? NodeContext ?: return

        when (key) {
            "translateX" -> {
                convertToFloat(value)?.let { context.translateX = it }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { context.translateXPercent = it }
                        }
                    }
            }

            "translateY" -> {
                convertToFloat(value)?.let { context.translateY = it }
                    ?: (value as? String)?.let { str ->
                        if (str.endsWith("%")) {
                            str.dropLast(1).toFloatOrNull()?.let { context.translateYPercent = it }
                        }
                    }
            }

            else -> {
                convertToFloat(value)?.let {
                    when (key) {
                        "rotate" -> context.rotate = it
                        "scale" -> context.scale = it
                        "scaleX" -> context.scaleX = it
                        "scaleY" -> context.scaleY = it
                    }
                } ?: (value as? String)?.let {
                    if (key == "positionType") context.positionType = it
                }
            }
        }
    }

    fun setCustomMeasureFunction(nodeId: String, measureFunc: YogaMeasureFunction) {
        val node = nodes[nodeId] ?: return

        if (node.childCount == 0) {
            node.setMeasureFunction(measureFunc)
        }
    }

    private fun applyLayoutToView(viewId: String, frame: RectF) {
        val view = DCFLayoutManager.shared.getView(viewId) ?: return
        val node = nodes[viewId] ?: return

        var finalFrame = RectF(frame)
        val context = node.data as? NodeContext

        if (context != null) {
            // Apply transforms
            var translationX = 0f
            var translationY = 0f

            context.translateX?.let { translationX += it }
            context.translateXPercent?.let { translationX += it * frame.width() / 100f }
            context.translateY?.let { translationY += it }
            context.translateYPercent?.let { translationY += it * frame.height() / 100f }

            finalFrame.offset(translationX, translationY)

            // Apply other transforms on main thread
            DCFLayoutManager.shared.getView(viewId)?.let { view ->
                view.post {
                    context.rotate?.let { view.rotation = Math.toDegrees(it.toDouble()).toFloat() }
                    context.scale?.let {
                        view.scaleX = it
                        view.scaleY = it
                    } ?: run {
                        context.scaleX?.let { view.scaleX = it }
                        context.scaleY?.let { view.scaleY = it }
                    }
                }
            }
        }

        // Apply layout
        DCFLayoutManager.shared.applyLayout(
            viewId,
            finalFrame.left,
            finalFrame.top,
            finalFrame.width(),
            finalFrame.height()
        )
    }

    // Web Defaults Support

    fun applyWebDefaults() {
        syncLock.write {
            useWebDefaults = true

            // Apply web defaults to root node
            rootNode?.let { root ->
                // Web default: flex-direction: row (instead of column)
                root.setFlexDirection(YogaFlexDirection.ROW)
                // Web default: align-content: stretch (instead of flex-start)
                root.setAlignContent(YogaAlign.STRETCH)
                // Web default: flex-shrink: 1 (instead of 0)
                root.setFlexShrink(1f)

                Log.d(TAG, "Applied web defaults to root node")
            }

            // Apply web defaults to all screen roots
            screenRoots.forEach { (_, screenRoot) ->
                screenRoot.setFlexDirection(YogaFlexDirection.ROW)
                screenRoot.setAlignContent(YogaAlign.STRETCH)
                screenRoot.setFlexShrink(1f)
            }

            Log.d(TAG, "Applied web defaults to ${screenRoots.size} screen roots")
        }
    }

    private fun applyDefaultNodeStyles(node: YogaNode) {
        if (useWebDefaults) {
            // Web defaults
            node.setFlexDirection(YogaFlexDirection.ROW)
            node.setAlignContent(YogaAlign.STRETCH)
            node.setFlexShrink(1f)
        } else {
            // Yoga native defaults
            node.setFlexDirection(YogaFlexDirection.COLUMN)
            node.setAlignContent(YogaAlign.FLEX_START)
            node.setFlexShrink(0f)
        }
    }

    private fun isStaticPositioned(node: YogaNode): Boolean {
        val context = node.data as? NodeContext
        return context?.positionType == "static"
    }

    fun clearAll() {
        syncLock.write {
            nodes.forEach { (nodeId, _) ->
                if (nodeId != "root") {
                    removeNode(nodeId)
                }
            }
        }
    }

    // Node context data class
    private data class NodeContext(
        val nodeId: String,
        val componentType: String,
        val props: MutableMap<String, Any?>,
        var translateX: Float? = null,
        var translateXPercent: Float? = null,
        var translateY: Float? = null,
        var translateYPercent: Float? = null,
        var rotate: Float? = null,
        var scale: Float? = null,
        var scaleX: Float? = null,
        var scaleY: Float? = null,
        var positionType: String? = null
    )
}
