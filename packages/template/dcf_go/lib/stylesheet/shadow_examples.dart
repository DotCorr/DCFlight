/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Shadow Examples
/// Demonstrates shadow-related StyleSheet properties
class ShadowExamples extends DCFStatelessComponent {
  ShadowExamples({super.key});

  static final styles = DCFStyleSheet.create({
    'subtleShadow': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
      shadowColor: DCFColors.black,
      shadowOpacity: 0.05,
      shadowRadius: 4,
      shadowOffsetX: 0,
      shadowOffsetY: 1,
    ),
    'mediumShadow': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
      shadowColor: DCFColors.black,
      shadowOpacity: 0.15,
      shadowRadius: 8,
      shadowOffsetX: 0,
      shadowOffsetY: 2,
    ),
    'strongShadow': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
      shadowColor: DCFColors.black,
      shadowOpacity: 0.3,
      shadowRadius: 12,
      shadowOffsetX: 0,
      shadowOffsetY: 4,
    ),
    'coloredShadow': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
      shadowColor: DCFColors.blue500,
      shadowOpacity: 0.2,
      shadowRadius: 8,
      shadowOffsetX: 0,
      shadowOffsetY: 2,
    ),
    'offsetShadow': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
      shadowColor: DCFColors.black,
      shadowOpacity: 0.2,
      shadowRadius: 8,
      shadowOffsetX: 4,
      shadowOffsetY: 4,
    ),
    'elevation': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
      elevation: 8,
    ),
  });

  static final layouts = DCFLayout.create({
    'container': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      // CRITICAL: Don't set padding here - parent wrapper already provides padding
      // Setting padding here causes double padding (40px total on each side)
      width: '100%',
    ),
    'section': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      marginBottom: 24,
    ),
    'card': DCFLayout(
      padding: 16,
      marginBottom: 16,
    ),
  });

  @override
  DCFComponentNode render() {
    // CRITICAL: Don't use DCFScrollView here - parent StyleSheetExamplesScreen already has a ScrollView
    // Just return the content directly to avoid nested ScrollViews
    return DCFView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray100),
      children: [
        DCFText(
          content: 'Shadow Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates shadow-related StyleSheet properties',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Subtle Shadow (opacity: 0.05, radius: 4)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['subtleShadow']!,
              children: [
                DCFText(
                  content: 'Used for cards and subtle elevation',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Medium Shadow (opacity: 0.15, radius: 8)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['mediumShadow']!,
              children: [
                DCFText(
                  content: 'Standard card shadow',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Strong Shadow (opacity: 0.3, radius: 12)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['strongShadow']!,
              children: [
                DCFText(
                  content: 'Prominent elevation',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Colored Shadow (blue)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['coloredShadow']!,
              children: [
                DCFText(
                  content: 'Custom shadow color',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Offset Shadow (offsetX: 4, offsetY: 4)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['offsetShadow']!,
              children: [
                DCFText(
                  content: 'Shadow with custom offset',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Elevation (elevation: 8)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['elevation']!,
              children: [
                DCFText(
                  content: 'Using elevation property (Android Material Design)',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
