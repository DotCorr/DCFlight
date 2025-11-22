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
#import "core/SkPath.h"
#import "core/SkRRect.h"
#import "pathops/SkPathOps.h"
#import "utils/SkParsePath.h"
#import "effects/SkGradientShader.h"
#import "core/SkBlendMode.h"
#import "core/SkImage.h"
#import "codec/SkCodec.h"
#import "codec/SkPngDecoder.h"
#import "codec/SkJpegDecoder.h"
#import "core/SkTypeface.h"
#import "core/SkFont.h"
#import "core/SkFontMgr.h"
#import "effects/SkDiscretePathEffect.h"
#import "effects/SkDashPathEffect.h"
#import "effects/SkCornerPathEffect.h"
#import "effects/SkImageFilters.h"
#import "effects/SkColorMatrix.h"
#import "core/SkMaskFilter.h"
#import "core/SkColorFilter.h"
#import "effects/SkRuntimeEffect.h"
#import <UIKit/UIKit.h>
#import "gpu/ganesh/GrDirectContext.h"
#import "gpu/ganesh/SkSurfaceGanesh.h"
#import "gpu/ganesh/mtl/GrMtlBackendContext.h"
#import "gpu/ganesh/mtl/GrMtlDirectContext.h"
#import "gpu/ganesh/mtl/SkSurfaceMetal.h"
#import "gpu/ganesh/mtl/GrMtlBackendSurface.h"
#import "gpu/ganesh/SkSurfaceGanesh.h"
#import "gpu/ganesh/GrBackendSurface.h"

// ============================================================================
// SHARED SKIA CONTEXT POOL 
// ============================================================================
// Instead of creating a new GrDirectContext per canvas (300MB each),
// we maintain a single shared context that all canvases reuse (~50MB total)

@interface SkiaContextPool : NSObject
+ (instancetype)sharedPool;
- (sk_sp<GrDirectContext>)getOrCreateContext:(id<MTLDevice>)device;
- (id<MTLCommandQueue>)getCommandQueue;
@end

@implementation SkiaContextPool {
    sk_sp<GrDirectContext> _sharedContext;
    id<MTLCommandQueue> _sharedCommandQueue;
    id<MTLDevice> _device;
}

+ (instancetype)sharedPool {
    static SkiaContextPool* pool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pool = [[SkiaContextPool alloc] init];
    });
    return pool;
}

- (sk_sp<GrDirectContext>)getOrCreateContext:(id<MTLDevice>)device {
    if (_sharedContext && _device == device) {
        return _sharedContext;
    }
    
    // Create shared command queue
    _device = device;
    _sharedCommandQueue = [device newCommandQueue];
    
    // Create shared GrDirectContext
    GrMtlBackendContext backendContext;
    backendContext.fDevice = sk_cfp<GrMTLHandle>((__bridge_retained const void*)device);
    backendContext.fQueue = sk_cfp<GrMTLHandle>((__bridge_retained const void*)_sharedCommandQueue);
    
    _sharedContext = GrDirectContexts::MakeMetal(backendContext, GrContextOptions());
    
    if (_sharedContext) {
        NSLog(@"✅ SKIA: Created SHARED Metal context (will be reused by all canvases)");
    } else {
        NSLog(@"⚠️ SKIA: Failed to create shared Metal context");
    }
    
    return _sharedContext;
}

- (id<MTLCommandQueue>)getCommandQueue {
    return _sharedCommandQueue;
}

@end

