/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Optional interceptor for prop diffing (engine: no VDOM, minimal use)
abstract class PropDiffInterceptor {
  bool shouldHandle(String elementType, Map<String, dynamic> oldProps, Map<String, dynamic> newProps);
  Map<String, dynamic> interceptPropDiff(
    String elementType,
    Map<String, dynamic> oldProps,
    Map<String, dynamic> newProps,
    Map<String, dynamic> changedProps,
  );
}
