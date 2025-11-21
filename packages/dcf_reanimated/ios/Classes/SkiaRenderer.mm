/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "SkiaRenderer.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>

// Skia headers - using header search paths from podspec
// With HEADER_SEARCH_PATHS including both Skia/ and Skia/include/, try direct paths
#import "core/SkCanvas.h"
#import "core/SkSurface.h"
#import "core/SkPaint.h"
#import "core/SkColor.h"
#import "core/SkImageInfo.h"
#import "core/SkColorSpace.h"
#import "gpu/ganesh/GrDirectContext.h"
#import "gpu/ganesh/SkSurfaceGanesh.h"
#import "gpu/ganesh/mtl/GrMtlBackendContext.h"
#import "gpu/ganesh/mtl/GrMtlDirectContext.h"
#import "gpu/ganesh/mtl/SkSurfaceMetal.h"
#import "gpu/ganesh/mtl/GrMtlBackendSurface.h"
#import "gpu/ganesh/SkSurfaceGanesh.h"
#import "gpu/ganesh/GrBackendSurface.h"

// Wrapper to hold Skia surface, context, and drawable together
@interface SkiaSurfaceWrapper : NSObject
@property (nonatomic) sk_sp<SkSurface> surface;
@property (nonatomic) sk_sp<GrDirectContext> context;
@property (nonatomic) id<CAMetalDrawable> drawable;
@property (nonatomic) CAMetalLayer* metalLayer;
@property (nonatomic) id<MTLCommandQueue> commandQueue;
@end

@implementation SkiaSurfaceWrapper
@end

// SkiaRenderer interface is defined in SkiaRenderer.h
@implementation SkiaRenderer

+ (void*)createSkiaSurface:(void*)metalDevice layer:(void*)metalLayer width:(int)width height:(int)height {
    id<MTLDevice> device = (__bridge id<MTLDevice>)metalDevice;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metalLayer;
    
    // Configure Metal layer
    layer.device = device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = NO;
    layer.opaque = NO;
    layer.drawableSize = CGSizeMake(width, height);
    
    // Create command queue and store it (we need to keep a reference)
    id<MTLCommandQueue> commandQueue = [device newCommandQueue];
    
    // Create GrDirectContext for Metal
    GrMtlBackendContext backendContext;
    // GrMTLHandle is const void*, and sk_cfp manages the lifetime
    backendContext.fDevice = sk_cfp<GrMTLHandle>((__bridge_retained const void*)device);
    backendContext.fQueue = sk_cfp<GrMTLHandle>((__bridge_retained const void*)commandQueue);
    
    sk_sp<GrDirectContext> context = GrDirectContexts::MakeMetal(backendContext, GrContextOptions());
    
    if (!context) {
        // Fallback to raster surface if Metal context creation fails
        NSLog(@"⚠️ SKIA: Failed to create Metal context, falling back to raster surface");
        SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
        sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
        // Store in wrapper for consistency
        SkiaSurfaceWrapper* wrapper = [[SkiaSurfaceWrapper alloc] init];
        wrapper.surface = surface;
        wrapper.metalLayer = layer;
        // No GPU context for raster surface
        return (__bridge_retained void*)wrapper;
    }
    
    // Store context, layer, and command queue - we'll create surface with drawable each frame
    SkiaSurfaceWrapper* wrapper = [[SkiaSurfaceWrapper alloc] init];
    wrapper.context = context;
    wrapper.metalLayer = layer;
    wrapper.commandQueue = commandQueue;
    // Surface will be created in prepareSurfaceForRender
    
    NSLog(@"✅ SKIA: Created Metal context %dx%d", width, height);
    
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

+ (void)prepareSurfaceForRender:(void*)surface {
    SkiaSurfaceWrapper* wrapper = (__bridge SkiaSurfaceWrapper*)surface;
    if (!wrapper || !wrapper.context || !wrapper.metalLayer) {
        return;
    }
    
    // Get a new drawable for this frame
    id<CAMetalDrawable> drawable = [wrapper.metalLayer nextDrawable];
    if (!drawable) {
        NSLog(@"⚠️ SKIA: Failed to get drawable from CAMetalLayer");
        return;
    }
    
    // Create a surface from the drawable's texture
    // Note: We use __bridge_retained for the texture so Skia manages it
    // But we keep a separate reference to the drawable for presentation
    GrMtlTextureInfo textureInfo;
    textureInfo.fTexture = sk_cfp<GrMTLHandle>((__bridge_retained const void*)[drawable texture]);
    
    GrBackendRenderTarget backendRT = GrBackendRenderTargets::MakeMtl(
        (int)wrapper.metalLayer.drawableSize.width,
        (int)wrapper.metalLayer.drawableSize.height,
        textureInfo
    );
    
    SkColorType colorType = kBGRA_8888_SkColorType;
    // Pass nullptr for color space - the template should accept it even with forward declaration
    sk_sp<SkSurface> newSurface = SkSurfaces::WrapBackendRenderTarget(
        wrapper.context.get(),
        backendRT,
        kTopLeft_GrSurfaceOrigin,
        colorType,
        nullptr, // color space - nullptr should work
        nullptr  // surface props
    );
    
    if (newSurface) {
        // The property is strong, so ARC will automatically retain the drawable
        // We just assign it directly - ARC handles the memory management
        wrapper.drawable = drawable;
        wrapper.surface = newSurface;
    } else {
        NSLog(@"⚠️ SKIA: Failed to create surface from drawable");
    }
}

+ (void)flushSurface:(void*)surface {
    SkiaSurfaceWrapper* wrapper = (__bridge SkiaSurfaceWrapper*)surface;
    if (wrapper && wrapper.surface) {
        if (wrapper.context && wrapper.drawable && wrapper.commandQueue) {
            // GPU surface - flush and submit to GPU, then present drawable
            wrapper.context->flushAndSubmit();
            
            // Present the drawable to the screen
            @autoreleasepool {
                id<MTLCommandBuffer> commandBuffer = [wrapper.commandQueue commandBuffer];
                [commandBuffer presentDrawable:wrapper.drawable];
                [commandBuffer commit];
            }
        } else if (wrapper.context) {
            // GPU context but no drawable (raster fallback) - just flush
            wrapper.context->flushAndSubmit();
        }
        // Raster surfaces don't need explicit flushing - they're CPU-based
        // The drawing is already complete when we return from drawing operations
    }
}

+ (void)destroySurface:(void*)surface {
    if (surface) {
        // ARC will automatically release the drawable and other properties
        // when the wrapper is deallocated
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

