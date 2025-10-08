/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent

/**
 * Android implementation of DCFTabNavigator component
 * Handles tab-based navigation
 */
class DCFTabNavigatorComponent : DCFComponent() {
    
    companion object {
        private const val TAG = "DCFTabNavigatorComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating tab navigator component")
        
        val tabContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        
        // Extract tab navigator properties
        val screens = props["screens"] as? List<String>
        val selectedIndex = props["selectedIndex"] as? Int ?: 0
        val isHidden = props["isHidden"] as? Boolean ?: false
        val lazyLoad = props["lazyLoad"] as? Boolean ?: true
        
        Log.d(TAG, "TabNavigator created - screens: $screens, selectedIndex: $selectedIndex, hidden: $isHidden, lazyLoad: $lazyLoad")
        
        return tabContainer
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "Updating tab navigator component")
        
        // Handle tab navigator updates
        val screens = props["screens"] as? List<String>
        val selectedIndex = props["selectedIndex"] as? Int
        
        Log.d(TAG, "TabNavigator updated - screens: $screens, selectedIndex: $selectedIndex")
        
        return true
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return when (method) {
            "selectTab" -> {
                val index = arguments["index"] as? Int
                Log.d(TAG, "Selecting tab at index: $index")
                true
            }
            "addTab" -> {
                val screenName = arguments["screenName"] as? String
                Log.d(TAG, "Adding tab: $screenName")
                true
            }
            "removeTab" -> {
                val screenName = arguments["screenName"] as? String
                Log.d(TAG, "Removing tab: $screenName")
                true
            }
            else -> null
        }
    }
}
