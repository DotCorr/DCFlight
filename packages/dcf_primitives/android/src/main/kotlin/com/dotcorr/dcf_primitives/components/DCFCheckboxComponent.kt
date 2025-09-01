/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.content.res.ColorStateList
import android.view.View
import android.widget.CheckBox
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFCheckboxComponent - 1:1 mapping with iOS DCFCheckboxComponent
 * ONLY implements props that iOS DCFCheckboxComponent has:
 * - checked: Boolean
 * - disabled: Boolean
 */
class DCFCheckboxComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val checkBox = CheckBox(context)
        
        // Set component identifier for debugging
        checkBox.setTag(R.id.dcf_component_type, "Checkbox")
        
        // Apply initial props
        updateView(checkBox, props)
        
        // Set up iOS-style onValueChange event
        checkBox.setOnCheckedChangeListener { _, isChecked ->
            // 🚀 MATCH iOS: Use propagateEvent for onValueChange
            propagateEvent(checkBox, "onValueChange", mapOf(
                "value" to isChecked,
                "checked" to isChecked
            ))
        }
        
        return checkBox
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val checkBox = view as CheckBox
        var hasUpdates = false

        // 🚀 MATCH iOS: "checked" prop (iOS uses "checked", not "value")
        props["checked"]?.let {
            val checked = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            if (checkBox.isChecked != checked) {
                checkBox.isChecked = checked
                hasUpdates = true
            }
        }

        // disabled prop
        props["disabled"]?.let {
            val disabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            if (checkBox.isEnabled == disabled) {
                checkBox.isEnabled = !disabled
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }
}
