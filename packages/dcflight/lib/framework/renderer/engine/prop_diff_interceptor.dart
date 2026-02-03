/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
