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
 import android.text.Editable
 import android.text.InputType
 import android.text.TextWatcher
 import android.util.Log
 import android.util.TypedValue
 import android.view.View
 import android.view.inputmethod.EditorInfo
 import android.widget.EditText
 import androidx.appcompat.widget.AppCompatEditText
 import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
 import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.components.DCFPrimitiveTags
 import com.dotcorr.dcflight.utils.ColorUtilities
 import com.dotcorr.dcflight.components.propagateEvent
 import com.dotcorr.dcf_primitives.components.dpToPx
 import com.dotcorr.dcf_primitives.components.parseColor
 import kotlin.math.max
 
 class DCFTextInputComponent : DCFComponent() {
 
     override fun createView(context: Context, props: Map<String, Any?>): View {
         val editText = AppCompatEditText(context)
 
         ColorUtilities.getColor("textColor", "primaryColor", props)?.let { colorInt ->
             editText.setTextColor(colorInt)
         }
         
         ColorUtilities.getColor("placeholderColor", "secondaryColor", props)?.let { colorInt ->
             editText.setHintTextColor(colorInt)
         }
         
         ColorUtilities.getColor("selectionColor", "accentColor", props)?.let { colorInt ->
             editText.setHighlightColor(colorInt)
         }
 
         editText.setPadding(
             dpToPx(12f, context),
             dpToPx(8f, context),
             dpToPx(12f, context),
             dpToPx(8f, context)
         )
 
         updateView(editText, props)
 
         val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
         editText.applyStyles(nonNullStyleProps)
 
         editText.setTag(DCFTags.COMPONENT_TYPE_KEY, "TextInput")
 
         return editText
     }
 
     override fun updateView(view: View, props: Map<String, Any?>): Boolean {
         val editText = view as? AppCompatEditText ?: return false
         
         // CRITICAL: Merge new props with existing stored props to preserve all properties
         val existingProps = getStoredProps(view)
         val mergedProps = mergeProps(existingProps, props)
         storeProps(view, mergedProps)
         
         val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

         mergedProps["value"]?.let { value ->
             val currentText = editText.text?.toString() ?: ""
             val newText = value.toString()
             if (currentText != newText) {
                 editText.setText(newText)
                 editText.setSelection(newText.length)
             }
         }

         mergedProps["placeholder"]?.let { placeholder ->
             editText.hint = placeholder.toString()
         }

         ColorUtilities.getColor("textColor", "primaryColor", nonNullProps)?.let { colorInt ->
             editText.setTextColor(colorInt)
         }

         ColorUtilities.getColor("placeholderColor", "secondaryColor", nonNullProps)?.let { colorInt ->
             editText.setHintTextColor(colorInt)
         }

         ColorUtilities.getColor("selectionColor", "accentColor", nonNullProps)?.let { colorInt ->
             editText.setHighlightColor(colorInt)
         }
 
         mergedProps["fontSize"]?.let { size ->
             when (size) {
                 is Number -> editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, size.toFloat())
                 is String -> {
                     size.removeSuffix("sp").toFloatOrNull()?.let { fontSize ->
                         editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize)
                     }
                 }
             }
         }
 
         mergedProps["keyboardType"]?.let { type ->
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
 
         mergedProps["secureTextEntry"]?.let { secure ->
             when (secure) {
                 is Boolean -> {
                     if (secure) {
                         editText.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                     }
                 }
             }
         }
 
         mergedProps["autoCapitalization"]?.let { capitalize ->
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
 
         mergedProps["autoCorrect"]?.let { autoCorrect ->
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
 
         mergedProps["maxLength"]?.let { maxLength ->
             when (maxLength) {
                 is Number -> {
                     val filters = editText.filters?.toMutableList() ?: mutableListOf()
                     filters.removeAll { it is android.text.InputFilter.LengthFilter }
                     filters.add(android.text.InputFilter.LengthFilter(maxLength.toInt()))
                     editText.filters = filters.toTypedArray()
                 }
             }
         }
 
         mergedProps["multiline"]?.let { multiline ->
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
 
         mergedProps["numberOfLines"]?.let { lines ->
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
 
         mergedProps["editable"]?.let { editable ->
             when (editable) {
                 is Boolean -> {
                     editText.isFocusable = editable
                     editText.isFocusableInTouchMode = editable
                     editText.isClickable = editable
                     editText.isCursorVisible = editable
                 }
             }
         }
 
         mergedProps["selection"]?.let { selection ->
             when (selection) {
                 is Map<*, *> -> {
                     val start = (selection["start"] as? Number)?.toInt() ?: 0
                     val end = (selection["end"] as? Number)?.toInt() ?: start
                     try {
                         editText.setSelection(start, end)
                     } catch (e: IndexOutOfBoundsException) {
                     }
                 }
             }
         }
 
         mergedProps["returnKeyType"]?.let { returnKey ->
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
 
         mergedProps["textAlign"]?.let { align ->
             editText.textAlignment = when (align) {
                 "center" -> View.TEXT_ALIGNMENT_CENTER
                 "right", "end" -> View.TEXT_ALIGNMENT_TEXT_END
                 "left", "start" -> View.TEXT_ALIGNMENT_TEXT_START
                 else -> View.TEXT_ALIGNMENT_TEXT_START
             }
         }
 
         mergedProps["blurOnSubmit"]?.let { blurOnSubmit ->
             when (blurOnSubmit) {
                 is Boolean -> {
                     editText.setTag(DCFPrimitiveTags.TEXT_INPUT_BLUR_ON_SUBMIT_KEY, blurOnSubmit)
                 }
             }
         }
 
         mergedProps["onChangeText"]?.let { onChange ->
             removeTextWatcher(editText)
 
             val textWatcher = object : TextWatcher {
                 override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
 
                 override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
 
                 override fun afterTextChanged(s: Editable?) {
                     propagateEvent(editText, "onChangeText", mapOf(
                         "text" to (s?.toString() ?: ""),
                         "length" to (s?.length ?: 0)
                     ))
                 }
             }
 
             editText.addTextChangedListener(textWatcher)
             editText.setTag(DCFPrimitiveTags.TEXT_INPUT_WATCHER_KEY, textWatcher)
         }
 
         mergedProps["onFocus"]?.let { onFocus ->
             editText.setOnFocusChangeListener { _, hasFocus ->
                 if (hasFocus) {
                     editText.setTag(DCFPrimitiveTags.TEXT_INPUT_FOCUS_LISTENER_KEY, onFocus)
                 }
             }
         }
 
         mergedProps["onBlur"]?.let { onBlur ->
             editText.setOnFocusChangeListener { _, hasFocus ->
                 if (!hasFocus) {
                     editText.setTag(DCFPrimitiveTags.TEXT_INPUT_FOCUS_LISTENER_KEY, onBlur)
                 }
             }
         }
 
         mergedProps["onSubmitEditing"]?.let { onSubmit ->
             editText.setOnEditorActionListener { _, actionId, _ ->
                 if (actionId == EditorInfo.IME_ACTION_DONE ||
                     actionId == EditorInfo.IME_ACTION_GO ||
                     actionId == EditorInfo.IME_ACTION_SEARCH ||
                     actionId == EditorInfo.IME_ACTION_SEND
                 ) {
 
                     editText.setTag(DCFTags.EVENT_CALLBACK_KEY, onSubmit)
 
                     val shouldBlur = editText.getTag(DCFPrimitiveTags.TEXT_INPUT_BLUR_ON_SUBMIT_KEY) as? Boolean ?: true
                     if (shouldBlur) {
                         editText.clearFocus()
                     }
 
                     true
                 } else {
                     false
                 }
             }
         }
 
         mergedProps["accessibilityLabel"]?.let { label ->
             editText.contentDescription = label.toString()
         }
 
         mergedProps["testID"]?.let { testId ->
             editText.setTag(DCFPrimitiveTags.TEST_ID_KEY, testId)
         }

         editText.setTag(DCFPrimitiveTags.TEXT_INPUT_PLACEHOLDER_KEY, mergedProps["placeholder"])
         editText.applyStyles(nonNullProps)

         return true
     }
 
     private fun removeTextWatcher(editText: EditText) {
         val existingWatcher = editText.getTag(DCFPrimitiveTags.TEXT_INPUT_WATCHER_KEY) as? TextWatcher
         existingWatcher?.let {
             editText.removeTextChangedListener(it)
             editText.setTag(DCFPrimitiveTags.TEXT_INPUT_WATCHER_KEY, null)
         }
     }
 
 
     override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
         val editText = view as? EditText ?: return PointF(0f, 0f)
 
         editText.measure(
             View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
             View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
         )
 
         val measuredWidth = editText.measuredWidth.toFloat()
         val measuredHeight = editText.measuredHeight.toFloat()
 
         return PointF(max(1f, measuredWidth), max(1f, measuredHeight))
     }
 
     override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
         Log.d("DCFTextInputComponent", "TextInput component registered with shadow tree: $nodeId")
     }
 
     override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
         return null
     }
 }
 
 