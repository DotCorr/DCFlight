package com.dotcorr.dcfscreens.components.navigation.utils

import android.app.Activity
import android.content.Context
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import androidx.lifecycle.ProcessLifecycleOwner
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import java.util.concurrent.ConcurrentHashMap

/**
 * Lifecycle Event Helper - Android Fallback Implementation
 * 
 * Manages screen lifecycle events and provides fallback functionality.
 * Integrates with Android's lifecycle system for proper event handling.
 */
class LifecycleEventHelper : LifecycleObserver {
    private var activity: Activity? = null
    private val screenLifecycleStates = ConcurrentHashMap<String, ScreenLifecycleState>()
    private val lifecycleListeners = mutableListOf<LifecycleEventListener>()
    
    // Screen lifecycle states
    private data class ScreenLifecycleState(
        var isCreated: Boolean = false,
        var isStarted: Boolean = false,
        var isResumed: Boolean = false,
        var isPaused: Boolean = false,
        var isStopped: Boolean = false,
        var isDestroyed: Boolean = false
    )
    
    fun setActivity(activity: Activity?) {
        this.activity = activity
        
        if (activity != null) {
            // Register for app lifecycle events
            ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        } else {
            // Unregister from app lifecycle events
            ProcessLifecycleOwner.get().lifecycle.removeObserver(this)
        }
    }
    
    // App lifecycle events
    @OnLifecycleEvent(Lifecycle.Event.ON_START)
    fun onAppStart() {
        println("📱 LifecycleEventHelper: App started")
        notifyAppLifecycleEvent("onAppStart", emptyMap())
    }
    
    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    fun onAppResume() {
        println("📱 LifecycleEventHelper: App resumed")
        notifyAppLifecycleEvent("onAppResume", emptyMap())
    }
    
    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    fun onAppPause() {
        println("📱 LifecycleEventHelper: App paused")
        notifyAppLifecycleEvent("onAppPause", emptyMap())
    }
    
    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    fun onAppStop() {
        println("📱 LifecycleEventHelper: App stopped")
        notifyAppLifecycleEvent("onAppStop", emptyMap())
    }
    
    // Screen lifecycle management
    fun onScreenAppear(route: String, container: ScreenContainer) {
        println("👁️ LifecycleEventHelper: Screen '$route' appeared")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isCreated = true
        state.isStarted = true
        state.isResumed = true
        
        container.onAppear()
        notifyScreenLifecycleEvent(route, "onAppear", container)
    }
    
    fun onScreenDisappear(route: String, container: ScreenContainer) {
        println("👁️ LifecycleEventHelper: Screen '$route' disappeared")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isPaused = true
        state.isStopped = true
        
        container.onDisappear()
        notifyScreenLifecycleEvent(route, "onDisappear", container)
    }
    
    fun onScreenActivate(route: String, container: ScreenContainer) {
        println("⚡ LifecycleEventHelper: Screen '$route' activated")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isResumed = true
        
        container.onActivate()
        notifyScreenLifecycleEvent(route, "onActivate", container)
    }
    
    fun onScreenDeactivate(route: String, container: ScreenContainer) {
        println("⚡ LifecycleEventHelper: Screen '$route' deactivated")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isPaused = true
        
        container.onDeactivate()
        notifyScreenLifecycleEvent(route, "onDeactivate", container)
    }
    
    fun onScreenStart(route: String, container: ScreenContainer) {
        println("🚀 LifecycleEventHelper: Screen '$route' started")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isStarted = true
        
        notifyScreenLifecycleEvent(route, "onStart", container)
    }
    
    fun onScreenStop(route: String, container: ScreenContainer) {
        println("🛑 LifecycleEventHelper: Screen '$route' stopped")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isStopped = true
        
        notifyScreenLifecycleEvent(route, "onStop", container)
    }
    
    fun onScreenResume(route: String, container: ScreenContainer) {
        println("▶️ LifecycleEventHelper: Screen '$route' resumed")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isResumed = true
        
        notifyScreenLifecycleEvent(route, "onResume", container)
    }
    
    fun onScreenPause(route: String, container: ScreenContainer) {
        println("⏸️ LifecycleEventHelper: Screen '$route' paused")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isPaused = true
        
        notifyScreenLifecycleEvent(route, "onPause", container)
    }
    
    fun onScreenDestroy(route: String, container: ScreenContainer) {
        println("💥 LifecycleEventHelper: Screen '$route' destroyed")
        
        val state = screenLifecycleStates.getOrPut(route) { ScreenLifecycleState() }
        state.isDestroyed = true
        
        notifyScreenLifecycleEvent(route, "onDestroy", container)
        screenLifecycleStates.remove(route)
    }
    
