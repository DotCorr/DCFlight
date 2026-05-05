/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library dcf_platform_view;

import 'package:flutter/widgets.dart';
import 'src/dcf_pipeline.dart';
import 'src/dcf_surface_manager.dart';
import 'src/dcf_platform_view_widget.dart';

export 'src/dcf_pipeline.dart' show DCFPipeline, kDCFSurfaceViewType;
export 'src/dcf_surface_manager.dart' show DCFSurfaceManager;
export 'src/dcf_platform_view_widget.dart' show DCFSurfaceScope, DCFPlatformView;

/// Runs a Flutter app with the DCF pipeline. Use this instead of [runApp] when
/// you want full control and to use [DCFPlatformView] (single shared surface).
///
/// The pipeline:
/// - Wraps your [app] in [DCFPipeline] (single platform view layer + scope).
/// - Any [DCFPlatformView] in your tree registers its rect with [DCFSurfaceManager].
/// - One native view is shown at the union of all DCFPlatformView rects.
///
/// Example:
/// ```dart
/// void main() {
///   runDCFApp(MyApp());
/// }
///
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: Scaffold(
///         body: DCFPlatformView(), // placeholder; real view is one shared surface
///       ),
///     );
///   }
/// }
/// ```
void runDCFApp(Widget app) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DCFPipeline(child: app));
}
