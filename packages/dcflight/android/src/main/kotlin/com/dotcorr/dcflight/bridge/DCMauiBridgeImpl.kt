/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.content.Context
import android.content.res.Resources
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.ViewRegistry
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

/**
 * Bridge between Dart and native Android code
 */
class DCMauiBridgeImpl private constructor() {

    companion object {
        private const val TAG = "DCMauiBridgeImpl"

        @JvmField
        val shared = DCMauiBridgeImpl()
    }

    internal val views = ConcurrentHashMap<String, View>()
    private val viewHierarchy = ConcurrentHashMap<String, MutableList<String>>()
    private val childToParent = ConcurrentHashMap<String, String>()
    private var appContext: Context? = null
    private var isInitialized = false

    fun setContext(context: Context) {
        appContext = context
    }

    fun initialize(): Boolean {
        if (isInitialized) return true
        Log.d(TAG, "Initializing DCMauiBridgeImpl")
        isInitialized = true
        return true
    }

    fun handleTunnelMethod(componentType: String, method: String, params: Map<String, Any>): Any? {
        Log.d(TAG, "Tunneling $method to $componentType")
        
        return try {
            val componentClass = DCFComponentRegistry.shared.getComponent(componentType)
            if (componentClass == null) {
                Log.e(TAG, "Component $componentType not registered")
                return null
            }

            val componentInstance = componentClass.getDeclaredConstructor().newInstance()
            if (componentInstance is DCFComponent) {
                componentInstance.handleTunnelMethod(method, params)
            } else {
                Log.e(TAG, "Component $componentType is not a DCFComponent")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle tunnel method", e)
            null
        }
    }

    fun createView(viewId: String, viewType: String, propsJson: String): Boolean {
        return try {
            val existingView = ViewRegistry.shared.getView(viewId)
            if (existingView != null) {
                // Check if view is actually in the hierarchy - if not, delete and recreate
                if (existingView.parent == null) {
                    Log.d(TAG, "🔥 REDIRECT: View $viewId exists but not in hierarchy, deleting and recreating")
                    deleteView(viewId)
                } else {
                    Log.d(TAG, "🔥 REDIRECT: View $viewId exists, calling updateView")
                    return updateView(viewId, propsJson)
                }
            }
            
            val props = if (propsJson.isNotEmpty()) {
                parseJsonToMap(propsJson)
            } else {
                emptyMap()
            }

            val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
            if (componentClass == null) {
                Log.e(TAG, "Component type '$viewType' not found")
                return false
            }

            val context = appContext
            if (context == null) {
                Log.e(TAG, "No context available for creating view")
                return false
            }

            // Create a new view
            val componentInstance = componentClass.getDeclaredConstructor().newInstance()
            val view = componentInstance.createView(context, props)
            Log.d(TAG, "✨ Created new view for type '$viewType' (viewId: $viewId)")

            // Ensure view is visible
            view.visibility = View.VISIBLE
            view.alpha = 1.0f

            ViewRegistry.shared.registerView(view, viewId, viewType)
            views[viewId] = view

            YogaShadowTree.shared.createNode(viewId, viewType)
            YogaShadowTree.shared.updateNodeLayoutProps(viewId, props)

            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create view: $viewId", e)
            false
        }
    }

    fun updateView(viewId: String, propsJson: String): Boolean {
        return try {
            val view = ViewRegistry.shared.getView(viewId)
            if (view == null) {
                Log.e(TAG, "View '$viewId' not found for update")
                return false
            }

            val props = if (propsJson.isNotEmpty()) {
                parseJsonToMap(propsJson)
            } else {
                emptyMap()
            }

            val viewType = ViewRegistry.shared.getViewType(viewId)
            if (viewType == null) {
                Log.e(TAG, "View type for '$viewId' not found")
                return false
            }

            val layoutProps = extractLayoutProps(props)
            val nonLayoutProps = props.filter { !layoutProps.containsKey(it.key) }

            // Debug logging for Screen components
            if (viewType == "Screen") {
                Log.d(TAG, "🔍 UPDATE_VIEW Screen - viewId: $viewId")
                Log.d(TAG, "🔍 All props: $props")
                Log.d(TAG, "🔍 Layout props: $layoutProps")
                Log.d(TAG, "🔍 Non-layout props: $nonLayoutProps")
                Log.d(TAG, "🔍 Has routeNavigationCommand: ${props.containsKey("routeNavigationCommand")}")
            }

            if (layoutProps.isNotEmpty()) {
                val isScreen = YogaShadowTree.shared.isScreenRoot(viewId)
                
                if (isScreen) {
                    YogaShadowTree.shared.updateNodeLayoutProps(viewId, layoutProps)
                } else {
                    DCFLayoutManager.shared.updateNodeWithLayoutProps(
                        nodeId = viewId,
                        componentType = viewType,
                        props = layoutProps
                    )
                }
            }

            if (nonLayoutProps.isNotEmpty()) {
                val componentClass = DCFComponentRegistry.shared.getComponentType(viewType)
                if (componentClass != null) {
                    try {
                        val componentInstance = componentClass.getDeclaredConstructor().newInstance()
                        componentInstance.updateView(view, nonLayoutProps)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error calling updateView on $viewType component", e)
                    }
                } else {
                    Log.w(TAG, "⚠️ Component class not found for type: $viewType")
                }
            }

            // Ensure view is visible and invalidated after update
            view.visibility = View.VISIBLE
            view.invalidate()
            view.requestLayout()

            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update view: $viewId", e)
            false
        }
    }

    fun deleteView(viewId: String): Boolean {
        return try {
            deleteChildrenRecursively(viewId)
            
            val view = ViewRegistry.shared.getView(viewId)
            val viewType = ViewRegistry.shared.getViewType(viewId)
            
            if (view != null) {
                val parentView = view.parent as? ViewGroup
                parentView?.removeView(view)
            }
            
            cleanupHierarchyReferences(viewId)
            
            ViewRegistry.shared.removeView(viewId)
            views.remove(viewId)
            YogaShadowTree.shared.removeNode(viewId)
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete view: $viewId", e)
            false
        }
    }

    fun attachView(childId: String, parentId: String, index: Int): Boolean {
        return try {
            val childView = ViewRegistry.shared.getView(childId)
            val parentView = ViewRegistry.shared.getView(parentId)

            if (childView == null || parentView == null) {
                Log.e(TAG, "Cannot attach - child '$childId' or parent '$parentId' not found")
                Log.e(TAG, "Available views: ${ViewRegistry.shared.allViewIds}")
                return false
            }

            Log.d(TAG, "🔍 attachView: child='$childId' (type=${childView.javaClass.simpleName}), parent='$parentId' (type=${parentView.javaClass.simpleName})")
            Log.d(TAG, "🔍 parentView is ViewGroup? ${parentView is ViewGroup}")
            
            val parentViewGroup = parentView as? ViewGroup
            if (parentViewGroup == null) {
                Log.e(TAG, "❌ Parent view '$parentId' is not a ViewGroup (type: ${parentView.javaClass.simpleName})")
                Log.e(TAG, "❌ Parent view class: ${parentView.javaClass.name}")
                Log.e(TAG, "❌ Parent view superclass: ${parentView.javaClass.superclass?.name}")
                return false
            }

            if (childView.parent != null) {
                (childView.parent as? ViewGroup)?.removeView(childView)
                Log.d(TAG, "Removed child '$childId' from existing parent")
            }

                try {
                    if (index >= 0 && index <= parentViewGroup.childCount) {
                        parentViewGroup.addView(childView, index)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at index $index")
                    } else {
                        parentViewGroup.addView(childView)
                        Log.d(TAG, "Attached child '$childId' to parent '$parentId' at end")
                    }
                    
                    Log.d(TAG, "Successfully attached child '$childId' to parent '$parentId'")
                } catch (e: Exception) {
                Log.e(TAG, "Error in attachment: ${e.message}", e)
                throw e
            }

            childToParent[childId] = parentId
            viewHierarchy.getOrPut(parentId) { mutableListOf() }.add(childId)

            YogaShadowTree.shared.addChildNode(parentId, childId, index)

            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to attach view: $childId to $parentId", e)
            false
        }
    }

    fun detachView(viewId: String): Boolean {
        return try {
            val view = ViewRegistry.shared.getView(viewId)
            if (view == null) {
                Log.e(TAG, "View '$viewId' not found for detach")
                return false
            }

            val parentView = view.parent as? ViewGroup
            parentView?.removeView(view)

            val parentId = childToParent.remove(viewId)
            if (parentId != null) {
                viewHierarchy[parentId]?.remove(viewId)
            }

            YogaShadowTree.shared.removeNode(viewId)

            true
        } catch (e: Exception) {
            false
        }
    }

    fun setChildren(viewId: String, childrenIds: List<String>): Boolean {
        return try {
            Log.d(TAG, "🔧 setChildren called: viewId='$viewId', children=${childrenIds.size}")
            val parentView = ViewRegistry.shared.getView(viewId)
            
            if (parentView == null) {
                Log.e(TAG, "❌ setChildren: parent view '$viewId' not found in registry")
                return false
            }
            
            Log.d(TAG, "🔍 setChildren: parentView type=${parentView.javaClass.simpleName}, is ViewGroup? ${parentView is ViewGroup}")
            val parentViewGroup = parentView as? ViewGroup

            if (parentViewGroup == null) {
                Log.e(TAG, "❌ setChildren: Parent view '$viewId' is not a ViewGroup (type: ${parentView.javaClass.simpleName})")
                return false
            }

            // Check if this is a DCFScreenComponent's FrameLayout (has DCFScreen tag)
            if (parentViewGroup.tag == "DCFScreen") {
                Log.d(TAG, "🎯 Using custom setChildren for DCFScreen: $viewId")
                val childViews = childrenIds.mapNotNull { childId ->
                    ViewRegistry.shared.getView(childId)
                }
                
                // Remove existing children (except navigation bar)
                val childCount = parentViewGroup.childCount
                for (i in childCount - 1 downTo 0) {
                    val child = parentViewGroup.getChildAt(i)
                    if (child.tag != "NavigationBar") { // Keep navigation bar
                        parentViewGroup.removeViewAt(i)
                    }
                }
                
                // Add new children
                childViews.forEach { childView ->
                    parentViewGroup.addView(childView)
                    childView.layoutParams = android.widget.FrameLayout.LayoutParams(
                        android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                        android.widget.FrameLayout.LayoutParams.MATCH_PARENT
                    )
                    childView.visibility = android.view.View.VISIBLE
                    childView.alpha = 1.0f
                }
                
                // Update view hierarchy
                viewHierarchy[viewId]?.clear()
                childrenIds.forEach { childId ->
                    childToParent[childId] = viewId
                    viewHierarchy.getOrPut(viewId) { mutableListOf() }.add(childId)
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = childrenIds.indexOf(childId))
                }
                
                Log.d(TAG, "✅ Added ${childViews.size} children to DCFScreen: $viewId")
                return true
            }

            // Fallback to default behavior
            parentViewGroup.removeAllViews()
            viewHierarchy[viewId]?.clear()

            childrenIds.forEachIndexed { index: Int, childId: String ->
                val childView = ViewRegistry.shared.getView(childId)
                if (childView != null) {
                    parentViewGroup.addView(childView)
                    childToParent[childId] = viewId
                    viewHierarchy.getOrPut(viewId) { mutableListOf() }.add(childId)
                    
                    DCFLayoutManager.shared.addChildNode(parentId = viewId, childId = childId, index = index)
                }
            }

            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set children for view: $viewId", e)
            false
        }
    }