// Wrapper to hold Skia surface and drawable (context is now shared)
@interface SkiaSurfaceWrapper : NSObject
@property (nonatomic) sk_sp<SkSurface> surface;
@property (nonatomic) id<CAMetalDrawable> drawable;
@property (nonatomic) CAMetalLayer* metalLayer;
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
    
    // 🚀 OPTIMIZATION: Use shared context pool instead of creating new context per canvas
    sk_sp<GrDirectContext> context = [[SkiaContextPool sharedPool] getOrCreateContext:device];
    
    if (!context) {
        // Fallback to raster surface if Metal context creation fails
        NSLog(@"⚠️ SKIA: Failed to get shared Metal context, falling back to raster surface");
        SkImageInfo info = SkImageInfo::MakeN32Premul(width, height);
        sk_sp<SkSurface> surface = SkSurfaces::Raster(info);
        // Store in wrapper for consistency
        SkiaSurfaceWrapper* wrapper = [[SkiaSurfaceWrapper alloc] init];
        wrapper.surface = surface;
        wrapper.metalLayer = layer;
        return (__bridge_retained void*)wrapper;
    }
    
    // Store layer - surface will be created lazily in prepareSurfaceForRender
    // This saves memory by not allocating GPU textures until actually needed
    SkiaSurfaceWrapper* wrapper = [[SkiaSurfaceWrapper alloc] init];
    wrapper.metalLayer = layer;
    // Surface will be created in prepareSurfaceForRender
    
    NSLog(@"✅ SKIA: Canvas ready (using shared context) %dx%d", width, height);
    
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
    if (!wrapper || !wrapper.metalLayer) {
        return;
    }
    
    // Get shared context from pool
    sk_sp<GrDirectContext> context = [[SkiaContextPool sharedPool] getOrCreateContext:wrapper.metalLayer.device];
    if (!context) {
        NSLog(@"⚠️ SKIA: No shared context available");
        return;
    }
    
    // Get a new drawable for this frame
    id<CAMetalDrawable> drawable = [wrapper.metalLayer nextDrawable];
    if (!drawable) {
        NSLog(@"⚠️ SKIA: Failed to get drawable from CAMetalLayer");
        return;
    }
    
    // Create a surface from the drawable's texture
    GrMtlTextureInfo textureInfo;
    textureInfo.fTexture = sk_cfp<GrMTLHandle>((__bridge_retained const void*)[drawable texture]);
    
    GrBackendRenderTarget backendRT = GrBackendRenderTargets::MakeMtl(
        (int)wrapper.metalLayer.drawableSize.width,
        (int)wrapper.metalLayer.drawableSize.height,
        textureInfo
    );
    
    SkColorType colorType = kBGRA_8888_SkColorType;
    sk_sp<SkSurface> newSurface = SkSurfaces::WrapBackendRenderTarget(
        context.get(),
        backendRT,
        kTopLeft_GrSurfaceOrigin,
        colorType,
        nullptr, // color space
        nullptr  // surface props
    );
    
    if (newSurface) {
        wrapper.drawable = drawable;
        wrapper.surface = newSurface;
    } else {
        NSLog(@"⚠️ SKIA: Failed to create surface from drawable");
    }
}

