/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
import Foundation
enum UserActions {
    static func a_change(_ model: AppModel) {
        model.s_message = "Updated by Swift on " + ProcessInfo.processInfo.operatingSystemVersionString
    }
}
