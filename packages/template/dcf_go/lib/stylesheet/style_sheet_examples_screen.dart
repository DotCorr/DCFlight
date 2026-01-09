/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcf_go/stylesheet/examples_registry.dart';

/// Main StyleSheet Examples Screen
/// Displays a list of all StyleSheet examples
class StyleSheetExamplesScreen extends DCFStatelessComponent {
  final VoidCallback? onBack;
  
  StyleSheetExamplesScreen({this.onBack, super.key});

  static final layouts = DCFLayout.create({
    'container': DCFLayout(
      flex: 1,
      flexDirection: DCFFlexDirection.column,
      padding: 20,
    ),
  });

  @override
  DCFComponentNode render() {
    final exampleNames = StyleSheetExamplesRegistry.exampleNames;

    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.red),
      scrollContent: [
        // Back Button
        if (onBack != null)
          DCFTouchableOpacity(
            onPress: (data) {
              onBack?.call();
            },
            styleSheet: DCFStyleSheet(
              backgroundColor: DCFColors.blue500,
              borderRadius: 8,
            ),
            layout: DCFLayout(
              padding: 12,
              marginBottom: 16,
              alignSelf: DCFAlign.flexStart,
            ),
            children: [
              DCFText(
                content: '← Back to Landing',
                textProps: DCFTextProps(
                  fontSize: 14,
                  fontWeight: DCFFontWeight.bold,
                ),
                styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
              ),
            ],
          ),
        DCFText(
          content: 'StyleSheet Examples',
          textProps: DCFTextProps(
            fontSize: 32,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
          layout: DCFLayout(marginBottom: 8, paddingTop: 20),
        ),
        DCFText(
          content: 'Explore all StyleSheet properties and best practices',
          textProps: DCFTextProps(fontSize: 16),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
          layout: DCFLayout(marginBottom: 24, paddingHorizontal: 20),
        ),
        ...exampleNames.map((name) {
          final example = StyleSheetExamplesRegistry.getExample(name);
          if (example == null) return DCFView(layout: DCFLayout(), children: []);
          
          return example; // Render the example directly
        }).toList(),
      ],
    );
  }
}
