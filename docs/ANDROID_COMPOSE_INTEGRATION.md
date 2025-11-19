# Android Compose Integration

## Overview

DCFlight supports Jetpack Compose for Android components, allowing you to use modern Material Design 3 components while maintaining full compatibility with Yoga layout and the VDOM system.

## Key Principle: ComposeView IS a View

**The fundamental insight:** `ComposeView` extends `View`, which means:
- ✅ Yoga can measure and position it natively
- ✅ No special handling needed in the layout system
- ✅ Works seamlessly with existing framework architecture
- ✅ Framework automatically ensures composition is ready before measurement

## Framework-Level Composition Handling

**CRITICAL:** The framework automatically handles ComposeView composition timing:
- ✅ **YogaShadowTree** ensures ComposeView is composed before `getIntrinsicSize` is called
- ✅ **DCFComposeWrapper** tracks composition readiness
- ✅ **No component-specific code needed** - framework handles it uniformly
- ✅ **No flash or disappearing text** - composition happens before layout

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
│    └─> DCFComposeWrapper(context, ComposeView)          │
│        └─> ComposeView.setContent { Material3Text(...) } │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ Yoga Layout
                       │
┌──────────────────────▼───────────────────────────────────┐
│         YogaShadowTree.setupMeasureFunction()            │
│  • Framework ensures ComposeView is composed            │
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
        // 1. Create ComposeView and wrap it in DCFComposeWrapper
        // DCFComposeWrapper provides composition readiness tracking
        val composeView = ComposeView(context)
        val wrapper = DCFComposeWrapper(context, composeView)
        
        // 2. Tag the wrapper for framework tracking
        wrapper.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // 3. Framework controls visibility - don't set here!
        // Visibility is handled by framework after layout is applied
        
        // 4. Store props for later retrieval
        storeProps(wrapper, props)
        
        // 5. Set Compose content BEFORE measuring
        // Framework calls getIntrinsicSize during layout calculation
        updateComposeContent(composeView, props)
        
        // 6. Apply styles (Yoga layout properties)
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        wrapper.applyStyles(nonNullProps)
        
        return wrapper
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val wrapper = view as? DCFComposeWrapper ?: return false
        val composeView = wrapper.composeView
        
        // CRITICAL: Framework automatically merges props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(wrapper, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Update Compose content with merged props
        updateComposeContent(composeView, mergedProps)
        
        // Update styles
        wrapper.applyStyles(nonNullProps)
        
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

**FRAMEWORK HANDLES COMPOSITION:** The framework ensures ComposeView is composed before `getIntrinsicSize` is called, so you can use **actual measurement**:

```kotlin
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    val wrapper = view as? DCFComposeWrapper ?: return PointF(0f, 0f)
    val composeView = wrapper.composeView
    
    // CRITICAL: Yoga calls getIntrinsicSize with emptyMap(), 
    // so we MUST get props from storedProps
    val storedProps = getStoredProps(view)
    val allProps = if (props.isEmpty()) storedProps else props
    
    val content = allProps["content"]?.toString() ?: ""
    if (content.isEmpty()) {
        return PointF(0f, 0f)
    }
    
    // CRITICAL: Framework ensures ComposeView is composed before this is called
    // (handled in YogaShadowTree.setupMeasureFunction)
    // So we can use actual measurement, not estimation
    
    // Ensure composition is ready (framework does this, but double-check)
    wrapper.ensureCompositionReady()
    
    // Measure the actual ComposeView (like iOS measures UILabel)
    val maxWidth = 10000 // Large but finite width for measurement
    composeView.measure(
        View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
    )
    
    val measuredWidth = composeView.measuredWidth.toFloat()
    val measuredHeight = composeView.measuredHeight.toFloat()
    
    // If measurement returns 0 (rare - framework ensures composition), use fallback
    if (measuredWidth == 0f || measuredHeight == 0f) {
        val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
        val lines = content.split("\n")
        val maxLineLength = lines.maxOfOrNull { it.length } ?: content.length
        val estimatedWidth = maxLineLength * fontSize * 0.6f
        val estimatedHeight = lines.size * fontSize * 1.2f
        return PointF(estimatedWidth.coerceAtLeast(1f), estimatedHeight.coerceAtLeast(1f))
    }
    
    return PointF(measuredWidth.coerceAtLeast(1f), measuredHeight.coerceAtLeast(1f))
}
```

**Why Actual Measurement Works:**
1. **Framework ensures composition** before `getIntrinsicSize` is called (in `YogaShadowTree.setupMeasureFunction`)
2. ComposeView is composed and ready to measure
3. Accurate measurement prevents flash and layout issues
4. Fallback estimation handles edge cases (should be rare)

## Complete Example: Text Component

