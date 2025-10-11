/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.core.view.ViewCompat
import com.dotcorr.dcflight.components.propagateEvent
import com.google.android.material.appbar.AppBarLayout
import com.google.android.material.appbar.MaterialToolbar
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * Android Navigation Controller - Equivalent to iOS UINavigationController
 * Manages the navigation stack with Material Design components
 */
class DCFAndroidNavigationController private constructor() {
    
    companion object {
        private const val TAG = "DCFAndroidNavigationController"
        val shared = DCFAndroidNavigationController()
    }
    
    private var activity: Activity? = null
    private var context: Context? = null
    private var appBarLayout: AppBarLayout? = null
    private var toolbar: MaterialToolbar? = null
    private var navigationContainer: FrameLayout? = null
    private var navigationStack: MutableList<NavigationItem> = mutableListOf()
    
    data class NavigationItem(
        val route: String,
        val view: View,
        val title: String?,
        val hideNavigationBar: Boolean = false,
        val prefixActions: List<Map<String, Any?>>? = null,
        val suffixActions: List<Map<String, Any?>>? = null
    )
    
    fun initialize(activity: Activity) {
        if (this.activity == null) {
            this.activity = activity
            setupNavigationContainer()
            setupAppBar()
            Log.d(TAG, "DCFAndroidNavigationController initialized")
            
            // Set up initial screen if available
            setupInitialScreen()
        }
    }
    
    fun initialize(context: Context) {
        if (this.activity == null) {
            // Try to find Activity from context
            val activity = when (context) {
                is Activity -> context
                is ContextWrapper -> {
                    var currentContext = context.baseContext
                    while (currentContext is ContextWrapper && currentContext !is Activity) {
                        currentContext = currentContext.baseContext
                    }
                    currentContext as? Activity
                }
                else -> null
            }
            
            if (activity != null) {
                initialize(activity)
            } else {
                Log.w(TAG, "Could not find Activity from context, will try to initialize later")
                // Store the context for later use
                this.context = context
            }
        } else if (this.activity != null && context is Activity) {
            // Already initialized with Activity, but got a new Activity context
            // This might be an upgrade from context to Activity
            val currentActivity = this.activity
            Log.d(TAG, "Navigation controller already initialized with Activity: ${currentActivity?.javaClass?.simpleName}")
        }
    }
    
    fun tryInitializeWithActivity() {
        if (activity == null && context != null) {
            // Try to get the Activity from the Flutter engine
            var activity = getActivityFromFlutterEngine()
            
            // If not found from Flutter engine, try the plugin
            if (activity == null) {
                activity = com.dotcorr.dcfscreens.DcfScreensPlugin.getActivity()
            }
            
            if (activity != null) {
                initialize(activity)
                Log.d(TAG, "Navigation controller initialized with Activity from Flutter engine/plugin")
            } else {
                Log.w(TAG, "Could not get Activity from Flutter engine or plugin")
            }
        }
    }
    
    private fun getActivityFromFlutterEngine(): Activity? {
        // Try to get the Activity from the current context
        val currentContext = context
        return when (currentContext) {
            is Activity -> currentContext
            is ContextWrapper -> {
                var ctx = currentContext.baseContext
                while (ctx is ContextWrapper && ctx !is Activity) {
                    ctx = ctx.baseContext
                }
                ctx as? Activity
            }
            else -> {
                // Try multiple strategies to find Activity
                findActivityFromApplication()
            }
        }
    }
    
