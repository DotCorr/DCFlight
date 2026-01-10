/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.extensions.applyStyles

// Note: ScrollViewKey is defined in DCFScrollView.kt as a companion object
// Both files use the same key via ScrollViewKey.KEY

/**
 * DCFScrollContentViewComponent - Content view component manager
 * 
 * This component creates the content view that wraps ScrollView's children.
 * Yoga will layout this view, and the ScrollView will use its frame.size
 * as the contentSize.
 */
class DCFScrollContentViewComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFScrollContentViewComponent"
    }
    
    override fun createView(context: Context, props: Map<String, Any?>): View {
        val contentView = DCFScrollContentView(context)
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        contentView.applyStyles(nonNullProps)
        return contentView
    }
    
    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        view.applyStyles(nonNullProps)
        return true
    }
    
    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        // CRITICAL: Ensure ScrollContentView itself is visible
        // This is essential - if the content view is invisible, children won't be drawn even if they're visible
        // iOS views are visible by default, but Android views start as INVISIBLE
        // This must be done BEFORE applying layout to ensure the view is ready to display content
        if (view.visibility != View.VISIBLE) {
            view.visibility = View.VISIBLE
            Log.d(TAG, "✅ DCFScrollContentViewComponent.applyLayout: Made ScrollContentView visible")
        }
        if (view.alpha < 1.0f) {
            view.alpha = 1.0f
        }
        
        // Apply Yoga layout to content view
        // The ScrollView will read this view's frame.size to set contentSize
        // CRITICAL: ScrollContentView should always start at (0, 0) relative to ScrollView
        // Yoga may calculate a negative Y position, but we need to reset it to 0 (matches iOS 1:1)
        // This matches iOS DCFScrollContentViewComponent.applyLayout behavior exactly
        // The height should be determined by children, not constrained
        val frame = Rect(
            0, // Always start at x=0 relative to ScrollView (ignore Yoga's calculated left)
            0, // Always start at y=0 relative to ScrollView (ignore Yoga's calculated top)
            kotlin.math.max(0f, layout.width).toInt(), // Use Yoga's calculated width
            kotlin.math.max(0f, layout.height).toInt() // Use Yoga's calculated height (should grow with children)
        )
        
        // CRITICAL: Store the frame in a tag so we can restore it after attachment
        // Android may reset the frame when the view is added to a parent
        val pendingFrameKey = "pendingFrame".hashCode()
        view.setTag(pendingFrameKey, frame)
        
        // CRITICAL: Set layout params to match the frame size
        // This ensures NestedScrollView can properly measure the contentView
        // CRITICAL: NestedScrollView extends FrameLayout, so it expects FrameLayout.LayoutParams
        // CRITICAL: For scrolling to work, contentView must have an explicit height from Yoga
        // NestedScrollView will compare the child's height to its own height to determine if scrolling is needed
        // Use MATCH_PARENT for width and explicit height from Yoga for height
        // If height is 0 or invalid, use WRAP_CONTENT as fallback
        val layoutParamsHeight = if (frame.height() > 0) {
            frame.height()
        } else {
            ViewGroup.LayoutParams.WRAP_CONTENT
        }
        view.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            layoutParamsHeight
        )
        Log.d(TAG, "🔍 DCFScrollContentViewComponent.applyLayout: Using MATCH_PARENT width and explicit height=$layoutParamsHeight (Yoga frame: width=${frame.width()}, height=${frame.height()})")
        
        // CRITICAL: Set frame directly (applyLayout is called on main thread from DCFLayoutManager)
        // Use measure + layout to ensure frame is applied correctly (matches iOS CATransaction pattern)
        // Measure first to ensure view has correct size
        if (frame.width() > 0 && frame.height() > 0) {
            view.measure(
                android.view.View.MeasureSpec.makeMeasureSpec(frame.width(), android.view.View.MeasureSpec.EXACTLY),
                android.view.View.MeasureSpec.makeMeasureSpec(frame.height(), android.view.View.MeasureSpec.EXACTLY)
            )
        }
        
        // Layout the view at (0, 0) relative to parent
        // CRITICAL: Even if view doesn't have parent yet, set the frame so it's ready when attached
        if (view.parent != null || view.rootView != null) {
            view.layout(
                frame.left,
                frame.top,
                frame.right,
                frame.bottom
            )
        }
        
        // Force layout to ensure frame is applied
        view.requestLayout()
        
        // CRITICAL: Always restore frame if it's zero or doesn't match, regardless of attachment status
        // This handles the case where applyLayout runs before or after setChildren
        val needsFrameRestoreKey = "needsFrameRestore".hashCode()
        val needsFrameRestore = view.getTag(needsFrameRestoreKey) as? Boolean ?: false
        val actualFrame = Rect(view.left, view.top, view.right, view.bottom)
        if (view.width == 0 || view.height == 0 || actualFrame != frame || needsFrameRestore) {
            // Retry layout - view might have been attached since last attempt
            if (view.parent != null || view.rootView != null) {
                if (frame.width() > 0 && frame.height() > 0) {
                    view.measure(
                        android.view.View.MeasureSpec.makeMeasureSpec(frame.width(), android.view.View.MeasureSpec.EXACTLY),
                        android.view.View.MeasureSpec.makeMeasureSpec(frame.height(), android.view.View.MeasureSpec.EXACTLY)
                    )
                }
                view.layout(
                    frame.left,
                    frame.top,
                    frame.right,
                    frame.bottom
                )
                view.requestLayout()
            } else {
            }
            
            // Clear the needsFrameRestore flag
            view.setTag(needsFrameRestoreKey, null)
        }
        
        Log.d(TAG, "🔍 DCFScrollContentViewComponent.applyLayout: Set frame=$frame, actualFrame=$actualFrame, parent=${view.parent?.javaClass?.simpleName ?: "nil"}")
        
        // CRITICAL: Find ScrollView and update contentSize AND expectedContentHeight
        // ALWAYS use stored reference first (set by insertContentView) - this is the most reliable method
        // The stored reference is set BEFORE the view is added to the hierarchy, so it's always available
        val scrollViewKey = ScrollViewKey.KEY.hashCode()
        var scrollView = view.getTag(scrollViewKey) as? DCFScrollView
        
        // Fallback: Try to find through hierarchy if stored reference is nil
        if (scrollView == null) {
            // Method 1: Through DCFCustomScrollView (normal case)
            val parent = view.parent
            if (parent is DCFCustomScrollView) {
                val parentParent = parent.parent
                if (parentParent is DCFScrollView) {
                    scrollView = parentParent
                }
            }
            
            // Method 2: Direct parent (fallback)
            if (scrollView == null && parent is DCFScrollView) {
                scrollView = parent
            }
            
            // Method 3: Walk up the hierarchy to find DCFScrollView
            if (scrollView == null) {
                var currentView: View? = parent as? View
                while (currentView != null) {
                    if (currentView is DCFScrollView) {
                        scrollView = currentView
                        break
                    }
                    currentView = currentView.parent as? View
                }
            }
        }
        
        // Update contentSize AND expectedContentHeight if ScrollView found
        scrollView?.let { sv ->
            // CRITICAL: Ensure frame is correct before updating contentSize
            // The frame might have been reset by Android, so restore it if needed
            val actualFrame = Rect(view.left, view.top, view.right, view.bottom)
            if (view.width == 0 || view.height == 0 || actualFrame != frame) {
                view.layout(
                    frame.left,
                    frame.top,
                    frame.right,
                    frame.bottom
                )
                view.requestLayout()
            }
            
            // 🔥 CRITICAL: Always set expectedContentHeight, even if it's the same
            // This ensures ScrollView re-measures if it measured to 0 before
            // This fixes the red background issue when navigating to examples
            if (frame.height() > 0) {
                val newHeight = frame.height().toInt()
                val customScrollView = sv.scrollView
                val oldHeight = customScrollView.expectedContentHeight
                
                // 🔥 CRITICAL: Update content view's layout params BEFORE setting expectedContentHeight
                // This ensures the content view has the correct size when ScrollView re-measures
                // This fixes the red background issue when navigating to examples
                if (view.layoutParams != null) {
                    view.layoutParams.height = newHeight
                    view.layoutParams.width = ViewGroup.LayoutParams.MATCH_PARENT
                } else {
                    view.layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        newHeight
                    )
                }
                
                customScrollView.expectedContentHeight = newHeight
                
                // Force re-measurement if ScrollView measured to 0 before
                if (oldHeight == 0 && newHeight > 0) {
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.applyLayout: expectedContentHeight changed from 0 to $newHeight, forcing re-measurement (layout params updated)")
                    // Use post to ensure layout params are applied before re-measurement
                    customScrollView.post {
                        customScrollView.requestLayout()
                    }
                }
            }
            
            val storedRefSet = view.getTag(scrollViewKey) != null
            Log.d(TAG, "✅ DCFScrollContentViewComponent.applyLayout: Found ScrollView (stored=$storedRefSet), contentView.frame=$actualFrame, updating contentSize")
            sv.updateContentSizeFromContentView()
            
            // CRITICAL: Only request layout if content size actually changed
            // The expectedContentHeight setter already handles layout requests when needed
            // No need for aggressive forceLayout/requestLayout calls that cause loops
        } ?: run {
            // If not found, the view might not be attached yet or stored reference wasn't set
            // Use async to retry after a brief delay to ensure attachment is complete
            Handler(Looper.getMainLooper()).post {
                val contentView = view
                
                // CRITICAL: Always restore frame first - it might have been reset
                val actualFrame = Rect(contentView.left, contentView.top, contentView.right, contentView.bottom)
                if (contentView.width == 0 || contentView.height == 0 || actualFrame != frame) {
                    contentView.layout(
                        frame.left,
                        frame.top,
                        frame.right,
                        frame.bottom
                    )
                    contentView.requestLayout()
                }
                
                // Try to find ScrollView using stored reference first (most reliable)
                var foundScrollView = contentView.getTag(scrollViewKey) as? DCFScrollView
                
                // Fallback: Try hierarchy
                if (foundScrollView == null) {
                    val parent = contentView.parent
                    if (parent is DCFCustomScrollView) {
                        val parentParent = parent.parent
                        if (parentParent is DCFScrollView) {
                            foundScrollView = parentParent
                        }
                    }
                    
                    if (foundScrollView == null && parent is DCFScrollView) {
                        foundScrollView = parent
                    }
                    
                    if (foundScrollView == null) {
                        var currentView: View? = parent as? View
                        while (currentView != null) {
                            if (currentView is DCFScrollView) {
                                foundScrollView = currentView
                                break
                            }
                            currentView = currentView.parent as? View
                        }
                    }
                }
                
                foundScrollView?.let { sv ->
                    val customScrollView = sv.scrollView
                    // CRITICAL: Set expectedContentHeight in async callback as well
                    // Only set if different to prevent layout loops
                    if (frame.height() > 0 && customScrollView.expectedContentHeight != frame.height().toInt()) {
                        customScrollView.expectedContentHeight = frame.height().toInt()
                    }
                    
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.applyLayout (async): Found ScrollView, contentView.frame=$actualFrame, updating contentSize")
                    sv.updateContentSizeFromContentView()
                    
                    // Force re-measurement
                    customScrollView.forceLayout()
                    customScrollView.requestLayout()
                } ?: run {
                    val storedRefSet = contentView.getTag(scrollViewKey) != null
                }
            }
        }
        
        Log.d(TAG, "🔍 DCFScrollContentViewComponent.applyLayout: layout=(${layout.left}, ${layout.top}, ${layout.width}, ${layout.height}) -> set frame=$frame")
    }
    
    override fun setChildren(view: View, childViews: List<View>, viewId: String): Boolean {
        Log.d(TAG, "🔍 DCFScrollContentViewComponent.setChildren: Called for viewId=$viewId, childViews.count=${childViews.size}, viewType=${view.javaClass.simpleName}")
        
        // CRITICAL: Ensure ScrollContentView itself is visible
        // This is essential - if the content view is invisible, children won't be drawn even if they're visible
        // iOS views are visible by default, but Android views start as INVISIBLE
        if (view.visibility != View.VISIBLE) {
            view.visibility = View.VISIBLE
            Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Made ScrollContentView (viewId=$viewId) visible")
        }
        if (view.alpha < 1.0f) {
            view.alpha = 1.0f
        }
        
        // ScrollContentView should contain all its children directly
        // Remove existing children
        if (view is ViewGroup) {
            view.removeAllViews()
        }
        
        // CRITICAL: Find ScrollView BEFORE adding children
        // This allows us to set expectedContentHeight immediately after children are added
        val scrollViewKey = ScrollViewKey.KEY.hashCode()
        var scrollView = view.getTag(scrollViewKey) as? DCFScrollView
        
        // Fallback: Try to find through hierarchy
        if (scrollView == null) {
            val parent = view.parent
            if (parent is DCFCustomScrollView) {
                val parentParent = parent.parent
                if (parentParent is DCFScrollView) {
                    scrollView = parentParent
                }
            }
            
            if (scrollView == null && parent is DCFScrollView) {
                scrollView = parent
            }
            
            if (scrollView == null) {
                var currentView: View? = parent as? View
                while (currentView != null) {
                    if (currentView is DCFScrollView) {
                        scrollView = currentView
                        break
                    }
                    currentView = currentView.parent as? View
                }
            }
        }
        
        // Add new children
        val viewIdKey = "viewId".hashCode()
        childViews.forEachIndexed { index, childView ->
            // Get viewId from tag
            val childViewId = childView.getTag(viewIdKey) as? String ?: "unknown"
            Log.d(TAG, "🔍 DCFScrollContentViewComponent.setChildren: Adding child $index: viewId=$childViewId, frame=(${childView.left}, ${childView.top}, ${childView.width}, ${childView.height}), type=${childView.javaClass.simpleName}, visibility=${childView.visibility}, alpha=${childView.alpha}")
            if (view is ViewGroup) {
                // CRITICAL: Ensure child has proper layout params before adding
                // This is essential for correct measurement in onMeasure()
                if (childView.layoutParams == null) {
                    childView.layoutParams = ViewGroup.MarginLayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                }
                
                view.addView(childView)
                
                // CRITICAL: Make child visible IMMEDIATELY after adding to ScrollContentView
                // Children are set to INVISIBLE during attachView to prevent flash of incorrect layout
                // But once they're added to ScrollContentView, they should be visible
                // This matches iOS behavior where views are visible by default
                // The layout system (Yoga) will position them correctly
                // 
                // CRITICAL: We must make children visible SYNCHRONOUSLY, not in a post block
                // This is because NestedScrollView calls onMeasure() on ScrollContentView
                // BEFORE applyLayoutsBatch makes views visible. If children are invisible during
                // onMeasure(), they won't be measured correctly, causing the ScrollView to think
                // there's no content (zero height), resulting in a red screen with no content.
                //
                // iOS doesn't have this issue because UIScrollView reads contentView.frame.size
                // AFTER layout (in layoutSubviews), when views are already visible.
                if (childView.visibility != View.VISIBLE || childView.alpha < 1.0f) {
                    childView.visibility = View.VISIBLE
                    childView.alpha = 1.0f
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Made child $index (viewId=$childViewId) visible immediately after adding to ScrollContentView")
                }
            }
        }
        
        // 🔥 CRITICAL: DO NOT call requestLayout() here!
        // The issue: setChildren() is called BEFORE calculateAndApplyLayout()
        // If we call requestLayout() here, it triggers measurement BEFORE pendingFrame is set
        // This causes ScrollView to measure with 0 height, and it won't re-measure later
        // 
        // Solution: Let applyLayout() handle requestLayout() AFTER pendingFrame is set
        // applyLayout() is called AFTER calculateAndApplyLayout(), so pendingFrame will be available
        // 
        // Rotation works because pendingFrame is already set from previous layout pass
        Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Added ${childViews.size} children (NOT requesting layout - will be done in applyLayout() after pendingFrame is set)")
        
        // 🔥 CRITICAL: If ScrollView found, try to set expectedContentHeight immediately
        // This ensures ScrollView knows the correct height even if it measures before applyLayout()
        // This fixes the issue where navigation to examples shows red background
        scrollView?.let { sv ->
            val customScrollView = sv.scrollView
            val pendingFrameKey = "pendingFrame".hashCode()
            val pendingFrame = view.getTag(pendingFrameKey) as? Rect
            
            if (pendingFrame != null && pendingFrame.height() > 0) {
                // pendingFrame is available - set expectedContentHeight immediately
                if (customScrollView.expectedContentHeight != pendingFrame.height().toInt()) {
                    customScrollView.expectedContentHeight = pendingFrame.height().toInt()
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Set expectedContentHeight=${pendingFrame.height()} from pendingFrame (during setChildren)")
                }
            } else {
                // pendingFrame not available yet - try to estimate from children
                // This is a fallback for when NestedScrollView.onMeasure() is called before pendingFrame is set
                // We measure children to get an approximate height
                if (view is ViewGroup && view.childCount > 0) {
                    var estimatedHeight = 0
                    for (i in 0 until view.childCount) {
                        val child = view.getChildAt(i)
                        if (child.visibility == View.VISIBLE) {
                            // Measure child if not already measured
                            if (child.measuredHeight == 0 && child.measuredWidth == 0) {
                                child.measure(
                                    View.MeasureSpec.makeMeasureSpec(view.width.coerceAtLeast(0), View.MeasureSpec.AT_MOST),
                                    View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
                                )
                            }
                            estimatedHeight += child.measuredHeight
                        }
                    }
                    
                    // Only set if we got a reasonable estimate (at least some height)
                    if (estimatedHeight > 0 && customScrollView.expectedContentHeight == 0) {
                        customScrollView.expectedContentHeight = estimatedHeight
                        Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Set estimated expectedContentHeight=$estimatedHeight from children (fallback, pendingFrame not available yet)")
                        
                        // 🔥 CRITICAL: Update content view's layout params to match estimated height
                        // This ensures the content view has the correct size when ScrollView re-measures
                        if (view.layoutParams != null) {
                            view.layoutParams.height = estimatedHeight
                            view.layoutParams.width = ViewGroup.LayoutParams.MATCH_PARENT
                        } else {
                            view.layoutParams = FrameLayout.LayoutParams(
                                ViewGroup.LayoutParams.MATCH_PARENT,
                                estimatedHeight
                            )
                        }
                        
                        // 🔥 CRITICAL: Force re-measurement of ScrollView after setting expectedContentHeight
                        // This fixes the red background issue when navigating to examples
                        // The ScrollView might have measured to 0 before children were added
                        // By setting expectedContentHeight and forcing re-measurement, we ensure it measures correctly
                        customScrollView.post {
                            // Force layout on content view first
                            view.requestLayout()
                            // Then force layout on ScrollView
                            customScrollView.requestLayout()
                            Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Forced re-measurement of ScrollView after setting expectedContentHeight=$estimatedHeight")
                        }
                    } else {
                        Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: ScrollView found, will update contentSize in applyLayout() after pendingFrame is set (estimatedHeight=$estimatedHeight)")
                    }
                } else {
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: ScrollView found, will update contentSize in applyLayout() after pendingFrame is set (no children yet)")
                }
            }
            
            // 🔥 CRITICAL: Even if pendingFrame is not available, try to measure content view after children are added
            // This is a last resort to prevent red background when navigating to examples
            // Measure the content view with all its children to get actual height
            if (view is ViewGroup && view.childCount > 0 && customScrollView.expectedContentHeight == 0) {
                // Measure content view with all children
                // Use parent's measured width if available, otherwise use screen width as fallback
                val parentView = view.parent as? View
                val availableWidth = when {
                    parentView != null && parentView.measuredWidth > 0 -> parentView.measuredWidth
                    parentView != null && parentView.width > 0 -> parentView.width
                    else -> view.context.resources.displayMetrics.widthPixels
                }
                val widthSpec = View.MeasureSpec.makeMeasureSpec(
                    availableWidth.coerceAtLeast(0),
                    View.MeasureSpec.AT_MOST
                )
                val heightSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
                view.measure(widthSpec, heightSpec)
                
                if (view.measuredHeight > 0) {
                    customScrollView.expectedContentHeight = view.measuredHeight
                    if (view.layoutParams != null) {
                        view.layoutParams.height = view.measuredHeight
                        view.layoutParams.width = ViewGroup.LayoutParams.MATCH_PARENT
                    } else {
                        view.layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            view.measuredHeight
                        )
                    }
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Measured content view height=${view.measuredHeight}, set expectedContentHeight and layout params")
                    
                    // Force re-measurement
                    customScrollView.post {
                        view.requestLayout()
                        customScrollView.requestLayout()
                        Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Forced re-measurement after measuring content view (height=${view.measuredHeight})")
                    }
                }
            }
        } ?: run {
        }
        
        val childCount = if (view is ViewGroup) view.childCount else 0
        Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: Added ${childViews.size} children to ScrollContentView (viewId=$viewId), view now has $childCount subviews, frame=(${view.left}, ${view.top}, ${view.width}, ${view.height})")
        return true
    }
    
    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

