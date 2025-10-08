/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcfscreens

import android.view.View

/**
 * Shared data class for screen containers
 */
data class DCFScreenContainer(
    val route: String,
    val view: View,
    val presentationStyle: String
)
