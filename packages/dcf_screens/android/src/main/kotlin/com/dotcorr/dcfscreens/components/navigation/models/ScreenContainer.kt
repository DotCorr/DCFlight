/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens.components.navigation.models

import android.view.View
import android.widget.FrameLayout
import androidx.compose.runtime.Composable

/**
 * Container for screen metadata and content
 * Bridges DCFlight's Dart layer with Compose Navigation
 */
data class ScreenContainer(
    val route: String,
    val presentationStyle: String = "push",
    val content: @Composable () -> Unit,
    val viewId: String,
    var pushConfig: Map<String, Any?>? = null,
    var modalConfig: Map<String, Any?>? = null,
    var frameLayout: FrameLayout? = null, // Changed from composeView to frameLayout
    var onAppear: ((Map<String, Any?>) -> Unit)? = null,
    var onDisappear: ((Map<String, Any?>) -> Unit)? = null,
    var onActivate: ((Map<String, Any?>) -> Unit)? = null,
    var onDeactivate: ((Map<String, Any?>) -> Unit)? = null,
    var onReceiveParams: ((Map<String, Any?>) -> Unit)? = null
)
