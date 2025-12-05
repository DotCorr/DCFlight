/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.extensions.applyStyles

/**
 * DCFScrollViewComponent - Component manager
 * Manages creation and updates of DCFScrollView instances
 */
class DCFScrollViewComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFScrollViewComponent"
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val scrollView = DCFScrollView(context)
        
        // Don't create contentView here
        // Wait for ScrollContentView component to be attached via attachView
        // This prevents the assertion error when insertContentView is called twice
        
        // Basic setup
        scrollView.setShowsVerticalScrollIndicator(true)
        scrollView.setShowsHorizontalScrollIndicator(true)
        scrollView.setBounces(true)
        scrollView.setScrollEnabled(true)
        scrollView.setAlwaysBounceVertical(true)
        scrollView.setAlwaysBounceHorizontal(false)
        
        updateView(scrollView, props)
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        scrollView.applyStyles(nonNullProps)
        
        return scrollView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val scrollView = view as? DCFScrollView ?: return false
        
        // Scroll indicators
        (props["showsScrollIndicator"] as? Boolean)?.let { showsScrollIndicator ->
            scrollView.setShowsVerticalScrollIndicator(showsScrollIndicator)
            scrollView.setShowsHorizontalScrollIndicator(showsScrollIndicator)
        }
        
        // Bounces
        (props["bounces"] as? Boolean)?.let { bounces ->
            scrollView.setBounces(bounces)
        }
        
        // Horizontal scrolling
        (props["horizontal"] as? Boolean)?.let { horizontal ->
            if (horizontal) {
                scrollView.setAlwaysBounceHorizontal(true)
                scrollView.setAlwaysBounceVertical(false)
                scrollView.setShowsHorizontalScrollIndicator(scrollView.scrollView.isVerticalScrollBarEnabled)
                scrollView.setShowsVerticalScrollIndicator(false)
            } else {
                scrollView.setAlwaysBounceHorizontal(false)
                scrollView.setAlwaysBounceVertical(true)
                scrollView.setShowsVerticalScrollIndicator(false)
            }
        }
        
        // Paging
        (props["pagingEnabled"] as? Boolean)?.let { pagingEnabled ->
            val contentOffset = PointF(scrollView.scrollView.scrollX.toFloat(), scrollView.scrollView.scrollY.toFloat())
            // Android doesn't have isPagingEnabled, handled via custom logic if needed
            scrollView.scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
        }
        
        // Scroll enabled
        (props["scrollEnabled"] as? Boolean)?.let { scrollEnabled ->
            scrollView.setScrollEnabled(scrollEnabled)
        }
        
        // Content insets
        (props["contentInset"] as? Map<*, *>)?.let { contentInset ->
            val top = (contentInset["top"] as? Number)?.toFloat()?.toInt() ?: 0
            val left = (contentInset["left"] as? Number)?.toFloat()?.toInt() ?: 0
            val bottom = (contentInset["bottom"] as? Number)?.toFloat()?.toInt() ?: 0
            val right = (contentInset["right"] as? Number)?.toFloat()?.toInt() ?: 0
            scrollView.contentInset = android.graphics.Rect(left, top, right, bottom)
        }
        
        // Center content
        (props["centerContent"] as? Boolean)?.let { centerContent ->
            scrollView.centerContent = centerContent
        }
        
        // Scroll event throttle
        (props["scrollEventThrottle"] as? Number)?.toDouble()?.let { throttle ->
            scrollView.scrollEventThrottle = throttle.toLong()
        }
        
        // Handle commands
        handleCommand(scrollView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        scrollView.applyStyles(nonNullProps)
        return true
    }
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        val scrollView = view as? DCFScrollView ?: return
        
        // Apply layout to scroll view
        scrollView.layout(
            layout.left.toInt(),
            layout.top.toInt(),
            (layout.left + layout.width).toInt(),
            (layout.top + layout.height).toInt()
        )
        
        // CRITICAL: Don't update contentSize here because ScrollContentView's layout hasn't been applied yet
        // Layouts are applied parent-first, so ScrollView's layout is applied before ScrollContentView's layout
        // ScrollContentViewComponent.applyLayout will trigger updateContentSizeFromContentView after it sets its frame
        // This ensures we read the correct frame size
        Log.d(TAG, "🔍 DCFScrollViewComponent.applyLayout: Applied frame=(${scrollView.left}, ${scrollView.top}, ${scrollView.width}, ${scrollView.height}), deferring contentSize update until ScrollContentView layout is applied")
    }
    
    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        val scrollView = view as? DCFScrollView ?: return
        
        view.setTag("nodeId".hashCode(), nodeId)
        
        Handler(Looper.getMainLooper()).post {
            scrollView.updateContentSizeFromContentView()
        }
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    /// Handle commands
    private fun handleCommand(scrollView: DCFScrollView, props: Map<String, Any?>) {
        val commandData = props["command"] as? Map<*, *> ?: return
        
        (commandData["scrollToPosition"] as? Map<*, *>)?.let { scrollToPositionData ->
            val x = (scrollToPositionData["x"] as? Number)?.toDouble()
            val y = (scrollToPositionData["y"] as? Number)?.toDouble()
            if (x != null && y != null) {
                val animated = (scrollToPositionData["animated"] as? Boolean) ?: true
                scrollView.scrollToOffset(PointF(x.toFloat(), y.toFloat()), animated)
            }
        }
        
        (commandData["scrollToTop"] as? Map<*, *>)?.let { scrollToTopData ->
            val animated = (scrollToTopData["animated"] as? Boolean) ?: true
            scrollView.scrollToOffset(PointF(scrollView.scrollView.scrollX.toFloat(), 0f), animated)
        }
        
        (commandData["scrollToBottom"] as? Map<*, *>)?.let { scrollToBottomData ->
            val animated = (scrollToBottomData["animated"] as? Boolean) ?: true
            scrollView.scrollToEnd(animated)
        }
        
        (commandData["flashScrollIndicators"] as? Boolean)?.let { flashScrollIndicators ->
            if (flashScrollIndicators) {
                // Android doesn't have flashScrollIndicators, handled via custom logic if needed
            }
        }
    }
}

