/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.view.View
import android.widget.ScrollView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFScrollViewComponent - 1:1 mapping with iOS DCFScrollViewComponent
 * Uses exact same prop names as iOS UIScrollView for cross-platform consistency
 */
class DCFScrollViewComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val scrollView = ScrollView(context)
        
        // Set component identifier for debugging
        scrollView.setTag(R.id.dcf_component_type, "ScrollView")
        
        // Apply initial props and return
        updateView(scrollView, props)
        return scrollView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val scrollView = view as ScrollView
        var hasUpdates = false

        // 🚀 MATCH iOS UIScrollView props exactly
        props["showsVerticalScrollIndicator"]?.let {
            val showScrollbar = when (it) {
                is Boolean -> it
                is String -> it.toBooleanStrictOrNull() ?: true
                else -> true
            }
            scrollView.isVerticalScrollBarEnabled = showScrollbar
            hasUpdates = true
        }

        props["showsHorizontalScrollIndicator"]?.let {
            val showScrollbar = when (it) {
                is Boolean -> it
                is String -> it.toBooleanStrictOrNull() ?: true
                else -> true
            }
            scrollView.isHorizontalScrollBarEnabled = showScrollbar
            hasUpdates = true
        }

        props["scrollEnabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBooleanStrictOrNull() ?: true
                else -> true
            }
            scrollView.isEnabled = enabled
            hasUpdates = true
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val scrollView = view as? ScrollView ?: return PointF(0f, 0f)

        // Measure the scroll view content
        scrollView.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = scrollView.measuredWidth.toFloat()
        val measuredHeight = scrollView.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // ScrollView components may contain children and need shadow tree handling
    }
}
