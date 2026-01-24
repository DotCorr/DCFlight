/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "DCFView.h"
#import "DCFBorderDrawing.h"

@implementation DCFView {
    // Border properties (using -1 as unset value, matching standard model)
    CGFloat _borderWidth;
    CGFloat _borderTopWidth;
    CGFloat _borderRightWidth;
    CGFloat _borderBottomWidth;
    CGFloat _borderLeftWidth;
    
    CGFloat _borderRadius;
    CGFloat _borderTopLeftRadius;
    CGFloat _borderTopRightRadius;
    CGFloat _borderBottomLeftRadius;
    CGFloat _borderBottomRightRadius;
    
    CGColorRef _borderColor;
    CGColorRef _borderTopColor;
    CGColorRef _borderRightColor;
    CGColorRef _borderBottomColor;
    CGColorRef _borderLeftColor;
    
    NSString *__unsafe_unretained _borderStyle;
    
    UIColor *_dcfBackgroundColor;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Initialize border properties to -1 (unset), matching standard model
        _borderWidth = -1;
        _borderTopWidth = -1;
        _borderRightWidth = -1;
        _borderBottomWidth = -1;
        _borderLeftWidth = -1;
        
        _borderRadius = -1;
        _borderTopLeftRadius = -1;
        _borderTopRightRadius = -1;
        _borderBottomLeftRadius = -1;
        _borderBottomRightRadius = -1;
        
        _borderStyle = @"solid";
        
        _dcfBackgroundColor = super.backgroundColor;
    }
    return self;
}

- (void)dealloc {
    CGColorRelease(_borderColor);
    CGColorRelease(_borderTopColor);
    CGColorRelease(_borderRightColor);
    CGColorRelease(_borderBottomColor);
    CGColorRelease(_borderLeftColor);
}

#pragma mark - Border Radius

- (void)setBorderRadius:(CGFloat)borderRadius {
    if (_borderRadius == borderRadius) {
        return;
    }
    _borderRadius = borderRadius;
    [self.layer setNeedsDisplay];
}

- (void)setBorderTopLeftRadius:(CGFloat)borderTopLeftRadius {
    if (_borderTopLeftRadius == borderTopLeftRadius) {
        return;
    }
    _borderTopLeftRadius = borderTopLeftRadius;
    [self.layer setNeedsDisplay];
}

- (void)setBorderTopRightRadius:(CGFloat)borderTopRightRadius {
    if (_borderTopRightRadius == borderTopRightRadius) {
        return;
    }
    _borderTopRightRadius = borderTopRightRadius;
    [self.layer setNeedsDisplay];
}

- (void)setBorderBottomLeftRadius:(CGFloat)borderBottomLeftRadius {
    if (_borderBottomLeftRadius == borderBottomLeftRadius) {
        return;
    }
    _borderBottomLeftRadius = borderBottomLeftRadius;
    [self.layer setNeedsDisplay];
}

- (void)setBorderBottomRightRadius:(CGFloat)borderBottomRightRadius {
    if (_borderBottomRightRadius == borderBottomRightRadius) {
        return;
    }
    _borderBottomRightRadius = borderBottomRightRadius;
    [self.layer setNeedsDisplay];
}

#pragma mark - Border Width

- (void)setBorderWidth:(CGFloat)borderWidth {
    if (_borderWidth == borderWidth) {
        return;
    }
    _borderWidth = borderWidth;
    [self.layer setNeedsDisplay];
}

- (void)setBorderTopWidth:(CGFloat)borderTopWidth {
    if (_borderTopWidth == borderTopWidth) {
        return;
    }
    _borderTopWidth = borderTopWidth;
    [self.layer setNeedsDisplay];
}

- (void)setBorderRightWidth:(CGFloat)borderRightWidth {
    if (_borderRightWidth == borderRightWidth) {
        return;
    }
    _borderRightWidth = borderRightWidth;
    [self.layer setNeedsDisplay];
}

- (void)setBorderBottomWidth:(CGFloat)borderBottomWidth {
    if (_borderBottomWidth == borderBottomWidth) {
        return;
    }
    _borderBottomWidth = borderBottomWidth;
    [self.layer setNeedsDisplay];
}

- (void)setBorderLeftWidth:(CGFloat)borderLeftWidth {
    if (_borderLeftWidth == borderLeftWidth) {
        return;
    }
    _borderLeftWidth = borderLeftWidth;
    [self.layer setNeedsDisplay];
}

#pragma mark - Border Color

- (void)setBorderColor:(CGColorRef)borderColor {
    if (CGColorEqualToColor(_borderColor, borderColor)) {
        return;
    }
    CGColorRelease(_borderColor);
    _borderColor = CGColorRetain(borderColor);
    [self.layer setNeedsDisplay];
}

- (void)setBorderTopColor:(CGColorRef)borderTopColor {
    if (CGColorEqualToColor(_borderTopColor, borderTopColor)) {
        return;
    }
    CGColorRelease(_borderTopColor);
    _borderTopColor = CGColorRetain(borderTopColor);
    [self.layer setNeedsDisplay];
}

