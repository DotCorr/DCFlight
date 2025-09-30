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
 */
class DCFComponentRegistry private constructor() {

    companion object {
        private const val TAG = "DCFComponentRegistry"

        @JvmField
        val shared = DCFComponentRegistry()
    }

    private val componentTypes = ConcurrentHashMap<String, Class<out DCFComponent>>()
    private val componentInstances = ConcurrentHashMap<String, DCFComponent>()

    fun registerComponent(type: String, componentClass: Class<out DCFComponent>) {
        componentTypes[type] = componentClass
        Log.d(TAG, "Registered component type: $type")
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

    fun updateComponent(id: String, properties: Map<String, Any?>): Boolean {
        val component = componentInstances[id]
        if (component == null) {
            Log.w(TAG, "Component not found with ID: $id")
            return false
        }

        try {
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update component: $id", e)
            return false
        }
    }

    fun removeComponent(id: String): Boolean {
        val component = componentInstances.remove(id)
        if (component != null) {
            Log.d(TAG, "Component removed: $id")
            return true
        }
        return false
    }

    fun removeAllComponents() {
        componentInstances.clear()
        Log.d(TAG, "All component instances removed")
    }

    fun getAllComponents(): Map<String, DCFComponent> {
        return componentInstances.toMap()
    }

    fun getStatistics(): Map<String, Any> {
        return mapOf(
            "registeredTypes" to componentTypes.size,
            "activeInstances" to componentInstances.size,
            "types" to getRegisteredComponentNames()
        )
    }

    fun cleanup() {
        removeAllComponents()
        componentTypes.clear()
        Log.d(TAG, "Component registry cleaned up")
    }
}