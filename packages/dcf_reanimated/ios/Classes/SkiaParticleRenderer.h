/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

// Particle data structure for Skia rendering
// Defined outside NS_ASSUME_NONNULL for better Swift interop
typedef struct {
    double x;
    double y;
    double size;
    uint32_t color; // ARGB
} ParticleData;

NS_ASSUME_NONNULL_BEGIN

// Skia particle renderer
@interface SkiaParticleRenderer : NSObject

+ (void)drawParticles:(void*)canvas particles:(const ParticleData*)particles count:(int)count;

@end

NS_ASSUME_NONNULL_END

