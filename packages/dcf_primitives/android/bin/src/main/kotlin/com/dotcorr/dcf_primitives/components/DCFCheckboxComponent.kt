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
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities

class DCFCheckboxComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val checkBox = CheckBox(context)
        
        val activeColor = ColorUtilities.getColor("checkedColor", "primaryColor", props)
            ?: props["primaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        val inactiveColor = ColorUtilities.getColor("uncheckedColor", "secondaryColor", props)
            ?: props["secondaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        val checkmarkColor = ColorUtilities.getColor("checkmarkColor", "primaryColor", props)
            ?: props["tertiaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        
        if (activeColor != null && inactiveColor != null) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf(-android.R.attr.state_checked)
            )
            checkBox.buttonTintList = ColorStateList(states, intArrayOf(activeColor, inactiveColor))
        }
        
        if (checkmarkColor != null) {
            checkBox.setTextColor(checkmarkColor)
        }
        
        checkBox.setTag(DCFTags.COMPONENT_TYPE_KEY, "Checkbox")
        
        updateView(checkBox, props)
        
        checkBox.setOnCheckedChangeListener { _, isChecked ->
            propagateEvent(checkBox, "onValueChange", mapOf(
                "value" to isChecked,
                "checked" to isChecked
            ))
        }
        
        return checkBox
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val checkBox = view as CheckBox
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

        mergedProps["checked"]?.let {
            val checked = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            checkBox.isChecked = checked
        }

        mergedProps["disabled"]?.let {
            val disabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            checkBox.isEnabled = !disabled
        }

        val activeColor = ColorUtilities.getColor("checkedColor", "primaryColor", nonNullProps)
            ?: nonNullProps["primaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        val inactiveColor = ColorUtilities.getColor("uncheckedColor", "secondaryColor", nonNullProps)
            ?: nonNullProps["secondaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        val checkmarkColor = ColorUtilities.getColor("checkmarkColor", "primaryColor", nonNullProps)
            ?: nonNullProps["tertiaryColor"]?.let { ColorUtilities.parseColor(it.toString()) }
        
        if (activeColor != null && inactiveColor != null) {
            val states = arrayOf(
                intArrayOf(android.R.attr.state_checked),
                intArrayOf(-android.R.attr.state_checked)
            )
            checkBox.buttonTintList = ColorStateList(states, intArrayOf(activeColor, inactiveColor))
        }
        
        checkmarkColor?.let {
            checkBox.setTextColor(it)
        }

        view.applyStyles(nonNullProps)
        return true
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

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