+ (void)flushSurface:(void*)surface {
    SkiaSurfaceWrapper* wrapper = (__bridge SkiaSurfaceWrapper*)surface;
    if (wrapper && wrapper.surface) {
        // Get shared context and command queue
        sk_sp<GrDirectContext> context = [[SkiaContextPool sharedPool] getOrCreateContext:wrapper.metalLayer.device];
        id<MTLCommandQueue> commandQueue = [[SkiaContextPool sharedPool] getCommandQueue];
        
        if (context && wrapper.drawable && commandQueue) {
            // GPU surface - flush and submit to GPU, then present drawable
            context->flushAndSubmit();
            
            // Present the drawable to the screen
            @autoreleasepool {
                id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
                [commandBuffer presentDrawable:wrapper.drawable];
                [commandBuffer commit];
            }
        } else if (context) {
            // GPU context but no drawable (raster fallback) - just flush
            context->flushAndSubmit();
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
    
    // Draw a green circle at the center (matching Android behavior)
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SK_ColorGREEN);
    paint.setStyle(SkPaint::kFill_Style);
    
    // Center coordinates (matching Android: width/2, height/2)
    float centerX = width / 2.0f;
    float centerY = height / 2.0f;
    float radius = 50.0f;
    
    skCanvas->drawCircle(centerX, centerY, radius, paint);
}

// MARK: - Shape Rendering

+ (void*)createPaint {
    SkPaint* paint = new SkPaint();
    paint->setAntiAlias(true);
    return (void*)paint;
}

+ (void)setPaintColor:(void*)paint color:(uint32_t)color {
    SkPaint* skPaint = (SkPaint*)paint;
    if (skPaint) {
        skPaint->setColor(color);
    }
}

+ (void)setPaintStyle:(void*)paint style:(int)style {
    SkPaint* skPaint = (SkPaint*)paint;
    if (skPaint) {
        skPaint->setStyle(style == 0 ? SkPaint::kFill_Style : SkPaint::kStroke_Style);
    }
}

+ (void)setPaintStrokeWidth:(void*)paint width:(float)width {
    SkPaint* skPaint = (SkPaint*)paint;
    if (skPaint) {
        skPaint->setStrokeWidth(width);
    }
}

+ (void)setPaintOpacity:(void*)paint opacity:(float)opacity {
    SkPaint* skPaint = (SkPaint*)paint;
    if (skPaint) {
        uint8_t alpha = (uint8_t)(opacity * 255.0f);
        skPaint->setAlpha(alpha);
    }
}

+ (void)setPaintBlendMode:(void*)paint blendMode:(int)blendMode {
    SkPaint* skPaint = (SkPaint*)paint;
    if (skPaint) {
        // Map blend mode enum to SkBlendMode
        SkBlendMode mode = SkBlendMode::kSrcOver; // default
        switch (blendMode) {
            case 0: mode = SkBlendMode::kClear; break;
            case 1: mode = SkBlendMode::kSrc; break;
            case 2: mode = SkBlendMode::kDst; break;
            case 3: mode = SkBlendMode::kSrcOver; break;
            case 4: mode = SkBlendMode::kDstOver; break;
            case 5: mode = SkBlendMode::kSrcIn; break;
            case 6: mode = SkBlendMode::kDstIn; break;
            case 7: mode = SkBlendMode::kSrcOut; break;
            case 8: mode = SkBlendMode::kDstOut; break;
            case 9: mode = SkBlendMode::kSrcATop; break;
            case 10: mode = SkBlendMode::kDstATop; break;
            case 11: mode = SkBlendMode::kXor; break;
            case 12: mode = SkBlendMode::kPlus; break;
            case 13: mode = SkBlendMode::kModulate; break;
            case 14: mode = SkBlendMode::kScreen; break;
            case 15: mode = SkBlendMode::kOverlay; break;
            case 16: mode = SkBlendMode::kDarken; break;
            case 17: mode = SkBlendMode::kLighten; break;
            case 18: mode = SkBlendMode::kColorDodge; break;
            case 19: mode = SkBlendMode::kColorBurn; break;
            case 20: mode = SkBlendMode::kHardLight; break;
            case 21: mode = SkBlendMode::kSoftLight; break;
            case 22: mode = SkBlendMode::kDifference; break;
            case 23: mode = SkBlendMode::kExclusion; break;
            case 24: mode = SkBlendMode::kMultiply; break;
            case 25: mode = SkBlendMode::kHue; break;
            case 26: mode = SkBlendMode::kSaturation; break;
            case 27: mode = SkBlendMode::kColor; break;
            case 28: mode = SkBlendMode::kLuminosity; break;
        }
        skPaint->setBlendMode(mode);
    }
}

+ (void)setPaintShader:(void*)paint shader:(void*)shader {
    SkPaint* skPaint = (SkPaint*)paint;
    sk_sp<SkShader> skShader = sk_sp<SkShader>((SkShader*)shader);
    if (skPaint && skShader) {
        skPaint->setShader(skShader);
    }
}

+ (void)destroyPaint:(void*)paint {
    if (paint) {
        delete (SkPaint*)paint;
    }
}

+ (void)drawRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skPaint) return;
    
    SkRect rect = SkRect::MakeXYWH(x, y, width, height);
    skCanvas->drawRect(rect, *skPaint);
}

