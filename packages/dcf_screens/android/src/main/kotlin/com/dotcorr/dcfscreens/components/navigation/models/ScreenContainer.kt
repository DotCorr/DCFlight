package com.dotcorr.dcfscreens.components.navigation.models

import java.util.concurrent.ConcurrentHashMap

/**
 * Screen Container - Android Fallback Implementation
 * 
 * Represents a screen instance with its configuration and state.
 * Provides fallback functionality for Android platform.
 */
class ScreenContainer(
    val route: String,
    private var config: Map<String, Any>
) {
    private val params = ConcurrentHashMap<String, Any>()
    private var isActive = false
    private var isVisible = false
    
    // Screen configuration
    val presentationStyle: String
        get() = config["presentationStyle"] as? String ?: "push"
    
    val title: String?
        get() = config["title"] as? String
    
    val hideNavigationBar: Boolean
        get() = config["hideNavigationBar"] as? Boolean ?: false
    
    val hideBackButton: Boolean
        get() = config["hideBackButton"] as? Boolean ?: false
    
    val backButtonTitle: String?
        get() = config["backButtonTitle"] as? String
    
    val largeTitleDisplayMode: Boolean
        get() = config["largeTitleDisplayMode"] as? Boolean ?: false
    
    // Modal configuration
    val modalConfig: Map<String, Any>?
        get() = config["modalConfig"] as? Map<String, Any>
    
    val allowsBackgroundDismiss: Boolean
        get() = modalConfig?.get("allowsBackgroundDismiss") as? Boolean ?: true
    
    val detents: List<String>?
        get() = modalConfig?.get("detents") as? List<String>
    
    val selectedDetentIndex: Int?
        get() = modalConfig?.get("selectedDetentIndex") as? Int
    
    val showDragIndicator: Boolean
        get() = modalConfig?.get("showDragIndicator") as? Boolean ?: true
    
    // Tab configuration
    val tabConfig: Map<String, Any>?
        get() = config["tabConfig"] as? Map<String, Any>
    
    val tabTitle: String?
        get() = tabConfig?.get("title") as? String
    
    val tabIcon: Map<String, Any>?
        get() = tabConfig?.get("icon") as? Map<String, Any>
    
    val tabIndex: Int?
        get() = tabConfig?.get("index") as? Int
    
    val tabBadge: String?
        get() = tabConfig?.get("badge") as? String
    
    val tabEnabled: Boolean
        get() = tabConfig?.get("enabled") as? Boolean ?: true
    
    // Header actions
    val prefixActions: List<Map<String, Any>>?
        get() = config["prefixActions"] as? List<Map<String, Any>>
    
    val suffixActions: List<Map<String, Any>>?
        get() = config["suffixActions"] as? List<Map<String, Any>>
    
    // Navigation bar configuration
    val navigationBarConfig: Map<String, Any>?
        get() = config["navigationBarConfig"] as? Map<String, Any>
    
    val navigationBarTitle: String?
        get() = navigationBarConfig?.get("navigationBarTitle") as? String
    
    val largeTitleDisplayModeNav: Boolean
        get() = navigationBarConfig?.get("largeTitleDisplayMode") as? Boolean ?: false
    
    val hideNavigationBarNav: Boolean
        get() = navigationBarConfig?.get("hideNavigationBar") as? Boolean ?: false
    
    val hideBackButtonNav: Boolean
        get() = navigationBarConfig?.get("hideBackButton") as? Boolean ?: false
    
    val backButtonTitleNav: String?
        get() = navigationBarConfig?.get("backButtonTitle") as? String
    
    val prefixActionsNav: List<Map<String, Any>>?
        get() = navigationBarConfig?.get("prefixActions") as? List<Map<String, Any>>
    
    val suffixActionsNav: List<Map<String, Any>>?
        get() = navigationBarConfig?.get("suffixActions") as? List<Map<String, Any>>
    
    // Screen state
    fun isScreenActive(): Boolean = isActive
    
    fun isScreenVisible(): Boolean = isVisible
    
    fun setActive(active: Boolean) {
        isActive = active
    }
    
    fun setVisible(visible: Boolean) {
        isVisible = visible
    }
    
    // Parameters management
    fun getParams(): Map<String, Any> = params.toMap()
    
    fun updateParams(newParams: Map<String, Any>) {
        params.clear()
        params.putAll(newParams)
    }
    
    fun getParam(key: String): Any? = params[key]
    
    fun setParam(key: String, value: Any) {
        params[key] = value
    }
    
    // Configuration management
    fun getConfig(): Map<String, Any> = config
    
    fun updateConfig(newConfig: Map<String, Any>) {
        config = newConfig
    }
    
    fun getConfigValue(key: String): Any? = config[key]
    
    fun setConfigValue(key: String, value: Any) {
        val mutableConfig = config.toMutableMap()
        mutableConfig[key] = value
        config = mutableConfig
    }
    
    // Event handling
    private val eventListeners = mutableListOf<ScreenEventListener>()
    
    fun addEventListener(listener: ScreenEventListener) {
        eventListeners.add(listener)
    }
    
    fun removeEventListener(listener: ScreenEventListener) {
        eventListeners.remove(listener)
    }
    
    fun notifyEvent(event: String, data: Map<String, Any>) {
        eventListeners.forEach { listener ->
            try {
                listener.onScreenEvent(route, event, data)
            } catch (e: Exception) {
                println("❌ ScreenContainer: Error notifying event '$event' for route '$route': ${e.message}")
            }
        }
    }
    
    // Lifecycle events
    fun onAppear() {
        isVisible = true
        notifyEvent("onAppear", mapOf("route" to route))
    }
    
    fun onDisappear() {
        isVisible = false
        notifyEvent("onDisappear", mapOf("route" to route))
    }
    
    fun onActivate() {
        isActive = true
        notifyEvent("onActivate", mapOf("route" to route))
    }
    
    fun onDeactivate() {
        isActive = false
        notifyEvent("onDeactivate", mapOf("route" to route))
    }
    
    fun onNavigationEvent(event: Map<String, Any>) {
        notifyEvent("onNavigationEvent", event)
    }
    
    fun onReceiveParams(params: Map<String, Any>) {
        updateParams(params)
        notifyEvent("onReceiveParams", params)
    }
    
    fun onHeaderActionPress(action: Map<String, Any>) {
        notifyEvent("onHeaderActionPress", action)
    }
    
    override fun toString(): String {
        return "ScreenContainer(route='$route', isActive=$isActive, isVisible=$isVisible, params=${params.size})"
    }
}

/**
 * Screen Event Listener Interface
 */
interface ScreenEventListener {
    fun onScreenEvent(route: String, event: String, data: Map<String, Any>)
}
