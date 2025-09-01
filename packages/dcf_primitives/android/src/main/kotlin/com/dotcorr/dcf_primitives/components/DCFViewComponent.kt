/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFViewComponent - Basic container view matching iOS DCFViewComponent
 * Acts as a container view similar to UIView in iOS or View in React Native
 */
class DCFViewComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val view = FrameLayout(context)

        // Store component type
        view.setTag(R.id.dcf_component_type, "View")

        // Apply props
        updateView(view, props)

        // Apply StyleSheet properties (filter nulls for style extensions)
        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        view.applyStyles(nonNullStyleProps)

        return view
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        // Convert nullable map to non-nullable for internal processing
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }
        return updateViewInternal(view, nonNullProps)
    }

    override protected fun updateViewInternal(view: View, props: Map<String, Any>): Boolean {
        // Just apply styles - the extension handles everything like iOS
        view.applyStyles(props)
        return true
    }
}