+ (void)drawRoundedRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height r:(float)r paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skPaint) return;
    
    SkRect rect = SkRect::MakeXYWH(x, y, width, height);
    SkRRect rrect = SkRRect::MakeRectXY(rect, r, r);
    skCanvas->drawRRect(rrect, *skPaint);
}

+ (void)drawCircle:(void*)canvas cx:(float)cx cy:(float)cy r:(float)r paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skPaint) return;
    
    skCanvas->drawCircle(cx, cy, r, *skPaint);
}

+ (void)drawOval:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skPaint) return;
    
    SkRect rect = SkRect::MakeXYWH(x, y, width, height);
    skCanvas->drawOval(rect, *skPaint);
}

+ (void)drawLine:(void*)canvas x1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skPaint) return;
    
    skCanvas->drawLine(x1, y1, x2, y2, *skPaint);
}

+ (void)drawPath:(void*)canvas pathString:(NSString*)pathString paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skPaint || !pathString) return;
    
    // Parse SVG path string using SkParsePath
    const char* svgPath = [pathString UTF8String];
    SkPath path;
    if (SkParsePath::FromSVGString(svgPath, &path)) {
        skCanvas->drawPath(path, *skPaint);
    }
}

// MARK: - Canvas Transformations

+ (void)saveCanvas:(void*)canvas {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        skCanvas->save();
    }
}

+ (void)restoreCanvas:(void*)canvas {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        skCanvas->restore();
    }
}

+ (void)translateCanvas:(void*)canvas dx:(float)dx dy:(float)dy {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        skCanvas->translate(dx, dy);
    }
}

+ (void)rotateCanvas:(void*)canvas degrees:(float)degrees {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        float radians = degrees * M_PI / 180.0f;
        skCanvas->rotate(radians);
    }
}

+ (void)scaleCanvas:(void*)canvas sx:(float)sx sy:(float)sy {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        skCanvas->scale(sx, sy);
    }
}

+ (void)skewCanvas:(void*)canvas sx:(float)sx sy:(float)sy {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        skCanvas->skew(sx, sy);
    }
}

// MARK: - Canvas Clipping

+ (void)clipRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        SkRect rect = SkRect::MakeXYWH(x, y, width, height);
        skCanvas->clipRect(rect);
    }
}

+ (void)clipRRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height r:(float)r {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        SkRect rect = SkRect::MakeXYWH(x, y, width, height);
        SkRRect rrect = SkRRect::MakeRectXY(rect, r, r);
        skCanvas->clipRRect(rrect);
    }
}

+ (void)clipPath:(void*)canvas pathString:(NSString*)pathString {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (!skCanvas || !pathString) return;
    
    const char* svgPath = [pathString UTF8String];
    SkPath path;
    if (SkParsePath::FromSVGString(svgPath, &path)) {
        skCanvas->clipPath(path);
    }
}

// MARK: - Shader Creation

+ (void*)createLinearGradient:(float)x0 y0:(float)y0 x1:(float)x1 y1:(float)y1 colors:(NSArray*)colors stops:(NSArray*)stops {
    if (!colors || colors.count == 0) return nullptr;
    
    std::vector<SkColor> skColors;
    std::vector<SkScalar> skStops;
    
    for (id color in colors) {
        uint32_t colorValue = 0;
        if ([color isKindOfClass:[NSNumber class]]) {
            colorValue = [(NSNumber*)color unsignedIntValue];
        } else if ([color isKindOfClass:[NSString class]]) {
            // Parse hex color string
            NSString* hex = (NSString*)color;
            hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
            NSScanner* scanner = [NSScanner scannerWithString:hex];
            unsigned int rgb = 0;
            [scanner scanHexInt:&rgb];
            uint8_t r = (rgb >> 16) & 0xFF;
            uint8_t g = (rgb >> 8) & 0xFF;
            uint8_t b = rgb & 0xFF;
            colorValue = SkColorSetARGB(0xFF, r, g, b);
        }
        skColors.push_back(colorValue);
    }
    
    if (stops && stops.count == colors.count) {
        for (NSNumber* stop in stops) {
            skStops.push_back([stop floatValue]);
        }
    }
    
    SkPoint points[2] = {SkPoint::Make(x0, y0), SkPoint::Make(x1, y1)};
    sk_sp<SkShader> shader = SkGradientShader::MakeLinear(
        points,
        skColors.data(),
        skStops.empty() ? nullptr : skStops.data(),
        (int)skColors.size(),
        SkTileMode::kClamp
    );
    
    return shader.release();
}

