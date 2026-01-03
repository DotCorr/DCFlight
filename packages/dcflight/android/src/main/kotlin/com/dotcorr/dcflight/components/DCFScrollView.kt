/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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
 */
class DCFCustomScrollView(context: Context) : NestedScrollView(context) {
    var centerContent: Boolean = false
    
    init {
        isNestedScrollingEnabled = true
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
    
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        
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
    
    val scrollView: NestedScrollView
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
        // NestedScrollView needs its child to have a defined size for scrolling to work
        val layoutParams = contentView.layoutParams
        if (layoutParams == null || layoutParams.width == ViewGroup.LayoutParams.WRAP_CONTENT || layoutParams.height == ViewGroup.LayoutParams.WRAP_CONTENT) {
            // Set layout params to match the actual size from Yoga
            val newParams = ViewGroup.LayoutParams(
                contentView.width.coerceAtLeast(0),
                contentView.height.coerceAtLeast(0)
            )
            contentView.layoutParams = newParams
            Log.d(TAG, "🔍 DCFScrollView.updateContentSizeFromContentView: Updated layout params to (${newParams.width}, ${newParams.height})")
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
            view.layoutParams = ViewGroup.LayoutParams(
                frameToRestore.width().coerceAtLeast(0),
                frameToRestore.height().coerceAtLeast(0)
            )
        } else {
            // Use WRAP_CONTENT as fallback - will be updated by applyLayout
            view.layoutParams = ViewGroup.LayoutParams(
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
            view.layoutParams = ViewGroup.LayoutParams(
                frameToRestore.width().coerceAtLeast(0),
                frameToRestore.height().coerceAtLeast(0)
            )
            view.requestLayout()
            Log.d(TAG, "✅ DCFScrollView.insertContentView: Restored frame=$frameToRestore after addView (was $frameBeforeAdd, pendingFrame=${pendingFrame?.toString() ?: "nil"})")
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
     */
    fun removeContentView(subview: View) {
        require(_contentView == subview) { "Attempted to remove non-existent subview" }
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
        // Defensive check - handle case where _scrollView might not be added yet
        if (childCount == 0) {
            Log.w(TAG, "⚠️ DCFScrollView.onLayout: No children, _scrollView not added yet")
            return
        }
        
        if (childCount != 1) {
            Log.w(TAG, "⚠️ DCFScrollView.onLayout: Expected 1 child, got $childCount")
            return
        }
        
        val firstChild = getChildAt(0)
        if (firstChild != _scrollView) {
            Log.w(TAG, "⚠️ DCFScrollView.onLayout: First child is not _scrollView (type: ${firstChild.javaClass.simpleName})")
            return
        }
        
        _scrollView.layout(0, 0, width, height)
        
        // Update content size from contentView after layout
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

