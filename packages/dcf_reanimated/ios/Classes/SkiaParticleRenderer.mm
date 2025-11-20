/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "include/core/SkCanvas.h"
#import "include/core/SkPaint.h"
#import "include/core/SkColor.h"
#import "include/core/SkPath.h"

// Particle data structure
struct ParticleData {
    double x;
    double y;
    double size;
    uint32_t color; // ARGB
};

@interface SkiaParticleRenderer : NSObject

+ (void)drawParticles:(void*)canvas particles:(ParticleData*)particles count:(int)count;

@end

@implementation SkiaParticleRenderer

+ (void)drawParticles:(void*)canvas particles:(ParticleData*)particles count:(int)count {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (!skCanvas) return;
    
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::kFill_Style);
    
    for (int i = 0; i < count; i++) {
        ParticleData* p = &particles[i];
        
        // Set color from ARGB
        paint.setColor(SkColorSetARGB(
            (p->color >> 24) & 0xFF,
            (p->color >> 16) & 0xFF,
            (p->color >> 8) & 0xFF,
            p->color & 0xFF
        ));
        
        // Draw circle
        skCanvas->drawCircle(p->x, p->y, p->size / 2.0, paint);
    }
}

@end