- (void)setBorderRightColor:(CGColorRef)borderRightColor {
    if (CGColorEqualToColor(_borderRightColor, borderRightColor)) {
        return;
    }
    CGColorRelease(_borderRightColor);
    _borderRightColor = CGColorRetain(borderRightColor);
    [self.layer setNeedsDisplay];
}

- (void)setBorderBottomColor:(CGColorRef)borderBottomColor {
    if (CGColorEqualToColor(_borderBottomColor, borderBottomColor)) {
        return;
    }
    CGColorRelease(_borderBottomColor);
    _borderBottomColor = CGColorRetain(borderBottomColor);
    [self.layer setNeedsDisplay];
}

- (void)setBorderLeftColor:(CGColorRef)borderLeftColor {
    if (CGColorEqualToColor(_borderLeftColor, borderLeftColor)) {
        return;
    }
    CGColorRelease(_borderLeftColor);
    _borderLeftColor = CGColorRetain(borderLeftColor);
    [self.layer setNeedsDisplay];
}

#pragma mark - Border Style

- (void)setBorderStyle:(NSString *)borderStyle {
    if ([_borderStyle isEqualToString:borderStyle]) {
        return;
    }
    _borderStyle = borderStyle;
    [self.layer setNeedsDisplay];
}

#pragma mark - Background Color

- (void)setDcfBackgroundColor:(UIColor *)dcfBackgroundColor {
    if ([_dcfBackgroundColor isEqual:dcfBackgroundColor]) {
        return;
    }
    _dcfBackgroundColor = dcfBackgroundColor;
    [self.layer setNeedsDisplay];
}

- (UIColor *)dcfBackgroundColor {
    return _dcfBackgroundColor;
}

#pragma mark - Shadow Properties (Direct Layer Mapping)

- (void)setShadowColor:(CGColorRef)shadowColor {
    self.layer.shadowColor = shadowColor;
}

