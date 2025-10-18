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
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry
import com.dotcorr.dcfscreens.components.navigation.utils.LifecycleEventHelper

/**
 * DCFScreenComponent - Android implementation of Screen component
 * Provides fallback navigation functionality using DCFlight's command system
 */
class DCFScreenComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFScreenComponent"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val route = props["route"] as? String ?: "unknown"
        val presentationStyle = props["presentationStyle"] as? String ?: "push"
        
        Log.d(TAG, "🔧 DCFScreenComponent: Creating screen for route '$route' with style '$presentationStyle'")

        // Create or get existing screen container
        val screenContainer = DCFScreenRegistry().getScreenContainer(route) ?: run {
            val container = ScreenContainer(route, presentationStyle)
            DCFScreenRegistry().registerScreen(route, container)
            container
        }

        // Create native Android layout with AppBar
        val rootLayout = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        // Create AppBar for native Android navigation
        val appBar = androidx.appcompat.widget.Toolbar(context).apply {
            setTitleTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(android.graphics.Color.parseColor("#2196F3"))
            elevation = 8f
        }

        // Set title from navigationBarConfig or use route as fallback
        val navigationBarConfig = props["navigationBarConfig"] as? Map<String, Any?>
        val title = navigationBarConfig?.get("title") as? String ?: route.replace("/", " ").replaceFirstChar { it.uppercase() }
        appBar.title = title

        // Add back button based on navigationBarConfig
        val showBackButton = navigationBarConfig?.get("showBackButton") as? Boolean ?: (route != "home")
        if (showBackButton) {
            appBar.setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material)
            appBar.setNavigationOnClickListener {
                Log.d(TAG, "🔙 DCFScreenComponent: Back button pressed for route '$route'")
                // Handle back navigation using command system
                NavigationManager().pop(route)
            }
        }

        // Create content container
        val contentContainer = android.widget.FrameLayout(context).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        // Add views to root layout
        rootLayout.addView(appBar)
        rootLayout.addView(contentContainer)

        // Store the content container as the screen's content view
        screenContainer.contentView = contentContainer
        
        // Set route as tag for easier lookup
        rootLayout.tag = route
        contentContainer.tag = route

        // Configure screen based on presentation style
        configureScreen(screenContainer, props)
        
        // Store configurations
        storeConfigurations(screenContainer, props)
        
        // Handle any navigation commands
        handleRouteNavigationCommand(screenContainer, props)

        return rootLayout
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        Log.d(TAG, "🔧 DCFScreenComponent: Updating screen view")
        
        // Find the screen container for this view
        val screenContainer = findScreenContainerForView(view)
        if (screenContainer != null) {
            storeConfigurations(screenContainer, props)
            handleRouteNavigationCommand(screenContainer, props)
            return true
        }

        Log.w(TAG, "⚠️ DCFScreenComponent: Could not find screen container for view update")
        return false
    }


    private fun configureScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        when (screenContainer.presentationStyle) {
            "tab" -> configureTabScreen(screenContainer, props)
            "push" -> configurePushScreen(screenContainer, props)
            "modal" -> configureModalScreen(screenContainer, props)
            "sheet" -> configureSheetScreen(screenContainer, props)
            "popover" -> configurePopoverScreen(screenContainer, props)
            "overlay" -> configureOverlayScreen(screenContainer, props)
            else -> {
                Log.w(TAG, "⚠️ DCFScreenComponent: Unknown presentation style '${screenContainer.presentationStyle}'")
            }
        }
    }

    private fun configureTabScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring tab screen '${screenContainer.route}'")
        
        // Store tab configuration
        screenContainer.tabConfig = mapOf(
            "title" to (props["title"] as? String),
            "icon" to props["icon"],
            "badge" to (props["badge"] as? String),
            "enabled" to (props["enabled"] as? Boolean ?: true),
            "index" to (props["index"] as? Int)
        ).filterValues { it != null } as Map<String, Any>
    }

    private fun configurePushScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring push screen '${screenContainer.route}'")
        
        // Store push configuration
        screenContainer.pushConfig = mapOf(
            "title" to (props["title"] as? String),
            "hideNavigationBar" to (props["hideNavigationBar"] as? Boolean ?: false),
            "hideBackButton" to (props["hideBackButton"] as? Boolean ?: false),
            "backButtonTitle" to (props["backButtonTitle"] as? String),
            "largeTitleDisplayMode" to (props["largeTitleDisplayMode"] as? Boolean ?: false),
            "prefixActions" to (props["prefixActions"] as? List<Map<String, Any?>>),
            "suffixActions" to (props["suffixActions"] as? List<Map<String, Any?>>)
        ).filterValues { it != null } as Map<String, Any>
    }

    private fun configureModalScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring modal screen '${screenContainer.route}'")
        
        // Store modal configuration
        screenContainer.modalConfig = mapOf(
            "detents" to (props["detents"] as? List<String>),
            "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
            "cornerRadius" to (props["cornerRadius"] as? Double),
            "transitionStyle" to (props["transitionStyle"] as? String)
        ).filterValues { it != null } as Map<String, Any>
    }

    private fun configureSheetScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring sheet screen '${screenContainer.route}'")
        
        // Store sheet configuration
        screenContainer.sheetConfig = mapOf(
            "title" to (props["title"] as? String),
            "detents" to (props["detents"] as? List<String>),
            "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
            "cornerRadius" to (props["cornerRadius"] as? Double)
        ).filterValues { it != null } as Map<String, Any>
    }

    private fun configurePopoverScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring popover screen '${screenContainer.route}'")
        
        // Store popover configuration
        screenContainer.popoverConfig = mapOf(
            "title" to (props["title"] as? String),
            "preferredWidth" to (props["preferredWidth"] as? Double),
            "preferredHeight" to (props["preferredHeight"] as? Double),
            "permittedArrowDirections" to (props["permittedArrowDirections"] as? List<String>),
            "dismissOnOutsideTap" to (props["dismissOnOutsideTap"] as? Boolean ?: true)
        ).filterValues { it != null } as Map<String, Any>
    }

    private fun configureOverlayScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring overlay screen '${screenContainer.route}'")
        
        // Store overlay configuration
        screenContainer.overlayConfig = mapOf(
            "title" to (props["title"] as? String),
            "overlayBackgroundColor" to (props["overlayBackgroundColor"] as? String),
            "dismissOnTap" to (props["dismissOnTap"] as? Boolean ?: true),
            "animationDuration" to (props["animationDuration"] as? Double),
            "blocksInteraction" to (props["blocksInteraction"] as? Boolean ?: false)
        ).filterValues { it != null } as Map<String, Any>
    }

    private fun storeConfigurations(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        // Store all configurations for later use
        storeTabConfiguration(screenContainer, props)
        storePushConfiguration(screenContainer, props)
        storeModalConfiguration(screenContainer, props)
        storePopoverConfiguration(screenContainer, props)
        storeOverlayConfiguration(screenContainer, props)
        storeSheetConfiguration(screenContainer, props)
        storeNavigationBarConfiguration(screenContainer, props)
    }

    private fun storeTabConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val tabConfig = props["tabConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.tabConfig = tabConfig.plus(
            mapOf(
                "title" to (props["title"] as? String),
                "icon" to props["icon"],
                "badge" to (props["badge"] as? String),
                "enabled" to (props["enabled"] as? Boolean ?: true),
                "index" to (props["index"] as? Int)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun storePushConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val pushConfig = props["pushConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.pushConfig = pushConfig.plus(
            mapOf(
                "title" to (props["title"] as? String),
                "hideNavigationBar" to (props["hideNavigationBar"] as? Boolean ?: false),
                "hideBackButton" to (props["hideBackButton"] as? Boolean ?: false),
                "backButtonTitle" to (props["backButtonTitle"] as? String),
                "largeTitleDisplayMode" to (props["largeTitleDisplayMode"] as? Boolean ?: false),
                "prefixActions" to (props["prefixActions"] as? List<Map<String, Any?>>),
                "suffixActions" to (props["suffixActions"] as? List<Map<String, Any?>>)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun storeModalConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val modalConfig = props["modalConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.modalConfig = modalConfig.plus(
            mapOf(
                "detents" to (props["detents"] as? List<String>),
                "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
                "cornerRadius" to (props["cornerRadius"] as? Double),
                "transitionStyle" to (props["transitionStyle"] as? String)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun storePopoverConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val popoverConfig = props["popoverConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.popoverConfig = popoverConfig.plus(
            mapOf(
                "title" to (props["title"] as? String),
                "preferredWidth" to (props["preferredWidth"] as? Double),
                "preferredHeight" to (props["preferredHeight"] as? Double),
                "permittedArrowDirections" to (props["permittedArrowDirections"] as? List<String>),
                "dismissOnOutsideTap" to (props["dismissOnOutsideTap"] as? Boolean ?: true)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun storeOverlayConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val overlayConfig = props["overlayConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.overlayConfig = overlayConfig.plus(
            mapOf(
                "title" to (props["title"] as? String),
                "overlayBackgroundColor" to (props["overlayBackgroundColor"] as? String),
                "dismissOnTap" to (props["dismissOnTap"] as? Boolean ?: true),
                "animationDuration" to (props["animationDuration"] as? Double),
                "blocksInteraction" to (props["blocksInteraction"] as? Boolean ?: false)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun storeSheetConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val sheetConfig = props["sheetConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.sheetConfig = sheetConfig.plus(
            mapOf(
                "detents" to (props["detents"] as? List<String>),
                "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
                "cornerRadius" to (props["cornerRadius"] as? Double)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun storeNavigationBarConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val navBarConfig = props["navigationBarConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.navigationBarConfig = navBarConfig.plus(
            mapOf(
                "navigationBarTitle" to (props["navigationBarTitle"] as? String),
                "largeTitleDisplayMode" to (props["largeTitleDisplayMode"] as? Boolean ?: false),
                "hideNavigationBar" to (props["hideNavigationBar"] as? Boolean ?: false),
                "prefixActions" to (props["prefixActions"] as? List<Map<String, Any?>>),
                "suffixActions" to (props["suffixActions"] as? List<Map<String, Any?>>)
            ).filterValues { it != null }
        ) as Map<String, Any>
    }

    private fun handleRouteNavigationCommand(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val commandData = props["routeNavigationCommand"] as? Map<String, Any?> ?: return

        Log.d(TAG, "🚀 DCFScreenComponent: Processing route navigation command for '${screenContainer.route}': $commandData")

        // Handle different navigation commands
        when {
            commandData.containsKey("navigateToRoute") -> {
                val targetRoute = commandData["navigateToRoute"] as? String
                val params = commandData["params"] as? Map<String, Any?> ?: emptyMap()
                val nonNullParams = params.filterValues { it != null } as Map<String, Any>
                if (targetRoute != null) {
                    Log.d(TAG, "🧭 DCFScreenComponent: Navigating to '$targetRoute' from '${screenContainer.route}'")
                    NavigationManager().navigateTo(targetRoute, nonNullParams, screenContainer.route)
                    // Hide current screen and show target screen
                    hideCurrentScreenAndShowTarget(screenContainer.route, targetRoute)
                }
            }
            commandData.containsKey("popToRoute") -> {
                val targetRoute = commandData["popToRoute"] as? String
                if (targetRoute != null) {
                    NavigationManager().popToRoute(targetRoute, screenContainer.route)
                    showTargetScreen(targetRoute)
                }
            }
            commandData.containsKey("pop") -> {
                NavigationManager().pop(screenContainer.route)
                showPreviousScreen()
            }
            commandData.containsKey("popToRoot") -> {
                NavigationManager().popToRoot(screenContainer.route)
                showRootScreen()
            }
            commandData.containsKey("replaceWithRoute") -> {
                val replaceCommand = commandData["replaceWithRoute"] as? Map<String, Any?>
                val targetRoute = replaceCommand?.get("route") as? String
                val params = replaceCommand?.get("params") as? Map<String, Any?> ?: emptyMap()
                val nonNullParams = params.filterValues { it != null } as Map<String, Any>
                if (targetRoute != null) {
                    NavigationManager().replace(targetRoute, nonNullParams, screenContainer.route)
                    hideCurrentScreenAndShowTarget(screenContainer.route, targetRoute)
                }
            }
            commandData.containsKey("presentModalRoute") -> {
                val modalCommand = commandData["presentModalRoute"] as? Map<String, Any?>
                val targetRoute = modalCommand?.get("route") as? String
                val params = modalCommand?.get("params") as? Map<String, Any?> ?: emptyMap()
                val nonNullParams = params.filterValues { it != null } as Map<String, Any>
                if (targetRoute != null) {
                    NavigationManager().presentModal(targetRoute, nonNullParams, screenContainer.route)
                    showTargetScreen(targetRoute)
                }
            }
            commandData.containsKey("dismissModal") -> {
                NavigationManager().dismissModal(screenContainer.route)
                hideCurrentScreenAndShowPrevious()
            }
        }
    }

    private fun hideCurrentScreenAndShowTarget(currentRoute: String, targetRoute: String) {
        Log.d(TAG, "🔄 DCFScreenComponent: Hiding '$currentRoute' and showing '$targetRoute'")
        
        // Get the root view of the current screen and hide it completely
        val currentContainer = DCFScreenRegistry().getScreenContainer(currentRoute)
        if (currentContainer != null) {
            Log.d(TAG, "👁️ DCFScreenComponent: Hiding current screen '$currentRoute'")
            currentContainer.setVisible(false)
            // Hide the entire screen root view
            val rootView = findRootViewForScreen(currentRoute)
            rootView?.visibility = android.view.View.GONE
        } else {
            Log.w(TAG, "⚠️ DCFScreenComponent: Could not find current screen container for '$currentRoute'")
        }
        
        // Show target screen
        showTargetScreen(targetRoute)
    }

    private fun showTargetScreen(route: String) {
        Log.d(TAG, "👁️ DCFScreenComponent: Showing screen '$route'")
        
        val targetContainer = DCFScreenRegistry().getScreenContainer(route)
        if (targetContainer != null) {
            Log.d(TAG, "✅ DCFScreenComponent: Found target screen container for '$route'")
            targetContainer.setVisible(true)
            targetContainer.contentView?.visibility = android.view.View.VISIBLE
            // Show the entire screen root view
            val rootView = findRootViewForScreen(route)
            rootView?.visibility = android.view.View.VISIBLE
            // Force a layout update
            rootView?.requestLayout()
        } else {
            Log.w(TAG, "⚠️ DCFScreenComponent: Could not find target screen container for '$route'")
            // List all available screens for debugging
            val allScreens = DCFScreenRegistry().getAllScreens()
            Log.d(TAG, "🔍 DCFScreenComponent: Available screens: ${allScreens.keys}")
        }
    }

    private fun showPreviousScreen() {
        val navigationStack = NavigationManager().getNavigationStack()
        if (navigationStack.isNotEmpty()) {
            val previousRoute = navigationStack[navigationStack.size - 2]
            showTargetScreen(previousRoute)
        }
    }

    private fun showRootScreen() {
        val navigationStack = NavigationManager().getNavigationStack()
        if (navigationStack.isNotEmpty()) {
            val rootRoute = navigationStack[0]
            showTargetScreen(rootRoute)
        }
    }

    private fun hideCurrentScreenAndShowPrevious() {
        val navigationStack = NavigationManager().getNavigationStack()
        if (navigationStack.size > 1) {
            val currentRoute = navigationStack.last()
            val previousRoute = navigationStack[navigationStack.size - 2]
            hideCurrentScreenAndShowTarget(currentRoute, previousRoute)
        }
    }

    private fun findRootViewForScreen(route: String): View? {
        val container = DCFScreenRegistry().getScreenContainer(route)
        return container?.contentView?.parent as? View
    }

    private fun findScreenContainerForView(view: View): ScreenContainer? {
        // Try to find by direct contentView match first
        val directMatch = DCFScreenRegistry().getAllScreens().values.find { it.contentView == view }
        if (directMatch != null) return directMatch
        
        // If not found, try to find by traversing the view hierarchy
        var currentView: View? = view
        while (currentView != null) {
            val parent = currentView.parent
            if (parent is View) {
                val parentMatch = DCFScreenRegistry().getAllScreens().values.find { it.contentView == parent }
                if (parentMatch != null) return parentMatch
                currentView = parent
            } else {
                break
            }
        }
        
        // Last resort: find by route from view tag or other identifier
        val route = view.tag as? String
        if (route != null) {
            return DCFScreenRegistry().getScreenContainer(route)
        }
        
        return null
    }
}
