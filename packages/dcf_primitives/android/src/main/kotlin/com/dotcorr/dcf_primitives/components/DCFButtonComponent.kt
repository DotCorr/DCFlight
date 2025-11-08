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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcflight.utils.ColorUtilities
import com.dotcorr.dcf_primitives.R

/**
 * DCFButtonComponent - Material Design 3 Button using Jetpack Compose
 * Provides native Material Design 3 button with proper theming and animations
 */
class DCFButtonComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFButtonComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val composeView = ComposeView(context)
        composeView.setTag(R.id.dcf_component_type, "Button")
        
        // Store props for Compose to access
        storeProps(composeView, props)
        
        // Set initial content
        updateComposeContent(composeView, props)
        
        // Apply framework-level styles (border, shadow, etc.)
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        composeView.applyStyles(nonNullProps)
        
        Log.d(TAG, "Created Compose-based Material3 Button component")
        
        return composeView
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        val composeView = view as? ComposeView ?: return false
        
        Log.d(TAG, "Updating button with props: $props")
        
        // Update Compose content if props changed
        if (hasPropChanged("title", existingProps, props) ||
            hasPropChanged("disabled", existingProps, props) ||
            hasPropChanged("primaryColor", existingProps, props) ||
            hasPropChanged("backgroundColor", existingProps, props)) {
            updateComposeContent(composeView, props)
        }
        
        // Apply framework-level styles
        composeView.applyStyles(props)
        
        return true
    }
    
    private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
        val title = props["title"]?.toString() ?: ""
        val disabled = when (val d = props["disabled"]) {
            is Boolean -> d
            is String -> d.toBoolean()
            else -> false
        }
        val primaryColor = props["primaryColor"]?.let { 
            ColorUtilities.parseColor(it.toString()) 
        }
        val backgroundColor = props["backgroundColor"]?.let { 
            ColorUtilities.parseColor(it.toString()) 
        }
        
        composeView.setContent {
            Material3Button(
                title = title,
                disabled = disabled,
                primaryColor = primaryColor,
                backgroundColor = backgroundColor,
                onPress = {
                    // Find viewId from ViewRegistry if not in tag
                    val viewId = composeView.getTag(com.dotcorr.dcflight.R.id.dcf_view_id) as? String
                        ?: ViewRegistry.shared.allViewIds.firstOrNull { id ->
                            ViewRegistry.shared.getView(id) == composeView
                        }
                    
                    if (viewId != null) {
                        propagateEvent(composeView, "onPress", mapOf(
                            "pressed" to true,
                            "timestamp" to System.currentTimeMillis() / 1000.0,
                            "title" to title
                        ))
                    } else {
                        Log.w(TAG, "Cannot propagate event - viewId not found for ComposeView")
                    }
                }
            )
        }
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val composeView = view as? ComposeView ?: return PointF(0f, 0f)
        
        val title = props["title"]?.toString() ?: ""
        
        // Material3 Button default sizing
        val minWidth = 100f
        val minHeight = 40f
        
        // Estimate width based on text (rough approximation)
        val estimatedWidth = if (title.isNotEmpty()) {
            (title.length * 10f).coerceAtLeast(minWidth)
        } else {
            minWidth
        }
        
        return PointF(estimatedWidth, minHeight)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        Log.d(TAG, "Compose Button component registered with shadow tree: $nodeId")
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

@Composable
private fun Material3Button(
    title: String,
    disabled: Boolean,
    primaryColor: Int?,
    backgroundColor: Int?,
    onPress: () -> Unit
) {
    val buttonColors = if (primaryColor != null || backgroundColor != null) {
        ButtonDefaults.buttonColors(
            containerColor = backgroundColor?.let { Color(it) } ?: Color.Unspecified,
            contentColor = primaryColor?.let { Color(it) } ?: Color.Unspecified,
            disabledContainerColor = backgroundColor?.let { Color(it).copy(alpha = 0.38f) } ?: Color.Unspecified,
            disabledContentColor = primaryColor?.let { Color(it).copy(alpha = 0.38f) } ?: Color.Unspecified
        )
    } else {
        ButtonDefaults.buttonColors()
    }
    
    Button(
        onClick = onPress,
        enabled = !disabled,
        modifier = Modifier.fillMaxWidth(),
        colors = buttonColors,
        shape = RoundedCornerShape(8.dp),
        elevation = ButtonDefaults.buttonElevation(
            defaultElevation = 2.dp,
            pressedElevation = 4.dp,
            disabledElevation = 0.dp
        ),
        contentPadding = PaddingValues(
            horizontal = 16.dp,
            vertical = 12.dp
        )
    ) {
        Text(
            text = title,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium
        )
    }
}
