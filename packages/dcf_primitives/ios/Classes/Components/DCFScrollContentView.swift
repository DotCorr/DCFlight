/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/**
 * DCFScrollContentView - Content view wrapper (1:1 with React Native's RCTScrollContentView)
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



