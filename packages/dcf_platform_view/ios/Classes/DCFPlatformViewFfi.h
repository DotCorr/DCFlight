/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

#ifndef DCFPlatformViewFfi_h
#define DCFPlatformViewFfi_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Called from Dart via FFI (no method channel). Updates the single DCF surface frame.
void dcplatformview_set_surface_frame(double x, double y, double width, double height);

#ifdef __cplusplus
}
#endif

#endif /* DCFPlatformViewFfi_h */
