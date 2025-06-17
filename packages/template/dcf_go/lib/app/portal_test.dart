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
        // Header
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

        // Primary Portal Target Container
        DCFText(
          content: "Primary Portal Target",
          textProps: DCFTextProps(fontSize: 18, fontWeight: "600"),
          layout: LayoutProps(marginBottom: 8, height: 25),
        ),
        
        DCFPortalTarget(
          targetId: 'primary-portal',
          children: [
            DCFView(
              layout: LayoutProps(
                height: 120,
                padding: 16,
                marginBottom: 16,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.lightBlue,
                borderRadius: 8,
                borderWidth: 2,
                borderColor: Colors.blue,
              ),
              children: [
                DCFText(
                  content: "Primary Portal Container",
                  textProps: DCFTextProps(fontSize: 16, fontWeight: "600"),
                  layout: LayoutProps(marginBottom: 8, height: 25),
                ),
                DCFText(
                  content: "Portal content will appear here when activated.",
                  textProps: DCFTextProps(fontSize: 14),
                  layout: LayoutProps(height: 40),
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
          layout: LayoutProps(marginBottom: 24, height: 44),
          styleSheet: StyleSheet(
            backgroundColor: showPortal.state ? Colors.red : Colors.green,
            borderRadius: 8,
          ),
          onPress: (v) {
            showPortal.setState(!showPortal.state);
          },
        ),

        // Secondary Portal Target Container  
        DCFText(
          content: "Secondary Portal Target",
          textProps: DCFTextProps(fontSize: 18, fontWeight: "600"),
          layout: LayoutProps(marginBottom: 8, height: 25),
        ),
        
        DCFPortalTarget(
          targetId: 'secondary-portal',
          children: [
            DCFView(
              layout: LayoutProps(
                height: 100,
                padding: 16,
                marginBottom: 24,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.orange,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: "Secondary Portal Container",
                  textProps: DCFTextProps(fontSize: 16, fontWeight: "600", color: Colors.white),
                  layout: LayoutProps(marginBottom: 8, height: 25),
                ),
                DCFText(
                  content: "Multiple notifications will appear here.",
                  textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                  layout: LayoutProps(height: 40),
                ),
              ],
            ),
          ],
        ),

        // Status Text - Always visible
        DCFText(
          content: showPortal.state ? "Portal Status: ACTIVE ✅" : "Portal Status: INACTIVE ❌",
          textProps: DCFTextProps(
            fontSize: 16, 
            fontWeight: "600",
            color: showPortal.state ? Colors.green : Colors.red,
          ),
          layout: LayoutProps(marginBottom: 16, height: 25),
        ),

        // Features Info - Always visible
        DCFText(
          content: "Portal Features:\n"
          "• Render content outside normal hierarchy\n"
          "• Multiple portals per target\n"
          "• Priority-based rendering\n"
          "• React-like API\n"
          "• Dynamic creation/cleanup",
          textProps: DCFTextProps(fontSize: 14),
          layout: LayoutProps(marginBottom: 32, height: 120),
        ),

        // Portal Components - Conditionally rendered but in dedicated container
        DCFView(
          layout: LayoutProps(height: showPortal.state ? 100 : 0),
          children: showPortal.state ? [
            // Primary portal content
            DCFPortal(
              targetId: 'primary-portal',
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
                      content: "🎯 Portaled Content!",
                      textProps: DCFTextProps(fontSize: 16, fontWeight: "600", color: Colors.white),
                      layout: LayoutProps(marginBottom: 8, height: 25),
                    ),
                    DCFText(
                      content: "This appears in the primary container above through a portal.",
                      textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                      layout: LayoutProps(height: 40),
                    ),
                  ],
                ),
              ],
            ),

            // High priority notification
            DCFPortal(
              targetId: 'secondary-portal',
              priority: 1, // Higher priority
              children: [
                DCFView(
                  layout: LayoutProps(
                    padding: 12,
                    marginTop: 8,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.red,
                    borderRadius: 4,
                  ),
                  children: [
                    DCFText(
                      content: "� High Priority Alert",
                      textProps: DCFTextProps(fontSize: 14, fontWeight: "600", color: Colors.white),
                      layout: LayoutProps(height: 25),
                    ),
                  ],
                ),
              ],
            ),

            // Lower priority notification
            DCFPortal(
              targetId: 'secondary-portal',
              priority: 0, // Lower priority (appears first)
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
                      content: "ℹ️ Info Notification",
                      textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                      layout: LayoutProps(height: 25),
                    ),
                  ],
                ),
              ],
            ),
          ] : [],
        ),
      ],
    );
  }
}
