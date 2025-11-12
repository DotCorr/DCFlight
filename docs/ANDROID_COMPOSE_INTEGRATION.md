# Android Compose Integration

## Overview

DCFlight supports Jetpack Compose for Android components, allowing you to use modern Material Design 3 components while maintaining full compatibility with Yoga layout and the VDOM system.

## Key Principle: ComposeView IS a View

**The fundamental insight:** `ComposeView` extends `View`, which means:
- ✅ Yoga can measure and position it natively
- ✅ No special handling needed in the layout system
- ✅ Works seamlessly with existing framework architecture
- ✅ No wrapper classes or workarounds needed

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              DCF Component (Dart)                       │
│  DCFText(content: "Hello")                              │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ createView()
                       │
┌──────────────────────▼───────────────────────────────────┐
│         Android Component Implementation                 │
│  DCFTextComponent.createView()                          │
│    └─> ComposeView(context)                              │
│        └─> setContent { Material3Text(...) }            │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Yoga Layout
                       │
┌──────────────────────▼───────────────────────────────────┐
│         YogaShadowTree.setupMeasureFunction()            │
│  • Measures ComposeView with constraints                 │
│  • Uses View.MeasureSpec.AT_MOST for wrapping           │
│  • Falls back to getIntrinsicSize() if needed            │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Layout Applied
                       │
┌──────────────────────▼───────────────────────────────────┐
│         Native View Tree                                 │
│  ComposeView (measured & positioned by Yoga)            │
│    └─> Material3Text (rendered by Compose)              │
└───────────────────────────────────────────────────────────┘
```

## Component Implementation Pattern

### Basic Compose Component Structure

```kotlin
class DCFTextComponent : DCFComponent() {
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        // 1. Create ComposeView directly (no wrapper needed)
        val composeView = ComposeView(context)
        
        // 2. Tag the view for framework tracking
        composeView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // 3. CRITICAL: Set visibility explicitly
        composeView.visibility = View.VISIBLE
        composeView.alpha = 1.0f
        
        // 4. Store props for later retrieval
        storeProps(composeView, props)
        
        // 5. Set Compose content
        updateComposeContent(composeView, props)
        
        // 6. Apply styles (Yoga layout properties)
        composeView.applyStyles(props)
        
        return composeView
    }
    
    override fun updateViewInternal(
        view: View, 
        props: Map<String, Any>, 
        existingProps: Map<String, Any>
    ): Boolean {
        val composeView = view as? ComposeView ?: return false
        
        // Update Compose content
        updateComposeContent(composeView, props)
        
        // Update styles
        composeView.applyStyles(props)
        
        return true
    }
    
    private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: 17f
        
        composeView.setContent {
            Material3Text(
                text = content,
                color = textColor ?: Color.Black,
                fontSize = fontSize.sp,
                // ... other props
            )
        }
    }
}
```

## Yoga Layout Integration

### How Yoga Measures ComposeView

Yoga's `setupMeasureFunction` generically measures **any** View with constraints:

```kotlin
// In YogaShadowTree.setupMeasureFunction()

// CRITICAL: Always try to measure view with constraints when available
// This allows components (Text, Button, etc.) to properly wrap/adapt to constraints
// Works for ALL view types, not just ComposeView - fully modular and scalable
if (widthMode != YogaMeasureMode.UNDEFINED || heightMode != YogaMeasureMode.UNDEFINED) {
    // Measure view with constraints for proper sizing/wrapping
    val widthSpec = if (widthMode == YogaMeasureMode.UNDEFINED) {
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    } else {
        View.MeasureSpec.makeMeasureSpec(
            constraintWidth.toInt(),
            View.MeasureSpec.AT_MOST  // Allows wrapping
        )
    }
    
    val heightSpec = if (heightMode == YogaMeasureMode.UNDEFINED) {
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    } else {
        View.MeasureSpec.makeMeasureSpec(
            constraintHeight.toInt(),
            View.MeasureSpec.AT_MOST  // Allows wrapping
        )
    }
    
    view.measure(widthSpec, heightSpec)
    
    // Use measured size if valid
    if (view.measuredWidth > 0 && view.measuredHeight > 0) {
        return YogaMeasureOutput.make(
            view.measuredWidth.toFloat(),
            view.measuredHeight.toFloat()
        )
    }
}