- (CGColorRef)shadowColor {
    return self.layer.shadowColor;
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity {
    self.layer.shadowOpacity = shadowOpacity;
}

- (CGFloat)shadowOpacity {
    return self.layer.shadowOpacity;
}

- (void)setShadowRadius:(CGFloat)shadowRadius {
    self.layer.shadowRadius = shadowRadius;
}

- (CGFloat)shadowRadius {
    return self.layer.shadowRadius;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    self.layer.shadowOffset = shadowOffset;
}

- (CGSize)shadowOffset {
    return self.layer.shadowOffset;
}

#pragma mark - Elevation (Converted to Shadow)

- (void)setElevation:(CGFloat)elevation {
    if (elevation > 0) {
        // Material Design elevation formula
        self.layer.shadowOpacity = (float)MIN(0.25, 0.1 + elevation * 0.01);
        self.layer.shadowRadius = elevation * 0.5;
        self.layer.shadowOffset = CGSizeMake(0, elevation * 0.5);
        self.layer.shadowColor = UIColor.blackColor.CGColor;
    } else {
        self.layer.shadowOpacity = 0;
        self.layer.shadowRadius = 0;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowColor = nil;
    }
}

- (CGFloat)elevation {
    // Calculate elevation from shadow properties (reverse of setter)
    if (self.layer.shadowOpacity > 0 && self.layer.shadowRadius > 0) {
        return self.layer.shadowRadius / 0.5;
    }
    return 0;
}

#pragma mark - Opacity (Direct UIView Mapping)

- (void)setOpacity:(CGFloat)opacity {
    self.alpha = opacity;
}

- (CGFloat)opacity {
    return self.alpha;
}

#pragma mark - Border Drawing (Standard Model Approach)

- (DCFCornerRadii)cornerRadii {
    const CGFloat radius = MAX(0, _borderRadius >= 0 ? _borderRadius : 0);
    return (DCFCornerRadii){
        _borderTopLeftRadius >= 0 ? _borderTopLeftRadius : radius,
        _borderTopRightRadius >= 0 ? _borderTopRightRadius : radius,
        _borderBottomLeftRadius >= 0 ? _borderBottomLeftRadius : radius,
        _borderBottomRightRadius >= 0 ? _borderBottomRightRadius : radius,
    };
}

- (UIEdgeInsets)bordersAsInsets {
    const CGFloat borderWidth = MAX(0, _borderWidth >= 0 ? _borderWidth : 0);
    return UIEdgeInsetsMake(
        _borderTopWidth >= 0 ? _borderTopWidth : borderWidth,
        _borderLeftWidth >= 0 ? _borderLeftWidth : borderWidth,
        _borderBottomWidth >= 0 ? _borderBottomWidth : borderWidth,
        _borderRightWidth >= 0 ? _borderRightWidth : borderWidth
    );
}

- (DCFBorderColors)borderColors {
    return (DCFBorderColors){
        _borderTopColor ?: _borderColor,
        _borderLeftColor ?: _borderColor,
        _borderBottomColor ?: _borderColor,
        _borderRightColor ?: _borderColor,
    };
}

- (void)displayLayer:(CALayer *)layer {
    if (CGSizeEqualToSize(layer.bounds.size, CGSizeZero)) {
        return;
    }
    
    // Update shadow path if shadow exists
    [self updateShadowPath];
    
    const DCFCornerRadii cornerRadii = [self cornerRadii];
    const UIEdgeInsets borderInsets = [self bordersAsInsets];
    const DCFBorderColors borderColors = [self borderColors];
    
    // Use native iOS border rendering for simple uniform borders
    BOOL useNativeBorderRendering =
        DCFCornerRadiiAreEqual(cornerRadii) &&
        DCFBorderInsetsAreEqual(borderInsets) &&
        DCFBorderColorsAreEqual(borderColors) &&
        [_borderStyle isEqualToString:@"solid"] &&
        (borderInsets.top == 0 || (borderColors.top && [self alphaFromColor:borderColors.top] == 0) || self.clipsToBounds);
    
    if (useNativeBorderRendering) {
        // Simple uniform border - use native CALayer properties
        layer.cornerRadius = cornerRadii.topLeft;
        layer.borderColor = borderColors.left;
        layer.borderWidth = borderInsets.left;
        layer.backgroundColor = _dcfBackgroundColor.CGColor;
        layer.contents = nil;
        layer.needsDisplayOnBoundsChange = NO;
        layer.mask = nil;
        return;
    }
    
    // Complex border - use border drawing
    UIImage *image = DCFGetBorderImage(
        _borderStyle,
        layer.bounds.size,
        cornerRadii,
        borderInsets,
        borderColors,
        _dcfBackgroundColor.CGColor,
        self.clipsToBounds
    );
    
    layer.backgroundColor = NULL;
    
    if (image == nil) {
        layer.contents = nil;
        layer.needsDisplayOnBoundsChange = NO;
        return;
    }
    
    CGRect contentsCenter = ({
        CGSize size = image.size;
        UIEdgeInsets insets = image.capInsets;
        CGRectMake(
            insets.left / size.width,
            insets.top / size.height,
            1.0 / size.width,
            1.0 / size.height
        );
    });
    
    layer.contents = (id)image.CGImage;
    layer.contentsScale = image.scale;
    layer.needsDisplayOnBoundsChange = YES;
    layer.magnificationFilter = kCAFilterNearest;
    
    const BOOL isResizable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
    if (isResizable) {
        layer.contentsCenter = contentsCenter;
    } else {
        layer.contentsCenter = CGRectMake(0.0, 0.0, 1.0, 1.0);
    }
    
    [self updateClippingForLayer:layer];
}

- (void)updateShadowPath {
    if (self.layer.shadowOpacity > 0 && [self alphaFromColor:self.layer.shadowColor] > 0) {
        if ([self alphaFromColor:_dcfBackgroundColor.CGColor] > 0.999) {
            // Solid background - calculate shadow path from border
            const DCFCornerRadii cornerRadii = [self cornerRadii];
            const DCFCornerInsets cornerInsets = DCFGetCornerInsets(cornerRadii, UIEdgeInsetsZero);
            CGPathRef shadowPath = DCFPathCreateWithRoundedRect(self.bounds, cornerInsets, NULL);
            self.layer.shadowPath = shadowPath;
            CGPathRelease(shadowPath);
        } else {
            // Transparent background - can't accurately calculate, fall back to pixel-based shadow
            self.layer.shadowPath = nil;
        }
    }
}

- (void)updateClippingForLayer:(CALayer *)layer {
    CALayer *mask = nil;
    CGFloat cornerRadius = 0;
    
    if (self.clipsToBounds) {
        const DCFCornerRadii cornerRadii = [self cornerRadii];
        if (DCFCornerRadiiAreEqual(cornerRadii)) {
            cornerRadius = cornerRadii.topLeft;
        } else {
            CAShapeLayer *shapeLayer = [CAShapeLayer layer];
            CGPathRef path = DCFPathCreateWithRoundedRect(
                self.bounds,
                DCFGetCornerInsets(cornerRadii, UIEdgeInsetsZero),
                NULL
            );
            shapeLayer.path = path;
            CGPathRelease(path);
            mask = shapeLayer;
        }
    }
    
    layer.cornerRadius = cornerRadius;
    layer.mask = mask;
}

- (void)reactSetFrame:(CGRect)frame {
    CGSize oldSize = self.bounds.size;
    [super setFrame:frame];
    if (!CGSizeEqualToSize(self.bounds.size, oldSize)) {
        [self.layer setNeedsDisplay];
    }
}

#pragma mark - Helper Methods

/// Get alpha component from CGColor (replaces deprecated CGColorGetAlpha)
- (CGFloat)alphaFromColor:(CGColorRef)color {
    if (color == NULL) {
        return 0.0;
    }
    const CGFloat *components = CGColorGetComponents(color);
    if (components == NULL) {
        return 0.0;
    }
    size_t componentCount = CGColorGetNumberOfComponents(color);
    if (componentCount == 4) {
        // RGBA format
        return components[3];
    } else if (componentCount == 2) {
        // Grayscale + Alpha
        return components[1];
    }
    return 1.0; // Default to opaque if format is unknown
}

@end
