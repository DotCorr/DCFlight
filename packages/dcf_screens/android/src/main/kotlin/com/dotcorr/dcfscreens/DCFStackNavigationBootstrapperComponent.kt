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
import com.dotcorr.dcfscreens.components.navigation.NavigationManager

/**
 * DCFStackNavigationBootstrapperComponent - Android implementation of StackNavigationBootstrapper
 * Provides fallback stack navigation bootstrapping using DCFlight's command system
 */
class DCFStackNavigationBootstrapperComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFStackNavigationBootstrapperComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "🔧 DCFStackNavigationBootstrapperComponent: Creating stack navigation bootstrapper")
        
        // Create a container for the navigation stack
        val container = FrameLayout(context)
        container.id = android.R.id.content
        
        // Configure stack navigation
        configureStackNavigation(container, props)
        
        return container
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "🔧 DCFStackNavigationBootstrapperComponent: Updating stack navigation bootstrapper")
        
        if (view is FrameLayout) {
            configureStackNavigation(view, props)
            return true
        }
        
        return false
    }


    private fun configureStackNavigation(container: FrameLayout, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFStackNavigationBootstrapperComponent: Configuring stack navigation")
        
        // Store stack navigation configuration
        val stackConfig = props["stackConfig"] as? Map<String, Any?> ?: mapOf()
        
        // Set initial route if provided
        val initialRoute = props["initialRoute"] as? String
        if (initialRoute != null) {
            NavigationManager.setInitialRoute(initialRoute)
            Log.d(TAG, "🔧 DCFStackNavigationBootstrapperComponent: Set initial route to '$initialRoute'")
        }
        
        // Configure navigation bar
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        if (hideNavigationBar) {
            NavigationManager.hideNavigationBar()
        }
        
        // Configure navigation bar style
        val navigationBarStyle = props["navigationBarStyle"] as? Map<String, Any?>
        if (navigationBarStyle != null) {
            NavigationManager.configureNavigationBar(navigationBarStyle)
        }
    }
}
