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
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * EXACT iOS DCFViewComponent port for Android
 * Matches iOS DCFViewComponent.swift behavior 1:1
 * Acts as a container view similar to UIView in iOS
 */
class DCFViewComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFViewComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val view = DCFFrameLayout(context)

        view.setTag(R.id.dcf_component_type, "View")

        // Use updateView (not updateViewInternal) to ensure props are stored for merging
        updateView(view, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        view.applyStyles(nonNullProps)

        return view
    }

    // Remove override - let base class handle props merging

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        Log.d(TAG, "Updating view component with props: $props")

        view.applyStyles(props)
        
        return true
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "View component registered with shadow tree: $nodeId")
    }
}

