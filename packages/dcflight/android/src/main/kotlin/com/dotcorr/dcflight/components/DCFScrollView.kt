/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.graphics.PointF
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.widget.NestedScrollView
import com.dotcorr.dcflight.components.propagateEvent
import kotlin.math.max
import kotlin.math.min

// Static pointer key for storing ScrollView reference on contentView
// Shared between DCFScrollView and DCFScrollContentViewComponent
// Using a companion object ensures both files use the same key
internal object ScrollViewKey {
    const val KEY = "DCFScrollView_ScrollViewKey"
}

/**
 * Custom NestedScrollView subclass that limits certain default Android behaviors
 * to ensure proper integration with DCFlight's layout system.
 * 
 * CRITICAL: This class overrides measureChildWithMargins to use the expected content 
 * height from Yoga rather than relying on child measurement. This is essential because:
 * 1. NestedScrollView calls onMeasure() BEFORE Yoga layout is calculated
 * 2. At that point, children haven't been sized by Yoga yet
 * 3. This causes NestedScrollView to think content is 0 height
 * 4. Result: content is invisible until device rotation forces re-layout
 * 
 * Solution: Store the expected content height from Yoga and use it when measuring children
 */
class DCFCustomScrollView(context: Context) : NestedScrollView(context) {
    var centerContent: Boolean = false
    
    // CRITICAL: Flag to prevent layout loops when setting expectedContentHeight during measurement
    private var isMeasuring = false
    
    // CRITICAL: Backing field for expectedContentHeight to allow direct setting during measurement
    private var _expectedContentHeight: Int = 0
    
    /**
     * Expected content height from Yoga layout.
     * Set by DCFScrollContentViewComponent when Yoga calculates the layout.
     * Used in measureChildWithMargins() to ensure NestedScrollView knows the correct content size.
     */
    var expectedContentHeight: Int
        get() = _expectedContentHeight
        set(value) {
            if (_expectedContentHeight != value) {
                val wasPlaceholder = _expectedContentHeight > 0 && _expectedContentHeight == context.resources.displayMetrics.heightPixels
                val isRealValue = value > 0 && value != context.resources.displayMetrics.heightPixels
                _expectedContentHeight = value
                
                // CRITICAL: Only trigger re-layout if we're NOT currently measuring
                // This prevents infinite layout loops where setting expectedContentHeight
                // triggers requestLayout() which calls onMeasure() which sets expectedContentHeight again
                if (value > 0 && !isMeasuring) {
                    // 🔥 CRITICAL: If we're updating from placeholder to real value, force full layout pass
                    // This ensures ScrollView properly updates content size when real height is available
                    // This fixes the red background issue - placeholder prevents red, real value ensures correct size
                    if (wasPlaceholder && isRealValue) {
                        // Force full layout pass: invalidate + requestLayout
                        invalidate()
                        requestLayout()
                        // Also force layout on parent DCFScrollView to ensure content size is updated
                        (parent as? DCFScrollView)?.let { parentScrollView ->
                            parentScrollView.post {
                                parentScrollView.updateContentSizeFromContentView()
                            }
                        }
                        Log.d("DCFCustomScrollView", "✅ expectedContentHeight: Updated from placeholder to real value=$value, forcing full layout pass")
                    } else {
                        // Normal update - just request layout
                        requestLayout()
                    }
                }
            }
        }
    
    init {
        isNestedScrollingEnabled = true
    }
    
