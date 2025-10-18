package com.dotcorr.dcfscreens.components.navigation.registry

import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import java.util.concurrent.ConcurrentHashMap

/**
 * DCF Screen Registry - Android Fallback Implementation
 * 
 * Manages screen registration and provides fallback functionality.
 * Maintains API compatibility while using Android native components.
 */
class DCFScreenRegistry {
    private val screens = ConcurrentHashMap<String, ScreenContainer>()
    private val screenListeners = mutableListOf<ScreenRegistryListener>()
    
    /**
     * Get a screen container by route
     */
    fun getScreenContainer(route: String): ScreenContainer? {
        return screens[route]
    }
    
    /**
     * Register a screen with the registry
     */
    fun registerScreen(route: String, container: ScreenContainer) {
        println("📝 DCFScreenRegistry: Registering screen '$route'")
        
        screens[route] = container
        
        // Add event listener for screen events
        container.addEventListener(object : com.dotcorr.dcfscreens.components.navigation.models.ScreenEventListener {
            override fun onScreenEvent(route: String, event: String, data: Map<String, Any>) {
                notifyScreenEvent(route, event, data)
            }
        })
        
        notifyScreenRegistered(route, container)
    }
    
    /**
     * Unregister a screen from the registry
     */
    fun unregisterScreen(route: String) {
        println("🗑️ DCFScreenRegistry: Unregistering screen '$route'")
        
        screens.remove(route)
        notifyScreenUnregistered(route)
    }
    
    /**
     * Get a screen container by route
     */
    fun getScreen(route: String): ScreenContainer? {
        return screens[route]
    }
    
    /**
     * Get all registered screens
     */
    fun getAllScreens(): Map<String, ScreenContainer> {
        return screens.toMap()
    }
    
    /**
     * Check if a screen is registered
     */
    fun isScreenRegistered(route: String): Boolean {
        return screens.containsKey(route)
    }
    
    /**
     * Get all screen routes
     */
    fun getAllRoutes(): List<String> {
        return screens.keys.toList()
    }
    
    /**
     * Find screens by presentation style
     */
    fun getScreensByPresentationStyle(style: String): List<ScreenContainer> {
        return screens.values.filter { container ->
            container.presentationStyle == style
        }
    }
    
    /**
     * Find screens by tab index
     */
    fun getScreensByTabIndex(index: Int): List<ScreenContainer> {
        return screens.values.filter { container ->
            container.tabIndex == index
        }
    }
    
    /**
     * Get active screens
     */
    fun getActiveScreens(): List<ScreenContainer> {
        return screens.values.filter { container ->
            container.isScreenActive()
        }
    }
    
    /**
     * Get visible screens
     */
    fun getVisibleScreens(): List<ScreenContainer> {
        return screens.values.filter { container ->
            container.isScreenVisible()
        }
    }
    
    /**
     * Update screen configuration
     */
    fun updateScreenConfig(route: String, config: Map<String, Any>) {
        screens[route]?.updateConfig(config)
        notifyScreenUpdated(route, screens[route])
    }
    
    /**
     * Update screen parameters
     */
    fun updateScreenParams(route: String, params: Map<String, Any>) {
        screens[route]?.updateParams(params)
        notifyScreenUpdated(route, screens[route])
    }
    
    /**
     * Activate a screen
     */
    fun activateScreen(route: String) {
        screens[route]?.setActive(true)
        screens[route]?.onActivate()
        notifyScreenActivated(route, screens[route])
    }
    
    /**
     * Deactivate a screen
     */
    fun deactivateScreen(route: String) {
        screens[route]?.setActive(false)
        screens[route]?.onDeactivate()
        notifyScreenDeactivated(route, screens[route])
    }
    
    /**
     * Show a screen
     */
    fun showScreen(route: String) {
        screens[route]?.setVisible(true)
        screens[route]?.onAppear()
        notifyScreenShown(route, screens[route])
    }
    
    /**
     * Hide a screen
     */
    fun hideScreen(route: String) {
        screens[route]?.setVisible(false)
        screens[route]?.onDisappear()
        notifyScreenHidden(route, screens[route])
    }
    
    /**
     * Clear all screens
     */
    fun clear() {
        println("🧹 DCFScreenRegistry: Clearing all screens")
        
        screens.clear()
        notifyRegistryCleared()
    }
    
    /**
     * Get registry statistics
     */
    fun getStatistics(): Map<String, Any> {
        return mapOf(
            "totalScreens" to screens.size,
            "activeScreens" to getActiveScreens().size,
            "visibleScreens" to getVisibleScreens().size,
            "routes" to getAllRoutes()
        )
    }
    
    // Event handling
    fun addListener(listener: ScreenRegistryListener) {
        screenListeners.add(listener)
    }
    
    fun removeListener(listener: ScreenRegistryListener) {
        screenListeners.remove(listener)
    }
    
    private fun notifyScreenRegistered(route: String, container: ScreenContainer) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenRegistered(route, container)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen registered for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenUnregistered(route: String) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenUnregistered(route)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen unregistered for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenUpdated(route: String, container: ScreenContainer?) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenUpdated(route, container)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen updated for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenActivated(route: String, container: ScreenContainer?) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenActivated(route, container)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen activated for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenDeactivated(route: String, container: ScreenContainer?) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenDeactivated(route, container)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen deactivated for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenShown(route: String, container: ScreenContainer?) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenShown(route, container)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen shown for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenHidden(route: String, container: ScreenContainer?) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenHidden(route, container)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen hidden for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenEvent(route: String, event: String, data: Map<String, Any>) {
        screenListeners.forEach { listener ->
            try {
                listener.onScreenEvent(route, event, data)
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying screen event '$event' for '$route': ${e.message}")
            }
        }
    }
    
    private fun notifyRegistryCleared() {
        screenListeners.forEach { listener ->
            try {
                listener.onRegistryCleared()
            } catch (e: Exception) {
                println("❌ DCFScreenRegistry: Error notifying registry cleared: ${e.message}")
            }
        }
    }
}

/**
 * Screen Registry Listener Interface
 */
interface ScreenRegistryListener {
    fun onScreenRegistered(route: String, container: ScreenContainer)
    fun onScreenUnregistered(route: String)
    fun onScreenUpdated(route: String, container: ScreenContainer?)
    fun onScreenActivated(route: String, container: ScreenContainer?)
    fun onScreenDeactivated(route: String, container: ScreenContainer?)
    fun onScreenShown(route: String, container: ScreenContainer?)
    fun onScreenHidden(route: String, container: ScreenContainer?)
    fun onScreenEvent(route: String, event: String, data: Map<String, Any>)
    fun onRegistryCleared()
}
