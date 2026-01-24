/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// DCFView provides direct property setters for style properties.
///
/// This matches the standard model's approach where each style property
/// is directly mapped to a native view property setter.
///
/// **Usage:**
/// ```swift
/// let view = DCFView()
/// view.borderRadius = 8.0
/// view.borderWidth = 2.0
/// view.borderColor = UIColor.blue.cgColor
/// ```
@interface DCFView : UIView

/// Border radii properties
@property (nonatomic, assign) CGFloat borderRadius;
@property (nonatomic, assign) CGFloat borderTopLeftRadius;
@property (nonatomic, assign) CGFloat borderTopRightRadius;
@property (nonatomic, assign) CGFloat borderBottomLeftRadius;
@property (nonatomic, assign) CGFloat borderBottomRightRadius;

/// Border color properties (retained)
@property (nonatomic, assign) CGColorRef borderColor;
@property (nonatomic, assign) CGColorRef borderTopColor;
@property (nonatomic, assign) CGColorRef borderRightColor;
@property (nonatomic, assign) CGColorRef borderBottomColor;
@property (nonatomic, assign) CGColorRef borderLeftColor;

/// Border width properties
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGFloat borderTopWidth;
@property (nonatomic, assign) CGFloat borderRightWidth;
@property (nonatomic, assign) CGFloat borderBottomWidth;
@property (nonatomic, assign) CGFloat borderLeftWidth;

/// Border style: 'solid', 'dotted', or 'dashed'
@property (nonatomic, assign) NSString *borderStyle;

/// Background color (stored separately from UIView.backgroundColor for border rendering)
@property (nonatomic, strong, nullable) UIColor *dcfBackgroundColor;

/// Shadow properties (directly mapped to layer properties)
@property (nonatomic, assign) CGColorRef shadowColor;
@property (nonatomic, assign) CGFloat shadowOpacity;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) CGSize shadowOffset;

/// Elevation (Android Material Design, converted to shadow on iOS)
@property (nonatomic, assign) CGFloat elevation;

/// Opacity (directly mapped to UIView.alpha)
@property (nonatomic, assign) CGFloat opacity;

@end

NS_ASSUME_NONNULL_END
