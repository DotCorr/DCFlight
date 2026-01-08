/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Corner Radius Examples
/// Demonstrates corner radius StyleSheet properties
class CornerRadiusExamples extends DCFStatelessComponent {
  CornerRadiusExamples({super.key});

  static final styles = DCFStyleSheet.create({
    'box': DCFStyleSheet(
      backgroundColor: DCFColors.blue500,
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
      marginBottom: 16,
    ),
  });

  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray100),
      children: [
        DCFText(
          content: 'Corner Radius Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates corner radius StyleSheet properties',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        // Uniform Border Radius
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Uniform Border Radius',
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
                    borderRadius: 0,
                  ),
                  children: [
                    DCFText(
                      content: '0',
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
                  ),
                  children: [
                    DCFText(
                      content: '8',
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
                    borderRadius: 16,
                  ),
                  children: [
                    DCFText(
                      content: '16',
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
                    borderRadius: 60,
                  ),
                  children: [
                    DCFText(
                      content: '60',
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
              layout: DCFLayout(
                width: 200,
                height: 120,
                padding: 16,
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
                marginBottom: 16,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.green500,
                borderTopLeftRadius: 20,
                borderTopRightRadius: 8,
                borderBottomLeftRadius: 8,
                borderBottomRightRadius: 20,
              ),
              children: [
                DCFText(
                  content: 'Top: 20/8\nBottom: 8/20',
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

        // Pill Shape
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Pill Shape (Full Radius)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                width: 200,
                height: 60,
                padding: 16,
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
                marginBottom: 16,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.purple500,
                borderRadius: 50,
              ),
              children: [
                DCFText(
                  content: 'Pill Button',
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

        // Rounded with Border
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Rounded with Border',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                width: 150,
                height: 150,
                padding: 16,
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
                marginBottom: 16,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.orange500,
                borderRadius: 16,
                borderWidth: 4,
                borderColor: DCFColors.white,
              ),
              children: [
                DCFText(
                  content: 'Rounded\nBorder',
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
