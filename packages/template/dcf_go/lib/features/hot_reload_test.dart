/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/devtools/hot_reload.dart';

/// Simple test component to demonstrate hot reload functionality
class HotReloadTestScreen extends DCFStatefulComponent {
  @override
  List<Object?> get props => [];

  @override
  DCFComponentNode render() {
    final counter = useState<int>(0);

    return DCFView(
      layout: DCFLayout(
        flex: 1,
        padding: 20,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
        gap: 20,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.grey.shade100),
      children: [
        DCFText(
          content: "🔥 Hot Reload Test (AUTO WATCHER ACTIVE!)",
          textProps: DCFTextProps(
            fontSize: 28,
            fontWeight: DCFFontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),

        DCFText(
          content:
              "Current Status: Manual trigger only\nChange this color and click 'Test Hot Reload'!",
          textProps: DCFTextProps(
            fontSize: 16,
            textAlign: DCFTextAlign.center,
            color: Colors.grey.shade700,
          ),
        ),

        DCFView(
          layout: DCFLayout(height: 250, padding: 20, gap: 12),
          styleSheet: DCFStyleSheet(
            backgroundColor: Colors.white,
            borderRadius: 12,
            borderWidth: 1,
            borderColor: Colors.grey.shade300,
          ),
          children: [
            DCFText(
              content: "Counter: ${counter.state}",
              textProps: DCFTextProps(
                fontSize: 24,
                fontWeight: DCFFontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),

            DCFButton(
              buttonProps: DCFButtonProps(title: "Increment"),
              styleSheet: DCFStyleSheet(
                backgroundColor: Colors.blue,
                borderRadius: 8,
              ),
              onPress: (_) {
                counter.setState(counter.state + 1);
              },
            ),

            // DCFButton(
            //   buttonProps: DCFButtonProps(title: "Reset"),
            //   styleSheet: StyleSheet(
            //     backgroundColor: Colors.orange,
            //     borderRadius: 8,
            //   ),
            //   onPress: (_) {
            //     counter.setState(0);
            //   },
            // ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "🔄 Test Hot Reload"),
              styleSheet: DCFStyleSheet(
                backgroundColor: Colors.green,
                borderRadius: 8,
              ),
              onPress: (_) {
                // Trigger manual hot reload for testing
                triggerManualHotReload();
              },
            ),
          ],
        ),

        DCFText(
          content:
              "Manual Hot Reload Test:\n1. Click buttons to change counter state\n2. Modify this text or background color\n3. Click 'Test Hot Reload' button\n4. State persists, UI updates with changes!",
          textProps: DCFTextProps(
            fontSize: 14,
            textAlign: DCFTextAlign.center,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
