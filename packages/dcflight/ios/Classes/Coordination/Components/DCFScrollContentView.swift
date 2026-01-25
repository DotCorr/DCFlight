/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

/**
 * DCFScrollContentView - Content view wrapper
 * This is a simple UIView that serves as the container for ScrollView's children.
 * Yoga will layout this view and its children, and the ScrollView will use its
 * frame.size as the contentSize.
 */
@objc public class DCFScrollContentView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        // Don't clip content - allow children to be positioned outside bounds (negative coordinates)
        clipsToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

