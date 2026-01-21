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

  
  StyleSheetExamplesScreen({super.key});

  static final layouts = DCFLayout.create({
    'container': DCFLayout(
      flex: 1,
      flexDirection: DCFFlexDirection.column,
      // CRITICAL: Don't set padding on ScrollView - it causes content to not fill width
      // Padding should be on the content wrapper instead
    ),
    'contentWrapper': DCFLayout(
      // Don't set width: '100%' - flex children in column naturally fill width
      // Setting width with padding can cause layout issues
      flexDirection: DCFFlexDirection.column,
      padding: 20,
    ),
  });
    final exampleNames = StyleSheetExamplesRegistry.exampleNames;
  @override
  DCFComponentNode render() {


    return DCFScrollView(
      layout: layouts['container'],
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.cyan),
      scrollContent: [
        // Wrap all content in a container with padding to ensure it fills width properly
        DCFView(
          layout: layouts['contentWrapper'],
          children: [
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
              layout: DCFLayout(marginBottom: 24),
            ),
            ...exampleNames.map((name) {
              final example = StyleSheetExamplesRegistry.getExample(name);
              if (example == null) return DCFView(layout: DCFLayout(), children: []);
              
              return example; // Render the example directly
            }).toList(),
          ],
        ),
      ],
    );
  }
}
