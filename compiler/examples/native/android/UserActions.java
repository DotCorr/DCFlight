/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
package com.dotcorr.escape;
public final class UserActions {
    public static void a_change(AppModel model) {
        model.s_message = "Updated by Java on Android " + android.os.Build.VERSION.RELEASE;
    }
}
