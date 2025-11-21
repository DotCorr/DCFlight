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
    if (!skCanvas || !particles) {
        NSLog(@"⚠️ SKIA ParticleRenderer: Invalid canvas or particles");
        return;
    }
    
    // Clear canvas with transparent background
    skCanvas->clear(SK_ColorTRANSPARENT);
    
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::kFill_Style);
    
    int drawnCount = 0;
    for (int i = 0; i < count; i++) {
        const ParticleData* p = &particles[i];
        
        // Extract ARGB components
        uint8_t a = (p->color >> 24) & 0xFF;
        uint8_t r = (p->color >> 16) & 0xFF;
        uint8_t g = (p->color >> 8) & 0xFF;
        uint8_t b = p->color & 0xFF;
        
        // Set color from ARGB
        paint.setColor(SkColorSetARGB(a, r, g, b));
        
        // Draw circle
        skCanvas->drawCircle(p->x, p->y, p->size / 2.0, paint);
        drawnCount++;
        
        // Log first few particles for debugging
        if (i < 3) {
            NSLog(@"🎨 Particle %d: x=%.1f y=%.1f size=%.1f color=0x%08X (A=%d R=%d G=%d B=%d)", 
                  i, p->x, p->y, p->size, p->color, a, r, g, b);
        }
    }
    
    if (drawnCount > 0) {
        NSLog(@"✅ SKIA ParticleRenderer: Drew %d particles", drawnCount);
    }
}

@end

