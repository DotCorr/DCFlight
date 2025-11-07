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

/**
 * DCFAlertComponent - 1:1 mapping with iOS DCFAlertComponent
 * Provides alert dialogs like iOS UIAlertController
 */
class DCFAlertComponent : DCFComponent() {

    companion object {
        private const val TAG_ALERT_DIALOG = "dcf_alert_dialog"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        frameLayout.setTag(R.id.dcf_component_type, "Alert")
        
        
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateViewInternal(view: View, props: Map<String, Any>, existingProps: Map<String, Any>): Boolean {
        var hasUpdates = false

        // CRITICAL: Only show/hide alert if visible prop ACTUALLY CHANGED
        // This prevents alerts from showing on unrelated state updates (like count increment)
        if (hasPropChanged("visible", existingProps, props)) {
            props["visible"]?.let {
                val visible = when (it) {
                    is Boolean -> it
                    is String -> it.toBoolean()
                    else -> false
                }
                
                val existingVisible = existingProps["visible"]?.let { existing ->
                    when (existing) {
                        is Boolean -> existing
                        is String -> existing.toBoolean()
                        else -> false
                    }
                } ?: false
                
                val alertDialog = getAlertDialog(view)
                
                // Only show if changing from false to true
                if (visible && !existingVisible && alertDialog == null) {
                    showAlert(view, props)
                    hasUpdates = true
                } 
                // Only hide if changing from true to false
                else if (!visible && existingVisible && alertDialog != null) {
                    hideAlert(view)
                    hasUpdates = true
                }
            }
        }

        view.applyStyles(props)

        return hasUpdates
    }
    
    private fun getAlertDialog(view: View): AlertDialog? {
        return view.getTag(TAG_ALERT_DIALOG.hashCode()) as? AlertDialog
    }
    
    private fun setAlertDialog(view: View, alertDialog: AlertDialog?) {
        view.setTag(TAG_ALERT_DIALOG.hashCode(), alertDialog)
    }

    private fun showAlert(view: View, props: Map<String, Any>) {
        val context = view.context
        val builder = AlertDialog.Builder(context)
        
        // Use alertContent like iOS for consistency
        val alertContent = props["alertContent"] as? Map<*, *>
        if (alertContent != null) {
            alertContent["title"]?.let {
                builder.setTitle(it.toString())
            }
            
            alertContent["message"]?.let {
                builder.setMessage(it.toString())
            }
        } else {
            // Fallback to direct props for backward compatibility
            props["title"]?.let {
                builder.setTitle(it.toString())
            }
            
            props["message"]?.let {
                builder.setMessage(it.toString())
            }
        }
        
        // Use actions like iOS for consistency (buttons is legacy)
        val actions = props["actions"] as? List<*> ?: props["buttons"] as? List<*>
        actions?.let { actionList ->
            when (actionList) {
                is List<*> -> {
                    actionList.forEachIndexed { index, action ->
                        when (action) {
                            is Map<*, *> -> {
                                val text = action["title"]?.toString() ?: action["text"]?.toString() ?: "Button"
                                val style = action["style"]?.toString() ?: "default"
                                
                                when (style) {
                                    "cancel" -> {
                                        builder.setNegativeButton(text) { dialog, _ ->
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
        
        val dialog = builder.create()
        
        builder.setOnDismissListener {
            propagateEvent(view, "onDismiss", mapOf())
            setAlertDialog(view, null)
        }
        
        setAlertDialog(view, dialog)
        dialog.show()
        
        propagateEvent(view, "onShow", mapOf())
    }

    private fun hideAlert(view: View) {
        val alertDialog = getAlertDialog(view)
        alertDialog?.dismiss()
        setAlertDialog(view, null)
        
        propagateEvent(view, "onDismiss", mapOf())
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val frameLayout = view as? FrameLayout ?: return PointF(0f, 0f)

        return PointF(1f, 1f)
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

