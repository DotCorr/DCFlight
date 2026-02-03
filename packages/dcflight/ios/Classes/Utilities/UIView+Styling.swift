/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

extension UIView {
    /// Apply common style properties to this view, driven only by explicit props.
    ///
    /// **DEPRECATED**: This method is maintained for backward compatibility.
    /// New code should use `applyProperties(props:)` which uses direct property mapping.
    ///
    /// This method now delegates to `applyProperties` which uses the standard model's
    /// direct property mapping approach.
    ///
    /// **Usage:**
    /// ```swift
    /// // Direct style props
    /// view.applyStyles(props: ["backgroundColor": "dcf:#0000ff", "borderRadius": 8])
    ///
    /// // Style ID (resolved automatically)
    /// view.applyStyles(props: ["styleId": 1])
    /// ```
    @available(*, deprecated, message: "Use applyProperties(props:) instead for direct property mapping")
    public func applyStyles(props: [String: Any]) {
        // Delegate to new direct property mapping approach
        applyProperties(props: props)
    }
}
