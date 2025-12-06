/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.graphics.Rect
import android.util.Log
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.layout.DCFTextShadowNode
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcflight.layout.YogaShadowTree

class DCFTextComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFTextComponent"
        private val fontCache = mutableMapOf<String, android.graphics.Typeface>()
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val textView = DCFTextView(context)
        
        storeProps(textView, props)
        
        updateView(textView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        textView.applyStyles(nonNullProps)
        
        return textView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val textView = view as? DCFTextView ?: return false
        
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(textView, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        textView.applyStyles(nonNullProps)
        
        return true
    }
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        val frame = Rect(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        view.layout(frame.left, frame.top, frame.right, frame.bottom)
        
        val textView = view as? DCFTextView ?: return
        
        val viewId = getViewId(view) ?: return
        val shadowNode = YogaShadowTree.shared.getShadowNode(viewId) as? DCFTextShadowNode ?: return
        
        Log.d(TAG, "🔍 DCFTextComponent.applyLayout: viewId=$viewId, frame=$frame")
        Log.d(TAG, "   computedTextLayout=${shadowNode.computedTextLayout != null}, computedTextFrame=${shadowNode.computedTextFrame}, computedContentInset=${shadowNode.computedContentInset}")
        
        textView.textLayout = shadowNode.computedTextLayout
        textView.textFrame = shadowNode.computedTextFrame
        textView.contentInset = shadowNode.computedContentInset
        
        Log.d(TAG, "   ✅ Set textLayout on view: ${textView.textLayout != null}, textFrame=${textView.textFrame}, contentInset=${textView.contentInset}")
        
        view.post {
            view.invalidate()
            Log.d(TAG, "   ✅ Invalidated view for redraw")
        }
    }
    
    private fun getViewId(view: View): Int? {
        for (viewId in ViewRegistry.shared.allViewIds) {
            val viewInfo = ViewRegistry.shared.getViewInfo(viewId)
            if (viewInfo?.view === view) {
                return viewId
            }
        }
        return null
    }
    
    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        val nodeIdKey = "nodeId".hashCode()
        view.setTag(nodeIdKey, nodeId)
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}
