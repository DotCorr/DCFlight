package com.dotcorr.dcflight.components.text

import android.text.SpannableStringBuilder
import android.text.Spannable
import com.dotcorr.dcflight.layout.DCFShadowNode

abstract class DCFTextShadowNode(viewId: Int) : DCFShadowNode(viewId) {
    
    private var mTextBegin: Int = 0
    private var mTextEnd: Int = 0
    
    var text: String = ""
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var fontSize: Float = 17f // Match iOS default (iOS uses 17, React Native uses 14)
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var fontWeight: String? = null
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var fontFamily: String? = null
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    open var letterSpacing: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var lineHeight: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var numberOfLines: Int = 0
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    var textAlign: String = "start"
        set(value) {
            if (field != value) {
                field = value
                dirtyText()
            }
        }
    
    /**
     * Propagates changes up to top-level text node without dirtying current node.
     * Matches React Native's FlatTextShadowNode.notifyChanged exactly.
     * When shouldRemeasure is true, marks the top-level text node's Yoga node as dirty.
     */
    protected fun notifyChanged(shouldRemeasure: Boolean) {
        val parent = superview
        if (parent is DCFTextShadowNode) {
            // Propagate up the tree (matches React Native)
            parent.notifyChanged(shouldRemeasure)
        } else {
            // We've reached a non-text parent - find the top-level text node
            // The top-level text node is the one with a measure function (layout/DCFTextShadowNode)
            // Find it by walking up the tree or by checking if this node has a measure function
            var currentNode: com.dotcorr.dcflight.layout.DCFShadowNode? = this
            while (currentNode != null) {
                // Check if this node has a measure function (it's the top-level text node)
                if (currentNode.yogaNode.isMeasureDefined) {
                    // This is the top-level text node - mark it dirty if remeasurement is needed
                    if (shouldRemeasure) {
                        currentNode.yogaNode.markLayoutSeen() // Reset layout seen flag
                        currentNode.yogaNode.dirty() // Mark as dirty to force re-measure
                    }
                    break
                }
                currentNode = currentNode.superview
            }
        }
    }
    
    final fun collectText(builder: SpannableStringBuilder) {
        mTextBegin = builder.length
        performCollectText(builder)
        mTextEnd = builder.length
    }
    
    protected open fun shouldAllowEmptySpans(): Boolean {
        return false
    }
    
    protected open fun isEditable(): Boolean {
        return false
    }
    
    final fun applySpans(builder: SpannableStringBuilder, isEditable: Boolean) {
        if (mTextBegin != mTextEnd || shouldAllowEmptySpans()) {
            performApplySpans(builder, mTextBegin, mTextEnd, isEditable)
        }
    }
    
    protected abstract fun performCollectText(builder: SpannableStringBuilder)
    protected abstract fun performApplySpans(
        builder: SpannableStringBuilder,
        begin: Int,
        end: Int,
        isEditable: Boolean
    )
    
    open fun performCollectAttachDetachListeners() {
    }
}

