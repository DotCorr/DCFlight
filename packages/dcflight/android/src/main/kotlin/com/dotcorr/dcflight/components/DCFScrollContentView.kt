/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.util.AttributeSet
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFFrameLayout

/**
 * DCFScrollContentView - Content view wrapper
 * This is a simple ViewGroup that serves as the container for ScrollView's children.
 * Yoga will layout this view and its children, and the ScrollView will use its
 * frame.size as the contentSize.
 */
class DCFScrollContentView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : DCFFrameLayout(context, attrs, defStyleAttr) {
    
    init {
        // Don't clip content - allow children to be positioned outside bounds (negative coordinates)
        clipToPadding = false
        clipChildren = false
    }
}

