/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.util.Log
import android.view.View
import java.util.concurrent.ConcurrentHashMap

/**
 * Registry for all DCFlight component types
 * 
 * Registration Pattern:
 * 1. Create component class extending DCFComponent
 * 2. Register via: DCFComponentRegistry.shared.registerComponent("TypeName", ComponentClass::class.java)
 * 
 * This follows React Native's ViewManagerRegistry pattern
 */
class DCFComponentRegistry private constructor() {

    companion object {
        private const val TAG = "DCFComponentRegistry"

        @JvmField
        val shared = DCFComponentRegistry()
    }

    private val componentTypes = ConcurrentHashMap<String, Class<out DCFComponent>>()
    private val componentInstances = ConcurrentHashMap<String, DCFComponent>()

    /**
     * Register a component type
     * 
     * @param type Component type name (must match iOS exactly for cross-platform)
     * @param componentClass Component class extending DCFComponent
     * 
     * Example:
     * ```kotlin
     * DCFComponentRegistry.shared.registerComponent("MyComponent", MyComponent::class.java)
     * ```
     */
    fun registerComponent(type: String, componentClass: Class<out DCFComponent>) {
        if (componentTypes.containsKey(type)) {
        }
        componentTypes[type] = componentClass
        Log.d(TAG, "✅ Registered component type: $type")
    }

    fun getComponentType(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }

    fun getComponent(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }

    fun isComponentRegistered(type: String): Boolean {
        return componentTypes.containsKey(type)
    }

    val registeredTypes: List<String>
        get() = componentTypes.keys.toList()

    fun getRegisteredComponentNames(): List<String> {
        return componentTypes.keys.toList()
    }

    fun createComponentInstance(type: String): DCFComponent? {
        val componentClass = componentTypes[type] ?: return null
        return try {
            componentClass.getDeclaredConstructor().newInstance()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component instance: $type", e)
            null
        }
    }

    fun addComponent(id: String, component: DCFComponent) {
        componentInstances[id] = component
    }

    fun getComponentInstance(id: String): DCFComponent? {
        return componentInstances[id]
    }

    /**
     * Validate that all registered components have proper implementations
     * Useful for debugging cross-platform consistency
     */
    fun validateRegistrations(): Map<String, Boolean> {
        val results = mutableMapOf<String, Boolean>()
        for ((type, componentClass) in componentTypes) {
            try {
                val instance = componentClass.getDeclaredConstructor().newInstance()
                results[type] = instance != null
        } catch (e: Exception) {
                Log.e(TAG, "❌ Validation failed for component: $type", e)
                results[type] = false
            }
        }
        return results
    }
}
