/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

abstract class PropDiffInterceptor {
  /// Should this interceptor handle prop diffing for this element type?
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps);
  
  /// Modify the changed props before sending to native
  Map<String, dynamic> interceptPropDiff(
    String elementType,
    Map<String, dynamic> oldProps,
    Map<String, dynamic> newProps,
    Map<String, dynamic> changedProps,
  );
}