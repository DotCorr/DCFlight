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
import android.widget.TabHost
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcfscreens.components.navigation.NavigationManager

/**
 * DCFTabNavigatorComponent - Android implementation of TabNavigator component
 * Provides fallback tab navigation functionality using DCFlight's command system
 */
class DCFTabNavigatorComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFTabNavigatorComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "🔧 DCFTabNavigatorComponent: Creating tab navigator")
        
        // Create a simple tab host for fallback
        val tabHost = TabHost(context)
        tabHost.setup()
        
        // Configure tab navigator
        configureTabNavigator(tabHost, props)
        
        return tabHost
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "🔧 DCFTabNavigatorComponent: Updating tab navigator")
        
        if (view is TabHost) {
            configureTabNavigator(view, props)
            return true
        }
        
        return false
    }


    private fun configureTabNavigator(tabHost: TabHost, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFTabNavigatorComponent: Configuring tab navigator")
        
        // Store tab navigator configuration
        val tabConfig = props["tabConfig"] as? Map<String, Any?> ?: mapOf()
        
        // Apply configuration
        val tabs = props["tabs"] as? List<Map<String, Any?>>
        if (tabs != null) {
            for ((index, tab) in tabs.withIndex()) {
                val route = tab["route"] as? String
                val title = tab["title"] as? String
                val icon = tab["icon"] as? String
                
                if (route != null && title != null) {
                    addTabToHost(tabHost, route, title, icon, index)
                }
            }
        }
        
        // Set initial selected tab
        val initialTab = props["initialTab"] as? Int ?: 0
        if (initialTab < tabHost.tabWidget.tabCount) {
            tabHost.currentTab = initialTab
        }
    }

    private fun addTabToHost(tabHost: TabHost, route: String, title: String, icon: String?, index: Int) {
        Log.d(TAG, "🔧 DCFTabNavigatorComponent: Adding tab '$title' for route '$route'")
        
        val tabSpec = tabHost.newTabSpec(route)
        tabSpec.setIndicator(title)
        tabSpec.setContent(android.R.id.tabcontent)
        tabHost.addTab(tabSpec)
    }
}
