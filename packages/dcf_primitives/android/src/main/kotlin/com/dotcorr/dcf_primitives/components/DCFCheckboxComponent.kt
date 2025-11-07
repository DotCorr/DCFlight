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
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // StyleSheet.toMap() always provides these colors, so they should never be null
        // But we use TRANSPARENT as safe fallback for type safety
        val activeColor = props["primaryColor"]?.let { ColorUtilities.parseColor(it.toString()) } ?: Color.TRANSPARENT
        val inactiveColor = props["secondaryColor"]?.let { ColorUtilities.parseColor(it.toString()) } ?: Color.TRANSPARENT
        val checkmarkColor = props["tertiaryColor"]?.let { ColorUtilities.parseColor(it.toString()) } 
            ?: Color.WHITE
        
        val states = arrayOf(
            intArrayOf(android.R.attr.state_checked),
            intArrayOf(-android.R.attr.state_checked)
        )
        checkBox.buttonTintList = ColorStateList(states, intArrayOf(activeColor, inactiveColor))
        checkBox.setTextColor(checkmarkColor)
        
        checkBox.setTag(R.id.dcf_component_type, "Checkbox")
        
        updateView(checkBox, props)
        
        checkBox.setOnCheckedChangeListener { _, isChecked ->
            propagateEvent(checkBox, "onValueChange", mapOf(
                "value" to isChecked,
                "checked" to isChecked
            ))
        }
        
        return checkBox
    }

    // Remove override - let base class handle props merging

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val checkBox = view as CheckBox
        var hasUpdates = false

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

        view.applyStyles(props)

        return hasUpdates
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): android.graphics.PointF {
        val checkBox = view as? CheckBox ?: return android.graphics.PointF(0f, 0f)

        checkBox.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = checkBox.measuredWidth.toFloat()
        val measuredHeight = checkBox.measuredHeight.toFloat()

        return android.graphics.PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }
}

