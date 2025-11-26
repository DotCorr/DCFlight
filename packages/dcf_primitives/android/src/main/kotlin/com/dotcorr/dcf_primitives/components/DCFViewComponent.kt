/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.util.Log
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFFrameLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.utils.DCFViewportObserver
import com.dotcorr.dcf_primitives.utils.ViewportConfig

class DCFViewComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFViewComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val view = DCFFrameLayout(context)

        view.setTag(DCFTags.COMPONENT_TYPE_KEY, "View")

        updateView(view, props)

        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        // Handle viewport detection (low-level API - any view can use it)
        val hasViewportCallbacks = mergedProps.containsKey("onViewportEnter") || mergedProps.containsKey("onViewportLeave")
        if (hasViewportCallbacks) {
            val viewportData = mergedProps["viewport"] as? Map<*, *>
            val config = ViewportConfig(
                once = (viewportData?.get("once") as? Boolean) ?: false,
                amount = (viewportData?.get("amount") as? Number)?.toDouble()
            )
            DCFViewportObserver.observe(view, config)
        } else {
            DCFViewportObserver.unobserve(view)
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        view.applyStyles(nonNullProps)
        return true
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "View component registered with shadow tree: $nodeId")
        
        // Setup viewport detection if callbacks are registered
        val props = getStoredProps(view)
        val hasViewportCallbacks = props.containsKey("onViewportEnter") || props.containsKey("onViewportLeave")
        if (hasViewportCallbacks) {
            val viewportData = props["viewport"] as? Map<*, *>
            val config = ViewportConfig(
                once = (viewportData?.get("once") as? Boolean) ?: false,
                amount = (viewportData?.get("amount") as? Number)?.toDouble()
            )
            // Delay observation until view is laid out
            view.post {
                DCFViewportObserver.observe(view, config)
            }
        }
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

