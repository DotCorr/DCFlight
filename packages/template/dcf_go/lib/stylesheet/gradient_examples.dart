/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Gradient Examples
/// Demonstrates background gradient StyleSheet properties
class GradientExamples extends DCFStatelessComponent {
  GradientExamples({super.key});

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
    'gradientBox': DCFLayout(
      padding: 16,
      marginBottom: 16,
      minHeight: 100,
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
          content: 'Gradient Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates background gradient StyleSheet properties',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        // Linear Gradient - Vertical
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Linear Gradient - Vertical (Top to Bottom)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['gradientBox']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [DCFColors.blue500, DCFColors.purple500],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 0.0,
                  endY: 1.0,
                ),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Blue to Purple (Vertical)',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Linear Gradient - Horizontal
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Linear Gradient - Horizontal (Left to Right)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['gradientBox']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [DCFColors.green500, DCFColors.yellow500],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 1.0,
                  endY: 0.0,
                ),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Green to Yellow (Horizontal)',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Linear Gradient - Diagonal
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Linear Gradient - Diagonal',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['gradientBox']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [DCFColors.red500, DCFColors.orange500],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 1.0,
                  endY: 1.0,
                ),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Red to Orange (Diagonal)',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Radial Gradient
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Radial Gradient',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['gradientBox']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.radial(
                  colors: [DCFColors.purple500, DCFColors.blue500],
                  centerX: 0.5,
                  centerY: 0.5,
                  radius: 0.5,
                ),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Purple to Blue (Radial)',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Gradient with Multiple Colors
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Multi-Color Gradient',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['gradientBox']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [
                    DCFColors.red500,
                    DCFColors.orange500,
                    DCFColors.yellow500,
                    DCFColors.green500,
                    DCFColors.blue500,
                  ],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 1.0,
                  endY: 0.0,
                ),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'Rainbow Gradient',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        // Gradient with Corner Radius
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Gradient with Rounded Corners',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['gradientBox']!,
              styleSheet: DCFStyleSheet(
                backgroundGradient: DCFGradient.linear(
                  colors: [DCFColors.indigo, DCFColors.blue500],
                  startX: 0.0,
                  startY: 0.0,
                  endX: 0.0,
                  endY: 1.0,
                ),
                borderRadius: 20,
              ),
              children: [
                DCFText(
                  content: 'Indigo to Blue (Rounded)',
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
