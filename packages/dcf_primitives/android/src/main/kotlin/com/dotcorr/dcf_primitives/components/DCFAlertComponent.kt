/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives.components

import android.app.AlertDialog
import android.content.Context
import android.graphics.PointF
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles

class DCFAlertComponent : DCFComponent() {

    companion object {
        private const val TAG_ALERT_DIALOG = "dcf_alert_dialog"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val frameLayout = FrameLayout(context)
        
        frameLayout.setTag(DCFTags.COMPONENT_TYPE_KEY, "Alert")
        
        
        updateView(frameLayout, props)
        return frameLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val visible = when (val v = mergedProps["visible"]) {
            is Boolean -> v
            is String -> v.toBoolean()
            else -> false
        }
        
        val alertDialog = getAlertDialog(view)
        
        if (visible && alertDialog == null) {
            showAlert(view, mergedProps.filterValues { it != null }.mapValues { it.value!! })
        } else if (!visible && alertDialog != null) {
            hideAlert(view)
        } else if (visible && alertDialog != null) {
            alertDialog.dismiss()
            setAlertDialog(view, null)
            showAlert(view, mergedProps.filterValues { it != null }.mapValues { it.value!! })
        }

        view.applyStyles(mergedProps.filterValues { it != null }.mapValues { it.value!! })
        return true
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
        
        val alertContent = props["alertContent"] as? Map<*, *>
        if (alertContent != null) {
            alertContent["title"]?.let {
                builder.setTitle(it.toString())
            }
            
            alertContent["message"]?.let {
                builder.setMessage(it.toString())
            }
        } else {
            props["title"]?.let {
                builder.setTitle(it.toString())
            }
            
            props["message"]?.let {
                builder.setMessage(it.toString())
            }
        }
        
        // Handle text fields
        val textFields = props["textFields"] as? List<*>
        val textFieldViews = mutableListOf<android.widget.EditText>()
        
        if (textFields != null && textFields.isNotEmpty()) {
            if (textFields.size == 1) {
                // Single text field - use setView directly
                textFields[0]?.let { textField ->
                    when (textField) {
                        is Map<*, *> -> {
                            val editText = android.widget.EditText(context)
                            textField["placeholder"]?.let {
                                editText.hint = it.toString()
                            }
                            textField["defaultValue"]?.let {
                                editText.setText(it.toString())
                            }
                            textField["secureTextEntry"]?.let {
                                if (it is Boolean && it) {
                                    editText.inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
                                }
                            }
                            textFieldViews.add(editText)
                            builder.setView(editText)
                        }
                    }
                }
            } else {
                // Multiple text fields - use LinearLayout container
                val container = android.widget.LinearLayout(context)
                container.orientation = android.widget.LinearLayout.VERTICAL
                val layoutParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                )
                layoutParams.setMargins(50, 20, 50, 20)
                container.layoutParams = layoutParams
                
                textFields.forEachIndexed { index, textField ->
                    when (textField) {
                        is Map<*, *> -> {
                            val editText = android.widget.EditText(context)
                            textField["placeholder"]?.let {
                                editText.hint = it.toString()
                            }
                            textField["defaultValue"]?.let {
                                editText.setText(it.toString())
                            }
                            textField["secureTextEntry"]?.let {
                                if (it is Boolean && it) {
                                    editText.inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
                                }
                            }
                            val editTextParams = android.widget.LinearLayout.LayoutParams(
                                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                            )
                            if (index > 0) {
                                editTextParams.topMargin = 16
                            }
                            editText.layoutParams = editTextParams
                            textFieldViews.add(editText)
                            container.addView(editText)
                        }
                    }
                }
                builder.setView(container)
            }
        }
        
        val actions = props["actions"] as? List<*> ?: props["buttons"] as? List<*>
        if (actions != null && actions.isNotEmpty()) {
            when (actions) {
                is List<*> -> {
                    actions.forEachIndexed { index, action ->
                        when (action) {
                            is Map<*, *> -> {
                                val text = action["title"]?.toString() ?: action["text"]?.toString() ?: "Button"
                                val style = action["style"]?.toString() ?: "default"
                                val handler = action["handler"]?.toString()
                                
                                when (style) {
                                    "cancel" -> {
                                        builder.setNegativeButton(text) { dialog, _ ->
                                            val eventData = mutableMapOf<String, Any>(
                                                "buttonIndex" to index,
                                                "buttonText" to text,
                                                "buttonStyle" to style
                                            )
                                            handler?.let { eventData["handler"] = it }
                                            if (textFieldViews.isNotEmpty()) {
                                                eventData["textFieldValues"] = textFieldViews.mapIndexed { idx, editText ->
                                                    mapOf("index" to idx, "value" to (editText.text?.toString() ?: ""))
                                                }
                                            }
                                            propagateEvent(view, "onActionPress", eventData)
                                            dialog.dismiss()
                                        }
                                    }
                                    "destructive" -> {
                                        builder.setNeutralButton(text) { dialog, _ ->
                                            val eventData = mutableMapOf<String, Any>(
                                                "buttonIndex" to index,
                                                "buttonText" to text,
                                                "buttonStyle" to style
                                            )
                                            handler?.let { eventData["handler"] = it }
                                            if (textFieldViews.isNotEmpty()) {
                                                eventData["textFieldValues"] = textFieldViews.mapIndexed { idx, editText ->
                                                    mapOf("index" to idx, "value" to (editText.text?.toString() ?: ""))
                                                }
                                            }
                                            propagateEvent(view, "onActionPress", eventData)
                                            dialog.dismiss()
                                        }
                                    }
                                    else -> {
                                        builder.setPositiveButton(text) { dialog, _ ->
                                            val eventData = mutableMapOf<String, Any>(
                                                "buttonIndex" to index,
                                                "buttonText" to text,
                                                "buttonStyle" to style
                                            )
                                            handler?.let { eventData["handler"] = it }
                                            if (textFieldViews.isNotEmpty()) {
                                                eventData["textFieldValues"] = textFieldViews.mapIndexed { idx, editText ->
                                                    mapOf("index" to idx, "value" to (editText.text?.toString() ?: ""))
                                                }
                                            }
                                            propagateEvent(view, "onActionPress", eventData)
                                            dialog.dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Default OK button if no actions provided
            builder.setPositiveButton("OK") { dialog, _ ->
                val eventData = mutableMapOf<String, Any>(
                    "buttonIndex" to 0,
                    "buttonText" to "OK",
                    "buttonStyle" to "default"
                )
                if (textFieldViews.isNotEmpty()) {
                    eventData["textFieldValues"] = textFieldViews.mapIndexed { idx, editText ->
                        mapOf("index" to idx, "value" to (editText.text?.toString() ?: ""))
                    }
                }
                propagateEvent(view, "onActionPress", eventData)
                dialog.dismiss()
            }
        }
        
        val dialog = builder.create()
        
        dialog.setOnDismissListener {
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


    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

