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
import android.view.View
import android.widget.ProgressBar
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFSpinnerComponent - Activity indicator matching iOS DCFSpinnerComponent
 * Uses exact same prop names as iOS UIActivityIndicatorView for cross-platform consistency
 */
class DCFSpinnerComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val progressBar = ProgressBar(context)

        // Set indeterminate mode (spinning)
        progressBar.isIndeterminate = true

        // Store component type
        progressBar.setTag(R.id.dcf_component_type, "Spinner")

        // Apply props
        updateView(progressBar, props)

        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        progressBar.applyStyles(nonNullStyleProps)

        return progressBar
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val progressBar = view as? ProgressBar ?: return false

        // animating - EXACT iOS prop name
        val isAnimating = props["animating"] as? Boolean ?: true

        // hidesWhenStopped - EXACT iOS prop name
        val hidesWhenStopped = props["hidesWhenStopped"] as? Boolean ?: true

        // Update visibility based on animating state
        if (hidesWhenStopped) {
            progressBar.visibility = if (isAnimating) View.VISIBLE else View.GONE
        } else {
            progressBar.visibility = View.VISIBLE
            // Can't actually stop the animation on Android ProgressBar
            // but we respect the visibility behavior
        }

        // Store animating state
        progressBar.setTag(R.id.dcf_spinner_animating, isAnimating)

        // size - EXACT iOS prop name (matching UIActivityIndicatorView.Style)
        props["size"]?.let { size ->
            when (size) {
                "small", "medium" -> {
                    // Small/medium size
                    progressBar.scaleX = 0.7f
                    progressBar.scaleY = 0.7f
                }

                "large" -> {
                    // Large size
                    progressBar.scaleX = 1.2f
                    progressBar.scaleY = 1.2f
                }

                "whiteLarge" -> {
                    // iOS legacy whiteLarge style
                    progressBar.scaleX = 1.2f
                    progressBar.scaleY = 1.2f
                    // Also set color to white
                    progressBar.indeterminateTintList = ColorStateList.valueOf(Color.WHITE)
                }

                "white" -> {
                    // iOS legacy white style
                    progressBar.scaleX = 1.0f
                    progressBar.scaleY = 1.0f
                    progressBar.indeterminateTintList = ColorStateList.valueOf(Color.WHITE)
                }

                "gray" -> {
                    // iOS legacy gray style
                    progressBar.scaleX = 1.0f
                    progressBar.scaleY = 1.0f
                    progressBar.indeterminateTintList = ColorStateList.valueOf(Color.GRAY)
                }

                else -> {
                    // Default size
                    progressBar.scaleX = 1.0f
                    progressBar.scaleY = 1.0f
                }
            }
        }

        // color - EXACT iOS prop name
        props["color"]?.let { color ->
            val colorInt = parseColor(color as String)
            progressBar.indeterminateTintList = ColorStateList.valueOf(colorInt)
        }

        // style - EXACT iOS prop name (alternative to size)
        props["style"]?.let { style ->
            when (style) {
                "small" -> {
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

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            progressBar.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            progressBar.setTag(R.id.dcf_test_id, testId)
        }

        return true
    }
}
