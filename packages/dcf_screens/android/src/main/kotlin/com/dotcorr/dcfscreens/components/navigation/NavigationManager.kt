package com.dotcorr.dcfscreens.components.navigation

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import com.dotcorr.dcfscreens.components.navigation.registry.DCFScreenRegistry
import com.dotcorr.dcfscreens.components.navigation.utils.LifecycleEventHelper

/**
 * Navigation Manager - Android Fallback Implementation
 * 
 * Manages navigation state and coordinates between Flutter and Android native navigation.
 * Provides fallback functionality that maintains API compatibility.
 */
class NavigationManager {
    private var activity: Activity? = null
    private val screenRegistry = DCFScreenRegistry()
    private val lifecycleHelper = LifecycleEventHelper()
    
    // Navigation state
    private var activeScreen: String? = null
    private val navigationStack = mutableListOf<String>()
    private val screenContainers = mutableMapOf<String, ScreenContainer>()
    
    fun setActivity(activity: Activity?) {
        this.activity = activity
        lifecycleHelper.setActivity(activity)
    }
    
    // Screen Management
    fun createScreen(route: String, config: Map<String, Any>) {
        println("🏗️ NavigationManager: Creating screen '$route' with config: $config")
        
        val presentationStyle = config["presentationStyle"] as? String ?: "push"
        val container = ScreenContainer(route, presentationStyle)
        screenContainers[route] = container
        screenRegistry.registerScreen(route, container)
        
        // Initialize screen state
        if (activeScreen == null) {
            activeScreen = route
            navigationStack.add(route)
        }
    }
    
    fun destroyScreen(route: String) {
        println("🗑️ NavigationManager: Destroying screen '$route'")
        
        screenContainers.remove(route)
        screenRegistry.unregisterScreen(route)
        
        if (activeScreen == route) {
            if (navigationStack.size > 1) {
                navigationStack.removeAt(navigationStack.size - 1)
                activeScreen = navigationStack.lastOrNull()
            } else {
                activeScreen = null
            }
        }
    }
    
    // Navigation Commands
    fun navigateTo(route: String, params: Map<String, Any>?, fromScreen: String?) {
        println("🧭 NavigationManager: Navigate to '$route' from '$fromScreen' with params: $params")
        
        // Update navigation state
        activeScreen = route
        if (!navigationStack.contains(route)) {
            navigationStack.add(route)
        }
        
        // Handle screen lifecycle
        screenContainers[route]?.let { container ->
            container.updateParams(params ?: emptyMap())
            lifecycleHelper.onScreenAppear(route, container)
        }
        
        // Notify Flutter about navigation change
        notifyNavigationChange("navigateTo", route, fromScreen)
    }
    
    fun pop(fromScreen: String?) {
        println("⬅️ NavigationManager: Pop from '$fromScreen'")
        
        if (navigationStack.size > 1) {
            val currentScreen = navigationStack.removeAt(navigationStack.size - 1)
            activeScreen = navigationStack.lastOrNull()
            
            // Handle screen lifecycle
            screenContainers[currentScreen]?.let { container ->
                lifecycleHelper.onScreenDisappear(currentScreen, container)
            }
            
            activeScreen?.let { screen ->
                screenContainers[screen]?.let { container ->
                    lifecycleHelper.onScreenAppear(screen, container)
                }
            }
            
            notifyNavigationChange("pop", activeScreen, fromScreen)
        }
    }
    
    fun popToRoute(route: String, fromScreen: String?) {
        println("🎯 NavigationManager: Pop to route '$route' from '$fromScreen'")
        
        val targetIndex = navigationStack.indexOf(route)
        if (targetIndex != -1) {
            // Remove screens after target
            val removedScreens = navigationStack.subList(targetIndex + 1, navigationStack.size)
            navigationStack.subList(targetIndex + 1, navigationStack.size).clear()
            
            activeScreen = route
            
            // Handle lifecycle for removed screens
            removedScreens.forEach { screen ->
                screenContainers[screen]?.let { container ->
                    lifecycleHelper.onScreenDisappear(screen, container)
                }
            }
            
            // Handle lifecycle for target screen
            screenContainers[route]?.let { container ->
                lifecycleHelper.onScreenAppear(route, container)
            }
            
            notifyNavigationChange("popToRoute", route, fromScreen)
        }
    }
    
    fun popToRoot(fromScreen: String?) {
        println("🏠 NavigationManager: Pop to root from '$fromScreen'")
        
        if (navigationStack.size > 1) {
            val removedScreens = navigationStack.subList(1, navigationStack.size)
            navigationStack.clear()
            navigationStack.add("home")
            activeScreen = "home"
            
            // Handle lifecycle for removed screens
            removedScreens.forEach { screen ->
                screenContainers[screen]?.let { container ->
                    lifecycleHelper.onScreenDisappear(screen, container)
                }
            }
            
            // Handle lifecycle for home screen
            screenContainers["home"]?.let { container ->
                lifecycleHelper.onScreenAppear("home", container)
            }
            
            notifyNavigationChange("popToRoot", "home", fromScreen)
        }
    }
    