    /**
     * CRITICAL: Override measureChildWithMargins to use expected content height from Yoga
     * 
     * NestedScrollView.measureChildWithMargins() is called during onMeasure to determine
     * the child's size. By overriding it, we can inject the Yoga-calculated height
     * before the child is measured, ensuring NestedScrollView knows the correct size.
     * 
     * ROTATION FIX: If expectedContentHeight is 0, let the child measure itself first,
     * then capture that measured height and use it for subsequent measurements. This handles
     * the case where onMeasure() is called before expectedContentHeight is set (initial render).
     * Rotation works because it triggers a full layout pass where children are already measured.
     */
    override fun measureChildWithMargins(
        child: View,
        parentWidthMeasureSpec: Int,
        widthUsed: Int,
        parentHeightMeasureSpec: Int,
        heightUsed: Int
    ) {
        // CRITICAL: Set flag to prevent layout loops
        isMeasuring = true
        try {
            // If we have an expected content height from Yoga, use it
            if (expectedContentHeight > 0) {
                val lp = child.layoutParams as MarginLayoutParams
                
                // Calculate width spec normally
                val childWidthMeasureSpec = getChildMeasureSpec(
                    parentWidthMeasureSpec,
                    paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin + widthUsed,
                    lp.width
                )
                
                // Use expected height from Yoga instead of UNSPECIFIED
                val childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(
                    expectedContentHeight,
                    MeasureSpec.EXACTLY
                )
                
                child.measure(childWidthMeasureSpec, childHeightMeasureSpec)
            } else {
                // ROTATION FIX: If expectedContentHeight is 0, let child measure itself first
                // This handles the initial measurement before expectedContentHeight is set
                super.measureChildWithMargins(child, parentWidthMeasureSpec, widthUsed, parentHeightMeasureSpec, heightUsed)
                
                // CRITICAL: If child measured to a non-zero height, capture it as expectedContentHeight
                // Only set if different to avoid triggering layout loop
                // Set directly to backing field without triggering setter's requestLayout
                // We're already measuring, so we don't want to trigger another layout request
                if (child.measuredHeight > 0 && _expectedContentHeight != child.measuredHeight) {
                    _expectedContentHeight = child.measuredHeight
                    Log.d("DCFCustomScrollView", "✅ measureChildWithMargins: Captured expectedContentHeight=${child.measuredHeight} from child measurement (fallback)")
                } else if (child.measuredHeight == 0 && _expectedContentHeight == 0) {
                    // 🔥 CRITICAL FIX: If both are 0, use screen height as placeholder to prevent red background
                    // This is the red background issue - measurement happened before pendingFrame was set
                    // By using screen height as placeholder, we prevent the ScrollView from measuring to 0
                    // When the real height is available (from pendingFrame), it will be updated
                    val placeholderHeight = context.resources.displayMetrics.heightPixels
                    _expectedContentHeight = placeholderHeight
                    Log.d("DCFCustomScrollView", "✅ measureChildWithMargins: Both measured to 0, using placeholder height=$placeholderHeight to prevent red background (will be updated when pendingFrame is set)")
                    
                    // Re-measure child with placeholder height so it doesn't measure to 0
                    val lp = child.layoutParams as? MarginLayoutParams ?: MarginLayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    )
                    val childWidthMeasureSpec = getChildMeasureSpec(
                        parentWidthMeasureSpec,
                        paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin + widthUsed,
                        lp.width
                    )
                    val childHeightMeasureSpec = MeasureSpec.makeMeasureSpec(
                        placeholderHeight,
                        MeasureSpec.AT_MOST  // Use AT_MOST so child can be smaller if needed
                    )
                    child.measure(childWidthMeasureSpec, childHeightMeasureSpec)
                }
            }
        } finally {
            isMeasuring = false
        }
    }
    
    override fun onScrollChanged(l: Int, t: Int, oldl: Int, oldt: Int) {
        super.onScrollChanged(l, t, oldl, oldt)
        
        // Handle centerContent logic similar to iOS
        val parent = parent
        if (parent is DCFScrollView) {
            val contentView = parent.contentView
            if (centerContent && contentView != null) {
                val subviewSize = android.graphics.PointF(contentView.width.toFloat(), contentView.height.toFloat())
                val scrollViewSize = android.graphics.PointF(width.toFloat(), height.toFloat())
                
                if (subviewSize.x <= scrollViewSize.x) {
                    val adjustedX = -(scrollViewSize.x - subviewSize.x) / 2.0f
                    if (scrollX != adjustedX.toInt()) {
                        scrollTo(adjustedX.toInt(), scrollY)
                    }
                }
                if (subviewSize.y <= scrollViewSize.y) {
                    val adjustedY = -(scrollViewSize.y - subviewSize.y) / 2.0f
                    if (scrollY != adjustedY.toInt()) {
                        scrollTo(scrollX, adjustedY.toInt())
                    }
                }
            }
        }
    }
    
    /**
     * Override onLayout to ensure child is laid out with correct size AND preserve scroll offset
     */
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        
        // CRITICAL: If we have expected content height and child exists, ensure it has correct bounds
        if (childCount > 0 && expectedContentHeight > 0) {
            val child = getChildAt(0)
            if (child.height != expectedContentHeight) {
                Log.d("DCFCustomScrollView", "📏 onLayout: Fixing child height from ${child.height} to $expectedContentHeight")
                child.layout(
                    child.left,
                    child.top,
                    child.right,
                    child.top + expectedContentHeight
                )
            }
        }
        
        // Preserving and revalidating contentOffset similar to iOS
        val originalOffsetX = scrollX
        val originalOffsetY = scrollY
        
        val contentInset = Rect(0, 0, 0, 0) // Android doesn't have contentInset like iOS
        val contentSize = android.graphics.PointF(
            (getChildAt(0)?.width ?: 0).toFloat(),
            (getChildAt(0)?.height ?: 0).toFloat()
        )
        val fullContentSize = android.graphics.PointF(
            contentSize.x + contentInset.left + contentInset.right,
            contentSize.y + contentInset.top + contentInset.bottom
        )
        
        val boundsSize = android.graphics.PointF(width.toFloat(), height.toFloat())
        
        val newOffsetX = max(0f, min(originalOffsetX.toFloat(), fullContentSize.x - boundsSize.x)).toInt()
        val newOffsetY = max(0f, min(originalOffsetY.toFloat(), fullContentSize.y - boundsSize.y)).toInt()
        
        if (scrollX != newOffsetX || scrollY != newOffsetY) {
            scrollTo(newOffsetX, newOffsetY)
        }
    }
}

