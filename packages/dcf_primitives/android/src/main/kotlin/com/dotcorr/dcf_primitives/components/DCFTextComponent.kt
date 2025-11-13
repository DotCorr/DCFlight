/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.PointF
import android.util.Log
import android.view.View
import android.view.ViewGroup
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import androidx.compose.ui.platform.ComposeView
import kotlin.math.max

/**
 * DCFTextComponent - Pure Compose Text implementation
 * 
 * Uses Jetpack Compose for rendering with Yoga layout integration.
 * ComposeView IS a View, so Yoga can measure and position it natively.
 * 
 * Benefits:
 * - No XML resources needed
 * - Modern Material Design 3 styling
 * - Consistent with Button component
 * - Works perfectly with Yoga layout
 */
class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // CRITICAL: Wrap ComposeView to prevent layout requests during content-only updates
        // This eliminates flickering by preventing double layout passes
        val composeView = ComposeView(context)
        val wrapper = NonLayoutRequestingWrapper(context, composeView)
        wrapper.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // CRITICAL: Set visibility explicitly
        wrapper.visibility = View.VISIBLE
        wrapper.alpha = 1.0f
        
        storeProps(wrapper, props)
        
        // CRITICAL: Set content BEFORE applying styles
        // This ensures Compose can measure correctly
        updateComposeContent(composeView, props)

        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        wrapper.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created Compose-based Text component")

        return wrapper
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val wrapper = view as? NonLayoutRequestingWrapper ?: return false
        val composeView = wrapper.composeView
        
        // Check if content or text-related props actually changed
        val contentChanged = props["content"]?.toString() != existingProps["content"]?.toString()
        val textColorChanged = ColorUtilities.getColor("textColor", "primaryColor", props) != 
                               ColorUtilities.getColor("textColor", "primaryColor", existingProps)
        val fontSizeChanged = (props["fontSize"] as? Number)?.toFloat() != 
                             (existingProps["fontSize"] as? Number)?.toFloat()
        val fontWeightChanged = props["fontWeight"]?.toString() != existingProps["fontWeight"]?.toString()
        val textAlignChanged = props["textAlign"]?.toString() != existingProps["textAlign"]?.toString()
        val maxLinesChanged = (props["numberOfLines"] as? Number)?.toInt() != 
                             (existingProps["numberOfLines"] as? Number)?.toInt()
        
        // Check if layout props changed (width, height, margin, padding, etc.)
        val layoutPropsChanged = props["width"] != existingProps["width"] ||
                                 props["height"] != existingProps["height"] ||
                                 props["margin"] != existingProps["margin"] ||
                                 props["padding"] != existingProps["padding"] ||
                                 props["marginTop"] != existingProps["marginTop"] ||
                                 props["marginBottom"] != existingProps["marginBottom"] ||
                                 props["marginLeft"] != existingProps["marginLeft"] ||
                                 props["marginRight"] != existingProps["marginRight"]
        
        // CRITICAL: Only allow layout requests if layout props changed
        // This prevents double layout passes when only content changes
        // The flag will be reset automatically after the current frame
        wrapper.setAllowLayoutRequests(layoutPropsChanged)
        
        // CRITICAL: Apply styles FIRST to avoid layout thrashing
        // This ensures layout is stable before Compose recomposition
        wrapper.applyStyles(props)
        
        // Only update Compose content if text-related props changed
        // This prevents unnecessary recomposition and flickering
        if (contentChanged || textColorChanged || fontSizeChanged || fontWeightChanged || 
            textAlignChanged || maxLinesChanged) {
            updateComposeContent(composeView, props)
        }

        return true
    }

    private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: 17f
        val fontWeight = fontWeightFromString(props["fontWeight"]?.toString() ?: "regular")
        val textAlign = textAlignFromString(props["textAlign"]?.toString() ?: "start")
        val maxLines = (props["numberOfLines"] as? Number)?.toInt() ?: Int.MAX_VALUE
        
        // Get default color based on theme if no color is provided
        val context = composeView.context
        val isDarkTheme = (context.resources.configuration.uiMode and 
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) == 
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val defaultColor = if (isDarkTheme) android.graphics.Color.WHITE else android.graphics.Color.BLACK
        val finalColor = textColor ?: defaultColor
        
        // CRITICAL: Use a SINGLE state object to prevent multiple recompositions
        // This ensures only ONE state change triggers ONE recomposition, eliminating flickering
        val STATE_HOLDER_TAG_KEY = "DCFTextStateHolder".hashCode()
        @Suppress("UNCHECKED_CAST")
        var stateHolder = composeView.getTag(STATE_HOLDER_TAG_KEY) as? androidx.compose.runtime.MutableState<TextState>
        if (stateHolder == null) {
            // First time: Create single state object and set content once
            val initialState = TextState(
                content = content,
                textColor = finalColor,
                fontSize = fontSize,
                fontWeight = fontWeight,
                textAlign = textAlign,
                maxLines = if (maxLines == 0) Int.MAX_VALUE else maxLines
            )
            stateHolder = mutableStateOf(initialState)
            composeView.setTag(STATE_HOLDER_TAG_KEY, stateHolder)
            
            // Set content once - single state object ensures stable recomposition
            composeView.setContent {
                val state = remember { stateHolder }.value
                Material3Text(
                    text = state.content,
                    color = state.textColor,
                    fontSize = state.fontSize,
                    fontWeight = state.fontWeight,
                    textAlign = state.textAlign,
                    maxLines = state.maxLines
                )
            }
        } else {
            // Subsequent updates: Update single state object atomically
            // This triggers only ONE recomposition, preventing flickering
            stateHolder.value = TextState(
                content = content,
                textColor = finalColor,
                fontSize = fontSize,
                fontWeight = fontWeight,
                textAlign = textAlign,
                maxLines = if (maxLines == 0) Int.MAX_VALUE else maxLines
            )
        }
        
        if (content.isNotEmpty()) {
            Log.d(TAG, "Updated text content: $content, color: ${ColorUtilities.hexString(finalColor)}")
        }
    }
    
    private data class TextState(
        val content: String,
        val textColor: Int,
        val fontSize: Float,
        val fontWeight: FontWeight,
        val textAlign: TextAlign,
        val maxLines: Int
    )

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        // CRITICAL: Yoga calls getIntrinsicSize with emptyMap(), so we MUST get props from storedProps
        // Also, view is now the wrapper, not ComposeView directly
        val wrapper = view as? NonLayoutRequestingWrapper
        val storedProps = getStoredProps(view)
        val allProps = if (props.isEmpty()) storedProps else props

        val content = allProps["content"]?.toString() ?: ""
        if (content.isEmpty()) {
            Log.w(TAG, "getIntrinsicSize: No content found in props or storedProps")
            return PointF(0f, 0f)
        }

        // CRITICAL: ComposeView can't be reliably measured before it's laid out
        // Return preferred size - Yoga will constrain based on parent width
        // Compose Text will wrap automatically when given width constraints
        val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
        
        // For text wrapping: Return preferred width (single line estimate)
        // Yoga will constrain this based on parent width, and Compose Text will wrap
        // This matches TextView behavior where text wraps when parent width is constrained
        val preferredWidth = content.length * fontSize * 0.6f
        
        // Height: single line height (text will grow vertically when wrapping)
        val singleLineHeight = fontSize * 1.2f
        
        // Ensure minimum size
        val finalWidth = preferredWidth.coerceAtLeast(1f)
        val finalHeight = singleLineHeight.coerceAtLeast(1f)

        Log.d(TAG, "Text preferred size for Yoga: ${finalWidth}x${finalHeight} (will wrap if parent constrains width)")
        return PointF(finalWidth, finalHeight)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Compose Text component registered with shadow tree: $nodeId")
        
        // CRITICAL: Ensure content is set after registration
        // This fixes the issue where the last text component doesn't show
        val wrapper = view as? NonLayoutRequestingWrapper ?: return
        val composeView = wrapper.composeView
        val storedProps = getStoredProps(view)
        updateComposeContent(composeView, storedProps)
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
    
    private fun fontWeightFromString(weight: String): FontWeight {
        return when (weight.lowercase()) {
            "thin", "100" -> FontWeight.Thin
            "ultralight", "200" -> FontWeight.ExtraLight
            "light", "300" -> FontWeight.Light
            "regular", "normal", "400" -> FontWeight.Normal
            "medium", "500" -> FontWeight.Medium
            "semibold", "600" -> FontWeight.SemiBold
            "bold", "700" -> FontWeight.Bold
            "heavy", "800" -> FontWeight.ExtraBold
            "black", "900" -> FontWeight.Black
            else -> FontWeight.Normal
        }
    }
    
    private fun textAlignFromString(align: String): TextAlign {
        return when (align.lowercase()) {
            "center" -> TextAlign.Center
            "right", "end" -> TextAlign.Right
            "left", "start" -> TextAlign.Left
            "justify" -> TextAlign.Justify
            else -> TextAlign.Start
        }
    }
}

