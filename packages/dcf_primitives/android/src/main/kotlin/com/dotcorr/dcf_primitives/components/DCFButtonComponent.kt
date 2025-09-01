/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.view.View
import androidx.appcompat.widget.AppCompatButton
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFButtonComponent - 1:1 mapping with iOS DCFButtonComponent
 * ONLY implements props that iOS DCFButtonComponent has:
 * - title: String
 * - disabled: Boolean
 * ALL styling handled by StyleSheet via .applyStyles() like iOS
 */
class DCFButtonComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val button = AppCompatButton(context)

        // iOS-style button defaults
        button.isAllCaps = false
        
        // Set iOS system colors as defaults
        ColorUtilities.color("#007AFF")?.let { button.setBackgroundColor(it) }
        ColorUtilities.color("#FFFFFF")?.let { button.setTextColor(it) }

        // Apply props
        updateView(button, props)

        // Apply StyleSheet properties (UNIFIED with iOS)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        button.applyStyles(nonNullStyleProps)

        // Store component type
        button.setTag(R.id.dcf_component_type, "Button")

        return button
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val button = view as? AppCompatButton ?: return false

        // 1:1 MATCH iOS DCFButtonComponent props:
        
        // "title" prop - matches iOS exactly
        props["title"]?.let { title ->
            button.text = when (title) {
                is String -> title
                else -> title.toString()
            }
        }

        // "disabled" prop - matches iOS exactly  
        props["disabled"]?.let { disabled ->
            when (disabled) {
                is Boolean -> {
                    button.isEnabled = !disabled
                    button.alpha = if (disabled) 0.5f else 1.0f
                }
            }
        }

        return true
    }
}