    // Navigation events
    fun onNavigationEvent(route: String, event: Map<String, Any>, container: ScreenContainer) {
        println("🧭 LifecycleEventHelper: Navigation event for '$route': $event")
        
        container.onNavigationEvent(event)
        notifyScreenLifecycleEvent(route, "onNavigationEvent", container, event)
    }
    
    fun onReceiveParams(route: String, params: Map<String, Any>, container: ScreenContainer) {
        println("📦 LifecycleEventHelper: Received params for '$route': $params")
        
        container.onReceiveParams(params)
        notifyScreenLifecycleEvent(route, "onReceiveParams", container, params)
    }
    
    fun onHeaderActionPress(route: String, action: Map<String, Any>, container: ScreenContainer) {
        println("🎯 LifecycleEventHelper: Header action for '$route': $action")
        
        container.onHeaderActionPress(action)
        notifyScreenLifecycleEvent(route, "onHeaderActionPress", container, action)
    }
    
    // State queries
    fun isScreenCreated(route: String): Boolean {
        return screenLifecycleStates[route]?.isCreated ?: false
    }
    
    fun isScreenStarted(route: String): Boolean {
        return screenLifecycleStates[route]?.isStarted ?: false
    }
    
    fun isScreenResumed(route: String): Boolean {
        return screenLifecycleStates[route]?.isResumed ?: false
    }
    
    fun isScreenPaused(route: String): Boolean {
        return screenLifecycleStates[route]?.isPaused ?: false
    }
    
    fun isScreenStopped(route: String): Boolean {
        return screenLifecycleStates[route]?.isStopped ?: false
    }
    
    fun isScreenDestroyed(route: String): Boolean {
        return screenLifecycleStates[route]?.isDestroyed ?: false
    }
    
    fun getScreenLifecycleState(route: String): Map<String, Boolean> {
        val state = screenLifecycleStates[route] ?: ScreenLifecycleState()
        return mapOf(
            "isCreated" to state.isCreated,
            "isStarted" to state.isStarted,
            "isResumed" to state.isResumed,
            "isPaused" to state.isPaused,
            "isStopped" to state.isStopped,
            "isDestroyed" to state.isDestroyed
        )
    }
    
    fun getAllScreenStates(): Map<String, Map<String, Boolean>> {
        return screenLifecycleStates.mapValues { (_, state) ->
            mapOf(
                "isCreated" to state.isCreated,
                "isStarted" to state.isStarted,
                "isResumed" to state.isResumed,
                "isPaused" to state.isPaused,
                "isStopped" to state.isStopped,
                "isDestroyed" to state.isDestroyed
            )
        }
    }
    
    // Event listeners
    fun addListener(listener: LifecycleEventListener) {
        lifecycleListeners.add(listener)
    }
    
    fun removeListener(listener: LifecycleEventListener) {
        lifecycleListeners.remove(listener)
    }
    
    private fun notifyAppLifecycleEvent(event: String, data: Map<String, Any>) {
        lifecycleListeners.forEach { listener ->
            try {
                listener.onAppLifecycleEvent(event, data)
            } catch (e: Exception) {
                println("❌ LifecycleEventHelper: Error notifying app lifecycle event '$event': ${e.message}")
            }
        }
    }
    
    private fun notifyScreenLifecycleEvent(
        route: String, 
        event: String, 
        container: ScreenContainer, 
        data: Map<String, Any> = emptyMap()
    ) {
        lifecycleListeners.forEach { listener ->
            try {
                listener.onScreenLifecycleEvent(route, event, container, data)
            } catch (e: Exception) {
                println("❌ LifecycleEventHelper: Error notifying screen lifecycle event '$event' for '$route': ${e.message}")
            }
        }
    }
    
    // Cleanup
    fun clear() {
        println("🧹 LifecycleEventHelper: Clearing all lifecycle states")
        
        screenLifecycleStates.clear()
        lifecycleListeners.clear()
        
        if (activity != null) {
            ProcessLifecycleOwner.get().lifecycle.removeObserver(this)
        }
    }
}

/**
 * Lifecycle Event Listener Interface
 */
interface LifecycleEventListener {
    fun onAppLifecycleEvent(event: String, data: Map<String, Any>)
    fun onScreenLifecycleEvent(route: String, event: String, container: ScreenContainer, data: Map<String, Any>)
}
