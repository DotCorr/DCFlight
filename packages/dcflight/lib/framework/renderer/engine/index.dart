/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// This file serves as a central export point for the VDOM system,
/// allowing easy swapping between implementations.
library;

// Re-export the new VDOM API
export 'engine_api.dart';
export 'package:dcflight/framework/renderer/engine/core/concurrency/priority.dart';
// Re-export the component classes from the new implementation
export 'component/component.dart';
export 'component/fragment.dart';
// Re-export element and node classes
export 'component/component_node.dart';
export 'component/dcf_element.dart';
export 'component/suspense.dart';



// Re-export error boundary
export 'component/error_boundary.dart';

// Re-export store
export 'component/hooks/store.dart';
export 'component/hooks/memo_hook.dart';
export 'component/hooks/state_hook.dart';
// Re-export portal system
export 'portal/enhanced_portal_manager.dart';
export 'portal/dcf_portal.dart';
// Re-export prop diff interceptors
export 'core/mutator/prop_diff_interceptor.dart';