// Fallback: Use intrinsic size
val intrinsicSize = componentInstance.getIntrinsicSize(view, emptyMap())
return YogaMeasureOutput.make(intrinsicSize.x, intrinsicSize.y)
```

**Key Points:**
- ✅ Uses `View.MeasureSpec.AT_MOST` for wrapping
- ✅ Works for **all** View types (not Compose-specific)
- ✅ ComposeView wraps content correctly when constrained
- ✅ Falls back to `getIntrinsicSize()` if measurement fails

## getIntrinsicSize Pattern for Compose

Since Compose content can't be measured before it's laid out, use **estimation**:

```kotlin
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    // CRITICAL: Yoga calls getIntrinsicSize with emptyMap(), 
    // so we MUST get props from storedProps
    val storedProps = getStoredProps(view)
    val allProps = if (props.isEmpty()) storedProps else props
    
    val content = allProps["content"]?.toString() ?: ""
    if (content.isEmpty()) {
        return PointF(0f, 0f)
    }
    
    // Estimation based on content length and font size
    val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
    
    // For text wrapping: Return preferred width (single line estimate)
    // Yoga will constrain this based on parent width, and Compose Text will wrap
    val preferredWidth = content.length * fontSize * 0.6f
    
    // Height: single line height (text will grow vertically when wrapping)
    val singleLineHeight = fontSize * 1.2f
    
    // Ensure minimum size
    val finalWidth = preferredWidth.coerceAtLeast(1f)
    val finalHeight = singleLineHeight.coerceAtLeast(1f)
    
    return PointF(finalWidth, finalHeight)
}
```

**Why Estimation Works:**
1. Yoga uses this for initial layout calculation
2. When constraints are available, Yoga measures the actual view
3. Compose Text wraps correctly when given width constraints
4. Final size is determined by actual measurement, not estimation

## Complete Example: Text Component

```kotlin
class DCFTextComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFTextComponent"
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val composeView = ComposeView(context)
        composeView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // CRITICAL: Set visibility explicitly
        composeView.visibility = View.VISIBLE
        composeView.alpha = 1.0f
        
        storeProps(composeView, props)
        
        // Set content BEFORE applying styles
        updateComposeContent(composeView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        composeView.applyStyles(nonNullProps)
        
        return composeView
    }
    
    override fun updateViewInternal(
        view: View, 
        props: Map<String, Any>, 
        existingProps: Map<String, Any>
    ): Boolean {
        val composeView = view as? ComposeView ?: return false
        
        // Always update content to ensure text is visible
        updateComposeContent(composeView, props)
        
        composeView.applyStyles(props)
        
        return true
    }
    
    private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
        val content = props["content"]?.toString() ?: ""
        val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
        val fontSize = (props["fontSize"] as? Number)?.toFloat() ?: 17f
        val fontWeight = fontWeightFromString(props["fontWeight"]?.toString() ?: "regular")
        val textAlign = textAlignFromString(props["textAlign"]?.toString() ?: "start")
        val maxLines = (props["numberOfLines"] as? Number)?.toInt() ?: Int.MAX_VALUE
        
        // Get default color based on theme
        val context = composeView.context
        val isDarkTheme = (context.resources.configuration.uiMode and 
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) == 
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val defaultColor = if (isDarkTheme) android.graphics.Color.WHITE else android.graphics.Color.BLACK
        val finalColor = textColor ?: defaultColor
        
        composeView.setContent {
            Material3Text(
                text = content,
                color = Color(finalColor),
                fontSize = fontSize.sp,
                fontWeight = fontWeight,
                textAlign = textAlign,
                maxLines = maxLines,
                // NO Modifier.wrapContentSize() - constraints come from Yoga
            )
        }
    }
    
    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        // Get props from storedProps if empty (Yoga calls with emptyMap())
        val storedProps = getStoredProps(view)
        val allProps = if (props.isEmpty()) storedProps else props
        
        val content = allProps["content"]?.toString() ?: ""
        if (content.isEmpty()) {
            return PointF(0f, 0f)
        }
        
        val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
        
        // Estimation for Yoga's initial layout
        val preferredWidth = content.length * fontSize * 0.6f
        val singleLineHeight = fontSize * 1.2f
        
        return PointF(
            preferredWidth.coerceAtLeast(1f),
            singleLineHeight.coerceAtLeast(1f)
        )
    }
    
    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        // Ensure content is set after registration
        val composeView = view as? ComposeView
        val props = getStoredProps(composeView)
        if (props.isNotEmpty()) {
            updateComposeContent(composeView, props)
        }
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null  // No tunnel methods needed
    }
}
```

## Benefits of Compose Integration

### 1. Modern Material Design 3
- ✅ Latest Material Design components
- ✅ Consistent with Android best practices
- ✅ Future-proof architecture

### 2. No XML Resources
- ✅ Pure Kotlin implementation
- ✅ No XML ID dependencies
- ✅ Fully modular and scalable

### 3. Perfect Yoga Integration
- ✅ ComposeView is just a View
- ✅ Yoga measures it natively
- ✅ No special handling needed

### 4. Text Wrapping
- ✅ Compose Text wraps correctly
- ✅ Yoga provides width constraints
- ✅ Automatic line breaking

## Best Practices

### 1. Always Set Visibility Explicitly

```kotlin
// ✅ Good
composeView.visibility = View.VISIBLE
composeView.alpha = 1.0f

