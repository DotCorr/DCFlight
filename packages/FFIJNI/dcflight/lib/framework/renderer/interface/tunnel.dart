/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/renderer/interface/interface.dart';

/// Universal tunnel for direct component method calls
/// Bypasses VDOM and calls component methods directly on native side
class FrameworkTunnel {
  /// Call a method on any registered component directly
  /// 
  /// Example:
  /// ```dart
  /// // Call animation engine directly
  /// FrameworkTunnel.call('AnimationManager', 'executeGroupCommand', {
  ///   'groupId': 'modal_animations',
  ///   'command': {'type': 'resetAll'}
  /// });
  /// 
  /// // Call individual animation directly
  /// FrameworkTunnel.call('AnimatedView', 'executeCommand', {
  ///   'controllerId': 'box1',
  ///   'command': {'type': 'pause'}
  /// });
  /// ```
  static Future<dynamic> call(String componentType, String method, Map<String, dynamic> params) async {
    return await PlatformInterface.instance.tunnel(componentType, method, params);
  }

}

