/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Border Examples
/// Demonstrates all border-related StyleSheet properties
class BorderExamples extends DCFStatelessComponent {
  BorderExamples({super.key});

  // Reusable styles using StyleSheet.create()
  static final styles = DCFStyleSheet.create({
    'container': DCFStyleSheet(
      backgroundColor: DCFColors.white,
      borderRadius: 8,
    ),
    'uniformBorder': DCFStyleSheet(
      borderWidth: 2,
      borderColor: DCFColors.blue500,
      borderRadius: 8,
      backgroundColor: DCFColors.white,
    ),
    'individualBorders': DCFStyleSheet(
      borderTopWidth: 4,
      borderRightWidth: 2,
      borderBottomWidth: 4,
      borderLeftWidth: 2,
      borderTopColor: DCFColors.red500,
      borderRightColor: DCFColors.green500,
      borderBottomColor: DCFColors.blue500,
      borderLeftColor: DCFColors.yellow500,
      borderRadius: 8,
      backgroundColor: DCFColors.white,
    ),
    'bottomBorderOnly': DCFStyleSheet(
      borderBottomWidth: 2,
      borderBottomColor: DCFColors.gray300,
      backgroundColor: DCFColors.white,
    ),
    'roundedCorners': DCFStyleSheet(
      borderWidth: 2,
      borderColor: DCFColors.purple500,
      borderRadius: 20,
      backgroundColor: DCFColors.white,
    ),
    'individualCornerRadius': DCFStyleSheet(
      borderWidth: 2,
      borderColor: DCFColors.orange500,
      borderTopLeftRadius: 20,
      borderTopRightRadius: 8,
      borderBottomLeftRadius: 8,
      borderBottomRightRadius: 20,
      backgroundColor: DCFColors.white,
    ),
  });

  // Reusable layouts
  static final layouts = DCFLayout.create({
    'container': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      padding: 20,
    ),
    'section': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      marginBottom: 24,
    ),
    'row': DCFLayout(
      flexDirection: DCFFlexDirection.row,
      gap: 12,
      flexWrap: DCFWrap.wrap,
    ),
    'column': DCFLayout(
      flexDirection: DCFFlexDirection.column,
      gap: 12,
    ),
    'card': DCFLayout(
      padding: 16,
      marginBottom: 12,
    ),
  });

  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray100),
      children: [
        DCFText(
          content: 'Border Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates all border-related StyleSheet properties',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        // Uniform Border
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Uniform Border',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['uniformBorder']!,
              children: [
                DCFText(
                  content: 'borderWidth: 2, borderColor: blue, borderRadius: 8',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        // Individual Borders
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Individual Border Sides',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['individualBorders']!,
              children: [
                DCFText(
                  content: 'Top: red (4px), Right: green (2px), Bottom: blue (4px), Left: yellow (2px)',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        // Bottom Border Only (like NavigationBar)
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Bottom Border Only',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['bottomBorderOnly']!,
              children: [
                DCFText(
                  content: 'borderBottomWidth: 2, borderBottomColor: gray',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        // Rounded Corners
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Rounded Corners',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['roundedCorners']!,
              children: [
                DCFText(
                  content: 'borderRadius: 20',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
                ),
              ],
            ),
          ],
        ),

        // Individual Corner Radius
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Individual Corner Radius',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: styles['individualCornerRadius']!,
              children: [
                DCFText(
                  content: 'Top-left: 20, Top-right: 8, Bottom-left: 8, Bottom-right: 20',
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
