/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "SkiaRenderer.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Skia headers - using header search paths from podspec
// With HEADER_SEARCH_PATHS including both Skia/ and Skia/include/, try direct paths
#import "core/SkCanvas.h"
#import "core/SkSurface.h"
#import "core/SkPaint.h"
#import "core/SkColor.h"
#import "core/SkImageInfo.h"
#import "gpu/ganesh/GrDirectContext.h"
#import "gpu/ganesh/SkSurfaceGanesh.h"
#import "gpu/ganesh/mtl/GrMtlBackendContext.h"
#import "gpu/ganesh/mtl/GrMtlDirectContext.h"

// Wrapper to hold Skia surface and context together
@interface SkiaSurfaceWrapper : NSObject
@property (nonatomic) sk_sp<SkSurface> surface;
@property (nonatomic) sk_sp<GrDirectContext> context;
@end

@implementation SkiaSurfaceWrapper
@end

// SkiaRenderer interface is defined in SkiaRenderer.h
@implementation SkiaRenderer

+ (void*)createSkiaSurface:(void*)metalDevice layer:(void*)metalLayer width:(int)width height:(int)height {
    id<MTLDevice> device = (__bridge id<MTLDevice>)metalDevice;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metalLayer;
    
    // Create GrDirectContext for Metal
    GrMtlBackendContext backendContext;
    // GrMTLHandle is const void*, and sk_cfp manages the lifetime
    backendContext.fDevice = sk_cfp<GrMTLHandle>((__bridge_retained const void*)device);
    backendContext.fQueue = sk_cfp<GrMTLHandle>((__bridge_retained const void*)[device newCommandQueue]);
    
    sk_sp<GrDirectContext> context = GrDirectContexts::MakeMetal(backendContext, GrContextOptions());
    if (!context) {
        // Fallback to raster surface if Metal context creation fails
        SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
        sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
        // Store in wrapper for consistency
        SkiaSurfaceWrapper* wrapper = [[SkiaSurfaceWrapper alloc] init];
        wrapper.surface = surface;
        // No GPU context for raster surface
        return (__bridge_retained void*)wrapper;
    }
    
    // Create Skia surface backed by Metal texture from CAMetalLayer
    // For now, use raster surface - Metal-backed surface requires more setup
    SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
    sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
    
    // Store context with surface for later use
    SkiaSurfaceWrapper* wrapper = [[SkiaSurfaceWrapper alloc] init];
    wrapper.surface = surface;
    wrapper.context = context;
    
    return (__bridge_retained void*)wrapper;
}

+ (void*)getCanvasFromSurface:(void*)surface {
    SkiaSurfaceWrapper* wrapper = (__bridge SkiaSurfaceWrapper*)surface;
    if (!wrapper || !wrapper.surface) {
        return nullptr;
    }
    SkCanvas* canvas = wrapper.surface->getCanvas();
    // Canvas pointer is valid as long as surface exists, return as opaque pointer
    return (void*)canvas;
}

+ (void)flushSurface:(void*)surface {
    SkiaSurfaceWrapper* wrapper = (__bridge SkiaSurfaceWrapper*)surface;
    if (wrapper && wrapper.surface) {
        if (wrapper.context) {
            // GPU surface - use flushAndSubmit on the context
            wrapper.context->flushAndSubmit();
        }
        // Raster surfaces don't need explicit flushing - they're CPU-based
        // The drawing is already complete when we return from drawing operations
    }
}

+ (void)destroySurface:(void*)surface {
    if (surface) {
        CFRelease((CFTypeRef)surface);
    }
}

+ (void)drawTestCircle:(void*)canvas width:(float)width height:(float)height {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (!skCanvas) return;
    
    // Clear canvas with transparent background
    skCanvas->clear(SK_ColorTRANSPARENT);
    
    // Draw a green circle
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SK_ColorGREEN);
    paint.setStyle(SkPaint::kFill_Style);
    
    float centerX = width / 2.0f;
    float centerY = height / 2.0f;
    float radius = 50.0f;
    
    skCanvas->drawCircle(centerX, centerY, radius, paint);
}

@end