```kotlin
class DCFTextComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFTextComponent"
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Use DCFComposeWrapper for composition readiness tracking
        val composeView = ComposeView(context)
        val wrapper = DCFComposeWrapper(context, composeView)
        wrapper.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
        
        // Framework controls visibility - don't set here!
        // Visibility is handled by framework after layout is applied
        
        storeProps(wrapper, props)
        
        // CRITICAL: Set content BEFORE measuring to prevent flash
        // Framework calls getIntrinsicSize during layout calculation
        updateComposeContent(composeView, props)
        
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        wrapper.applyStyles(nonNullProps)
        
        return wrapper
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val wrapper = view as? DCFComposeWrapper ?: return false
        val composeView = wrapper.composeView
        
        // CRITICAL: Framework automatically merges props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(wrapper, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        
        // Update Compose content with merged props
        updateComposeContent(composeView, mergedProps)
        
        // Update styles
        wrapper.applyStyles(nonNullProps)
        
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
        val wrapper = view as? DCFComposeWrapper ?: return PointF(0f, 0f)
        val composeView = wrapper.composeView
        
        // Get props from storedProps if empty (Yoga calls with emptyMap())
        val storedProps = getStoredProps(view)
        val allProps = if (props.isEmpty()) storedProps else props
        
        val content = allProps["content"]?.toString() ?: ""
        if (content.isEmpty()) {
            return PointF(0f, 0f)
        }
        
        // CRITICAL: Framework ensures ComposeView is composed before this is called
        // (handled in YogaShadowTree.setupMeasureFunction)
        // So we can use actual measurement
        
        // Ensure composition is ready (framework does this, but double-check)
        wrapper.ensureCompositionReady()
        
        // Measure the actual ComposeView
        val maxWidth = 10000
        composeView.measure(
            View.MeasureSpec.makeMeasureSpec(maxWidth, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        
        val measuredWidth = composeView.measuredWidth.toFloat()
        val measuredHeight = composeView.measuredHeight.toFloat()
        
        // Fallback if measurement returns 0 (should be rare)
        if (measuredWidth == 0f || measuredHeight == 0f) {
            val fontSize = (allProps["fontSize"] as? Number)?.toFloat() ?: 17f
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
        updateComposeContent(composeView, storedProps)
        
        // Force composition to be ready before layout calculation
        if (view.parent != null) {
            wrapper.ensureCompositionReady()
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

### 1. Use DCFComposeWrapper

```kotlin
// ✅ Good - Framework handles composition readiness
val composeView = ComposeView(context)
val wrapper = DCFComposeWrapper(context, composeView)
return wrapper

// ❌ Bad - No composition tracking
val composeView = ComposeView(context)
return composeView
```

### 2. Framework Controls Visibility

```kotlin
// ✅ Good - Framework handles visibility after layout
// Don't set visibility in createView

// ❌ Bad - Don't manually set visibility
composeView.visibility = View.VISIBLE  // Framework does this
```

### 3. Set Content Before Styles

```kotlin
// ✅ Good
updateComposeContent(composeView, props)
composeView.applyStyles(props)

// ❌ Bad - styles might override content
composeView.applyStyles(props)
updateComposeContent(composeView, props)
```

### 4. Don't Use wrapContentSize Modifier

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

### 5. Use Actual Measurement in getIntrinsicSize

```kotlin
// ✅ Good - Framework ensures composition, so use actual measurement
override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
    val wrapper = view as? DCFComposeWrapper ?: return PointF(0f, 0f)
    val composeView = wrapper.composeView
    
    // Framework ensures composition before this is called
    wrapper.ensureCompositionReady()
    
    composeView.measure(...)
    return PointF(composeView.measuredWidth.toFloat(), composeView.measuredHeight.toFloat())
}

// ❌ Bad - Don't use estimation (framework handles composition)
val estimatedWidth = content.length * fontSize * 0.6f
```

### 6. Retrieve Props from storedProps in getIntrinsicSize

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

### 7. Use ColorUtilities for Colors

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
    val wrapper = DCFComposeWrapper(context, composeView)
    wrapper.setTag(DCFTags.COMPONENT_TYPE_KEY, "Text")
    
    // Framework controls visibility - don't set here!
    
    storeProps(wrapper, props)
    updateComposeContent(composeView, props)
    wrapper.applyStyles(props)
    
    return wrapper
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
// ✅ Use DCFComposeWrapper
val wrapper = DCFComposeWrapper(context, composeView)

// ✅ Ensure content is set
updateComposeContent(composeView, props)

// ✅ Framework handles visibility automatically
// Don't manually set visibility - framework does this after layout
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

## Framework-Level Composition Handling

**The framework automatically ensures ComposeView composition is ready before measurement:**

1. **YogaShadowTree.setupMeasureFunction()** - Detects `DCFComposeWrapper` and calls `ensureCompositionReady()` before `getIntrinsicSize`
2. **DCFComposeWrapper** - Tracks composition readiness and provides `ensureCompositionReady()` method
3. **No component-specific code needed** - Framework handles it uniformly for all ComposeView-based components

**Benefits:**
- ✅ **No flash or disappearing text** - Composition happens before layout
- ✅ **Accurate measurement** - Can use actual measurement instead of estimation
- ✅ **Automatic** - Works for all ComposeView components (Text, Button, etc.)
- ✅ **Scalable** - Future ComposeView components automatically benefit

## Summary

✅ **ComposeView is just a View** - Works natively with Yoga  
✅ **Framework handles composition** - No flash, no disappearing text  
✅ **Use DCFComposeWrapper** - Provides composition readiness tracking  
✅ **Modern Material Design 3** - Latest Android components  
✅ **No XML dependencies** - Pure Kotlin implementation  
✅ **Perfect text wrapping** - Compose + Yoga constraints work together  
✅ **Actual measurement** - Framework ensures composition before `getIntrinsicSize`  

The integration is **fully modular and scalable** - any component can use Compose without framework changes, and the framework automatically handles composition timing.

