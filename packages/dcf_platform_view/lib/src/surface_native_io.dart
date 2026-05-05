/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

/// Calls native dcplatformview_set_surface_frame via FFI (iOS: ObjC bridge, Android: NDK JNI shim).
void setSurfaceFrameNative(double x, double y, double width, double height) {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  try {
    final dylib = ffi.DynamicLibrary.process();
    final fn = dylib
        .lookup<ffi.NativeFunction<_SetSurfaceFrameNative>>(
            'dcplatformview_set_surface_frame')
        .asFunction<_SetSurfaceFrameDart>();
    fn(x, y, width, height);
  } catch (_) {}
}

typedef _SetSurfaceFrameNative = ffi.Void Function(
  ffi.Double x,
  ffi.Double y,
  ffi.Double width,
  ffi.Double height,
);
typedef _SetSurfaceFrameDart = void Function(
  double x,
  double y,
  double width,
  double height,
);
