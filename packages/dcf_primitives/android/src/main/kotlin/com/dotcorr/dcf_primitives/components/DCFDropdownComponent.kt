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
import android.widget.TextView
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFDropdownComponent - 1:1 mapping with iOS DCFDropdownComponent
 * Provides dropdown selection like iOS UIPickerView
 */
class DCFDropdownComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val spinner = Spinner(context)
        
        spinner.setTag(R.id.dcf_component_type, "Dropdown")
        
        spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedItem = parent?.getItemAtPosition(position)
                
                propagateEvent(spinner, "onValueChange", mapOf(
                    "selectedIndex" to position,
                    "selectedValue" to (selectedItem?.toString() ?: ""),
                    "selectedItem" to selectedItem
                ))
            }
            
            override fun onNothingSelected(parent: AdapterView<*>?) {
                propagateEvent(spinner, "onValueChange", mapOf(
                    "selectedIndex" to -1,
                    "selectedValue" to "",
                    "selectedItem" to null
                ))
            }
        }
        
        updateView(spinner, props)
        return spinner
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val spinner = view as Spinner
        var hasUpdates = false

        if (hasPropChanged("items", existingProps, props)) {
            props["items"]?.let { items ->
            when (items) {
                is List<*> -> {
                    val itemStrings = items.mapNotNull { item ->
                        when (item) {
                            is Map<*, *> -> {
                                (item["label"] as? String) ?: (item["title"] as? String) ?: ""
                            }
                            is String -> item
                            else -> item?.toString() ?: ""
                        }
                    }
                    val adapter = ArrayAdapter(
                        spinner.context,
                        android.R.layout.simple_spinner_item,
                        itemStrings
                    )
                    adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                    spinner.adapter = adapter
                    
                    applyPlaceholderColor(spinner, props)
                    
                    hasUpdates = true
                }
            }
        }
        }
        
        if (hasPropChanged("placeholderColor", existingProps, props) || hasPropChanged("secondaryColor", existingProps, props)) {
            applyPlaceholderColor(spinner, props)
            hasUpdates = true
        }

        if (hasPropChanged("selectedIndex", existingProps, props)) {
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
        }

        if (hasPropChanged("enabled", existingProps, props)) {
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
        }

        view.applyStyles(props)

        return hasUpdates
    }
    
    private fun applyPlaceholderColor(spinner: Spinner, props: Map<String, Any>) {
        ColorUtilities.getColor("placeholderColor", "secondaryColor", props)?.let { colorInt ->
            spinner.post {
                val selectedView = spinner.selectedView as? TextView
                selectedView?.setTextColor(colorInt)
            }
        }
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val spinner = view as? Spinner ?: return PointF(0f, 0f)

        spinner.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = spinner.measuredWidth.toFloat()
        val measuredHeight = spinner.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

