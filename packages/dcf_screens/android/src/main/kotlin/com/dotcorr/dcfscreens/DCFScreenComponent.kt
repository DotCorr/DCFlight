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
        val screenContainer = DCFScreenRegistry.getScreenContainer(route) ?: run {
            val container = ScreenContainer(route, presentationStyle)
            DCFScreenRegistry.registerScreen(container)
            container
        }

        // Configure screen based on presentation style
        configureScreen(screenContainer, props)
        
        // Store configurations
        storeConfigurations(screenContainer, props)
        
        // Handle any navigation commands
        handleRouteNavigationCommand(screenContainer, props)

        return screenContainer.contentView
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
        ).filterValues { it != null }
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
        ).filterValues { it != null }
    }

    private fun configureModalScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring modal screen '${screenContainer.route}'")
        
        // Store modal configuration
        screenContainer.modalConfig = mapOf(
            "detents" to (props["detents"] as? List<String>),
            "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
            "cornerRadius" to (props["cornerRadius"] as? Double),
            "transitionStyle" to (props["transitionStyle"] as? String)
        ).filterValues { it != null }
    }

    private fun configureSheetScreen(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        Log.d(TAG, "🔧 DCFScreenComponent: Configuring sheet screen '${screenContainer.route}'")
        
        // Store sheet configuration
        screenContainer.sheetConfig = mapOf(
            "title" to (props["title"] as? String),
            "detents" to (props["detents"] as? List<String>),
            "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
            "cornerRadius" to (props["cornerRadius"] as? Double)
        ).filterValues { it != null }
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
        ).filterValues { it != null }
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
        ).filterValues { it != null }
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
        )
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
        )
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
        )
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
        )
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
        )
    }

    private fun storeSheetConfiguration(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val sheetConfig = props["sheetConfig"] as? Map<String, Any?> ?: mapOf()
        screenContainer.sheetConfig = sheetConfig.plus(
            mapOf(
                "detents" to (props["detents"] as? List<String>),
                "showDragIndicator" to (props["showDragIndicator"] as? Boolean ?: true),
                "cornerRadius" to (props["cornerRadius"] as? Double)
            ).filterValues { it != null }
        )
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
        )
    }

    private fun handleRouteNavigationCommand(screenContainer: ScreenContainer, props: Map<String, Any?>) {
        val commandData = props["routeNavigationCommand"] as? Map<String, Any?> ?: return
        
        Log.d(TAG, "🚀 DCFScreenComponent: Processing route navigation command for '${screenContainer.route}': $commandData")

        // Handle different navigation commands
        when {
            commandData.containsKey("navigateToRoute") -> {
                val targetRoute = commandData["navigateToRoute"] as? String
                val animated = commandData["animated"] as? Boolean ?: true
                val params = commandData["params"] as? Map<String, Any?>
                if (targetRoute != null) {
                    NavigationManager.navigateTo(targetRoute, animated, params)
                }
            }
            commandData.containsKey("popToRoute") -> {
                val targetRoute = commandData["popToRoute"] as? String
                val animated = commandData["animated"] as? Boolean ?: true
                if (targetRoute != null) {
                    NavigationManager.popToRoute(targetRoute, animated)
                }
            }
            commandData.containsKey("pop") -> {
                val popCommand = commandData["pop"] as? Map<String, Any?>
                val animated = popCommand?.get("animated") as? Boolean ?: true
                val result = popCommand?.get("result") as? Map<String, Any?>
                NavigationManager.pop(animated, result)
            }
            commandData.containsKey("popToRoot") -> {
                val popToRootCommand = commandData["popToRoot"] as? Map<String, Any?>
                val animated = popToRootCommand?.get("animated") as? Boolean ?: true
                NavigationManager.popToRoot(animated)
            }
            commandData.containsKey("replaceWithRoute") -> {
                val replaceCommand = commandData["replaceWithRoute"] as? Map<String, Any?>
                val targetRoute = replaceCommand?.get("route") as? String
                val animated = replaceCommand?.get("animated") as? Boolean ?: true
                val params = replaceCommand?.get("params") as? Map<String, Any?>
                if (targetRoute != null) {
                    NavigationManager.replace(targetRoute, animated, params)
                }
            }
            commandData.containsKey("presentModalRoute") -> {
                val modalCommand = commandData["presentModalRoute"] as? Map<String, Any?>
                val targetRoute = modalCommand?.get("route") as? String
                val animated = modalCommand?.get("animated") as? Boolean ?: true
                val params = modalCommand?.get("params") as? Map<String, Any?>
                val presentationStyle = modalCommand?.get("presentationStyle") as? String
                if (targetRoute != null) {
                    NavigationManager.presentModal(targetRoute, animated, params, presentationStyle)
                }
            }
            commandData.containsKey("dismissModal") -> {
                val dismissModalCommand = commandData["dismissModal"] as? Map<String, Any?>
                val animated = dismissModalCommand?.get("animated") as? Boolean ?: true
                val result = dismissModalCommand?.get("result") as? Map<String, Any?>
                NavigationManager.dismissModal(animated, result)
            }
        }
    }

    private fun findScreenContainerForView(view: View): ScreenContainer? {
        return DCFScreenRegistry.getAllScreens().values.find { it.contentView == view }
    }
}
