/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Skia renderer wrapper for Objective-C++/Swift interop
@interface SkiaRenderer : NSObject

+ (void* _Nullable)createSkiaSurface:(void*)metalDevice layer:(void*)metalLayer width:(int)width height:(int)height;
+ (void* _Nullable)getCanvasFromSurface:(void*)surface;
+ (void)prepareSurfaceForRender:(void*)surface NS_SWIFT_NAME(prepareSurface(forRender:));
+ (void)flushSurface:(void*)surface;
+ (void)destroySurface:(void*)surface;
+ (void)drawTestCircle:(void*)canvas width:(float)width height:(float)height;

// Shape rendering functions
+ (void)drawRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height paint:(void*)paint;
+ (void)drawRoundedRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height r:(float)r paint:(void*)paint;
+ (void)drawCircle:(void*)canvas cx:(float)cx cy:(float)cy r:(float)r paint:(void*)paint;
+ (void)drawOval:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height paint:(void*)paint;
+ (void)drawLine:(void*)canvas x1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 paint:(void*)paint;
+ (void)drawPath:(void*)canvas pathString:(NSString*)pathString paint:(void*)paint;
+ (void*)createPaint;
+ (void)setPaintColor:(void*)paint color:(uint32_t)color;
+ (void)setPaintStyle:(void*)paint style:(int)style; // 0=fill, 1=stroke
+ (void)setPaintStrokeWidth:(void*)paint width:(float)width;
+ (void)setPaintOpacity:(void*)paint opacity:(float)opacity;
+ (void)setPaintBlendMode:(void*)paint blendMode:(int)blendMode;
+ (void)setPaintShader:(void*)paint shader:(void*)shader;
+ (void)destroyPaint:(void*)paint;

// Canvas transformations
+ (void)saveCanvas:(void*)canvas;
+ (void)restoreCanvas:(void*)canvas;
+ (void)translateCanvas:(void*)canvas dx:(float)dx dy:(float)dy;
+ (void)rotateCanvas:(void*)canvas degrees:(float)degrees;
+ (void)scaleCanvas:(void*)canvas sx:(float)sx sy:(float)sy;
+ (void)skewCanvas:(void*)canvas sx:(float)sx sy:(float)sy;

// Canvas clipping
+ (void)clipRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height;
+ (void)clipRRect:(void*)canvas x:(float)x y:(float)y width:(float)width height:(float)height r:(float)r;
+ (void)clipPath:(void*)canvas pathString:(NSString*)pathString;

// Shader creation
+ (void*)createLinearGradient:(float)x0 y0:(float)y0 x1:(float)x1 y1:(float)y1 colors:(NSArray*)colors stops:(NSArray*)stops;
+ (void*)createRadialGradient:(float)cx cy:(float)cy r:(float)r colors:(NSArray*)colors stops:(NSArray*)stops;
+ (void*)createConicGradient:(float)cx cy:(float)cy startAngle:(float)startAngle colors:(NSArray*)colors stops:(NSArray*)stops;
+ (void)destroyShader:(void*)shader;

// Image rendering
+ (void*)loadImageFromPath:(NSString*)path NS_SWIFT_NAME(loadImage(fromPath:));
+ (void*)loadImageFromData:(NSData*)data NS_SWIFT_NAME(loadImage(from:));
+ (void)drawImage:(void*)canvas image:(void*)image x:(float)x y:(float)y width:(float)width height:(float)height fit:(NSString*)fit paint:(void* _Nullable)paint;
+ (void)destroyImage:(void*)image;

// Text rendering
+ (void* _Nullable)createFont:(NSString*)fontFamily size:(float)size weight:(int)weight style:(int)style;
+ (void)drawText:(void*)canvas text:(NSString*)text x:(float)x y:(float)y font:(void*)font paint:(void*)paint;
+ (void)destroyFont:(void*)font;

// Path effects
+ (void*)createDiscretePathEffect:(float)length deviation:(float)deviation seed:(float)seed;
+ (void*)createDashPathEffect:(float*)intervals count:(int)count phase:(float)phase;
+ (void*)createCornerPathEffect:(float)r;
+ (void)destroyPathEffect:(void*)pathEffect;
+ (void)setPaintPathEffect:(void*)paint pathEffect:(void*)pathEffect;

// Image filters
+ (void*)createBlurFilter:(float)blurX blurY:(float)blurY mode:(int)tileMode;
+ (void*)createColorMatrixFilter:(float*)matrix; // 20 values (5x4)
+ (void*)createDropShadowFilter:(float)dx dy:(float)dy blurX:(float)blurX blurY:(float)blurY color:(uint32_t)color;
+ (void*)createOffsetFilter:(float)x y:(float)y;
+ (void*)createMorphologyFilter:(int)opValue radiusX:(float)radiusX radiusY:(float)radiusY;
+ (void)destroyImageFilter:(void*)filter;
+ (void)setPaintImageFilter:(void*)paint filter:(void*)filter;

// Color Filters
+ (void*)createColorFilterMatrix:(float*)matrix; // 20 values (5x4)
+ (void*)createColorFilterBlend:(uint32_t)color mode:(int)blendMode;
+ (void)destroyColorFilter:(void*)filter;
+ (void)setPaintColorFilter:(void*)paint filter:(void*)filter;

// Backdrop Filters
+ (void*)createBackdropBlurFilter:(float)blurX blurY:(float)blurY;
+ (void*)createBackdropColorMatrixFilter:(float*)matrix; // 20 values
+ (void)destroyBackdropFilter:(void*)filter;

// Mask
+ (void)beginMask:(void*)canvas mode:(int)mode; // mode: 0=alpha, 1=luminance
+ (void)endMask:(void*)canvas clip:(BOOL)clip;

// Custom Shaders (GLSL)
+ (void*)createRuntimeShader:(NSString*)source;
+ (void)setRuntimeShaderUniform:(void*)shader name:(NSString*)name value:(float)value;
+ (void)setRuntimeShaderUniformVec2:(void*)shader name:(NSString*)name x:(float)x y:(float)y;
+ (void)setRuntimeShaderUniformVec3:(void*)shader name:(NSString*)name x:(float)x y:(float)y z:(float)z;
+ (void)setRuntimeShaderUniformVec4:(void*)shader name:(NSString*)name x:(float)x y:(float)y z:(float)z w:(float)w;
+ (void)destroyRuntimeShader:(void*)shader;

@end

NS_ASSUME_NONNULL_END

