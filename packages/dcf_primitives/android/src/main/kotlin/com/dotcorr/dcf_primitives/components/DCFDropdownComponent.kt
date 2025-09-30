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
import android.widget.ArrayAdapter
import android.widget.Spinner
import android.widget.AdapterView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcflight.utils.AdaptiveColorHelper

/**
 * DCFDropdownComponent - 1:1 mapping with iOS DCFDropdownComponent
 * Provides dropdown selection like iOS UIPickerView
 */
class DCFDropdownComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val spinner = Spinner(context)
        
        // Set component identifier
        spinner.setTag(R.id.dcf_component_type, "Dropdown")
        
        // Set up selection listener for events
        spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedItem = parent?.getItemAtPosition(position)
                
                // 🚀 MATCH iOS: Use propagateEvent for onValueChange
                propagateEvent(spinner, "onValueChange", mapOf(
                    "selectedIndex" to position,
                    "selectedValue" to (selectedItem?.toString() ?: ""),
                    "selectedItem" to selectedItem
                ))
            }
            
            override fun onNothingSelected(parent: AdapterView<*>?) {
                // 🚀 MATCH iOS: Use propagateEvent for onValueChange
                propagateEvent(spinner, "onValueChange", mapOf(
                    "selectedIndex" to -1,
                    "selectedValue" to "",
                    "selectedItem" to null
                ))
            }
        }
        
        // Apply initial props
        updateView(spinner, props)
        return spinner
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        val spinner = view as Spinner
        var hasUpdates = false

        // items prop - array of options
        props["items"]?.let { items ->
            when (items) {
                is List<*> -> {
                    val itemStrings = items.map { it?.toString() ?: "" }
                    val adapter = ArrayAdapter(
                        spinner.context,
                        android.R.layout.simple_spinner_item,
                        itemStrings
                    )
                    adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                    spinner.adapter = adapter
                    hasUpdates = true
                }
            }
        }

        // selectedIndex prop
        props["selectedIndex"]?.let {
            val index = when (it) {
                is Number -> it.toInt()
                is String -> it.toIntOrNull() ?: 0
                else -> 0
            }
            if (spinner.selectedItemPosition != index) {
                spinner.setSelection(index)
                hasUpdates = true
            }
        }

        // enabled prop
        props["enabled"]?.let {
            val enabled = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> true
            }
            if (spinner.isEnabled != enabled) {
                spinner.isEnabled = enabled
                hasUpdates = true
            }
        }

        // adaptive prop - matches iOS adaptivity
        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                // Apply adaptive background color
                spinner.setBackgroundColor(AdaptiveColorHelper.getSystemBackgroundColor(spinner.context))
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val spinner = view as? Spinner ?: return PointF(0f, 0f)

        // Measure the spinner content
        spinner.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = spinner.measuredWidth.toFloat()
        val measuredHeight = spinner.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Dropdown components are typically leaf nodes and don't need special handling
    }
}