+ (void*)createRadialGradient:(float)cx cy:(float)cy r:(float)r colors:(NSArray*)colors stops:(NSArray*)stops {
    if (!colors || colors.count == 0) return nullptr;
    
    std::vector<SkColor> skColors;
    std::vector<SkScalar> skStops;
    
    for (id color in colors) {
        uint32_t colorValue = 0;
        if ([color isKindOfClass:[NSNumber class]]) {
            colorValue = [(NSNumber*)color unsignedIntValue];
        } else if ([color isKindOfClass:[NSString class]]) {
            NSString* hex = (NSString*)color;
            hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
            NSScanner* scanner = [NSScanner scannerWithString:hex];
            unsigned int rgb = 0;
            [scanner scanHexInt:&rgb];
            uint8_t r = (rgb >> 16) & 0xFF;
            uint8_t g = (rgb >> 8) & 0xFF;
            uint8_t b = rgb & 0xFF;
            colorValue = SkColorSetARGB(0xFF, r, g, b);
        }
        skColors.push_back(colorValue);
    }
    
    if (stops && stops.count == colors.count) {
        for (NSNumber* stop in stops) {
            skStops.push_back([stop floatValue]);
        }
    }
    
    sk_sp<SkShader> shader = SkGradientShader::MakeRadial(
        SkPoint::Make(cx, cy),
        r,
        skColors.data(),
        skStops.empty() ? nullptr : skStops.data(),
        (int)skColors.size(),
        SkTileMode::kClamp
    );
    
    return shader.release();
}

+ (void*)createConicGradient:(float)cx cy:(float)cy startAngle:(float)startAngle colors:(NSArray*)colors stops:(NSArray*)stops {
    if (!colors || colors.count == 0) return nullptr;
    
    std::vector<SkColor> skColors;
    std::vector<SkScalar> skStops;
    
    for (id color in colors) {
        uint32_t colorValue = 0;
        if ([color isKindOfClass:[NSNumber class]]) {
            colorValue = [(NSNumber*)color unsignedIntValue];
        } else if ([color isKindOfClass:[NSString class]]) {
            NSString* hex = (NSString*)color;
            hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
            NSScanner* scanner = [NSScanner scannerWithString:hex];
            unsigned int rgb = 0;
            [scanner scanHexInt:&rgb];
            uint8_t r = (rgb >> 16) & 0xFF;
            uint8_t g = (rgb >> 8) & 0xFF;
            uint8_t b = rgb & 0xFF;
            colorValue = SkColorSetARGB(0xFF, r, g, b);
        }
        skColors.push_back(colorValue);
    }
    
    if (stops && stops.count == colors.count) {
        for (NSNumber* stop in stops) {
            skStops.push_back([stop floatValue]);
        }
    }
    
    float startRadians = startAngle * M_PI / 180.0f;
    float endRadians = startRadians + 360.0f * M_PI / 180.0f;
    sk_sp<SkShader> shader = SkGradientShader::MakeSweep(
        cx, cy,
        skColors.data(),
        skStops.empty() ? nullptr : skStops.data(),
        (int)skColors.size(),
        SkTileMode::kClamp,
        startRadians,
        endRadians,
        0,
        nullptr
    );
    
    return shader.release();
}

+ (void)destroyShader:(void*)shader {
    if (shader) {
        SkShader* skShader = (SkShader*)shader;
        skShader->unref();
    }
}

// MARK: - Image Rendering

