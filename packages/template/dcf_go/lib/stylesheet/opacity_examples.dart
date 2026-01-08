/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Opacity Examples
/// Demonstrates opacity StyleSheet property
class OpacityExamples extends DCFStatelessComponent {
  OpacityExamples({super.key});

  static final styles = DCFStyleSheet.create({
    'box': DCFStyleSheet(
      backgroundColor: DCFColors.blue500,
      borderRadius: 8,
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
    'row': DCFLayout(
      flexDirection: DCFFlexDirection.row,
      gap: 16,
      flexWrap: DCFWrap.wrap,
    ),
    'box': DCFLayout(
      width: 120,
      height: 120,
      padding: 16,
      alignItems: DCFAlign.center,
      justifyContent: DCFJustifyContent.center,
    ),
  });

  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.gray100,
        backgroundGradient: DCFGradient.linear(
          colors: [DCFColors.gray200, DCFColors.gray100],
          startX: 0.0,
          startY: 0.0,
          endX: 0.0,
          endY: 1.0,
        ),
      ),
      children: [
        DCFText(
          content: 'Opacity Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates opacity StyleSheet property (0.0 to 1.0)',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Opacity Levels',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['row']!,
              children: [
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.blue500,
                    borderRadius: 8,
                    opacity: 1.0,
                  ),
                  children: [
                    DCFText(
                      content: '1.0',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.blue500,
                    borderRadius: 8,
                    opacity: 0.75,
                  ),
                  children: [
                    DCFText(
                      content: '0.75',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.blue500,
                    borderRadius: 8,
                    opacity: 0.5,
                  ),
                  children: [
                    DCFText(
                      content: '0.5',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.blue500,
                    borderRadius: 8,
                    opacity: 0.25,
                  ),
                  children: [
                    DCFText(
                      content: '0.25',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Opacity with Different Colors',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['row']!,
              children: [
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.red500,
                    borderRadius: 8,
                    opacity: 0.5,
                  ),
                  children: [
                    DCFText(
                      content: 'Red 0.5',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.green500,
                    borderRadius: 8,
                    opacity: 0.5,
                  ),
                  children: [
                    DCFText(
                      content: 'Green 0.5',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.purple500,
                    borderRadius: 8,
                    opacity: 0.5,
                  ),
                  children: [
                    DCFText(
                      content: 'Purple 0.5',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Opacity with Border',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                width: 200,
                height: 120,
                padding: 16,
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.orange500,
                borderRadius: 8,
                borderWidth: 4,
                borderColor: DCFColors.white,
                opacity: 0.6,
              ),
              children: [
                DCFText(
                  content: 'Opacity 0.6\nwith Border',
                  textProps: DCFTextProps(
                    fontSize: 14,
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
