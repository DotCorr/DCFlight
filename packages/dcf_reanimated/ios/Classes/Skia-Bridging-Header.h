/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#ifndef Skia_Bridging_Header_h
#define Skia_Bridging_Header_h

// Skia C++ headers
// These will be available to Swift via bridging header
#ifdef __cplusplus
#include "include/core/SkCanvas.h"
#include "include/core/SkSurface.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkColor.h"
#include "include/core/SkRect.h"
#include "include/core/SkPoint.h"
#include "include/core/SkImage.h"
#include "include/core/SkShader.h"
#include "include/core/SkImageInfo.h"
#include "include/gpu/GrDirectContext.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#include "include/gpu/ganesh/mtl/GrMtlTypes.h"
#include "include/gpu/mtl/GrMtlTypes.h"

// Particle data structure for Skia rendering
struct ParticleData {
    double x;
    double y;
    double size;
    uint32_t color; // ARGB
};
#endif

#endif /* Skia_Bridging_Header_h */

