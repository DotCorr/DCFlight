/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.graphics.PointF
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFSegmentedControlComponent - View-based segmented control using LinearLayout and Buttons
 * Provides native Android segmented control similar to iOS UISegmentedControl
 */
class DCFSegmentedControlComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFSegmentedControlComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val container = LinearLayout(context)
        container.orientation = LinearLayout.HORIZONTAL
        container.setTag(R.id.dcf_component_type, "SegmentedControl")
        
        // Store props
        storeProps(container, props)
        
        // Parse segments
        val segments = parseSegments(props)
        val selectedIndex = getSelectedIndex(props, segments.size)
        
        // Create buttons for each segment
        segments.forEachIndexed { index, segmentTitle ->
            val button = createSegmentButton(context, segmentTitle, index == selectedIndex, index, segments.size)
            // Set up click listener immediately
            button.setOnClickListener {
                val currentSegments = parseSegments(getStoredProps(container))
                val title = currentSegments.getOrNull(index) ?: ""
                
                // Immediately update visual state for better UX
                updateSelectedButton(container, index)
                
                // Propagate event to Dart side
                propagateEvent(container, "onSelectionChange", mapOf(
                    "selectedIndex" to index,
                    "selectedTitle" to title
                ))
            }
            container.addView(button)
        }
        
        // Apply framework-level styles
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        container.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created View-based SegmentedControl with ${segments.size} segments")
        
        return container
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val container = view as? LinearLayout ?: return false
        var hasUpdates = false
        
        // Update if segments changed
        if (hasPropChanged("segments", existingProps, props)) {
            val segments = parseSegments(props)
            val selectedIndex = getSelectedIndex(props, segments.size)
            
            container.removeAllViews()
            segments.forEachIndexed { index, segmentTitle ->
                val button = createSegmentButton(container.context, segmentTitle, index == selectedIndex, index, segments.size)
                // Set up click listener
                button.setOnClickListener {
                    val currentSegments = parseSegments(getStoredProps(container))
                    val title = currentSegments.getOrNull(index) ?: ""
                    
                    // Immediately update visual state
                    updateSelectedButton(container, index)
                    
                    // Propagate event to Dart side
                    propagateEvent(container, "onSelectionChange", mapOf(
                        "selectedIndex" to index,
                        "selectedTitle" to title
                    ))
                }
                container.addView(button)
            }
            hasUpdates = true
        }
        
        // Update selected index
        if (hasPropChanged("selectedIndex", existingProps, props)) {
            val selectedIndex = getSelectedIndex(props, container.childCount)
            updateSelectedButton(container, selectedIndex)
            hasUpdates = true
        }
        
        // Update colors if changed
        if (hasPropChanged("primaryColor", existingProps, props) ||
            hasPropChanged("secondaryColor", existingProps, props) ||
            hasPropChanged("tertiaryColor", existingProps, props) ||
            hasPropChanged("accentColor", existingProps, props)) {
            val selectedIndex = getSelectedIndex(props, container.childCount)
            updateButtonColors(container, selectedIndex, props)
            hasUpdates = true
        }
        
        // Update enabled state
        if (hasPropChanged("enabled", existingProps, props)) {
            val enabled = when (val en = props["enabled"]) {
                is Boolean -> en
                is String -> en.toBoolean()
                else -> true
            }
            for (i in 0 until container.childCount) {
                container.getChildAt(i).isEnabled = enabled
            }
            hasUpdates = true
        }
        
        // Apply framework-level styles
        container.applyStyles(props)
        
        return hasUpdates
    }
    
    private fun parseSegments(props: Map<String, Any?>): List<String> {
        return when (val segmentsProp = props["segments"]) {
            is List<*> -> segmentsProp.mapNotNull { segment ->
                when (segment) {
                    is Map<*, *> -> {
                        val segmentMap = segment as Map<String, Any?>
                        segmentMap["title"]?.toString() ?: ""
                    }
                    is String -> segment
                    else -> null
                }
            }.filter { it.isNotEmpty() }
            else -> listOf("Segment 1")
        }
    }
    
    private fun getSelectedIndex(props: Map<String, Any?>, maxIndex: Int): Int {
        return when (val idx = props["selectedIndex"]) {
            is Number -> idx.toInt().coerceIn(0, maxIndex - 1)
            is String -> idx.toIntOrNull()?.coerceIn(0, maxIndex - 1) ?: 0
            else -> 0
        }
    }
    
    private fun createSegmentButton(
        context: Context,
        title: String,
        isSelected: Boolean,
        index: Int,
        totalCount: Int
    ): Button {
        val button = Button(context)
        button.text = title
        button.gravity = Gravity.CENTER
        button.textSize = 14f
        
        // Disable all caps to prevent text clipping
        button.setAllCaps(false)
        
        // Set padding to prevent text clipping - more horizontal padding for text
        val horizontalPadding = (20 * context.resources.displayMetrics.density).toInt()
        val verticalPadding = (14 * context.resources.displayMetrics.density).toInt()
        button.setPadding(horizontalPadding, verticalPadding, horizontalPadding, verticalPadding)
        
        // Set minimum height - taller to prevent clipping
        val minHeight = (56 * context.resources.displayMetrics.density).toInt()
        button.minHeight = minHeight
        
        // Remove default button insets that cause clipping
        button.setIncludeFontPadding(false)
        
        // Ensure text is single line and ellipsize if needed
        button.maxLines = 1
        button.ellipsize = TextUtils.TruncateAt.END
        
        val layoutParams = LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            1.0f
        )
        
        // Add negative margins to connect buttons
        if (index > 0) {
            layoutParams.marginStart = (-1 * context.resources.displayMetrics.density).toInt()
        }
        
        button.layoutParams = layoutParams
        
        // Set initial background
        updateButtonBackground(button, isSelected, index, totalCount)
        
        return button
    }
    
    private fun updateButtonBackground(button: Button, isSelected: Boolean, index: Int, totalCount: Int) {
        val drawable = GradientDrawable()
        
        // Set corner radius based on position
        val cornerRadius = 8f * button.context.resources.displayMetrics.density
        when {
            index == 0 && totalCount == 1 -> {
                drawable.cornerRadii = floatArrayOf(cornerRadius, cornerRadius, cornerRadius, cornerRadius, cornerRadius, cornerRadius, cornerRadius, cornerRadius)
            }
            index == 0 -> {
                drawable.cornerRadii = floatArrayOf(cornerRadius, cornerRadius, 0f, 0f, 0f, 0f, cornerRadius, cornerRadius)
            }
            index == totalCount - 1 -> {
                drawable.cornerRadii = floatArrayOf(0f, 0f, cornerRadius, cornerRadius, cornerRadius, cornerRadius, 0f, 0f)
            }
            else -> {
                drawable.cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f)
            }
        }
        
        // Set stroke
        drawable.setStroke(2, Color.parseColor("#E0E0E0"))
        
        // Set background color based on selection
        if (isSelected) {
            drawable.setColor(Color.parseColor("#2196F3")) // Material Blue
            button.setTextColor(Color.WHITE)
        } else {
            drawable.setColor(Color.TRANSPARENT)
            button.setTextColor(Color.parseColor("#757575")) // Material Grey
        }
        
        button.background = drawable
    }
    
    private fun updateSelectedButton(container: LinearLayout, selectedIndex: Int) {
        for (i in 0 until container.childCount) {
            val button = container.getChildAt(i) as? Button ?: continue
            val isSelected = i == selectedIndex
            updateButtonBackground(button, isSelected, i, container.childCount)
        }
    }
    
    private fun updateButtonColors(container: LinearLayout, selectedIndex: Int, props: Map<String, Any>) {
        val primaryColor = props["primaryColor"]?.let {
            ColorUtilities.parseColor(it.toString())
        } ?: props["tertiaryColor"]?.let {
            ColorUtilities.parseColor(it.toString())
        } ?: Color.parseColor("#2196F3")
        
        val secondaryColor = props["secondaryColor"]?.let {
            ColorUtilities.parseColor(it.toString())
        } ?: props["accentColor"]?.let {
            ColorUtilities.parseColor(it.toString())
        } ?: Color.parseColor("#757575")
        
        for (i in 0 until container.childCount) {
            val button = container.getChildAt(i) as? Button ?: continue
            val isSelected = i == selectedIndex
            
            val drawable = button.background as? GradientDrawable ?: continue
            if (isSelected) {
                drawable.setColor(primaryColor)
                button.setTextColor(Color.WHITE)
            } else {
                drawable.setColor(Color.TRANSPARENT)
                button.setTextColor(secondaryColor)
            }
        }
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val segments = parseSegments(props)
        val segmentCount = segments.size
        
        val minSegmentWidth = 80f
        val segmentHeight = 40f
        
        val totalWidth = minSegmentWidth * segmentCount
        
        return PointF(totalWidth, segmentHeight)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val container = view as? LinearLayout ?: return
        
        // Set up click listeners for buttons
        for (i in 0 until container.childCount) {
            val button = container.getChildAt(i) as? Button ?: continue
            button.setOnClickListener {
                val segments = parseSegments(getStoredProps(container))
                val title = segments.getOrNull(i) ?: ""
                
                // Immediately update visual state for better UX
                updateSelectedButton(container, i)
                
                // Propagate event to Dart side
                propagateEvent(container, "onSelectionChange", mapOf(
                    "selectedIndex" to i,
                    "selectedTitle" to title
                ))
            }
        }
        
        Log.d(TAG, "View-based SegmentedControl registered with shadow tree: $nodeId")
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}