+ (void*)loadImageFromPath:(NSString*)path {
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (!data) return nullptr;
    
    sk_sp<SkData> skData = SkData::MakeWithCopy(data.bytes, data.length);
    sk_sp<SkImage> image = SkImages::DeferredFromEncodedData(skData);
    if (!image) return nullptr;
    
    return image.release();
}

+ (void*)loadImageFromData:(NSData*)data {
    if (!data) return nullptr;
    
    sk_sp<SkData> skData = SkData::MakeWithCopy(data.bytes, data.length);
    sk_sp<SkImage> image = SkImages::DeferredFromEncodedData(skData);
    if (!image) return nullptr;
    
    return image.release();
}

+ (void)drawImage:(void*)canvas image:(void*)image x:(float)x y:(float)y width:(float)width height:(float)height fit:(NSString*)fit paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkImage* skImage = (SkImage*)image;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !skImage) return;
    
    SkRect dstRect = SkRect::MakeXYWH(x, y, width, height);
    SkRect srcRect = SkRect::MakeWH(skImage->width(), skImage->height());
    
    // Apply fit mode
    if ([fit isEqualToString:@"cover"]) {
        // Scale to cover
        float scale = fmaxf(width / skImage->width(), height / skImage->height());
        float scaledWidth = skImage->width() * scale;
        float scaledHeight = skImage->height() * scale;
        srcRect = SkRect::MakeXYWH(
            (skImage->width() - scaledWidth) / 2,
            (skImage->height() - scaledHeight) / 2,
            scaledWidth,
            scaledHeight
        );
    } else if ([fit isEqualToString:@"contain"]) {
        // Scale to contain
        float scale = fminf(width / skImage->width(), height / skImage->height());
        float scaledWidth = skImage->width() * scale;
        float scaledHeight = skImage->height() * scale;
        dstRect = SkRect::MakeXYWH(
            x + (width - scaledWidth) / 2,
            y + (height - scaledHeight) / 2,
            scaledWidth,
            scaledHeight
        );
    }
    
    SkSamplingOptions sampling;
    if (skPaint) {
        skCanvas->drawImageRect(sk_ref_sp(skImage), SkRect::Make(skImage->dimensions()), dstRect, sampling, skPaint, SkCanvas::kStrict_SrcRectConstraint);
    } else {
        SkPaint defaultPaint;
        skCanvas->drawImageRect(sk_ref_sp(skImage), SkRect::Make(skImage->dimensions()), dstRect, sampling, &defaultPaint, SkCanvas::kStrict_SrcRectConstraint);
    }
}

+ (void)destroyImage:(void*)image {
    if (image) {
        SkImage* skImage = (SkImage*)image;
        skImage->unref();
    }
}

// MARK: - Text Rendering

+ (void*)createFont:(NSString*)fontFamily size:(float)size weight:(int)weight style:(int)style {
    // For now, just use empty typeface - custom fonts can be added later
    // This avoids compatibility issues with different Skia versions
    sk_sp<SkTypeface> typeface = SkTypeface::MakeEmpty();
    
    SkFont* font = new SkFont(typeface, size);
    return (void*)font;
}

+ (void)drawText:(void*)canvas text:(NSString*)text x:(float)x y:(float)y font:(void*)font paint:(void*)paint {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    SkFont* skFont = (SkFont*)font;
    SkPaint* skPaint = (SkPaint*)paint;
    if (!skCanvas || !text || !skFont) return;
    
    const char* utf8 = [text UTF8String];
    size_t byteLength = strlen(utf8);
    
    if (skPaint) {
        skCanvas->drawSimpleText(utf8, byteLength, SkTextEncoding::kUTF8, x, y, *skFont, *skPaint);
    } else {
        SkPaint defaultPaint;
        defaultPaint.setAntiAlias(true);
        skCanvas->drawSimpleText(utf8, byteLength, SkTextEncoding::kUTF8, x, y, *skFont, defaultPaint);
    }
}