    /**
     * ⭐ OPTIMIZED: Commit a batch of operations atomically with improved performance
     * Now accepts pre-serialized JSON strings to eliminate native JSON parsing overhead
     */
    fun commitBatchUpdate(operations: List<Map<String, Any>>): Boolean {
        val startTime = System.currentTimeMillis()
        Log.d(TAG, "🔥 BATCH: Committing ${operations.size} operations (OPTIMIZED ATOMIC)")
        
        data class CreateOp(val viewId: String, val viewType: String, val propsJson: String)
        data class UpdateOp(val viewId: String, val propsJson: String)
        data class AttachOp(val childId: String, val parentId: String, val index: Int)
        data class AddEventListenersOp(val viewId: String, val eventTypes: List<String>)
        
        val createOps = mutableListOf<CreateOp>()
        val updateOps = mutableListOf<UpdateOp>()
        val attachOps = mutableListOf<AttachOp>()
        val eventOps = mutableListOf<AddEventListenersOp>()
        
        // ⭐ OPTIMIZATION: Parse phase - collect all operations
        val parseStartTime = System.currentTimeMillis()
        
        operations.forEach { operation ->
            val operationType = operation["operation"] as? String
            
            when (operationType) {
                "createView" -> {
                    val viewId = operation["viewId"] as? String
                    val viewType = operation["viewType"] as? String
                    
                    if (viewId != null && viewType != null) {
                        // ⭐ OPTIMIZATION: Check for pre-serialized JSON first (from Dart)
                        val propsJson = operation["propsJson"] as? String ?: run {
                            // Legacy fallback: serialize on native side
                            val props = operation["props"] as? Map<String, Any>
                            if (props != null) {
                                JSONObject(props).toString()
                            } else {
                                "{}"
                            }
                        }
                        createOps.add(CreateOp(viewId, viewType, propsJson))
                    }
                }
                
                "updateView" -> {
                    val viewId = operation["viewId"] as? String
                    
                    if (viewId != null) {
                        // ⭐ OPTIMIZATION: Check for pre-serialized JSON first (from Dart)
                        val propsJson = operation["propsJson"] as? String ?: run {
                            // Legacy fallback: serialize on native side
                            val props = operation["props"] as? Map<String, Any>
                            if (props != null) {
                                JSONObject(props).toString()
                            } else {
                                "{}"
                            }
                        }
                        updateOps.add(UpdateOp(viewId, propsJson))
                    }
                }
                
                "attachView" -> {
                    val childId = operation["childId"] as? String
                    val parentId = operation["parentId"] as? String
                    val index = operation["index"] as? Int
                    if (childId != null && parentId != null && index != null) {
                        attachOps.add(AttachOp(childId, parentId, index))
                    }
                }
                
                "addEventListeners" -> {
                    val viewId = operation["viewId"] as? String
                    val eventTypes = operation["eventTypes"] as? List<String>
                    if (viewId != null && eventTypes != null) {
                        eventOps.add(AddEventListenersOp(viewId, eventTypes))
                    }
                }
            }
        }
        
        val parseTime = System.currentTimeMillis() - parseStartTime
        Log.d(TAG, "📊 BATCH_TIMING: Parse phase completed in ${parseTime}ms")
        Log.d(TAG, "🔥 BATCH: Collected ${createOps.size} creates, ${updateOps.size} updates, ${attachOps.size} attaches, ${eventOps.size} event registrations")
        
        try {
            // ⭐ OPTIMIZATION: Execute phase - process all operations with minimal overhead
            val createStartTime = System.currentTimeMillis()
            
            // Create all views (props are already JSON strings - no serialization needed!)
            createOps.forEach { op ->
                createView(op.viewId, op.viewType, op.propsJson)
            }
            
            val createTime = System.currentTimeMillis() - createStartTime
            Log.d(TAG, "📊 BATCH_TIMING: Create phase completed in ${createTime}ms (${createOps.size} views)")
            
            val updateStartTime = System.currentTimeMillis()
            
            // Update all views (props are already JSON strings - no serialization needed!)
            updateOps.forEach { op ->
                updateView(op.viewId, op.propsJson)
            }
            
            val updateTime = System.currentTimeMillis() - updateStartTime
            Log.d(TAG, "📊 BATCH_TIMING: Update phase completed in ${updateTime}ms (${updateOps.size} views)")
            
            val attachStartTime = System.currentTimeMillis()
            
            // Attach all views to hierarchy
            attachOps.forEach { op ->
                attachView(op.childId, op.parentId, op.index)
            }
            
            val attachTime = System.currentTimeMillis() - attachStartTime
            Log.d(TAG, "📊 BATCH_TIMING: Attach phase completed in ${attachTime}ms (${attachOps.size} attachments)")
            
            val eventsStartTime = System.currentTimeMillis()
            
            // Register all event listeners
            eventOps.forEach { op ->
                Log.d(TAG, "🔥 BATCH_COMMIT: Registering event listeners for ${op.viewId}")
                DCMauiEventMethodHandler.shared.addEventListenersForBatch(op.viewId, op.eventTypes)
            }
            
            val eventsTime = System.currentTimeMillis() - eventsStartTime
            Log.d(TAG, "📊 BATCH_TIMING: Events phase completed in ${eventsTime}ms (${eventOps.size} registrations)")
            
            val layoutStartTime = System.currentTimeMillis()
            
            // ⭐ OPTIMIZATION: Single layout calculation after all view operations
            Log.d(TAG, "🔥 BATCH_COMMIT: Triggering SYNCHRONOUS layout calculation")
            
            val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()
            
            val rootView = ViewRegistry.shared.getView("root")
            rootView?.let { root ->
                root.measure(
                    View.MeasureSpec.makeMeasureSpec(screenWidth.toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(screenHeight.toInt(), View.MeasureSpec.EXACTLY)
                )
                Log.d(TAG, "🔥 BATCH_COMMIT: Root view measured: ${root.measuredWidth}x${root.measuredHeight}")
            }
            
            val layoutSuccess = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
            
            val layoutTime = System.currentTimeMillis() - layoutStartTime
            Log.d(TAG, "📊 BATCH_TIMING: Layout phase completed in ${layoutTime}ms")
            Log.d(TAG, "🔥 BATCH_COMMIT: Layout calculation completed synchronously: $layoutSuccess")
            
            rootView?.let { root ->
                fun invalidateAll(v: View) {
                    v.invalidate()
                    if (v is ViewGroup) {
                        for (i in 0 until v.childCount) {
                            invalidateAll(v.getChildAt(i))
                        }
                    }
                }
                invalidateAll(root)
                Log.d(TAG, "🔥 BATCH_COMMIT: Forced recursive invalidation")
                
                root.post {
                    YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)
                    Log.d(TAG, "🔥 BATCH_COMMIT: Forced layout recalculation on next frame")
                }
            }
            
            val totalTime = System.currentTimeMillis() - startTime
            Log.d(TAG, "📊 BATCH_TIMING: ✅ TOTAL BATCH COMMIT TIME: ${totalTime}ms for ${operations.size} operations")
            Log.d(TAG, "🔥 BATCH_COMMIT: Successfully committed all operations atomically")
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "🔥 BATCH_COMMIT: Failed during atomic commit", e)
            return false
        }
    }

    private fun deleteChildrenRecursively(parentId: String) {
        val children = viewHierarchy[parentId] ?: return
        children.forEach { childId ->
            deleteChildrenRecursively(childId)
        }
        viewHierarchy.remove(parentId)
    }

    private fun cleanupHierarchyReferences(viewId: String) {
        childToParent.remove(viewId)
        val parentId = childToParent[viewId]
        if (parentId != null) {
            viewHierarchy[parentId]?.remove(viewId)
        }
    }

    fun clearAll() {
        Log.d(TAG, "🔥 DCF_ENGINE: Clearing DCMauiBridgeImpl")
        try {
            childToParent.clear()
            viewHierarchy.clear()
            Log.d(TAG, "🔥 DCF_ENGINE: DCMauiBridgeImpl cleared successfully")
        } catch (e: Exception) {
            Log.e(TAG, "🔥 DCF_ENGINE: Error clearing DCMauiBridgeImpl", e)
        }
    }

    private fun parseJsonToMap(json: String): Map<String, Any> {
        return try {
            val jsonObject = JSONObject(json)
            jsonObject.keys().asSequence().associateWith { key ->
                when (val value = jsonObject.get(key)) {
                    is JSONObject -> parseJsonObjectToMap(value)
                    is JSONArray -> parseJsonArrayToList(value)
                    else -> value
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse JSON: $json", e)
            emptyMap()
        }
    }

    private fun parseJsonObjectToMap(jsonObject: JSONObject): Map<String, Any> {
        return jsonObject.keys().asSequence().associateWith { key ->
            when (val value = jsonObject.get(key)) {
                is JSONObject -> parseJsonObjectToMap(value)
                is JSONArray -> parseJsonArrayToList(value)
                else -> value
            }
        }
    }

    private fun parseJsonArrayToList(jsonArray: JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (i in 0 until jsonArray.length()) {
            when (val value = jsonArray.get(i)) {
                is JSONObject -> list.add(parseJsonObjectToMap(value))
                is JSONArray -> list.add(parseJsonArrayToList(value))
                else -> list.add(value)
            }
        }
        return list
    }

    private fun extractLayoutProps(props: Map<String, Any>): Map<String, Any> {
        val supportedLayoutProps = setOf(
            "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
            "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
            "marginHorizontal", "marginVertical",
            "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
            "paddingHorizontal", "paddingVertical",
            "left", "top", "right", "bottom", "position",
            "translateX", "translateY",
            "rotateInDegrees",
            "scale", "scaleX", "scaleY",
            "flexDirection", "justifyContent", "alignItems", "alignSelf", "alignContent",
            "flexWrap", "flex", "flexGrow", "flexShrink", "flexBasis",
            "display", "overflow", "direction", "borderWidth",
            "aspectRatio", "gap", "rowGap", "columnGap"
        )
        
        return props.filter { supportedLayoutProps.contains(it.key) }
    }
}

