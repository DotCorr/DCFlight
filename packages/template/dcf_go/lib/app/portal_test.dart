/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

class PortalTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final showPortal = useState<bool>(false, 'showPortal');

    return DCFScrollView(
      layout: LayoutProps(flex: 1, padding: 16),
      children: [
        DCFText(
          content: "Portal System Test",
          textProps: DCFTextProps(fontSize: 24, fontWeight: "bold"),
          layout: LayoutProps(marginBottom: 16, height: 30),
        ),
        
        DCFText(
          content: "React-like Portal System\n"
          "Portals provide a way to render children into a DOM node "
          "that exists outside the parent component's DOM hierarchy.",
          textProps: DCFTextProps(fontSize: 16),
          layout: LayoutProps(marginBottom: 24, height: 80),
        ),

        // Portal Target Container
        DCFPortalTarget(
          targetId: 'modal-root',
          children: [
            DCFView(
              layout: LayoutProps(
                height: 200,
                padding: 16,
                marginBottom: 24,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.lightBlue,
                borderRadius: 8,
                borderWidth: 2,
                borderColor: Colors.blue,
              ),
              children: [
                DCFText(
                  content: "Portal Target Container",
                  textProps: DCFTextProps(fontSize: 18, fontWeight: "600"),
                  layout: LayoutProps(marginBottom: 8, height: 25),
                ),
                DCFText(
                  content: "This container will receive portal content when the portal is active.",
                  textProps: DCFTextProps(fontSize: 14),
                  layout: LayoutProps(marginBottom: 16, height: 40),
                ),
                DCFText(
                  content: "Portal content will appear below this text.",
                  textProps: DCFTextProps(fontSize: 12),
                  layout: LayoutProps(height: 20),
                ),
              ],
            ),
          ],
        ),

        // Controls
        DCFButton(
          buttonProps: DCFButtonProps(
            title: showPortal.state ? "Hide Portal Content" : "Show Portal Content",
          ),
          layout: LayoutProps(marginBottom: 16, height: 44),
          styleSheet: StyleSheet(
            backgroundColor: Colors.green,
            borderRadius: 8,
          ),
          onPress: (v) {
            showPortal.setState(!showPortal.state);
          },
        ),

        // Portal Example
        if (showPortal.state) 
          DCFPortal(
            targetId: 'modal-root',
            children: [
              DCFView(
                layout: LayoutProps(
                  padding: 16,
                  marginTop: 8,
                ),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.purple,
                  borderRadius: 8,
                ),
                children: [
                  DCFText(
                    content: "🎯 Portal Content!",
                    textProps: DCFTextProps(fontSize: 16, fontWeight: "600", color: Colors.white),
                    layout: LayoutProps(marginBottom: 8, height: 25),
                  ),
                  DCFText(
                    content: "This content is rendered through a portal into the target container above, "
                    "even though it's defined down here in the component tree.",
                    textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                    layout: LayoutProps(height: 60),
                  ),
                ],
              ),
            ],
          ),

        // Multiple Portals Example
        DCFText(
          content: "Multiple Portals Example",
          textProps: DCFTextProps(fontSize: 20, fontWeight: "600"),
          layout: LayoutProps(marginBottom: 16, marginTop: 32, height: 30),
        ),

        // Second Portal Target
        DCFPortalTarget(
          targetId: 'notifications-root',
          children: [
            DCFView(
              layout: LayoutProps(
                height: 150,
                padding: 16,
                marginBottom: 24,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.orange,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: "Notifications Portal Target",
                  textProps: DCFTextProps(fontSize: 16, fontWeight: "600", color: Colors.white),
                  layout: LayoutProps(marginBottom: 8, height: 25),
                ),
                DCFText(
                  content: "Multiple portal content will appear here:",
                  textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                  layout: LayoutProps(height: 40),
                ),
              ],
            ),
          ],
        ),

        // Multiple portals to the same target
        if (showPortal.state) ...[
          DCFPortal(
            targetId: 'notifications-root',
            priority: 1,
            children: [
              DCFView(
                layout: LayoutProps(
                  padding: 12,
                  marginTop: 8,
                ),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.green,
                  borderRadius: 4,
                ),
                children: [
                  DCFText(
                    content: "📨 High Priority Notification",
                    textProps: DCFTextProps(fontSize: 14, fontWeight: "600", color: Colors.white),
                    layout: LayoutProps(height: 25),
                  ),
                ],
              ),
            ],
          ),
          
          DCFPortal(
            targetId: 'notifications-root',
            priority: 0,
            children: [
              DCFView(
                layout: LayoutProps(
                  padding: 12,
                  marginTop: 4,
                ),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.cyan,
                  borderRadius: 4,
                ),
                children: [
                  DCFText(
                    content: "ℹ️ Normal Priority Notification",
                    textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                    layout: LayoutProps(height: 25),
                  ),
                ],
              ),
            ],
          ),
        ],

        DCFText(
          content: "Features Demonstrated:\n"
          "• Portal rendering outside component hierarchy\n"
          "• Multiple portals per target\n"
          "• Portal priority system\n"
          "• Dynamic portal creation/destruction\n"
          "• React-like portal API",
          textProps: DCFTextProps(fontSize: 14),
          layout: LayoutProps(marginTop: 32, height: 120),
        ),
      ],
    );
  }
}