/**
 * DCFScrollView - Main ScrollView class
 * 
 * The ScrollView may have at most one single subview (contentView). This ensures
 * that the scroll view's contentSize will be efficiently set to the size of the
 * single subview's frame. That frame size will be determined efficiently since
 * it will have already been computed by the off-main-thread layout system (Yoga).
 */
class DCFScrollView(context: Context) : ViewGroup(context), DCFScrollableProtocol, DCFAutoInsetsProtocol {
    
    companion object {
        private const val TAG = "DCFScrollView"
    }
    
    private val _scrollView: DCFCustomScrollView
    private var _contentView: View? = null
    private var _lastScrollDispatchTime: Long = 0
    private var _allowNextScrollNoMatterWhat: Boolean = false
    private var _scrollEventThrottle: Long = 0L
    private var _coalescingKey: Int = 0
    private var _lastEmittedEventName: String? = null
    private val _scrollListeners = mutableListOf<Any>() // Simplified - iOS uses NSHashTable
    
    // Props
    var centerContent: Boolean = false
        set(value) {
            field = value
            _scrollView.centerContent = value
        }
    
    var scrollEventThrottle: Long
        get() = _scrollEventThrottle
        set(value) {
            _scrollEventThrottle = value
        }
    
    override var contentInset: Rect = Rect(0, 0, 0, 0)
        set(value) {
            if (field != value) {
                val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
                field = value
                // Android doesn't have contentInset on ScrollView, so we handle it differently
                _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
            }
        }
    
    override var automaticallyAdjustContentInsets: Boolean = true
    
    init {
        _scrollView = DCFCustomScrollView(context)
        _scrollView.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        addView(_scrollView)
    }
    
    // MARK: - Public Properties
    
    val scrollView: DCFCustomScrollView
        get() = _scrollView
    
    val contentView: View?
        get() = _contentView
    
    // MARK: - Content Size Management
    
    /**
     * Once you set the contentSize, to a nonzero value, it is assumed to be
     * managed by you, and we'll never automatically compute the size for you,
     * unless you manually reset it back to {0, 0}
     * 
     * contentSize is determined by contentView.frame.size
     * CRITICAL: Always use contentView's size, not scrollView's size (matches iOS)
     */
    override val contentSize: PointF
        get() {
            // Use contentView.frame.size directly (matches iOS behavior)
            // Yoga has already calculated this, so we just use it
            return _contentView?.let {
                val width = it.width.toFloat()
                val height = it.height.toFloat()
                PointF(width, height)
            } ?: PointF(0f, 0f)
        }
    
