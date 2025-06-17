/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

class SimplePortalTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final showPortal = useState<bool>(false, 'showPortal');
    
    return DCFView(
      layout: LayoutProps(flex: 1, padding: 20),
      children: [
        DCFText(
          content: "Simple Portal Test",
          textProps: DCFTextProps(fontSize: 24, fontWeight: "bold"),
          layout: LayoutProps(marginBottom: 20, height: 30),
        ),
        
        DCFButton(
          buttonProps: DCFButtonProps(
            title: showPortal.state ? "Hide Portal" : "Show Portal",
          ),
          layout: LayoutProps(marginBottom: 20, height: 50),
          styleSheet: StyleSheet(
            backgroundColor: showPortal.state ? Colors.red : Colors.blue,
          ),
          onPress: (v) {
            showPortal.setState(!showPortal.state);
          },
        ),
        
        DCFText(
          content: "Portal Target Below:",
          textProps: DCFTextProps(fontSize: 16),
          layout: LayoutProps(marginBottom: 10, height: 20),
        ),
        
        DCFPortalTarget(
          targetId: 'simple-target',
          children: [
            DCFText(
              content: "Default content (portal content will replace this)",
              textProps: DCFTextProps(fontSize: 14),
              layout: LayoutProps(height: 100), // Give it explicit height
            ),
          ],
        ),
        
        // Always render portal, but conditionally render its children
        DCFPortal(
          key: 'simple-portal', // Add a key to maintain identity
          targetId: 'simple-target',
          children: showPortal.state ? [
            DCFText(
              content: "🎉 PORTAL CONTENT WORKS!",
              textProps: DCFTextProps(fontSize: 18, fontWeight: "bold", color: Colors.green),
              layout: LayoutProps(height: 100),
            ),
          ] : [], // Empty children when hidden
        ),
      ],
    );
  }
}
