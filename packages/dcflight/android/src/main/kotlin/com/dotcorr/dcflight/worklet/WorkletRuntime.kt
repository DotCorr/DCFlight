/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.worklet

import android.view.View
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.components.text.DCFTextShadowNode

/**
 * WorkletRuntime - Provides a Reanimated-like API for worklets to directly access and modify native views.
 * 
 * This abstracts away shadow views, layout managers, and component-specific glue code.
 * Worklets can directly manipulate views like React Native Reanimated.
 * 
 * Example usage in worklet IR:
 * - `WorkletRuntime.getView(viewId).setProperty("text", value)`
 * - `WorkletRuntime.getView(viewId).setProperty("opacity", value)`
 * - `WorkletRuntime.getView(viewId).setProperty("transform.scale", value)`
 */
object WorkletRuntime {
    /**
     * Get a view proxy that allows direct property manipulation.
     * This is the main entry point for worklets to access views.
     */
    fun getView(viewId: Int): WorkletViewProxy? {
        val viewInfo = ViewRegistry.shared.getViewInfo(viewId) ?: return null
        return WorkletViewProxy(viewId, viewInfo.view)
    }
    
    /**
     * Get a view by tag (if views support tags).
     */
    fun getViewByTag(tag: Int): WorkletViewProxy? {
        // Find view by tag in ViewRegistry
        for (viewId in ViewRegistry.shared.allViewIds) {
            val viewInfo = ViewRegistry.shared.getViewInfo(viewId)
            if (viewInfo?.view?.tag == tag) {
                return WorkletViewProxy(viewId, viewInfo.view)
            }
        }
        return null
    }
}

/**
 * WorkletViewProxy - A proxy object that allows worklets to directly manipulate view properties.
 * 
 * This is similar to React Native Reanimated's view API where you can do:
 * `view.opacity = value` or `view.text = value`
 * 
 * All property updates automatically handle shadow view updates and layout recalculation.
 */