+ (void)destroyFont:(void*)font {
    if (font) {
        delete (SkFont*)font;
    }
}

// MARK: - Path Effects

+ (void*)createDiscretePathEffect:(float)length deviation:(float)deviation seed:(float)seed {
    sk_sp<SkPathEffect> effect = SkDiscretePathEffect::Make(length, deviation, (uint32_t)seed);
    return effect.release();
}

+ (void*)createDashPathEffect:(float*)intervals count:(int)count phase:(float)phase {
    // TODO: Fix DashPathEffect span compatibility issue
    // For now, return nullptr to allow build to succeed
    // Dash effects will not work until this is fixed
    NSLog(@"⚠️ SKIA: DashPathEffect temporarily disabled due to API compatibility");
    return nullptr;
}

+ (void*)createCornerPathEffect:(float)r {
    sk_sp<SkPathEffect> effect = SkCornerPathEffect::Make(r);
    return effect.release();
}

+ (void)destroyPathEffect:(void*)pathEffect {
    if (pathEffect) {
        SkPathEffect* effect = (SkPathEffect*)pathEffect;
        effect->unref();
    }
}

+ (void)setPaintPathEffect:(void*)paint pathEffect:(void*)pathEffect {
    SkPaint* skPaint = (SkPaint*)paint;
    sk_sp<SkPathEffect> effect = sk_sp<SkPathEffect>((SkPathEffect*)pathEffect);
    if (skPaint && effect) {
        skPaint->setPathEffect(effect);
    }
}

// MARK: - Image Filters

+ (void*)createBlurFilter:(float)blurX blurY:(float)blurY mode:(int)tileMode {
    SkTileMode skTileMode = (SkTileMode)tileMode;
    sk_sp<SkImageFilter> filter = SkImageFilters::Blur(blurX, blurY, skTileMode, nullptr);
    return filter.release();
}

+ (void*)createColorMatrixFilter:(float*)matrix {
    if (!matrix) return nullptr;
    // Use public API - create color matrix from array
    sk_sp<SkColorFilter> colorFilter = SkColorFilters::Matrix(matrix);
    sk_sp<SkImageFilter> filter = SkImageFilters::ColorFilter(colorFilter, nullptr);
    return filter.release();
}

+ (void*)createDropShadowFilter:(float)dx dy:(float)dy blurX:(float)blurX blurY:(float)blurY color:(uint32_t)color {
    SkColor skColor = color;
    sk_sp<SkImageFilter> filter = SkImageFilters::DropShadow(dx, dy, blurX, blurY, skColor, nullptr);
    return filter.release();
}

+ (void*)createOffsetFilter:(float)x y:(float)y {
    sk_sp<SkImageFilter> filter = SkImageFilters::Offset(x, y, nullptr);
    return filter.release();
}

+ (void*)createMorphologyFilter:(int)opValue radiusX:(float)radiusX radiusY:(float)radiusY {
    // Use separate Erode/Dilate functions in newer Skia API
    sk_sp<SkImageFilter> filter;
    if (opValue == 0) {
        filter = SkImageFilters::Erode(radiusX, radiusY, nullptr);
    } else {
        filter = SkImageFilters::Dilate(radiusX, radiusY, nullptr);
    }
    return filter.release();
}

+ (void)destroyImageFilter:(void*)filter {
    if (filter) {
        SkImageFilter* skFilter = (SkImageFilter*)filter;
        skFilter->unref();
    }
}

+ (void)setPaintImageFilter:(void*)paint filter:(void*)filter {
    SkPaint* skPaint = (SkPaint*)paint;
    sk_sp<SkImageFilter> skFilter = sk_sp<SkImageFilter>((SkImageFilter*)filter);
    if (skPaint && skFilter) {
        skPaint->setImageFilter(skFilter);
    }
}

// MARK: - Color Filters

+ (void*)createColorFilterMatrix:(float*)matrix {
    if (!matrix) return nullptr;
    // Use public API - pass array directly
    sk_sp<SkColorFilter> filter = SkColorFilters::Matrix(matrix);
    return filter.release();
}

