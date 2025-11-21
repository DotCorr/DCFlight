/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "SkiaParticleRenderer.h"
#import <Metal/Metal.h>
#import "core/SkCanvas.h"
#import "core/SkPaint.h"
#import "core/SkColor.h"
#import "core/SkPath.h"

// ParticleData struct is defined in SkiaParticleRenderer.h

@implementation SkiaParticleRenderer

+ (void)drawParticles:(void*)canvas particles:(const ParticleData*)particles count:(int)count {
    SkCanvas* skCanvas = (SkCanvas*)canvas;
    if (!skCanvas || !particles) return;
    
    // Clear canvas with transparent background
    skCanvas->clear(SK_ColorTRANSPARENT);
    
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::kFill_Style);
    
    for (int i = 0; i < count; i++) {
        const ParticleData* p = &particles[i];
        
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