    fun replace(route: String, params: Map<String, Any>?, fromScreen: String?) {
        println("🔄 NavigationManager: Replace with '$route' from '$fromScreen' with params: $params")
        
        if (navigationStack.isNotEmpty()) {
            val currentScreen = navigationStack[navigationStack.size - 1]
            navigationStack[navigationStack.size - 1] = route
            activeScreen = route
            
            // Handle lifecycle
            screenContainers[currentScreen]?.let { container ->
                lifecycleHelper.onScreenDisappear(currentScreen, container)
            }
            
            screenContainers[route]?.let { container ->
                container.updateParams(params ?: emptyMap())
                lifecycleHelper.onScreenAppear(route, container)
            }
            
            notifyNavigationChange("replace", route, fromScreen)
        }
    }
    
    // Modal Navigation
    fun presentModal(route: String, params: Map<String, Any>?, fromScreen: String?) {
        println("📱 NavigationManager: Present modal '$route' from '$fromScreen' with params: $params")
        
        // For Android fallback, treat modal as regular navigation
        navigateTo(route, params, fromScreen)
        
        // Notify about modal presentation
        notifyNavigationChange("presentModal", route, fromScreen)
    }
    
    fun dismissModal(fromScreen: String?) {
        println("❌ NavigationManager: Dismiss modal from '$fromScreen'")
        
        // For Android fallback, treat as regular pop
        pop(fromScreen)
        
        // Notify about modal dismissal
        notifyNavigationChange("dismissModal", activeScreen, fromScreen)
    }
    
    // Tab Navigation
    fun createTabNavigator(config: Map<String, Any>) {
        println("📑 NavigationManager: Create tab navigator with config: $config")
        
        val screens = config["screens"] as? List<String> ?: emptyList()
        val selectedIndex = config["selectedIndex"] as? Int ?: 0
        
        if (screens.isNotEmpty() && selectedIndex < screens.size) {
            val selectedScreen = screens[selectedIndex]
            activeScreen = selectedScreen
            navigationStack.clear()
            navigationStack.add(selectedScreen)
            
            notifyNavigationChange("createTabNavigator", selectedScreen, null)
        }
    }
    
    fun selectTab(index: Int) {
        println("📑 NavigationManager: Select tab at index $index")
        
        // This would be handled by the tab navigator component
        notifyNavigationChange("selectTab", index.toString(), null)
    }
    
    // State Management
    fun getActiveScreen(): String? = activeScreen
    
    fun getNavigationStack(): List<String> = navigationStack.toList()
    
    fun clearNavigationState() {
        println("🔄 NavigationManager: Clearing navigation state")
        
        activeScreen = null
        navigationStack.clear()
        screenContainers.clear()
        screenRegistry.clear()
    }
    
    // Event Handling
    fun handleNavigationEvent(event: Map<String, Any>) {
        println("📡 NavigationManager: Handle navigation event: $event")
        
        val action = event["action"] as? String
        val targetRoute = event["targetRoute"] as? String
        val userInitiated = event["userInitiated"] as? Boolean ?: false
        
        when (action) {
            "navigateTo" -> {
                if (targetRoute != null) {
                    navigateTo(targetRoute, null, null)
                }
            }
            "pop" -> {
                pop(null)
            }
            "popToRoute" -> {
                if (targetRoute != null) {
                    popToRoute(targetRoute, null)
                }
            }
            "popToRoot" -> {
                popToRoot(null)
            }
            "replace" -> {
                if (targetRoute != null) {
                    replace(targetRoute, null, null)
                }
            }
            "presentModal" -> {
                if (targetRoute != null) {
                    presentModal(targetRoute, null, null)
                }
            }
            "dismissModal" -> {
                dismissModal(null)
            }
        }
    }
    
    fun handleHeaderAction(action: Map<String, Any>) {
        println("🎯 NavigationManager: Handle header action: $action")
        
        val actionId = action["actionId"] as? String
        val title = action["title"] as? String
        
        // Notify Flutter about header action
        notifyHeaderAction(actionId, title)
    }
    
    // Private helpers
    private fun notifyNavigationChange(action: String, targetRoute: String?, fromScreen: String?) {
        // This would send events back to Flutter
        println("📡 NavigationManager: Navigation change - action: $action, target: $targetRoute, from: $fromScreen")
    }
    
    private fun notifyHeaderAction(actionId: String?, title: String?) {
        // This would send header action events back to Flutter
        println("🎯 NavigationManager: Header action - id: $actionId, title: $title")
    }
}