// ❌ Bad - might be invisible
val composeView = ComposeView(context)
```

### 2. Set Content Before Styles

```kotlin
// ✅ Good
updateComposeContent(composeView, props)
composeView.applyStyles(props)

// ❌ Bad - styles might override content
composeView.applyStyles(props)
updateComposeContent(composeView, props)
```

### 3. Don't Use wrapContentSize Modifier

```kotlin
// ✅ Good - constraints come from Yoga
Material3Text(
    text = content,
    // NO Modifier.wrapContentSize()
)

// ❌ Bad - interferes with Yoga constraints
Material3Text(
    text = content,
    modifier = Modifier.wrapContentSize()  // Don't do this
)
```

### 4. Retrieve Props from storedProps in getIntrinsicSize

```kotlin
// ✅ Good - handles emptyMap() from Yoga
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    val storedProps = getStoredProps(view)
    val allProps = if (props.isEmpty()) storedProps else props
    // Use allProps...
}

// ❌ Bad - props might be empty
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    val content = props["content"]?.toString()  // Might be null!
}
```

### 5. Use ColorUtilities for Colors

```kotlin
// ✅ Good - supports explicit + semantic colors
val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)

// ❌ Bad - only explicit colors
val textColor = props["textColor"] as? String
```

## Migration from Traditional Views

### Before (Traditional View)

```kotlin
override fun createView(context: Context, props: Map<String, Any?>): View {
    val textView = TextView(context)
    props["content"]?.let { textView.text = it.toString() }
    props["textColor"]?.let { 
        val color = ColorUtilities.parseColor(it.toString())
        textView.setTextColor(color)
    }
    return textView
}
```

### After (Compose)

```kotlin
override fun createView(context: Context, props: Map<String, Any?>): View {
    val composeView = ComposeView(context)
    composeView.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
    composeView.visibility = View.VISIBLE
    composeView.alpha = 1.0f
    
    storeProps(composeView, props)
    updateComposeContent(composeView, props)
    composeView.applyStyles(props)
    
    return composeView
}

private fun updateComposeContent(composeView: ComposeView, props: Map<String, Any?>) {
    val content = props["content"]?.toString() ?: ""
    val textColor = ColorUtilities.getColor("textColor", "primaryColor", props)
    
    composeView.setContent {
        Material3Text(
            text = content,
            color = Color(textColor ?: Color.Black),
        )
    }
}
```

## Current Compose Components

- ✅ **DCFTextComponent** - Full Compose implementation
- ✅ **DCFButtonComponent** - Full Compose implementation

## Future Components

Any component can use Compose:
- ✅ Same protocol (DCFComponent)
- ✅ Same Yoga integration
- ✅ Same measurement pattern
- ✅ No special handling needed

## Troubleshooting

### Text Not Visible

**Problem:** Compose content not showing

**Solution:**
```kotlin
// Ensure visibility is set
composeView.visibility = View.VISIBLE
composeView.alpha = 1.0f

// Ensure content is set
updateComposeContent(composeView, props)
```

### Text Not Wrapping

**Problem:** Text overflows container

**Solution:**
- ✅ Don't use `Modifier.wrapContentSize()`
- ✅ Let Yoga provide width constraints
- ✅ Compose Text will wrap automatically

### getIntrinsicSize Returns 0

**Problem:** Component has zero size

**Solution:**
```kotlin
// Always retrieve props from storedProps
val storedProps = getStoredProps(view)
val allProps = if (props.isEmpty()) storedProps else props

// Return minimum size
return PointF(
    preferredWidth.coerceAtLeast(1f),
    preferredHeight.coerceAtLeast(1f)
)
```

## Summary

✅ **ComposeView is just a View** - Works natively with Yoga  
✅ **No special handling needed** - Generic measurement works for all Views  
✅ **Modern Material Design 3** - Latest Android components  
✅ **No XML dependencies** - Pure Kotlin implementation  
✅ **Perfect text wrapping** - Compose + Yoga constraints work together  

The integration is **fully modular and scalable** - any component can use Compose without framework changes.

