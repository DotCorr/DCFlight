/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.app.AlertDialog
import android.content.Context
import android.graphics.PointF
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R
import com.dotcorr.dcflight.utils.AdaptiveColorHelper

/**
 * DCFAlertComponent - 1:1 mapping with iOS DCFAlertComponent
 * Provides alert dialogs like iOS UIAlertController
 */
class DCFAlertComponent : DCFComponent() {

    private var alertDialog: AlertDialog? = null

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        // Set component identifier
        frameLayout.setTag(R.id.dcf_component_type, "Alert")
        
        // Let the system handle visibility naturally - no manual control
        
        // Apply initial props
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        return updateViewInternal(view, props.filterValues { it != null }.mapValues { it.value!! })
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        var hasUpdates = false

        // visible prop - show/hide alert
        props["visible"]?.let {
            val visible = when (it) {
                is Boolean -> it
                is String -> it.toBoolean()
                else -> false
            }
            
            if (visible && alertDialog == null) {
                showAlert(view, props)
                hasUpdates = true
            } else if (!visible && alertDialog != null) {
                hideAlert(view)
                hasUpdates = true
            }
        }

        // adaptive prop - matches iOS adaptivity
        props["adaptive"]?.let { adaptive ->
            if (adaptive == true) {
                // Apply adaptive background color for container
                view.setBackgroundColor(AdaptiveColorHelper.getSystemBackgroundColor(view.context))
                hasUpdates = true
            }
        }

        // Apply common view styling
        view.applyStyles(props)

        return hasUpdates
    }

    private fun showAlert(view: View, props: Map<String, Any>) {
        val context = view.context
        val builder = AlertDialog.Builder(context)
        
        // title prop
        props["title"]?.let {
            builder.setTitle(it.toString())
        }
        
        // message prop
        props["message"]?.let {
            builder.setMessage(it.toString())
        }
        
        // buttons prop
        props["buttons"]?.let { buttons ->
            when (buttons) {
                is List<*> -> {
                    buttons.forEachIndexed { index, button ->
                        when (button) {
                            is Map<*, *> -> {
                                val text = button["text"]?.toString() ?: "Button"
                                val style = button["style"]?.toString() ?: "default"
                                
                                when (style) {
                                    "cancel" -> {
                                        builder.setNegativeButton(text) { dialog, _ ->
                                            // 🚀 MATCH iOS: Use propagateEvent for onActionPress
                                            propagateEvent(view, "onActionPress", mapOf(
                                                "buttonIndex" to index,
                                                "buttonText" to text,
                                                "buttonStyle" to style
                                            ))
                                            dialog.dismiss()
                                        }
                                    }
                                    "destructive" -> {
                                        builder.setNeutralButton(text) { dialog, _ ->
                                            // 🚀 MATCH iOS: Use propagateEvent for onActionPress
                                            propagateEvent(view, "onActionPress", mapOf(
                                                "buttonIndex" to index,
                                                "buttonText" to text,
                                                "buttonStyle" to style
                                            ))
                                            dialog.dismiss()
                                        }
                                    }
                                    else -> {
                                        builder.setPositiveButton(text) { dialog, _ ->
                                            // 🚀 MATCH iOS: Use propagateEvent for onActionPress
                                            propagateEvent(view, "onActionPress", mapOf(
                                                "buttonIndex" to index,
                                                "buttonText" to text,
                                                "buttonStyle" to style
                                            ))
                                            dialog.dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Set up dismiss listener
        builder.setOnDismissListener {
            // 🚀 MATCH iOS: Use propagateEvent for onDismiss
            propagateEvent(view, "onDismiss", mapOf())
            alertDialog = null
        }
        
        alertDialog = builder.create()
        alertDialog?.show()
        
        // 🚀 MATCH iOS: Use propagateEvent for onShow
        propagateEvent(view, "onShow", mapOf())
    }

    private fun hideAlert(view: View) {
        alertDialog?.dismiss()
        alertDialog = null
        
        // 🚀 MATCH iOS: Use propagateEvent for onDismiss
        propagateEvent(view, "onDismiss", mapOf())
    }

    // MARK: - Intrinsic Size Calculation - MATCH iOS

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val frameLayout = view as? FrameLayout ?: return PointF(0f, 0f)

        // Alert components typically have minimal intrinsic size
        // as they overlay content
        return PointF(1f, 1f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Alert components are typically overlay components and don't need special handling
    }
}

