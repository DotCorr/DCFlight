/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.TypedValue
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import androidx.appcompat.widget.AppCompatEditText
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFTextInputComponent - Text input component matching iOS DCFTextInputComponent
 */
class DCFTextInputComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val editText = AppCompatEditText(context)

        // Default styling
        editText.setPadding(
            dpToPx(context, 12f),
            dpToPx(context, 8f),
            dpToPx(context, 12f),
            dpToPx(context, 8f)
        )

        // Apply props
        updateView(editText, props)

        // Apply StyleSheet properties
        editText.applyStyles(props)

        // Store component type
        editText.setTag(R.id.dcf_component_type, "TextInput")

        return editText
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val editText = view as? AppCompatEditText ?: return false

        // Text value
        props["value"]?.let { value ->
            val currentText = editText.text?.toString() ?: ""
            val newText = value.toString()
            if (currentText != newText) {
                editText.setText(newText)
                editText.setSelection(newText.length)
            }
        }

        // Placeholder
        props["placeholder"]?.let { placeholder ->
            editText.hint = placeholder.toString()
        }

        // Placeholder text color
        props["placeholderTextColor"]?.let { color ->
            when (color) {
                is String -> {
                    try {
                        editText.setHintTextColor(Color.parseColor(color))
                    } catch (e: IllegalArgumentException) {
                        // Invalid color
                    }
                }

                is Int -> editText.setHintTextColor(color)
            }
        }

        // Text color
        props["color"]?.let { color ->
            when (color) {
                is String -> {
                    try {
                        editText.setTextColor(Color.parseColor(color))
                    } catch (e: IllegalArgumentException) {
                        // Invalid color
                    }
                }

                is Int -> editText.setTextColor(color)
            }
        }

        // Font size
        props["fontSize"]?.let { size ->
            when (size) {
                is Number -> editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, size.toFloat())
                is String -> {
                    size.removeSuffix("sp").toFloatOrNull()?.let { fontSize ->
                        editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize)
                    }
                }
            }
        }

        // Keyboard type
        props["keyboardType"]?.let { type ->
            editText.inputType = when (type) {
                "default" -> InputType.TYPE_CLASS_TEXT
                "number-pad", "numeric" -> InputType.TYPE_CLASS_NUMBER
                "decimal-pad" -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                "phone-pad" -> InputType.TYPE_CLASS_PHONE
                "email-address" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                "url" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                "visible-password" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                else -> InputType.TYPE_CLASS_TEXT
            }
        }

        // Secure text entry
        props["secureTextEntry"]?.let { secure ->
            when (secure) {
                is Boolean -> {
                    if (secure) {
                        editText.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                    }
                }
            }
        }

        // Auto capitalize
        props["autoCapitalize"]?.let { capitalize ->
            val currentInputType = editText.inputType
            editText.inputType = when (capitalize) {
                "none" -> currentInputType and InputType.TYPE_TEXT_FLAG_CAP_SENTENCES.inv() and
                        InputType.TYPE_TEXT_FLAG_CAP_WORDS.inv() and
                        InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS.inv()

                "sentences" -> currentInputType or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                "words" -> currentInputType or InputType.TYPE_TEXT_FLAG_CAP_WORDS
                "characters" -> currentInputType or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
                else -> currentInputType
            }
        }

        // Auto correct
        props["autoCorrect"]?.let { autoCorrect ->
            when (autoCorrect) {
                is Boolean -> {
                    val currentInputType = editText.inputType
                    editText.inputType = if (autoCorrect) {
                        currentInputType and InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS.inv()
                    } else {
                        currentInputType or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                    }
                }
            }
        }

        // Max length
        props["maxLength"]?.let { maxLength ->
            when (maxLength) {
                is Number -> {
                    val filters = editText.filters?.toMutableList() ?: mutableListOf()
                    filters.removeAll { it is android.text.InputFilter.LengthFilter }
                    filters.add(android.text.InputFilter.LengthFilter(maxLength.toInt()))
                    editText.filters = filters.toTypedArray()
                }
            }
        }

        // Multiline
        props["multiline"]?.let { multiline ->
            when (multiline) {
                is Boolean -> {
                    if (multiline) {
                        editText.inputType = editText.inputType or InputType.TYPE_TEXT_FLAG_MULTI_LINE
                        editText.setSingleLine(false)
                        editText.minLines = 2
                    } else {
                        editText.inputType = editText.inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE.inv()
                        editText.setSingleLine(true)
                    }
                }
            }
        }

        // Number of lines
        props["numberOfLines"]?.let { lines ->
            when (lines) {
                is Number -> {
                    val numLines = lines.toInt()
                    if (numLines > 1) {
                        editText.minLines = numLines
                        editText.maxLines = numLines
                    }
                }
            }
        }

        // Editable
        props["editable"]?.let { editable ->
            when (editable) {
                is Boolean -> {
                    editText.isFocusable = editable
                    editText.isFocusableInTouchMode = editable
                    editText.isClickable = editable
                    editText.isCursorVisible = editable
                }
            }
        }

        // Selection
        props["selection"]?.let { selection ->
            when (selection) {
                is Map<*, *> -> {
                    val start = (selection["start"] as? Number)?.toInt() ?: 0
                    val end = (selection["end"] as? Number)?.toInt() ?: start
                    try {
                        editText.setSelection(start, end)
                    } catch (e: IndexOutOfBoundsException) {
                        // Invalid selection range
                    }
                }
            }
        }

        // Return key type
        props["returnKeyType"]?.let { returnKey ->
            editText.imeOptions = when (returnKey) {
                "done" -> EditorInfo.IME_ACTION_DONE
                "go" -> EditorInfo.IME_ACTION_GO
                "next" -> EditorInfo.IME_ACTION_NEXT
                "search" -> EditorInfo.IME_ACTION_SEARCH
                "send" -> EditorInfo.IME_ACTION_SEND
                "previous" -> EditorInfo.IME_ACTION_PREVIOUS
                else -> EditorInfo.IME_ACTION_UNSPECIFIED
            }
        }

        // Text alignment
        props["textAlign"]?.let { align ->
            editText.textAlignment = when (align) {
                "center" -> View.TEXT_ALIGNMENT_CENTER
                "right", "end" -> View.TEXT_ALIGNMENT_TEXT_END
                "left", "start" -> View.TEXT_ALIGNMENT_TEXT_START
                else -> View.TEXT_ALIGNMENT_TEXT_START
            }
        }

        // Blur on submit
        props["blurOnSubmit"]?.let { blurOnSubmit ->
            when (blurOnSubmit) {
                is Boolean -> {
                    editText.setTag(R.id.dcf_text_input_blur_on_submit, blurOnSubmit)
                }
            }
        }

        // Handle text change events
        props["onChangeText"]?.let { onChange ->
            removeTextWatcher(editText)

            val textWatcher = object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}

                override fun afterTextChanged(s: Editable?) {
                    // Store the callback for event handling
                    editText.setTag(R.id.dcf_event_callback, onChange)
                    // The actual callback would be handled by the framework
                }
            }

            editText.addTextChangedListener(textWatcher)
            editText.setTag(R.id.dcf_text_input_watcher, textWatcher)
        }

        // Handle focus events
        props["onFocus"]?.let { onFocus ->
            editText.setOnFocusChangeListener { _, hasFocus ->
                if (hasFocus) {
                    editText.setTag(R.id.dcf_text_input_focus_listener, onFocus)
                    // The actual callback would be handled by the framework
                }
            }
        }

        // Handle blur events
        props["onBlur"]?.let { onBlur ->
            editText.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    editText.setTag(R.id.dcf_text_input_focus_listener, onBlur)
                    // The actual callback would be handled by the framework
                }
            }
        }

        // Handle submit events
        props["onSubmitEditing"]?.let { onSubmit ->
            editText.setOnEditorActionListener { _, actionId, _ ->
                if (actionId == EditorInfo.IME_ACTION_DONE ||
                    actionId == EditorInfo.IME_ACTION_GO ||
                    actionId == EditorInfo.IME_ACTION_SEARCH ||
                    actionId == EditorInfo.IME_ACTION_SEND
                ) {

                    editText.setTag(R.id.dcf_event_callback, onSubmit)

                    // Check if should blur on submit
                    val shouldBlur = editText.getTag(R.id.dcf_text_input_blur_on_submit) as? Boolean ?: true
                    if (shouldBlur) {
                        editText.clearFocus()
                    }

                    true
                } else {
                    false
                }
            }
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            editText.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            editText.setTag(R.id.dcf_test_id, testId)
        }

        // Store placeholder for potential reuse
        editText.setTag(R.id.dcf_text_input_placeholder, props["placeholder"])

        return true
    }

    private fun removeTextWatcher(editText: EditText) {
        val existingWatcher = editText.getTag(R.id.dcf_text_input_watcher) as? TextWatcher
        existingWatcher?.let {
            editText.removeTextChangedListener(it)
            editText.setTag(R.id.dcf_text_input_watcher, null)
        }
    }

    private fun dpToPx(context: Context, dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            context.resources.displayMetrics
        ).toInt()
    }
}
