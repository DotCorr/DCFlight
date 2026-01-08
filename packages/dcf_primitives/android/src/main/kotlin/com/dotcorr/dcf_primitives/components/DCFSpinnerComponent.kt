/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.PointF
import android.view.View
import android.widget.ProgressBar
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

class DCFSpinnerComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val progressBar = ProgressBar(context)

        progressBar.isIndeterminate = true

        ColorUtilities.getColor("spinnerColor", "primaryColor", props)?.let { colorInt ->
            progressBar.indeterminateTintList = ColorStateList.valueOf(colorInt)
        }

        progressBar.setTag(DCFTags.COMPONENT_TYPE_KEY, "Spinner")

        updateView(progressBar, props)
        return progressBar
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val progressBar = view as? ProgressBar ?: return false
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

        val isAnimating = mergedProps["animating"] as? Boolean ?: true
        val hidesWhenStopped = mergedProps["hidesWhenStopped"] as? Boolean ?: true

        if (hidesWhenStopped) {
            progressBar.visibility = if (isAnimating) View.VISIBLE else View.GONE
        } else {
            progressBar.visibility = View.VISIBLE
        }

        ColorUtilities.getColor("spinnerColor", "primaryColor", nonNullProps)?.let { colorInt ->
            progressBar.indeterminateTintList = ColorStateList.valueOf(colorInt)
        }

        mergedProps["size"]?.let { size ->
            when (size) {
                "small", "medium" -> {
                    progressBar.scaleX = 0.7f
                    progressBar.scaleY = 0.7f
                }
                "large" -> {
                    progressBar.scaleX = 1.2f
                    progressBar.scaleY = 1.2f
                }
                else -> {
                    progressBar.scaleX = 1.0f
                    progressBar.scaleY = 1.0f
                }
            }
        }

        view.applyStyles(nonNullProps)
        return true
    }


    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

