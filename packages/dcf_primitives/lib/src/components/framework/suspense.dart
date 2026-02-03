/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

/// 🎯 DCFSuspense - Conditional rendering component for lazy loading
///
/// This component allows you to suspend rendering of expensive content
/// until a condition is met, preventing unnecessary component creation
/// and lifecycle execution.
class DCFSuspense extends DCFStatelessComponent {
  /// Whether to render the children or show fallback
  final bool shouldRender;

  /// The content to render when shouldRender is true
  final DCFComponentNode Function() children;

  /// Optional fallback content when shouldRender is false
  /// If null, renders an empty DCFView
  final DCFComponentNode Function()? fallback;

  /// Optional debug name for logging
  final String? debugName;

  /// Layout properties for the container
  final DCFLayout? layout;

  /// Style sheet for the container
  final DCFStyleSheet? styleSheet;

  /// Whether to show debug logs
  final bool enableDebugLogs;

  DCFSuspense({
    super.key,
    required this.shouldRender,
    required this.children,
    this.fallback,
    this.debugName,
    this.layout,
    this.styleSheet,
    this.enableDebugLogs = true,
  });

  @override
  DCFComponentNode render() {
    final name = debugName ?? 'Unknown';

    if (shouldRender) {
      if (enableDebugLogs) {
        print("🏗️ DCFSuspense[$name]: Rendering children (active)");
      }

      return DCFView(
        layout: layout ?? DCFLayout(),
        styleSheet: styleSheet ?? DCFStyleSheet(),
        children: [children()],
      );
    } else {
      if (enableDebugLogs) {
        print("⏸️ DCFSuspense[$name]: Rendering fallback (suspended)");
      }

      if (fallback != null) {
        return DCFView(
          layout: layout ?? DCFLayout(flex: 1),
          styleSheet: styleSheet ?? DCFStyleSheet(),
          children: [fallback!()],
        );
      } else {
        return DCFView(
          layout: layout ?? DCFLayout(flex: 1),
          styleSheet: styleSheet ?? DCFStyleSheet(),
          children: [],
        );
      }
    }
  }
}
