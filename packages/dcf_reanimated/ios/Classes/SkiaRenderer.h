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
+ (void)prepareSurfaceForRender:(void*)surface;
+ (void)flushSurface:(void*)surface;
+ (void)destroySurface:(void*)surface;
+ (void)drawTestCircle:(void*)canvas width:(float)width height:(float)height;

@end

NS_ASSUME_NONNULL_END

