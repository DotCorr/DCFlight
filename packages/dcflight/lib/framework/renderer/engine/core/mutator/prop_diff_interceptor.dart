/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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