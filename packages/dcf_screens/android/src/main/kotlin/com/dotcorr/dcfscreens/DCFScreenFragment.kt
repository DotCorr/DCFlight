package com.dotcorr.dcfscreens

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment

/**
 * DCFScreenFragment - Wraps a DCF screen view in a Fragment
 * Matches react-native-screens pattern: Fragment-based screen management
 * This provides proper Android screen lifecycle (onCreate -> onResume -> onPause -> onDestroy)
 */
class DCFScreenFragment : Fragment() {
    
    companion object {
        private const val TAG = "DCFScreenFragment"
        private const val ARG_ROUTE = "route"
        
        fun newInstance(route: String): DCFScreenFragment {
            return DCFScreenFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_ROUTE, route)
                }
            }
        }
    }
    
    private var route: String? = null
    private var screenView: View? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        route = arguments?.getString(ARG_ROUTE)
        Log.d(TAG, "📱 Fragment created for route: $route")
    }
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        Log.d(TAG, "📱 onCreateView for route: $route")
        
        val route = this.route ?: return null
        
        // Get the screen container from the registry
        val screenContainer = DCFScreenComponent.getScreenContainer(route)
        if (screenContainer == null) {
            Log.e(TAG, "❌ Screen not found in registry: $route")
            return null
        }
        
        screenView = screenContainer.view
        
        // Remove from any existing parent (critical for re-parenting)
        val existingParent = screenView?.parent as? ViewGroup
        existingParent?.removeView(screenView)
        
        Log.d(TAG, "✅ Returning screen view for route: $route")
        return screenView
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "📱 Fragment resumed (screen visible): $route")
        // TODO: Fire onAppear event to Flutter
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "📱 Fragment paused (screen hidden): $route")
        // TODO: Fire onDisappear event to Flutter
    }
    
    override fun onDestroyView() {
        Log.d(TAG, "📱 Fragment view destroyed: $route")
        screenView = null
        super.onDestroyView()
    }
    
    override fun onDestroy() {
        Log.d(TAG, "📱 Fragment destroyed: $route")
        super.onDestroy()
    }
}
