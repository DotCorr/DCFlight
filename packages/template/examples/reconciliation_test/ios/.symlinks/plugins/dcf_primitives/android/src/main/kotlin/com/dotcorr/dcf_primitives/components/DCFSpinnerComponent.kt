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
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFSpinnerComponent - Activity indicator matching iOS DCFSpinnerComponent
 * Uses exact same prop names as iOS UIActivityIndicatorView for cross-platform consistency
 */
class DCFSpinnerComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val progressBar = ProgressBar(context)

        progressBar.isIndeterminate = true

        ColorUtilities.getColor("spinnerColor", "primaryColor", props)?.let { colorInt ->
            progressBar.indeterminateTintList = ColorStateList.valueOf(colorInt)
        }

        progressBar.setTag(R.id.dcf_component_type, "Spinner")

        updateView(progressBar, props)
        return progressBar
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val progressBar = view as? ProgressBar ?: return false
        var hasUpdates = false

        if (hasPropChanged("animating", existingProps, props) || hasPropChanged("hidesWhenStopped", existingProps, props)) {
            val isAnimating = props["animating"] as? Boolean ?: true
            val hidesWhenStopped = props["hidesWhenStopped"] as? Boolean ?: true

            if (hidesWhenStopped) {
                progressBar.visibility = if (isAnimating) View.VISIBLE else View.GONE
            } else {
                progressBar.visibility = View.VISIBLE
            }
            hasUpdates = true
        }

        if (hasPropChanged("spinnerColor", existingProps, props) || hasPropChanged("primaryColor", existingProps, props)) {
            ColorUtilities.getColor("spinnerColor", "primaryColor", props)?.let { colorInt ->
                progressBar.indeterminateTintList = ColorStateList.valueOf(colorInt)
                hasUpdates = true
            }
        }

        if (hasPropChanged("size", existingProps, props)) {
            props["size"]?.let { size ->
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
                hasUpdates = true
            }
        }

        view.applyStyles(props)

        return hasUpdates
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val progressBar = view as? ProgressBar ?: return PointF(0f, 0f)

        progressBar.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = progressBar.measuredWidth.toFloat()
        val measuredHeight = progressBar.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

