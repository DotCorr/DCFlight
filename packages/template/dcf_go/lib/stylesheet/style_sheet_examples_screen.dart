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
      padding: 20,
    ),
  });
    final exampleNames = StyleSheetExamplesRegistry.exampleNames;
  @override
  DCFComponentNode render() {


    return DCFScrollView(
      layout: layouts['container']!,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.cyan),
      scrollContent: [
       
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
