/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:developer' as developer;

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/components/button_component.dart';
import 'package:flutter/material.dart' show Colors;

/// Framework-level error boundary that automatically wraps the root component
/// This provides React Native-style crash protection without requiring developers
/// to manually wrap their app components
class RootErrorBoundary extends ErrorBoundary {
  final DCFComponentNode _app;
  
  RootErrorBoundary(this._app, {super.key});

  @override
  DCFComponentNode renderContent() {
    // Wrap app in a DCFView with flex: 1 to ensure it fills the parent
    // This prevents white screen issues when the root view doesn't have proper layout
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        width: '100%',
        height: '100%',
      ),
      children: [_app],
    );
  }

  @override
  DCFComponentNode renderFallback(Object error, StackTrace? stackTrace) {
    developer.log('RootErrorBoundary: Rendering fallback UI for error: $error',
        name: 'RootErrorBoundary', error: error, stackTrace: stackTrace);
    
    // Render a simple error UI instead of crashing
    // Using framework-level components (Button and TouchableOpacity are now in framework)
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        justifyContent: DCFJustifyContent.center,
        alignItems: DCFAlign.center,
        paddingHorizontal: 24,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.white),
      children: [
        DCFText(
          content: "Something went wrong",
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          styleSheet: DCFStyleSheet(primaryColor: Colors.red),
        ),
        DCFView(
          layout: DCFLayout(marginTop: 16),
          children: [
            DCFText(
              content: error.toString(),
              textProps: DCFTextProps(
                fontSize: 14,
                numberOfLines: 10,
              ),
              styleSheet: DCFStyleSheet(primaryColor: Colors.grey[600]!),
            ),
          ],
        ),
        DCFView(
          layout: DCFLayout(marginTop: 24),
          children: [
            DCFButton(
              onPress: (DCFButtonPressData data) {
                resetError();
              },
              layout: DCFLayout(
                paddingHorizontal: 24,
                paddingVertical: 12,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: Colors.blue,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: "Try Again",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    fontWeight: DCFFontWeight.medium,
                  ),
                  styleSheet: DCFStyleSheet(primaryColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
