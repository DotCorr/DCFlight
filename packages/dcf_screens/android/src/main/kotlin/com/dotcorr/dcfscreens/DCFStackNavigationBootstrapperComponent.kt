package com.dotcorr.dcfscreens

import android.content.Context
import android.util.Log
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.navigation.NavController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

/**
 * DCFStackNavigationBootstrapperComponent for Android using Jetpack Compose Navigation
 * This follows the same pattern as iOS but uses Android's native navigation
 */
class DCFStackNavigationBootstrapperComponent {
    
    companion object {
        private const val TAG = "DCFStackNavigationBootstrapperComponent"
    }
    
    fun createView(context: Context, props: Map<String, Any?>): View {
        Log.d(TAG, "Creating stack navigation bootstrapper component")
        
        val initialScreen = props["initialScreen"] as? String ?: "home"
        val hideNavigationBar = props["hideNavigationBar"] as? Boolean ?: false
        val animationDuration = props["animationDuration"] as? Int
        
        Log.d(TAG, "StackNavigationBootstrapper created - initialScreen: $initialScreen, hideNavBar: $hideNavigationBar, animationDuration: $animationDuration")
        
        // Create a ComposeView that will hold our navigation
        val composeView = ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            setContent {
                // Create the navigation using Jetpack Compose Navigation
                val navController = rememberNavController()
                
                // Store the nav controller in our navigation controller
                DCFAndroidNavigationController.shared.setNavController(navController)
                
                NavHost(
                    navController = navController,
                    startDestination = initialScreen
                ) {
                    // Define routes here - following JetNews pattern
                    composable("home") {
                        HomeScreen(navController = navController)
                    }
                    composable("profile") {
                        ProfileScreen(navController = navController)
                    }
                    composable("settings") {
                        SettingsScreen(navController = navController)
                    }
                }
            }
        }
        
        // Initialize the navigation controller
        DCFAndroidNavigationController.shared.initialize(context)
        
        Log.d(TAG, "Stack navigation bootstrapper created successfully")
        
        return composeView
    }
}

@Composable
fun HomeScreen(navController: NavController) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Home Screen",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}

@Composable
fun ProfileScreen(navController: NavController) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Profile Screen",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}

@Composable
fun SettingsScreen(navController: NavController) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "Settings Screen",
            style = MaterialTheme.typography.headlineMedium
        )
    }
}
