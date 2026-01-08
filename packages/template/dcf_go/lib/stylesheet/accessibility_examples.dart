/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Accessibility Examples
/// Demonstrates accessibility-related StyleSheet properties
class AccessibilityExamples extends DCFStatelessComponent {
  AccessibilityExamples({super.key});

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
          content: 'Accessibility Examples',
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 16),
        ),
        DCFText(
          content: 'Demonstrates accessibility-related StyleSheet properties',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 12),
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Accessible Button',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.blue500,
                borderRadius: 8,
                accessible: true,
                accessibilityLabel: 'Submit Button',
                accessibilityHint: 'Double tap to submit the form',
                accessibilityRole: 'button',
              ),
              children: [
                DCFText(
                  content: 'Submit',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Accessible Link',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.green500,
                borderRadius: 8,
                accessible: true,
                accessibilityLabel: 'Learn More Link',
                accessibilityRole: 'link',
              ),
              children: [
                DCFText(
                  content: 'Learn More',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Accessible Header',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.purple500,
                borderRadius: 8,
                accessible: true,
                accessibilityLabel: 'Section Header',
                accessibilityRole: 'header',
              ),
              children: [
                DCFText(
                  content: 'Section Title',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Accessible with State',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.orange500,
                borderRadius: 8,
                accessible: true,
                accessibilityLabel: 'Toggle Switch',
                accessibilityRole: 'button',
                accessibilityState: {
                  'selected': true,
                  'checked': true,
                },
                accessibilityValue: 'On',
              ),
              children: [
                DCFText(
                  content: 'Toggle: On',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Hidden from Accessibility',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.gray400,
                borderRadius: 8,
                accessible: false,
                accessibilityElementsHidden: true,
              ),
              children: [
                DCFText(
                  content: 'This is hidden from screen readers',
                  styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                ),
              ],
            ),
          ],
        ),

        DCFView(
          layout: layouts['section']!,
          children: [
            DCFText(
              content: 'Test ID (for testing)',
              textProps: DCFTextProps(fontSize: 16),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(marginBottom: 12),
            ),
            DCFView(
              layout: layouts['card']!,
              styleSheet: DCFStyleSheet(
                backgroundColor: DCFColors.red500,
                borderRadius: 8,
                testID: 'test-button',
              ),
              children: [
                DCFText(
                  content: 'Button with testID',
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