    private fun findActivityFromApplication(): Activity? {
        // Strategy 1: Try to get Activity from Flutter engine using reflection
        try {
            val flutterEngine = FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get the Activity from the engine's context using reflection
                val contextField = engine.javaClass.getDeclaredField("context")
                contextField.isAccessible = true
                val engineContext = contextField.get(engine) as? Context
                if (engineContext is Activity) {
                    Log.d(TAG, "Found Activity from Flutter engine context: ${engineContext.javaClass.simpleName}")
                    return engineContext
                }
                
                // Try to unwrap the context
                if (engineContext is ContextWrapper) {
                    var ctx = engineContext.baseContext
                    while (ctx is ContextWrapper && ctx !is Activity) {
                        ctx = ctx.baseContext
                    }
                    if (ctx is Activity) {
                        Log.d(TAG, "Found Activity from Flutter engine unwrapped context: ${ctx.javaClass.simpleName}")
                        return ctx
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Flutter engine context: ${e.message}")
        }
        
        // Strategy 2: Try to get Activity from Flutter engine using activity field
        try {
            val flutterEngine = FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get the Activity from the engine's activity field
                val activityField = engine.javaClass.getDeclaredField("activity")
                activityField.isAccessible = true
                val engineActivity = activityField.get(engine) as? Activity
                if (engineActivity != null) {
                    Log.d(TAG, "Found Activity from Flutter engine activity: ${engineActivity.javaClass.simpleName}")
                    return engineActivity
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Flutter engine activity: ${e.message}")
        }
        
        // Strategy 3: Try to get Activity from Application context using reflection
        try {
            val application = context?.applicationContext
            if (application != null) {
                val activityManagerField = application.javaClass.getDeclaredField("mActivityManager")
                activityManagerField.isAccessible = true
                val activityManager = activityManagerField.get(application)
            
                // Try to get running tasks to find current activity
                val getRunningTasksMethod = activityManager.javaClass.getDeclaredMethod("getRunningTasks", Int::class.java)
                getRunningTasksMethod.isAccessible = true
                val runningTasks = getRunningTasksMethod.invoke(activityManager, 1) as? List<*>
                
                runningTasks?.firstOrNull()?.let { task ->
                    val topActivityField = task.javaClass.getDeclaredField("topActivity")
                    topActivityField.isAccessible = true
                    val topActivity = topActivityField.get(task) as? Activity
                    if (topActivity != null) {
                        Log.d(TAG, "Found Activity from running tasks: ${topActivity.javaClass.simpleName}")
                        return topActivity
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from Application context: ${e.message}")
        }
        
        // Strategy 4: Try to get Activity from Flutter engine's plugin registry
        try {
            val flutterEngine = FlutterEngineCache.getInstance().get("main")
            flutterEngine?.let { engine ->
                // Try to get Activity from plugin registry
                val pluginRegistry = engine.plugins
                val registrarClass = Class.forName("io.flutter.plugin.common.PluginRegistry\$Registrar")
                val contextMethod = registrarClass.getDeclaredMethod("context")
                contextMethod.isAccessible = true
                
                // Try to find a registrar that has an Activity context
                val registrars = pluginRegistry.javaClass.getDeclaredField("mRegistrars")
                registrars.isAccessible = true
                val registrarMap = registrars.get(pluginRegistry) as? Map<*, *>
                
                registrarMap?.values?.forEach { registrar ->
                    try {
                        val registrarContext = contextMethod.invoke(registrar) as? Context
                        if (registrarContext is Activity) {
                            Log.d(TAG, "Found Activity from plugin registry: ${registrarContext.javaClass.simpleName}")
                            return registrarContext
                        }
                    } catch (e: Exception) {
                        // Continue to next registrar
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from plugin registry: ${e.message}")
        }
        
        // Strategy 5: Try to get Activity from current thread's context
        try {
            val currentThread = Thread.currentThread()
            val contextClassLoader = currentThread.contextClassLoader
            if (contextClassLoader != null) {
                // Try to find Activity in the current thread's context
                val activityClass = Class.forName("android.app.Activity")
                val currentActivity = activityClass.cast(context)
                if (currentActivity is Activity) {
                    Log.d(TAG, "Found Activity from current thread: ${currentActivity.javaClass.simpleName}")
                    return currentActivity
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get Activity from current thread: ${e.message}")
        }
        
        Log.w(TAG, "Could not find Activity using any strategy")
        return null
    }
    
    private fun setupInitialScreen() {
        // Try to find and show the home screen initially
        val homeScreen = DCFScreenComponent.getScreenContainer("home")
        if (homeScreen != null) {
            Log.d(TAG, "Setting up initial home screen")
            pushScreen(
                route = "home",
                title = "Home",
                hideNavigationBar = false
            )
        } else {
            Log.d(TAG, "Home screen not found, will be set up when available")
        }
    }
    
    private fun setupNavigationContainer() {
        activity?.let { currentActivity ->
            navigationContainer = FrameLayout(currentActivity).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                setBackgroundColor(android.graphics.Color.WHITE)
            }
            
            val rootView = currentActivity.findViewById<ViewGroup>(android.R.id.content)
            rootView?.addView(navigationContainer)
            Log.d(TAG, "Navigation container set up")
        }
    }
    
    private fun setupAppBar() {
        activity?.let { currentActivity ->
            // Create AppBarLayout for Material Design
            appBarLayout = AppBarLayout(currentActivity).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
                setBackgroundColor(android.graphics.Color.BLUE)
            }
            
            // Create MaterialToolbar
            toolbar = MaterialToolbar(currentActivity).apply {
                layoutParams = AppBarLayout.LayoutParams(
                    AppBarLayout.LayoutParams.MATCH_PARENT,
                    AppBarLayout.LayoutParams.WRAP_CONTENT
                )
                setTitleTextColor(android.graphics.Color.WHITE)
                setBackgroundColor(android.graphics.Color.BLUE)
                
                // Enable back button
                setNavigationOnClickListener {
                    goBack()
                }
            }
            
            appBarLayout?.addView(toolbar)
            navigationContainer?.addView(appBarLayout)
            
            if (currentActivity is AppCompatActivity) {
                currentActivity.setSupportActionBar(toolbar)
                currentActivity.supportActionBar?.setDisplayHomeAsUpEnabled(true)
                Log.d(TAG, "Material Toolbar set as ActionBar")
            }
        }
    }
    
    fun pushScreen(
        route: String,
        title: String? = null,
        hideNavigationBar: Boolean = false,
        prefixActions: List<Map<String, Any?>>? = null,
        suffixActions: List<Map<String, Any?>>? = null
    ) {
        // Try to initialize if not already done
        if (activity == null) {
            tryInitializeWithActivity()
        }
        
        if (activity == null) {
            Log.w(TAG, "Cannot push screen '$route' - navigation controller not initialized with Activity")
            return
        }
        
        activity?.runOnUiThread {
            Log.d(TAG, "Pushing screen: $route")
            
            val screenContainer = DCFScreenComponent.getScreenContainer(route)
            if (screenContainer != null) {
                // Hide current screen
                navigationStack.lastOrNull()?.let { currentItem ->
                    currentItem.view.visibility = View.GONE
                }
                
                // Create navigation item
                val navigationItem = NavigationItem(
                    route = route,
                    view = screenContainer.view,
                    title = title ?: route,
                    hideNavigationBar = hideNavigationBar,
                    prefixActions = prefixActions,
                    suffixActions = suffixActions
                )
                
                // Add to stack
                navigationStack.add(navigationItem)
                
                // Show new screen
                showScreen(navigationItem)
                
                // Configure navigation bar
                configureNavigationBar(navigationItem)
                
                Log.d(TAG, "Successfully pushed screen: $route (stack size: ${navigationStack.size})")
            } else {
                Log.e(TAG, "Screen '$route' not found for navigation")
            }
        }
    }
    
    fun popScreen(): Boolean {
        // Try to initialize if not already done
        if (activity == null) {
            tryInitializeWithActivity()
        }
        
        if (activity == null) {
            Log.w(TAG, "Cannot pop screen - navigation controller not initialized with Activity")
            return false
        }
        
        return if (navigationStack.size > 1) {
            activity?.runOnUiThread {
                val currentItem = navigationStack.removeAt(navigationStack.size - 1)
                currentItem.view.visibility = View.GONE
                
                val previousItem = navigationStack.lastOrNull()
                if (previousItem != null) {
                    showScreen(previousItem)
                    configureNavigationBar(previousItem)
                    Log.d(TAG, "Popped to screen: ${previousItem.route} (stack size: ${navigationStack.size})")
                }
            }
            true
        } else {
            Log.d(TAG, "Cannot pop - only one screen in stack")
            false
        }
    }
    
    fun goBack(): Boolean {
        return popScreen()
    }
    
    fun popToRoot() {
        // Try to initialize if not already done
        if (activity == null) {
            tryInitializeWithActivity()
        }
        
        if (activity == null) {
            Log.w(TAG, "Cannot pop to root - navigation controller not initialized with Activity")
            return
        }
        
        activity?.runOnUiThread {
            if (navigationStack.size > 1) {
                // Hide all screens except root
                navigationStack.drop(1).forEach { item ->
                    item.view.visibility = View.GONE
                }
                
                // Keep only root screen
                val rootItem = navigationStack.first()
                navigationStack.clear()
                navigationStack.add(rootItem)
                
                showScreen(rootItem)
                configureNavigationBar(rootItem)
                
                Log.d(TAG, "Popped to root screen: ${rootItem.route}")
            }
        }
    }
    
    fun replaceScreen(
        route: String,
        title: String? = null,
        hideNavigationBar: Boolean = false,
        prefixActions: List<Map<String, Any?>>? = null,
        suffixActions: List<Map<String, Any?>>? = null
    ) {
        activity?.runOnUiThread {
            Log.d(TAG, "Replacing current screen with: $route")
            
            val screenContainer = DCFScreenComponent.getScreenContainer(route)
            if (screenContainer != null) {
                // Hide current screen
                navigationStack.lastOrNull()?.let { currentItem ->
                    currentItem.view.visibility = View.GONE
                }
                
                // Remove current screen from stack
                if (navigationStack.isNotEmpty()) {
                    navigationStack.removeAt(navigationStack.size - 1)
                }
                
                // Create new navigation item
                val navigationItem = NavigationItem(
                    route = route,
                    view = screenContainer.view,
                    title = title ?: route,
                    hideNavigationBar = hideNavigationBar,
                    prefixActions = prefixActions,
                    suffixActions = suffixActions
                )
                
                // Add to stack
                navigationStack.add(navigationItem)
                
                // Show new screen
                showScreen(navigationItem)
                
                // Configure navigation bar
                configureNavigationBar(navigationItem)
                
                Log.d(TAG, "Successfully replaced with screen: $route")
            } else {
                Log.e(TAG, "Screen '$route' not found for replacement")
            }
        }
    }
    
    private fun showScreen(navigationItem: NavigationItem) {
        // Remove from any existing parent
        if (navigationItem.view.parent != null) {
            (navigationItem.view.parent as? ViewGroup)?.removeView(navigationItem.view)
        }
        
        // Add to navigation container
        navigationContainer?.addView(navigationItem.view)
        
        // Make sure it's visible
        navigationItem.view.visibility = View.VISIBLE
        navigationItem.view.alpha = 1.0f
        
        // Ensure proper layout - use FrameLayout.LayoutParams for FrameLayout parent
        navigationItem.view.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        
        // Fire lifecycle events
        propagateEvent(
            view = navigationItem.view,
            eventName = "onAppear",
            data = mapOf("route" to navigationItem.route)
        )
        
        propagateEvent(
            view = navigationItem.view,
            eventName = "onActivate",
            data = mapOf("route" to navigationItem.route)
        )
    }
    
    private fun configureNavigationBar(navigationItem: NavigationItem) {
        Log.d(TAG, "Configuring navigation bar for: ${navigationItem.route}")
        
        appBarLayout?.visibility = if (navigationItem.hideNavigationBar) View.GONE else View.VISIBLE
        
        if (activity is AppCompatActivity && !navigationItem.hideNavigationBar) {
            val supportActionBar = (activity as? AppCompatActivity)?.supportActionBar
            supportActionBar?.title = navigationItem.title ?: navigationItem.route
            
            // Show/hide back button based on stack size
            supportActionBar?.setDisplayHomeAsUpEnabled(navigationStack.size > 1)
            
            // Clear existing actions
            toolbar?.menu?.clear()
            
            // Add prefix actions (left side)
            navigationItem.prefixActions?.forEach { action ->
                val actionId = action["actionId"] as? String
                val actionTitle = action["title"] as? String
                val enabled = action["enabled"] as? Boolean ?: true
                
                val menuItem = toolbar?.menu?.add(actionTitle)
                menuItem?.isEnabled = enabled
                menuItem?.setShowAsAction(android.view.MenuItem.SHOW_AS_ACTION_ALWAYS)
                menuItem?.setOnMenuItemClickListener {
                    propagateEvent(
                        view = toolbar!!,
                        eventName = "onHeaderActionPress",
                        data = mapOf("actionId" to actionId, "route" to navigationItem.route)
                    )
                    true
                }
            }
            
            // Add suffix actions (right side)
            navigationItem.suffixActions?.forEach { action ->
                val actionId = action["actionId"] as? String
                val actionTitle = action["title"] as? String
                val enabled = action["enabled"] as? Boolean ?: true
                
                val menuItem = toolbar?.menu?.add(actionTitle)
                menuItem?.isEnabled = enabled
                menuItem?.setShowAsAction(android.view.MenuItem.SHOW_AS_ACTION_ALWAYS)
                menuItem?.setOnMenuItemClickListener {
                    propagateEvent(
                        view = toolbar!!,
                        eventName = "onHeaderActionPress",
                        data = mapOf("actionId" to actionId, "route" to navigationItem.route)
                    )
                    true
                }
            }
        }
    }
    
    fun getCurrentRoute(): String? {
        return navigationStack.lastOrNull()?.route
    }
    
    fun getNavigationStack(): List<String> {
        return navigationStack.map { it.route }
    }
    
    fun isRootScreen(): Boolean {
        return navigationStack.size <= 1
    }
    
    /**
     * Get the root view of the navigation controller
     * This is used to replace the Activity's root view (Android equivalent of iOS replaceRoot)
     */
    fun getRootView(): View? {
        return navigationContainer
    }
}