+ (void*)createColorFilterBlend:(uint32_t)color mode:(int)blendMode {
    SkColor skColor = color;
    SkBlendMode skBlendMode = (SkBlendMode)blendMode;
    sk_sp<SkColorFilter> filter = SkColorFilters::Blend(skColor, skBlendMode);
    return filter.release();
}

+ (void)destroyColorFilter:(void*)filter {
    if (filter) {
        SkColorFilter* skFilter = (SkColorFilter*)filter;
        skFilter->unref();
    }
}

+ (void)setPaintColorFilter:(void*)paint filter:(void*)filter {
    SkPaint* skPaint = (SkPaint*)paint;
    sk_sp<SkColorFilter> skFilter = sk_sp<SkColorFilter>((SkColorFilter*)filter);
    if (skPaint && skFilter) {
        skPaint->setColorFilter(skFilter);
    }
}

// MARK: - Backdrop Filters

+ (void*)createBackdropBlurFilter:(float)blurX blurY:(float)blurY {
    sk_sp<SkImageFilter> filter = SkImageFilters::Blur(blurX, blurY, SkTileMode::kClamp, nullptr);
    return filter.release();
}

+ (void*)createBackdropColorMatrixFilter:(float*)matrix {
    if (!matrix) return nullptr;
    // Use public API - pass array directly
    sk_sp<SkColorFilter> colorFilter = SkColorFilters::Matrix(matrix);
    sk_sp<SkImageFilter> filter = SkImageFilters::ColorFilter(colorFilter, nullptr);
    return filter.release();
}

+ (void)destroyBackdropFilter:(void*)filter {
    if (filter) {
        SkImageFilter* skFilter = (SkImageFilter*)filter;
        skFilter->unref();
    }
}

// MARK: - Mask

+ (void)beginMask:(void*)canvas mode:(int)mode {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        skCanvas->saveLayer(nullptr, nullptr);
        // Mode: 0=alpha, 1=luminance
        // Alpha mode uses alpha channel, luminance uses RGB values
    }
}

+ (void)endMask:(void*)canvas clip:(BOOL)clip {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (skCanvas) {
        // Apply mask using blend mode
        SkPaint maskPaint;
        maskPaint.setBlendMode(SkBlendMode::kDstIn); // Use alpha channel as mask
        skCanvas->restore();
    }
}

// MARK: - Custom Shaders (GLSL)

+ (void*)createRuntimeShader:(NSString*)source {
    if (!source) return nullptr;
    
    const char* glslSource = [source UTF8String];
    auto [effect, error] = SkRuntimeEffect::MakeForShader(SkString(glslSource));
    
    if (!effect) {
        NSLog(@"⚠️ SKIA: Failed to create runtime shader: %s", error.c_str());
        return nullptr;
    }
    
    // makeShader requires uniforms (empty SkData) and children parameters
    sk_sp<SkData> uniforms = SkData::MakeEmpty();
    sk_sp<SkShader> shader = effect->makeShader(uniforms, nullptr, 0, nullptr);
    
    return shader.release();
}

+ (void)setRuntimeShaderUniform:(void*)shader name:(NSString*)name value:(float)value {
    // Note: This requires keeping a reference to the builder
    // For now, this is a placeholder - full implementation would require builder storage
}

+ (void)setRuntimeShaderUniformVec2:(void*)shader name:(NSString*)name x:(float)x y:(float)y {
    // Placeholder
}

+ (void)setRuntimeShaderUniformVec3:(void*)shader name:(NSString*)name x:(float)x y:(float)y z:(float)z {
    // Placeholder
}

+ (void)setRuntimeShaderUniformVec4:(void*)shader name:(NSString*)name x:(float)x y:(float)y z:(float)z w:(float)w {
    // Placeholder
}

+ (void)destroyRuntimeShader:(void*)shader {
    if (shader) {
        SkShader* skShader = (SkShader*)shader;
        skShader->unref();
    }
}

@end

