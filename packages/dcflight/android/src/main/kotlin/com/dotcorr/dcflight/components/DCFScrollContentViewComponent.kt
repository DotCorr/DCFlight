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
                Log.w(TAG, "⚠️ DCFScrollContentViewComponent.applyLayout: Frame was zero/mismatch/needsRestore - restored to $frame, actualFrame=$actualFrame")
            } else {
                Log.w(TAG, "⚠️ DCFScrollContentViewComponent.applyLayout: Frame needs restore but view has no parent yet - frame=$frame, actualFrame=$actualFrame")
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
                Log.w(TAG, "⚠️ DCFScrollContentViewComponent.applyLayout: Frame was incorrect, restored to $frame, actualFrame=$actualFrame")
            }
            
            // CRITICAL: Set expectedContentHeight on DCFCustomScrollView
            // Only set if different to prevent layout loops
            if (frame.height() > 0 && sv.scrollView.expectedContentHeight != frame.height().toInt()) {
                sv.scrollView.expectedContentHeight = frame.height().toInt()
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
                    Log.w(TAG, "⚠️ DCFScrollContentViewComponent.applyLayout (async): Restored frame=$frame, actualFrame=$actualFrame")
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
                    // CRITICAL: Set expectedContentHeight in async callback as well
                    // Only set if different to prevent layout loops
                    if (frame.height() > 0 && sv.scrollView.expectedContentHeight != frame.height().toInt()) {
                        sv.scrollView.expectedContentHeight = frame.height().toInt()
                    }
                    
                    Log.d(TAG, "✅ DCFScrollContentViewComponent.applyLayout (async): Found ScrollView, contentView.frame=$actualFrame, updating contentSize")
                    sv.updateContentSizeFromContentView()
                    
                    // Force re-measurement
                    sv.scrollView.forceLayout()
                    sv.scrollView.requestLayout()
                } ?: run {
                    val storedRefSet = contentView.getTag(scrollViewKey) != null
                    Log.w(TAG, "⚠️ DCFScrollContentViewComponent.applyLayout (async): Could not find ScrollView, contentView.parent=${contentView.parent?.javaClass?.simpleName ?: "nil"}, frame=$actualFrame, storedRef=$storedRefSet")
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
        
        // Only update if ScrollView found, but don't trigger measurement yet
        scrollView?.let { sv ->
            Log.d(TAG, "✅ DCFScrollContentViewComponent.setChildren: ScrollView found, will update contentSize in applyLayout() after pendingFrame is set")
        } ?: run {
            Log.w(TAG, "⚠️ DCFScrollContentViewComponent.setChildren: Could not find ScrollView")
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

