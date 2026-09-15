/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
package com.dotcorr.escape;
public final class UserViews {
    public static android.view.View v_badge(android.app.Activity activity, AppModel model) {
        android.widget.TextView badge = new android.widget.TextView(activity);
        badge.setText("Native Android extension");
        badge.setTextAppearance(android.R.style.TextAppearance_Material_Headline);
        return badge;
    }
}
