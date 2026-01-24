/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

/// Corner radii structure for border drawing
typedef struct {
    CGFloat topLeft;
    CGFloat topRight;
    CGFloat bottomLeft;
    CGFloat bottomRight;
} DCFCornerRadii;

/// Corner insets structure for border drawing
typedef struct {
    CGSize topLeft;
    CGSize topRight;
    CGSize bottomLeft;
    CGSize bottomRight;
} DCFCornerInsets;

/// Border colors structure for border drawing
typedef struct {
    CGColorRef top;
    CGColorRef left;
    CGColorRef bottom;
    CGColorRef right;
} DCFBorderColors;

/// Determine if border properties are equal (for optimization)
BOOL DCFBorderInsetsAreEqual(UIEdgeInsets borderInsets);
BOOL DCFCornerRadiiAreEqual(DCFCornerRadii cornerRadii);
BOOL DCFBorderColorsAreEqual(DCFBorderColors borderColors);

/// Convert corner radii to corner insets by applying border insets
DCFCornerInsets DCFGetCornerInsets(DCFCornerRadii cornerRadii, UIEdgeInsets borderInsets);

/// Create a CGPath representing a rounded rectangle
CGPathRef DCFPathCreateWithRoundedRect(CGRect bounds,
                                       DCFCornerInsets cornerInsets,
                                       const CGAffineTransform *transform);

/// Draw a CSS-compliant border as an image
UIImage *DCFGetBorderImage(NSString *borderStyle,
                            CGSize viewSize,
                            DCFCornerRadii cornerRadii,
                            UIEdgeInsets borderInsets,
                            DCFBorderColors borderColors,
                            CGColorRef backgroundColor,
                            BOOL drawToEdge);
