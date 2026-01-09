/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Transform Examples
/// Demonstrates transform-related Layout properties (transforms are in DCFLayout, not StyleSheet)
class TransformExamples extends DCFStatelessComponent {
  TransformExamples({super.key});

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
      marginBottom: 32,
    ),
    'row': DCFLayout(
      flexDirection: DCFFlexDirection.row,
      gap: 20,
      flexWrap: DCFWrap.wrap,
    ),
    'box': DCFLayout(
      width: 100,
      height: 100,
      padding: 16,
      alignItems: DCFAlign.center,
      justifyContent: DCFJustifyContent.center,
    ),
  });

  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray100),
      scrollContent: [
        DCFText(
          content: 'Transform Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates transform Layout properties (rotateInDegrees, translateX/Y, scale)',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        // Rotation
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Rotation',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['row']!,
              children: [
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: styles['box']!,
                  children: [
                    DCFText(
                      content: '0°',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    rotateInDegrees: 45,
                  ),
                  styleSheet: styles['box']!,
                  children: [
                    DCFText(
                      content: '45°',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    rotateInDegrees: 90,
                  ),
                  styleSheet: styles['box']!,
                  children: [
                    DCFText(
                      content: '90°',
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

        // Translation
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Translation',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                flexDirection: DCFFlexDirection.column,
                gap: 12,
              ),
              children: [
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: styles['box']!,
                  children: [
                    DCFText(
                      content: 'Original',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    absoluteLayout: AbsoluteLayout(
                      translateX: 50,
                      translateY: 0,
                    ),
                  ),
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.green500,
                    borderRadius: 8,
                  ),
                  children: [
                    DCFText(
                      content: 'X: 50',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    absoluteLayout: AbsoluteLayout(
                      translateX: 0,
                      translateY: 50,
                    ),
                  ),
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.green500,
                    borderRadius: 8,
                  ),
                  children: [
                    DCFText(
                      content: 'Y: 50',
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

        // Scale
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Scale',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['row']!,
              children: [
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: styles['box']!,
                  children: [
                    DCFText(
                      content: '1x',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    scale: 1.5,
                  ),
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.purple500,
                    borderRadius: 8,
                  ),
                  children: [
                    DCFText(
                      content: '1.5x',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    scale: 0.5,
                  ),
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.purple500,
                    borderRadius: 8,
                  ),
                  children: [
                    DCFText(
                      content: '0.5x',
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

        // Scale X/Y
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Scale X/Y (Independent)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['row']!,
              children: [
                DCFView(
                  layout: layouts['box']!,
                  styleSheet: styles['box']!,
                  children: [
                    DCFText(
                      content: 'Normal',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    scaleX: 1.5,
                    scaleY: 1.0,
                  ),
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.orange500,
                    borderRadius: 8,
                  ),
                  children: [
                    DCFText(
                      content: 'X: 1.5',
                      textProps: DCFTextProps(
                        fontSize: 14,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                    ),
                  ],
                ),
                DCFView(
                  layout: DCFLayout(
                    width: 100,
                    height: 100,
                    padding: 16,
                    alignItems: DCFAlign.center,
                    justifyContent: DCFJustifyContent.center,
                    scaleX: 1.0,
                    scaleY: 1.5,
                  ),
                  styleSheet: DCFStyleSheet(
                    backgroundColor: DCFColors.orange500,
                    borderRadius: 8,
                  ),
                  children: [
                    DCFText(
                      content: 'Y: 1.5',
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

        // Combined Transforms
        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Combined Transforms',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: DCFLayout(
                width: 100,
                height: 100,
                padding: 16,
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
                rotateInDegrees: 45,
                scale: 1.2,
                absoluteLayout: AbsoluteLayout(
                  translateX: 20,
                  translateY: 20,
                ),
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.red500,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: 'All',
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