    /**
     * Update contentSize from contentView.frame.size
     * Called after layout is complete
     * 
     * KEY INSIGHT: We use contentView.frame.size directly because
     * ScrollContentView is laid out by Yoga. Yoga calculates the frame.size based on
     * the children's layout, so we just use it directly.
     * 
     * CRITICAL: On Android, NestedScrollView automatically sizes based on its child.
     * We need to ensure the contentView has proper layout params and size.
     */
    fun updateContentSizeFromContentView() {
        val contentView = _contentView ?: run {
            Log.w(TAG, "⚠️ DCFScrollView.updateContentSizeFromContentView: No contentView, setting contentSize to zero")
            return
        }
        
        // 🔥 CRITICAL: If DCFScrollView wrapper hasn't been laid out yet, request layout first
        // This fixes the red background issue - the wrapper must be laid out before we can set content size
        // The logs show scrollView size=(0, 0), meaning the wrapper hasn't been laid out
        // Check both measured dimensions and actual layout dimensions
        val isMeasured = width > 0 && height > 0
        val isLaidOut = left != 0 || top != 0 || right != 0 || bottom != 0 || (width > 0 && height > 0 && measuredWidth == width && measuredHeight == height)
        
        if (!isMeasured || !isLaidOut) {
            Log.d(TAG, "✅ DCFScrollView.updateContentSizeFromContentView: Wrapper not ready (measured=$isMeasured, laidOut=$isLaidOut, size=$width x $height, measured=$measuredWidth x $measuredHeight), requesting layout first")
            requestLayout()
            // Schedule updateContentSizeFromContentView to run after layout
            // Use a double post to ensure layout has completed
            post {
                post {
                    updateContentSizeFromContentView()
                }
            }
            return
        }
        
        // CRITICAL: If frame is zero, try to restore it from pendingFrame
        // This handles the case where applyLayout hasn't run yet or the frame was reset
        if (contentView.width == 0 || contentView.height == 0) {
            val pendingFrameKey = "pendingFrame".hashCode()
            val pendingFrame = contentView.getTag(pendingFrameKey) as? Rect
            if (pendingFrame != null && pendingFrame.width() > 0 && pendingFrame.height() > 0) {
                contentView.layout(
                    pendingFrame.left,
                    pendingFrame.top,
                    pendingFrame.right,
                    pendingFrame.bottom
                )
                Log.w(TAG, "⚠️ DCFScrollView.updateContentSizeFromContentView: Frame was zero, restored from pendingFrame=$pendingFrame, actualFrame=(${contentView.left}, ${contentView.top}, ${contentView.width}, ${contentView.height})")
            } else {
                Log.w(TAG, "⚠️ DCFScrollView.updateContentSizeFromContentView: Frame is zero and no pendingFrame available - will wait for applyLayout")
                return
            }
        }
        
        // CRITICAL: Ensure contentView has proper layout params for NestedScrollView
        // NestedScrollView extends FrameLayout, so it expects FrameLayout.LayoutParams
        // FrameLayout.LayoutParams extends MarginLayoutParams, so it supports margins
        // CRITICAL: For scrolling to work, contentView must have explicit height from Yoga
        // NestedScrollView compares the child's height to its own height to determine if scrolling is needed
        val layoutParams = contentView.layoutParams
        val actualHeight = contentView.height
        val scrollViewHeight = _scrollView.height
        
        // CRITICAL: Always use explicit height from Yoga's calculation (actualHeight)
        // This ensures NestedScrollView can properly determine if scrolling is needed
        // If actualHeight is 0 or invalid, use WRAP_CONTENT as fallback
        if (layoutParams == null || layoutParams !is android.widget.FrameLayout.LayoutParams) {
            // Create new FrameLayout.LayoutParams with explicit height
            val newParams = if (actualHeight > 0) {
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    actualHeight.coerceAtLeast(0)
                )
            } else {
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
            }
            contentView.layoutParams = newParams
            Log.d(TAG, "🔍 DCFScrollView.updateContentSizeFromContentView: Created new FrameLayout.LayoutParams (${newParams.width}, ${newParams.height})")
        } else {
            // Update existing layout params to use explicit height
            val newHeight = if (actualHeight > 0) {
                actualHeight.coerceAtLeast(0)
            } else {
                ViewGroup.LayoutParams.WRAP_CONTENT
            }
            // Only update if height changed
            if (layoutParams.height != newHeight) {
                layoutParams.height = newHeight
                contentView.layoutParams = layoutParams
                Log.d(TAG, "🔍 DCFScrollView.updateContentSizeFromContentView: Updated layout params height to $newHeight (actualHeight=$actualHeight, scrollViewHeight=$scrollViewHeight)")
            }
        }
        
        // Use contentView.frame.size directly
        // ScrollContentView is in the Yoga tree, so Yoga has already calculated its size
        // DCFScrollContentViewComponent.applyLayout sets contentView.frame from Yoga layout
        val contentSize = PointF(contentView.width.toFloat(), contentView.height.toFloat())
        val childCount = if (contentView is ViewGroup) contentView.childCount else 0
        Log.d(TAG, "🔍 DCFScrollView.updateContentSizeFromContentView: contentView.frame=(${contentView.left}, ${contentView.top}, ${contentView.width}, ${contentView.height}), contentSize=$contentSize, scrollView size=(${_scrollView.width}, ${_scrollView.height}), subviews.count=$childCount")
        
