/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcf_go/stylesheet/border_examples.dart';
import 'package:dcf_go/stylesheet/shadow_examples.dart';
import 'package:dcf_go/stylesheet/gradient_examples.dart';
import 'package:dcf_go/stylesheet/transform_examples.dart';
import 'package:dcf_go/stylesheet/corner_radius_examples.dart';
import 'package:dcf_go/stylesheet/opacity_examples.dart';
import 'package:dcf_go/stylesheet/accessibility_examples.dart';
import 'package:dcf_go/stylesheet/comprehensive_examples.dart';
import 'package:dcflight/dcflight.dart';

/// Registry of all StyleSheet examples
/// Each example demonstrates specific StyleSheet properties and best practices
class StyleSheetExamplesRegistry {
  static final Map<String, DCFComponentNode Function()> examples = {
    'Borders': () => BorderExamples(),
    'Shadows': () => ShadowExamples(),   
    'Gradients': () => GradientExamples(),
    'Transforms': () => TransformExamples(),
    'Corner Radius': () => CornerRadiusExamples(),
    'Opacity': () => OpacityExamples(),
    'Accessibility': () => AccessibilityExamples(),
    'Comprehensive': () => ComprehensiveExamples(),
  };

  static List<String> get exampleNames => examples.keys.toList();

  static DCFComponentNode? getExample(String name) {
    final builder = examples[name];
    return builder?.call();
  }
}


