/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.app.Activity
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class DCFWrapperActivity(
    private val activity: Activity,
    private val contentView: View
) : DCFViewControllerProtocol {
    
    private var previousTopLayoutLength: Int = 0
    private var previousBottomLayoutLength: Int = 0
    private var wrapperView: ViewGroup? = null
    
    override val currentTopLayoutGuide: Int
        get() = ViewCompat.getRootWindowInsets(activity.window.decorView)
            ?.getInsets(WindowInsetsCompat.Type.statusBars())?.top ?: 0
    
    override val currentBottomLayoutGuide: Int
        get() = ViewCompat.getRootWindowInsets(activity.window.decorView)
            ?.getInsets(WindowInsetsCompat.Type.navigationBars())?.bottom ?: 0
    
    fun setupWrapper() {
        val rootView = activity.findViewById<ViewGroup>(android.R.id.content)
        wrapperView = android.widget.FrameLayout(activity).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            addView(contentView)
        }
        rootView?.addView(wrapperView)
    }
    
    fun onLayoutChanged() {
        val currentTopLength = currentTopLayoutGuide
        val currentBottomLength = currentBottomLayoutGuide
        
        if (previousTopLayoutLength != currentTopLength ||
            previousBottomLayoutLength != currentBottomLength) {
            findScrollViewAndRefreshContentInset(contentView)
            previousTopLayoutLength = currentTopLength
            previousBottomLayoutLength = currentBottomLength
        }
    }
    
    private fun findScrollViewAndRefreshContentInset(view: View): Boolean {
        if (view is DCFAutoInsetsProtocol) {
            view.refreshContentInset()
            return true
        }
        
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                if (findScrollViewAndRefreshContentInset(view.getChildAt(i))) {
                    return true
                }
            }
        }
        
        return false
    }
}

