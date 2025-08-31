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
 * CRITICAL FIX: Registry for all DCFlight component types
 * Now matches iOS DCFComponentRegistry exactly with proper tunnel method support
 */
class DCFComponentRegistry private constructor() {

    companion object {
        private const val TAG = "DCFComponentRegistry"

        @JvmField
        val shared = DCFComponentRegistry()
    }

    // CRITICAL FIX: Thread-safe map of component CLASSES not factories
    // This matches iOS pattern: componentTypes: [String: DCFComponent.Type] = [:]
    private val componentTypes = ConcurrentHashMap<String, Class<out DCFComponent>>()

    // Map for storing component instances by ID
    private val componentInstances = ConcurrentHashMap<String, DCFComponent>()

    /**
     * CRITICAL FIX: Register a component type handler - EXACT iOS signature
     */
    fun registerComponent(type: String, componentClass: Class<out DCFComponent>) {
        componentTypes[type] = componentClass
        Log.d(TAG, "Registered component type: $type")
    }

    /**
     * CRITICAL FIX: Get the component handler for a specific type - EXACT iOS pattern
     */
    fun getComponentType(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }

    /**
     * CRITICAL FIX: Get the component class for tunnel calls (bridge compatibility) - EXACT iOS method
     */
    fun getComponent(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }

    /**
     * Get all registered component types - iOS compatibility
     */
    val registeredTypes: List<String>
        get() = componentTypes.keys.toList()

    /**
     * CRITICAL FIX: Create a component instance - simplified like iOS
     */
    fun createComponentInstance(type: String): DCFComponent? {
        val componentClass = componentTypes[type]
        if (componentClass == null) {
            Log.e(TAG, "No component registered for type: $type")
            return null
        }

        return try {
            // Try no-arg constructor first like iOS pattern
            componentClass.getDeclaredConstructor().newInstance()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component instance of type: $type", e)
            null
        }
    }

    /**
     * Check if a component type is registered
     */
    fun isComponentRegistered(type: String): Boolean {
        return componentTypes.containsKey(type)
    }

    /**
     * Get the count of registered component types
     */
    fun getRegisteredComponentCount(): Int {
        return componentTypes.size
    }

    /**
     * Get a list of all registered component type names
     */
    fun getRegisteredComponentNames(): List<String> {
        return componentTypes.keys.toList()
    }

    /**
     * Create a component with view
     */
    fun createComponent(
        type: String,
        properties: Map<String, Any?>,
        context: Context
    ): View? {
        Log.d(TAG, "Creating component of type: $type")

        val componentClass = componentTypes[type]
        if (componentClass == null) {
            Log.e(TAG, "No component registered for type: $type")
            return null
        }

        return try {
            val component = componentClass.getDeclaredConstructor().newInstance()

            // Store instance if it has an ID
            val componentId = properties["id"] as? String
            if (componentId != null) {
                componentInstances[componentId] = component
            }

            // Create and configure the view
            val view = component.createView(context, properties)
            component.bindView(view)
            component.applyProperties(properties)

            Log.d(TAG, "Component created successfully: $type")
            view
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component of type: $type", e)
            null
        }
    }

    /**
     * Get a component instance by ID
     */
    fun getComponentById(id: String): DCFComponent? {
        return componentInstances[id]
    }

    /**
     * Update a component's properties
     */
    fun updateComponent(id: String, properties: Map<String, Any?>): Boolean {
        val component = componentInstances[id]
        if (component == null) {
            Log.w(TAG, "Component not found with ID: $id")
            return false
        }

        try {
            component.updateProperties(properties)
            Log.d(TAG, "Component updated: $id")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update component: $id", e)
            return false
        }
    }

    /**
     * Remove a component instance
     */
    fun removeComponent(id: String): Boolean {
        val component = componentInstances.remove(id)
        if (component != null) {
            component.cleanup()
            Log.d(TAG, "Component removed: $id")
            return true
        }
        return false
    }

    /**
     * Remove all component instances
     */
    fun removeAllComponents() {
        componentInstances.forEach { (_, component) ->
            component.cleanup()
        }
        componentInstances.clear()
        Log.d(TAG, "All component instances removed")
    }

    /**
     * Get all component instances
     */
    fun getAllComponents(): Map<String, DCFComponent> {
        return componentInstances.toMap()
    }

    /**
     * Get component statistics for debugging
     */
    fun getStatistics(): Map<String, Any> {
        return mapOf(
            "registeredTypes" to componentTypes.size,
            "activeInstances" to componentInstances.size,
            "types" to getRegisteredComponentNames()
        )
    }

    /**
     * Cleanup the registry
     */
    fun cleanup() {
        removeAllComponents()
        componentTypes.clear()
        Log.d(TAG, "Component registry cleaned up")
    }
}