        // CRITICAL: Request layout on both contentView and scrollView to ensure proper sizing
        // This ensures NestedScrollView recalculates its content size based on the child
        contentView.requestLayout()
        _scrollView.requestLayout()
        requestLayout()
    }
    
    /**
     * Calculate offset for new content size (preserving scroll position when possible)
     */
    private fun calculateOffsetForContentSize(newContentSize: PointF): PointF {
        val oldOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        var newOffset = PointF(oldOffset.x, oldOffset.y)
        
        val oldContentSize = PointF(_scrollView.width.toFloat(), _scrollView.height.toFloat())
        val viewportSize = PointF(width.toFloat(), height.toFloat())
        
        // If contentSize was zero (initial case), start at top
        if (oldContentSize.x == 0f && oldContentSize.y == 0f) {
            return PointF(0f, 0f)
        }
        
        // Vertical
        val fitsInViewportY = oldContentSize.y <= viewportSize.y && newContentSize.y <= viewportSize.y
        if (newContentSize.y < oldContentSize.y && !fitsInViewportY) {
            val offsetHeight = oldOffset.y + viewportSize.y
            if (oldOffset.y < 0) {
                // Overscrolled on top, leave offset alone
            } else if (offsetHeight > oldContentSize.y) {
                // Overscrolled on the bottom, preserve overscroll amount
                newOffset.y = max(0f, oldOffset.y - (oldContentSize.y - newContentSize.y))
            } else if (offsetHeight > newContentSize.y) {
                // Offset falls outside of bounds, scroll back to end of list
                newOffset.y = max(0f, newContentSize.y - viewportSize.y)
            }
        }
        
        // Horizontal
        val fitsInViewportX = oldContentSize.x <= viewportSize.x && newContentSize.x <= viewportSize.x
        if (newContentSize.x < oldContentSize.x && !fitsInViewportX) {
            val offsetWidth = oldOffset.x + viewportSize.x
            if (oldOffset.x < 0) {
                // Overscrolled at the beginning, leave offset alone
            } else if (offsetWidth > oldContentSize.x && newContentSize.x > viewportSize.x) {
                // Overscrolled at the end, preserve overscroll amount as much as possible
                newOffset.x = max(0f, oldOffset.x - (oldContentSize.x - newContentSize.x))
            } else if (offsetWidth > newContentSize.x) {
                // Offset falls outside of bounds, scroll back to end
                newOffset.x = max(0f, newContentSize.x - viewportSize.x)
            }
        }
        
        return newOffset
    }
    
    // MARK: - Child Management
    
    /**
     * Insert a subview (DCFScrollView may only contain a single subview)
     * 
     * If a contentView already exists, remove it first before adding the new one.
     * This handles the case where ScrollContentView component is replaced or re-attached.
     */
    fun insertContentView(view: View) {
        // Remove existing contentView if it exists and is different
        // This prevents assertion errors when ScrollContentView is re-attached or replaced
        val existingContentView = _contentView
        if (existingContentView != null && existingContentView != view) {
            Log.w(TAG, "⚠️ DCFScrollView.insertContentView: Removing existing contentView before adding new one")
            _scrollView.removeView(existingContentView)
            _contentView = null
        }
        
        // Assert that we don't already have this exact view (shouldn't happen, but safety check)
        require(_contentView == null || _contentView == view) { "DCFScrollView may only contain a single subview" }
        
        // If this is the same view, we're done (already attached)
        if (_contentView == view) {
            Log.d(TAG, "🔍 DCFScrollView.insertContentView: ContentView already attached, skipping")
            return
        }
        
        // CRITICAL: Get the frame that should be restored after addView
        // Android resets the frame to zero when adding a view to a parent
        val pendingFrameKey = "pendingFrame".hashCode()
        val pendingFrame = view.getTag(pendingFrameKey) as? Rect
        val frameBeforeAdd = Rect(view.left, view.top, view.right, view.bottom)
        
        _contentView = view
        
        // CRITICAL: Store reference to this DCFScrollView on the contentView
        // This allows applyLayout to find the ScrollView even if parent is null
        // Use tag to ensure the reference persists
        val scrollViewKey = ScrollViewKey.KEY.hashCode()
        view.setTag(scrollViewKey, this)
        
        // Verify the stored reference was set correctly
        val storedRef = view.getTag(scrollViewKey) as? DCFScrollView
        Log.d(TAG, "🔍 DCFScrollView.insertContentView: Stored ScrollView reference, storedRef=${if (storedRef != null) "set" else "nil"}, self=$this")
        
        // CRITICAL: Set layout params BEFORE adding to parent
        // This ensures NestedScrollView can properly measure the child
        val frameToRestore: Rect? = when {
            pendingFrame != null && pendingFrame.width() > 0 && pendingFrame.height() > 0 -> pendingFrame
            frameBeforeAdd.width() > 0 && frameBeforeAdd.height() > 0 -> frameBeforeAdd
            else -> null
        }
        
        if (frameToRestore != null) {
            // Set layout params to match the frame size
            // CRITICAL: Use FrameLayout.LayoutParams because NestedScrollView extends FrameLayout
            // CRITICAL: Use MATCH_PARENT for width (scroll view fills parent width)
            // Use explicit height from Yoga's calculation for height
            val height = frameToRestore.height().coerceAtLeast(0)
            view.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                height
            )
            
            // 🔥 CRITICAL: Set expectedContentHeight IMMEDIATELY when frame is available
            // This ensures ScrollView knows the correct height BEFORE it measures
            // This fixes the issue where navigation to examples shows red background
            // The issue: During direct replacement, a new ScrollView is created, and it measures
            // before applyLayout() sets expectedContentHeight. By setting it here, we ensure
            // it's available for the first measurement.
            if (height > 0 && _scrollView.expectedContentHeight != height) {
                _scrollView.expectedContentHeight = height
                Log.d(TAG, "✅ DCFScrollView.insertContentView: Set expectedContentHeight=$height from frameToRestore (BEFORE addView)")
            }
        } else {
            // Use WRAP_CONTENT as fallback - will be updated by applyLayout
            // CRITICAL: Use FrameLayout.LayoutParams because NestedScrollView extends FrameLayout
            view.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        
        _scrollView.addView(view)
        
        // CRITICAL: Restore frame immediately after addView
        // Android resets the frame when adding to parent, so we restore it from the stored value
        // Priority: 1) pendingFrame (from applyLayout), 2) frameBeforeAdd (if valid)
        if (frameToRestore != null) {
            view.layout(
                frameToRestore.left,
                frameToRestore.top,
                frameToRestore.right,
                frameToRestore.bottom
            )
            // Update layout params to match actual size
            // CRITICAL: Use FrameLayout.LayoutParams because NestedScrollView extends FrameLayout
            // CRITICAL: Use MATCH_PARENT for width (scroll view fills parent width)
            // Use explicit height from Yoga's calculation for height
            view.layoutParams = android.widget.FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                frameToRestore.height().coerceAtLeast(0)
            )
            view.requestLayout()
            Log.d(TAG, "✅ DCFScrollView.insertContentView: Restored frame=$frameToRestore after addView (was $frameBeforeAdd, pendingFrame=${pendingFrame?.toString() ?: "nil"})")
            
            // 🔥 CRITICAL: Ensure expectedContentHeight is set AFTER addView as well
            // This handles the case where frameToRestore wasn't available before addView
            val height = frameToRestore.height().coerceAtLeast(0)
            if (height > 0 && _scrollView.expectedContentHeight != height) {
                _scrollView.expectedContentHeight = height
                Log.d(TAG, "✅ DCFScrollView.insertContentView: Set expectedContentHeight=$height from frameToRestore (AFTER addView)")
            }
            
            // Update contentSize immediately since frame is valid
            updateContentSizeFromContentView()
        } else {
            Log.w(TAG, "⚠️ DCFScrollView.insertContentView: No frame to restore - frameBeforeAdd=$frameBeforeAdd, pendingFrame=${pendingFrame?.toString() ?: "nil"} - will wait for applyLayout")
            // Set a flag so applyLayout knows to restore the frame and update contentSize
            val needsFrameRestoreKey = "needsFrameRestore".hashCode()
            view.setTag(needsFrameRestoreKey, true)
        }
        
        Log.d(TAG, "✅ DCFScrollView.insertContentView: Added view to _scrollView, finalFrame=(${view.left}, ${view.top}, ${view.width}, ${view.height}), parent=${view.parent?.javaClass?.simpleName ?: "nil"}")
    }
    
    /**
     * Remove a subview
     * CRASH PROTECTION: Convert require to warning to prevent app crashes
     */
    fun removeContentView(subview: View) {
        if (_contentView != subview) {
            Log.w(TAG, "⚠️ DCFScrollView.removeContentView: Attempted to remove non-existent subview. Expected: ${_contentView?.javaClass?.simpleName ?: "null"}, Got: ${subview.javaClass.simpleName}")
            // Don't crash - just return if it's not the contentView
            return
        }
        _scrollView.removeView(subview)
        _contentView = null
    }
    
    // MARK: - DCFScrollableProtocol
    
    override fun scrollToOffset(offset: PointF) {
        scrollToOffset(offset, animated = true)
    }
    
    override fun scrollToOffset(offset: PointF, animated: Boolean) {
        val currentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        if (currentOffset.x != offset.x || currentOffset.y != offset.y) {
            _allowNextScrollNoMatterWhat = true
            if (animated) {
                _scrollView.smoothScrollTo(offset.x.toInt(), offset.y.toInt())
            } else {
                _scrollView.scrollTo(offset.x.toInt(), offset.y.toInt())
            }
        }
    }
    
    override fun scrollToEnd(animated: Boolean) {
        val isHorizontal = contentSize.x > width.toFloat()
        val offset: PointF = if (isHorizontal) {
            val offsetX = contentSize.x - _scrollView.width + contentInset.right
            PointF(max(offsetX, 0f), 0f)
        } else {
            val offsetY = contentSize.y - _scrollView.height + contentInset.bottom
            PointF(0f, max(offsetY, 0f))
        }
        val currentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        if (currentOffset.x != offset.x || currentOffset.y != offset.y) {
            _allowNextScrollNoMatterWhat = true
            if (animated) {
                _scrollView.smoothScrollTo(offset.x.toInt(), offset.y.toInt())
            } else {
                _scrollView.scrollTo(offset.x.toInt(), offset.y.toInt())
            }
        }
    }
    
    override fun zoomToRect(rect: Rect, animated: Boolean) {
        // Android NestedScrollView doesn't support zoom, so this is a no-op
    }
    
    override fun addScrollListener(scrollListener: Any) {
        _scrollListeners.add(scrollListener)
    }
    
    override fun removeScrollListener(scrollListener: Any) {
        _scrollListeners.remove(scrollListener)
    }
    
    // MARK: - Layout
    
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        // CRASH PROTECTION: Convert assertions to warnings to prevent app crashes
        // React Native-style error handling - log errors instead of crashing
        
        // Defensive check - handle case where _scrollView might not be added yet
        if (childCount == 0) {
            Log.w(TAG, "⚠️ DCFScrollView.onLayout: No children, _scrollView not added yet")
            // Try to recover by adding _scrollView if it exists
            if (_scrollView.parent != this) {
                addView(_scrollView)
                Log.d(TAG, "✅ DCFScrollView.onLayout: Added _scrollView, continuing with layout")
                // Continue with layout instead of returning - this fixes the red background issue
                // The wrapper needs to be laid out even if _scrollView was just added
            } else {
                // _scrollView is already a child but childCount is 0 - this shouldn't happen
                // But if it does, return early to avoid crashes
                Log.e(TAG, "❌ DCFScrollView.onLayout: childCount is 0 but _scrollView.parent == this, skipping layout")
                return
            }
        }
        
        if (childCount != 1) {
            Log.w(TAG, "⚠️ DCFScrollView.onLayout: Expected 1 child, got $childCount. This may indicate a reconciliation issue.")
            // Try to recover by removing extra children and ensuring _scrollView is present
            while (childCount > 1) {
                val child = getChildAt(0)
                if (child != _scrollView) {
                    removeViewAt(0)
                } else {
                    break
                }
            }
            // Ensure _scrollView is present
            if (_scrollView.parent != this) {
                addView(_scrollView)
            }
            // Only proceed if we now have valid structure
            if (childCount != 1) {
                Log.e(TAG, "❌ DCFScrollView.onLayout: Could not recover from invalid structure, skipping layout")
                return
            }
        }
        
        val firstChild = getChildAt(0)
        if (firstChild != _scrollView) {
            Log.w(TAG, "⚠️ DCFScrollView.onLayout: First child is not _scrollView (type: ${firstChild.javaClass.simpleName}). Attempting to fix...")
            // Try to recover by removing wrong child and adding _scrollView
            removeViewAt(0)
            if (_scrollView.parent != this) {
                addView(_scrollView)
            }
            // Only proceed if we now have valid structure
            if (childCount != 1 || getChildAt(0) != _scrollView) {
                Log.e(TAG, "❌ DCFScrollView.onLayout: Could not recover from invalid structure, skipping layout")
                return
            }
        }
        
        _scrollView.layout(0, 0, width, height)
        
        // 🔥 CRITICAL: Update content size from contentView after layout
        // This ensures content size is set when the wrapper is laid out
        // This fixes the red background issue - content size is updated when wrapper has proper dimensions
        updateContentSizeFromContentView()
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        _scrollView.measure(widthMeasureSpec, heightMeasureSpec)
    }
    
    // MARK: - Event Sending
    
    private fun sendScrollEvent(eventName: String, scrollView: NestedScrollView, userData: Map<String, Any>? = null) {
        if (_lastEmittedEventName != eventName) {
            _coalescingKey += 1
            _lastEmittedEventName = eventName
        }
        
        val eventData = mutableMapOf<String, Any>(
            "contentOffset" to mapOf(
                "x" to scrollView.scrollX.toDouble(),
                "y" to scrollView.scrollY.toDouble()
            ),
            "contentInset" to mapOf(
                "top" to contentInset.top.toDouble(),
                "left" to contentInset.left.toDouble(),
                "bottom" to contentInset.bottom.toDouble(),
                "right" to contentInset.right.toDouble()
            ),
            "contentSize" to mapOf(
                "width" to contentSize.x.toDouble(),
                "height" to contentSize.y.toDouble()
            ),
            "layoutMeasurement" to mapOf(
                "width" to width.toDouble(),
                "height" to height.toDouble()
            ),
            "zoomScale" to 1.0 // Android doesn't support zoom
        )
        
        userData?.let { eventData.putAll(it) }
        
        propagateEvent(this, eventName, eventData)
    }
    
    // MARK: - Property Setters
    
    // Note: setting several properties of ScrollView has the effect of
    // resetting its contentOffset to {0, 0}. To prevent this, we generate
    // setters here that will record the contentOffset beforehand, and
    // restore it after the property has been set
    
    fun setAlwaysBounceHorizontal(value: Boolean) {
        val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        // Android doesn't have alwaysBounceHorizontal, handled via overScrollMode
        _scrollView.overScrollMode = if (value) View.OVER_SCROLL_ALWAYS else View.OVER_SCROLL_IF_CONTENT_SCROLLS
        _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
    }
    
    fun setAlwaysBounceVertical(value: Boolean) {
        val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        // Android doesn't have alwaysBounceVertical, handled via overScrollMode
        _scrollView.overScrollMode = if (value) View.OVER_SCROLL_ALWAYS else View.OVER_SCROLL_IF_CONTENT_SCROLLS
        _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
    }
    
    fun setBounces(value: Boolean) {
        val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        _scrollView.overScrollMode = if (value) View.OVER_SCROLL_ALWAYS else View.OVER_SCROLL_NEVER
        _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
    }
    
    fun setScrollEnabled(value: Boolean) {
        val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        _scrollView.isNestedScrollingEnabled = value
        _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
    }
    
    fun setShowsHorizontalScrollIndicator(value: Boolean) {
        val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        _scrollView.isHorizontalScrollBarEnabled = value
        _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
    }
    
    fun setShowsVerticalScrollIndicator(value: Boolean) {
        val contentOffset = PointF(_scrollView.scrollX.toFloat(), _scrollView.scrollY.toFloat())
        _scrollView.isVerticalScrollBarEnabled = value
        _scrollView.scrollTo(contentOffset.x.toInt(), contentOffset.y.toInt())
    }
    
    // MARK: - DCFAutoInsetsProtocol
    
    /**
     * Refresh content insets based on layout guides.
     * Called automatically by DCFWrapperViewController when layout guides change.
     */
    override fun refreshContentInset() {
        // Android implementation would go here
        // Similar to iOS UIView.autoAdjustInsets
    }
    
    // MARK: - Scroll Listener Setup
    
    init {
        _scrollView.setOnScrollChangeListener { _, scrollX, scrollY, oldScrollX, oldScrollY ->
            val now = System.currentTimeMillis()
            
            if (_allowNextScrollNoMatterWhat ||
                (_scrollEventThrottle > 0 && _scrollEventThrottle < (now - _lastScrollDispatchTime))) {
                sendScrollEvent("onScroll", _scrollView, null)
                _lastScrollDispatchTime = now
                _allowNextScrollNoMatterWhat = false
            }
        }
    }
}

// MARK: - Protocol Interfaces

interface DCFScrollableProtocol {
    val contentSize: PointF
    fun scrollToOffset(offset: PointF)
    fun scrollToOffset(offset: PointF, animated: Boolean)
    fun scrollToEnd(animated: Boolean)
    fun zoomToRect(rect: Rect, animated: Boolean)
    fun addScrollListener(scrollListener: Any)
    fun removeScrollListener(scrollListener: Any)
}

interface DCFAutoInsetsProtocol {
    var contentInset: Rect
    var automaticallyAdjustContentInsets: Boolean
    fun refreshContentInset()
}

