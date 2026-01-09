/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Comprehensive Examples
/// Demonstrates combining multiple StyleSheet properties
class ComprehensiveExamples extends DCFStatelessComponent {
  ComprehensiveExamples({super.key});

  static final styles = DCFStyleSheet.create({
    'card': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 12,
      shadowColor: DCFColors.black,
      shadowOpacity: 0.1,
      shadowRadius: 8,
      shadowOffsetX: 0,
      shadowOffsetY: 2,
    ),
  });

  static final layouts = DCFLayout.create({
    'container': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      padding: 20,
    ),
    'section': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      marginBottom: 24,
    ),
    'card': DCFLayout(
      padding: 20,
      marginBottom: 16,
    ),
  });

  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray100),
      scrollContent: [
        DCFText(
          content: 'Comprehensive Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates combining multiple StyleSheet properties',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        // Card with Shadow and Border
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Card with Shadow and Border',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.white,
                borderRadius: 12,
                borderWidth: 1,
                borderColor: DCFColors.gray300,
                shadowColor: DCFColors.black,
                shadowOpacity: 0.1,
                shadowRadius: 8,
                shadowOffsetX: 0,
                shadowOffsetY: 2,
              ),
              children: [
                DCFText(
                  content: 'Card Title',
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                  layout: DCFLayout(marginBottom: 8),
                ),
                DCFText(
                  content: 'This card combines border, shadow, and rounded corners for a polished look.',
                  textProps: DCFTextProps(
                    fontSize: 14,
                    lineHeight: 1.5,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray700),
                ),
              ],
            ),
          ],
        ),

        // Gradient Card with Border
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Gradient Card with Border',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [DCFColors.blue500, DCFColors.purple500],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 0.0,
                  endY: 1.0,
                ),
                borderRadius: 12,
                borderWidth: 2,
                borderColor: DCFColors.white,
                shadowColor: DCFColors.black,
                shadowOpacity: 0.2,
                shadowRadius: 12,
                shadowOffsetX: 0,
                shadowOffsetY: 4,
              ),
              children: [
                DCFText(
                  content: 'Gradient Card',
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                  layout: DCFLayout(marginBottom: 8),
                ),
                DCFText(
                  content: 'Combines gradient background, border, and shadow.',
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFColors.white,
                    opacity: 0.9,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Transformed Card
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Transformed Card',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                padding: 20,
                marginBottom: 16,
                rotateInDegrees: 5,
                scale: 1.05,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.green500,
                borderRadius: 12,
                shadowColor: DCFColors.black,
                shadowOpacity: 0.15,
                shadowRadius: 10,
                shadowOffsetX: 0,
                shadowOffsetY: 3,
              ),
              children: [
                DCFText(
                  content: 'Rotated & Scaled',
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Opacity Card
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Card with Opacity',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.orange500,
                borderRadius: 12,
                opacity: 0.8,
                borderWidth: 2,
                borderColor: DCFColors.white,
                shadowColor: DCFColors.black,
                shadowOpacity: 0.1,
                shadowRadius: 8,
                shadowOffsetX: 0,
                shadowOffsetY: 2,
              ),
              children: [
                DCFText(
                  content: 'Semi-Transparent',
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Complex Card with All Properties
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Complex Card (All Properties)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                padding: 24,
                marginBottom: 16,
                rotateInDegrees: -2,
                scale: 1.02,
              ),
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [DCFColors.red500, DCFColors.orange500],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 1.0,
                  endY: 1.0,
                ),
                borderRadius: 16,
                borderTopWidth: 4,
                borderTopColor: DCFColors.white,
                borderBottomWidth: 4,
                borderBottomColor: DCFColors.white,
                opacity: 0.95,
                shadowColor: DCFColors.black,
                shadowOpacity: 0.2,
                shadowRadius: 12,
                shadowOffsetX: 0,
                shadowOffsetY: 4,
                accessible: true,
                accessibilityLabel: 'Complex Card Example',
                accessibilityRole: 'button',
                testID: 'complex-card',
              ),
              children: [
                DCFText(
                  content: 'All-in-One Card',
                  textProps: DCFTextProps(
                    fontSize: 20,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                  layout: DCFLayout(marginBottom: 8),
                ),
                DCFText(
                  content: 'Gradient + Border + Shadow + Opacity + Transform + Accessibility',
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFColors.white,
                    opacity: 0.9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
