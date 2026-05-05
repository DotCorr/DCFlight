/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

#import "DCFPlatformViewFfi.h"

// Swift exports dcplatformview_set_surface_frame_impl via @_cdecl (no Swift header needed).
extern void dcplatformview_set_surface_frame_impl(double x, double y, double width, double height);

void dcplatformview_set_surface_frame(double x, double y, double width, double height) {
  dispatch_async(dispatch_get_main_queue(), ^{
    dcplatformview_set_surface_frame_impl(x, y, width, height);
  });
}
