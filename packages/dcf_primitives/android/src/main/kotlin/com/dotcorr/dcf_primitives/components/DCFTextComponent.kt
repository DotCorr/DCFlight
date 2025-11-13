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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.DCFComposeWrapper
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.utils.ColorUtilities
import androidx.compose.ui.platform.ComposeView

class DCFTextComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTextComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val composeView = ComposeView(context)
        val wrapper = DCFComposeWrapper(context, composeView)
        wrapper.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // Framework controls visibility - don't set here!
        // We'll ensure composition happens before layout instead
        
        storeProps(wrapper, props)
        
        // CRITICAL: Set content BEFORE measuring to prevent flash
        // Framework calls getIntrinsicSize during layout calculation
        // ComposeView must have content composed before measurement
        updateComposeContent(composeView, props)

        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        wrapper.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created Compose-based Text component")

        return wrapper
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val wrapper = view as? DCFComposeWrapper ?: return false
        val composeView = wrapper.composeView
        
        val contentChanged = props["content"]?.toString() != existingProps["content"]?.toString()
        val textColorChanged = ColorUtilities.getColor("textColor", "primaryColor", props) != 
                               ColorUtilities.getColor("textColor", "primaryColor", existingProps)
        val fontSizeChanged = (props["fontSize"] as? Number)?.toFloat() != 
                             (existingProps["fontSize"] as? Number)?.toFloat()
        val fontWeightChanged = props["fontWeight"]?.toString() != existingProps["fontWeight"]?.toString()
        val textAlignChanged = props["textAlign"]?.toString() != existingProps["textAlign"]?.toString()
        val maxLinesChanged = (props["numberOfLines"] as? Number)?.toInt() != 
                             (existingProps["numberOfLines"] as? Number)?.toInt()
        
        wrapper.setAllowLayoutRequests(hasLayoutPropsChanged(existingProps, props))
        wrapper.applyStyles(props)
        
        if (contentChanged || textColorChanged || fontSizeChanged || fontWeightChanged || 
            textAlignChanged || maxLinesChanged) {
            // CRITICAL: For content changes during reconciliation, ensure composition completes
            // before view becomes visible again (handled by framework in applyLayoutDirectly)
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
        
        val context = composeView.context
        val isDarkTheme = (context.resources.configuration.uiMode and 
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) == 
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val defaultColor = if (isDarkTheme) android.graphics.Color.WHITE else android.graphics.Color.BLACK
        val finalColor = textColor ?: defaultColor
        
        val STATE_HOLDER_TAG_KEY = "DCFTextStateHolder".hashCode()
        @Suppress("UNCHECKED_CAST")
        var stateHolder = composeView.getTag(STATE_HOLDER_TAG_KEY) as? androidx.compose.runtime.MutableState<TextState>
        if (stateHolder == null) {
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
            
            // Mark composition as ready after setContent
            // Note: setContent is async, but we'll verify in getIntrinsicSize
            val wrapper = composeView.parent as? DCFComposeWrapper
            wrapper?.markCompositionReady()
        } else {
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
        val wrapper = view as? DCFComposeWrapper ?: return PointF(0f, 0f)
        val composeView = wrapper.composeView
        
        // Match iOS: Use actual measurement, not estimate
        // iOS: label.sizeThatFits(maxSize) - we do the same with ComposeView
        
        val storedProps = getStoredProps(view)
        val allProps = if (props.isEmpty()) storedProps else props
        val content = allProps["content"]?.toString() ?: ""
        
        if (content.isEmpty()) {
            return PointF(0f, 0f)
        }
        
        // CRITICAL: Ensure ComposeView is composed before measuring
        // ComposeView.setContent is async, so we need to ensure composition is ready
        // This prevents flash on reconciliation (new views need accurate size immediately)
        
        // Force composition if not already composed
        val STATE_HOLDER_TAG_KEY = "DCFTextStateHolder".hashCode()
        @Suppress("UNCHECKED_CAST")
        val stateHolder = composeView.getTag(STATE_HOLDER_TAG_KEY) as? androidx.compose.runtime.MutableState<*>
        if (stateHolder == null) {
            // Not composed yet - ensure it's composed now
            updateComposeContent(composeView, allProps)
        }
        
        // CRITICAL: Ensure composition is ready before measuring
        // This forces ComposeView to compose synchronously if possible
        wrapper.ensureCompositionReady()
        
        // Measure the actual ComposeView (like iOS measures UILabel)
        // Use a reasonable width constraint for measurement (like iOS maxSize)
        val maxWidth = 10000 // Large but finite width for measurement
        composeView.measure(
            View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        
        val measuredWidth = composeView.measuredWidth.toFloat()
        val measuredHeight = composeView.measuredHeight.toFloat()
        
        // If measurement returns 0 (Compose not composed yet), use improved fallback
        // This should be rare - we ensure composition above
        if (measuredWidth == 0f || measuredHeight == 0f) {
            val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
            // Improved estimate: account for multi-line text and actual character width
            val lines = content.split("\n")
            val maxLineLength = lines.maxOfOrNull { it.length } ?: content.length
            val estimatedWidth = maxLineLength * fontSize * 0.6f
            val estimatedHeight = lines.size * fontSize * 1.2f
            return PointF(estimatedWidth.coerceAtLeast(1f), estimatedHeight.coerceAtLeast(1f))
        }
        
        return PointF(measuredWidth.coerceAtLeast(1f), measuredHeight.coerceAtLeast(1f))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val wrapper = view as? DCFComposeWrapper ?: return
        val composeView = wrapper.composeView
        val storedProps = getStoredProps(view)
        
        // CRITICAL: Ensure ComposeView is composed before layout calculation
        // This prevents flash because getIntrinsicSize will get accurate measurement
        // Framework calls this before layout calculation, so we ensure composition is ready
        updateComposeContent(composeView, storedProps)
        
        // CRITICAL: Force composition to be ready before layout calculation
        // This ensures measurement in getIntrinsicSize is accurate
        if (view.parent != null) {
            wrapper.ensureCompositionReady()
        }
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

@Composable
private fun Material3Text(
    text: String,
    color: Int,
    fontSize: Float,
    fontWeight: FontWeight,
    textAlign: TextAlign,
    maxLines: Int
) {
    Text(
        text = text,
        color = Color(color),
        fontSize = fontSize.sp,
        fontWeight = fontWeight,
        textAlign = textAlign,
        maxLines = maxLines
    )
}