/**
 * Wrapper ViewGroup that prevents ComposeView from requesting layout during content-only updates.
 * 
 * This eliminates flickering by preventing double layout passes when only text content changes.
 * Layout requests are only allowed when layout props (width, height, margin, padding) change.
 */
private class NonLayoutRequestingWrapper(
    context: Context,
    val composeView: ComposeView
) : ViewGroup(context) {
    private var allowLayoutRequests = true
    private var resetRunnable: Runnable? = null
    
    init {
        addView(composeView, LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }
    
    fun setAllowLayoutRequests(allow: Boolean) {
        // Cancel any pending reset
        resetRunnable?.let { removeCallbacks(it) }
        resetRunnable = null
        
        allowLayoutRequests = allow
        
        // CRITICAL: Reset flag after current frame to allow future layout requests
        // This ensures Compose recomposition doesn't trigger layout during content-only updates
        // Using View.post() ensures it runs after the current frame is processed
        if (!allow) {
            resetRunnable = Runnable {
                allowLayoutRequests = true
            }
            post(resetRunnable!!)
        }
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        composeView.measure(widthMeasureSpec, heightMeasureSpec)
        setMeasuredDimension(composeView.measuredWidth, composeView.measuredHeight)
    }
    
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        composeView.layout(0, 0, r - l, b - t)
    }
    
    override fun requestLayout() {
        // CRITICAL: Only request layout if allowed
        // This prevents double layout passes when only content changes
        // When ComposeView calls requestLayout(), it propagates to parent (this wrapper)
        // So we intercept it here to prevent unnecessary Yoga recalculations
        if (allowLayoutRequests) {
            super.requestLayout()
        }
    }
    
    override fun invalidate() {
        // Always allow invalidation (redraw) but not layout requests
        super.invalidate()
    }
}

@Composable
private fun Material3Text(
    text: String,
    color: Int,
    fontSize: Float,
    fontWeight: FontWeight,
    textAlign: TextAlign,
    maxLines: Int
) {
    // Text wraps by default in Compose when given proper constraints
    // No modifier needed - ComposeView will provide constraints from Yoga layout
    Text(
        text = text,
        color = Color(color),
        fontSize = fontSize.sp,
        fontWeight = fontWeight,
        textAlign = textAlign,
        maxLines = maxLines
    )
}
