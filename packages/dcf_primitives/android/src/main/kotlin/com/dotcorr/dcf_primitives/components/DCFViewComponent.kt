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

        // Store component type for identification
        view.setTag(R.id.dcf_component_type, "View")

        // ANDROID FLASH FIX: Start invisible to prevent flash screen
        view.visibility = View.INVISIBLE
        view.alpha = 0f

        // Apply adaptive default styling - let OS handle light/dark mode
        val isAdaptive = props["adaptive"] as? Boolean ?: true
        if (isAdaptive) {
            // Use system colors that automatically adapt to light/dark mode
            try {
                val typedValue = android.util.TypedValue()
                if (context.theme.resolveAttribute(android.R.attr.colorBackground, typedValue, true)) {
                    view.setBackgroundColor(typedValue.data)
                } else {
                    // Fallback based on current theme detection
                    val isDarkTheme = (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
                    view.setBackgroundColor(if (isDarkTheme) android.graphics.Color.BLACK else android.graphics.Color.WHITE)
                }
            } catch (e: Exception) {
                view.setBackgroundColor(android.graphics.Color.WHITE)
            }
        } else {
            view.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }

        // Apply props - convert nullable to non-nullable
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        updateViewInternal(view, nonNullProps)

        // Apply StyleSheet properties
        view.applyStyles(nonNullProps)

        Log.d(TAG, "Created view component with adaptive: $isAdaptive")

        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        Log.d(TAG, "Updating view component with props: $props")

        // Apply StyleSheet properties - the extension handles everything like iOS
        view.applyStyles(props)
        
        return true
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        // Views are containers and typically don't have intrinsic size
        // They rely on their children and layout constraints
        return PointF(0f, 0f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // View components can be containers, so they might need layout management
        Log.d(TAG, "View component registered with shadow tree: $nodeId")
    }
}