class WorkletViewProxy(
    val viewId: Int,
    val view: View
) {
    /**
     * Set a property on the view. This is the main API for worklets.
     * 
     * Supported properties:
     * - "text" - Updates text content (for text views)
     * - "opacity" - Updates alpha/opacity
     * - "scale" - Updates scale transform
     * - "scaleX", "scaleY" - Updates individual scale components
     * - "translateX", "translateY" - Updates translation
     * - "rotation" - Updates rotation
     * - "rotationX", "rotationY", "rotationZ" - Updates 3D rotation
     * - "transform.scale" - Nested property access
     * 
     * All updates automatically:
     * 1. Update the native view
     * 2. Update the shadow view (if applicable)
     * 3. Trigger layout recalculation (if needed)
     */
    fun setProperty(property: String, value: Any) {
        when (property) {
            "text" -> setText(value as? String ?: "")
            "opacity", "alpha" -> setOpacity((value as? Number)?.toFloat() ?: 1.0f)
            "scale" -> setScale((value as? Number)?.toFloat() ?: 1.0f)
            "scaleX" -> setScaleX((value as? Number)?.toFloat() ?: 1.0f)
            "scaleY" -> setScaleY((value as? Number)?.toFloat() ?: 1.0f)
            "translateX" -> setTranslateX((value as? Number)?.toFloat() ?: 0.0f)
            "translateY" -> setTranslateY((value as? Number)?.toFloat() ?: 0.0f)
            "rotation", "rotationZ" -> setRotation((value as? Number)?.toFloat() ?: 0.0f)
            "rotationX" -> setRotationX((value as? Number)?.toFloat() ?: 0.0f)
            "rotationY" -> setRotationY((value as? Number)?.toFloat() ?: 0.0f)
            else -> {
                // Try nested property access (e.g., "transform.scale")
                if (property.contains(".")) {
                    setNestedProperty(property, value)
                } else {
                    android.util.Log.w("WorkletRuntime", "⚠️ WORKLET: Unknown property '$property' for viewId=$viewId")
                }
            }
        }
    }
    
    /**
     * Set text property - worklets update shadow node, framework handles the rest.
     * 
     * 🔥 UNIVERSAL: Worklets are for animation, not layout. They update shadow node text,
     * then trigger framework update. Framework handles all complex layout logic.
     */
    private fun setText(text: String) {
        // Update shadow node
        val shadowNode = YogaShadowTree.shared.getShadowNode(viewId) as? DCFTextShadowNode
        if (shadowNode != null) {
            shadowNode.text = text
            shadowNode.dirtyText()
            
            // Trigger framework update - framework handles all layout logic
            // This is the same pattern as normal prop updates - framework does the work
            com.dotcorr.dcflight.Coordinator.DCFViewManager.shared.updateView(
                viewId,
                mapOf("content" to text)
            )
        } else {
            android.util.Log.w("WorkletRuntime", "⚠️ WORKLET: Cannot update text - shadow node not found for viewId=$viewId")
        }
    }
    
    /**
     * Set opacity - directly updates native view (no shadow view needed).
     */
    private fun setOpacity(opacity: Float) {
        view.post {
            view.alpha = opacity.coerceIn(0f, 1f)
        }
    }
    
    /**
     * Set scale - directly updates native view transform.
     */
    private fun setScale(scale: Float) {
        view.post {
            view.scaleX = scale
            view.scaleY = scale
        }
    }
    
    /**
     * Set scaleX - directly updates native view transform.
     */
    private fun setScaleX(scaleX: Float) {
        view.post {
            view.scaleX = scaleX
        }
    }
    
    /**
     * Set scaleY - directly updates native view transform.
     */
    private fun setScaleY(scaleY: Float) {
        view.post {
            view.scaleY = scaleY
        }
    }
    
    /**
     * Set translateX - directly updates native view transform.
     */
    private fun setTranslateX(translateX: Float) {
        view.post {
            view.translationX = translateX
        }
    }
    
    /**
     * Set translateY - directly updates native view transform.
     */
    private fun setTranslateY(translateY: Float) {
        view.post {
            view.translationY = translateY
        }
    }
    
    /**
     * Set rotation - directly updates native view transform.
     */
    private fun setRotation(rotation: Float) {
        view.post {
            view.rotation = rotation
        }
    }
    
    /**
     * Set rotationX - directly updates native view transform (3D).
     */
    private fun setRotationX(rotationX: Float) {
        view.post {
            view.rotationX = rotationX
        }
    }
    
    /**
     * Set rotationY - directly updates native view transform (3D).
     */
    private fun setRotationY(rotationY: Float) {
        view.post {
            view.rotationY = rotationY
        }
    }
    
    /**
     * Set nested property (e.g., "transform.scale").
     */
    private fun setNestedProperty(property: String, value: Any) {
        val parts = property.split(".")
        if (parts.size == 2) {
            val parent = parts[0]
            val child = parts[1]
            
            if (parent == "transform") {
                when (child) {
                    "scale" -> setScale((value as? Number)?.toFloat() ?: 1.0f)
                    "scaleX" -> setScaleX((value as? Number)?.toFloat() ?: 1.0f)
                    "scaleY" -> setScaleY((value as? Number)?.toFloat() ?: 1.0f)
                    "translateX" -> setTranslateX((value as? Number)?.toFloat() ?: 0.0f)
                    "translateY" -> setTranslateY((value as? Number)?.toFloat() ?: 0.0f)
                    "rotation" -> setRotation((value as? Number)?.toFloat() ?: 0.0f)
                    else -> android.util.Log.w("WorkletRuntime", "⚠️ WORKLET: Unknown transform property '$child'")
                }
            } else {
                android.util.Log.w("WorkletRuntime", "⚠️ WORKLET: Unknown parent property '$parent'")
            }
        } else {
            android.util.Log.w("WorkletRuntime", "⚠️ WORKLET: Invalid nested property format '$property'")
        }
    }
}

