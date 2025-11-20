/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "include/core/SkCanvas.h"
#import "include/core/SkSurface.h"
#import "include/core/SkPaint.h"
#import "include/core/SkColor.h"
#import "include/gpu/GrDirectContext.h"
#import "include/gpu/ganesh/SkSurfaceGanesh.h"
#import "include/gpu/ganesh/mtl/GrMtlBackendContext.h"

// Wrapper to hold Skia surface and context together
@interface SkiaSurfaceWrapper : NSObject
@property (nonatomic) sk_sp<SkSurface> surface;
@property (nonatomic) sk_sp<GrDirectContext> context;
@end

@implementation SkiaSurfaceWrapper
@end

// Skia renderer wrapper for Objective-C++/Swift interop
@interface SkiaRenderer : NSObject

+ (void*)createSkiaSurface:(void*)metalDevice layer:(void*)metalLayer width:(int)width height:(int)height;
+ (void*)getCanvasFromSurface:(void*)surface;
+ (void)flushSurface:(void*)surface;
+ (void)destroySurface:(void*)surface;

@end

@implementation SkiaRenderer

+ (void*)createSkiaSurface:(void*)metalDevice layer:(void*)metalLayer width:(int)width height:(int)height {
    id<MTLDevice> device = (__bridge id<MTLDevice>)metalDevice;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metalLayer;
    
    // Create GrDirectContext for Metal
    GrMtlBackendContext backendContext;
    backendContext.fDevice = (__bridge void*)device;
    backendContext.fQueue = (__bridge void*)[device newCommandQueue];
    backendContext.fBinaryArchive = nullptr;
    
    sk_sp<GrDirectContext> context = GrDirectContext::MakeMetal(backendContext, GrContextOptions());
    if (!context) {
        // Fallback to raster surface if Metal context creation fails
        SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
        sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
        return (__bridge_retained void*)CFBridgingRetain((__bridge id)surface.release());
    }
    
    // Create Skia surface backed by Metal texture from CAMetalLayer
    SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
    sk_sp<SkSurface> surface = SkSurfaces::MakeRenderTarget(
        context.get(),
        skgpu::Budgeted::kYes,
        info
    );
    
    if (!surface) {
        // Fallback to raster surface
        surface = SkSurfaces::Raster(info);
    }
    
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
    return (__bridge void*)canvas;
}

+ (void)flushSurface:(void*)surface {
    SkiaSurfaceWrapper* wrapper = (__bridge SkiaSurfaceWrapper*)surface;
    if (wrapper && wrapper.surface) {
        wrapper.surface->flushAndSubmit();
        if (wrapper.context) {
            wrapper.context->submit();
        }
    }
}

+ (void)destroySurface:(void*)surface {
    if (surface) {
        CFRelease((CFTypeRef)surface);
    }
}

@end

