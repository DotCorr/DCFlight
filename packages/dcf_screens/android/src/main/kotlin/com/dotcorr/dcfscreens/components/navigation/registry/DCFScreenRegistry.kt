/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation.registry

import android.util.Log
import com.dotcorr.dcfscreens.components.navigation.models.ScreenContainer
import java.util.concurrent.ConcurrentHashMap

/**
 * Global registry for all registered screens
 * Thread-safe singleton managing screen containers and navigation stack
 */
object DCFScreenRegistry {
    private const val TAG = "DCFScreenRegistry"
    
    private val routeRegistry = ConcurrentHashMap<String, ScreenContainer>()
    private val currentRouteStack = mutableListOf<String>()
    private val stackLock = Any()
    
    fun registerScreen(route: String, container: ScreenContainer) {
        routeRegistry[route] = container
        Log.d(TAG, "✅ Registered screen: $route (total: ${routeRegistry.size})")
    }
    
    fun getScreen(route: String): ScreenContainer? {
        return routeRegistry[route]
    }
    
    fun hasScreen(route: String): Boolean {
        return routeRegistry.containsKey(route)
    }
    
    fun getAllRoutes(): List<String> {
        return routeRegistry.keys.toList()
    }
    
    fun getAllScreens(): Map<String, ScreenContainer> {
        return routeRegistry.toMap()
    }
    
    fun pushRoute(route: String) {
        synchronized(stackLock) {
            currentRouteStack.add(route)
            Log.d(TAG, "📚 Stack push: $route | Stack: $currentRouteStack")
        }
    }
    
    fun popRoute(): String? {
        synchronized(stackLock) {
            if (currentRouteStack.isEmpty()) return null
            val popped = currentRouteStack.removeAt(currentRouteStack.size - 1)
            Log.d(TAG, "📚 Stack pop: $popped | Stack: $currentRouteStack")
            return popped
        }
    }
    
    fun popToRoute(route: String) {
        synchronized(stackLock) {
            val index = currentRouteStack.indexOf(route)
            if (index >= 0 && index < currentRouteStack.size - 1) {
                val removed = currentRouteStack.subList(index + 1, currentRouteStack.size)
                Log.d(TAG, "📚 Stack pop to $route, removing: $removed")
                currentRouteStack.subList(index + 1, currentRouteStack.size).clear()
            }
            Log.d(TAG, "📚 Stack after pop to route: $currentRouteStack")
        }
    }
    
    fun popToRoot() {
        synchronized(stackLock) {
            if (currentRouteStack.size > 1) {
                val kept = currentRouteStack.first()
                Log.d(TAG, "📚 Stack pop to root, keeping: $kept")
                currentRouteStack.clear()
                currentRouteStack.add(kept)
            }
            Log.d(TAG, "📚 Stack after pop to root: $currentRouteStack")
        }
    }
    
    fun replaceTopRoute(route: String) {
        synchronized(stackLock) {
            if (currentRouteStack.isNotEmpty()) {
                val replaced = currentRouteStack.removeAt(currentRouteStack.size - 1)
                Log.d(TAG, "📚 Stack replace: $replaced → $route")
            }
            currentRouteStack.add(route)
            Log.d(TAG, "📚 Stack after replace: $currentRouteStack")
        }
    }
    
    fun getCurrentRoute(): String? {
        synchronized(stackLock) {
            return currentRouteStack.lastOrNull()
        }
    }
    
    fun getNavigationStack(): List<String> {
        synchronized(stackLock) {
            return currentRouteStack.toList()
        }
    }
    
    fun clearStack() {
        synchronized(stackLock) {
            currentRouteStack.clear()
            Log.d(TAG, "📚 Stack cleared")
        }
    }
    
    fun clearRegistry() {
        routeRegistry.clear()
        clearStack()
        Log.d(TAG, "🗑️ Registry and stack cleared")
    }
}
