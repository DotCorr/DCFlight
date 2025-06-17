/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

class PortalTestNew extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final showModal = useState<bool>(false, 'showModal');
    final showNotifications = useState<bool>(false, 'showNotifications');
    final clickCount = useState<int>(0, 'clickCount');

    return DCFScrollView(
      layout: LayoutProps(flex: 1, padding: 20),
      children: [
        // Main Header - Always Visible
        DCFText(
          content: "🚀 Portal System Demo",
          textProps: DCFTextProps(fontSize: 28, fontWeight: "bold", color: Colors.blue),
          layout: LayoutProps(marginBottom: 20, height: 35),
        ),
        
        // Description - Always Visible
        DCFText(
          content: "This demonstrates DCFlight's React-like portal system. "
          "Portals allow rendering content into different parts of the UI tree.",
          textProps: DCFTextProps(fontSize: 16, color: Color(0xFF666666)),
          layout: LayoutProps(marginBottom: 30, height: 60),
        ),
        
        // Control Buttons
        DCFView(
          layout: LayoutProps(marginBottom: 25),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(
                title: showModal.state ? "❌ Close Modal" : "📋 Open Modal Portal",
              ),
              layout: LayoutProps(marginBottom: 10, height: 50),
              styleSheet: StyleSheet(
                backgroundColor: showModal.state ? Colors.red : Colors.blue,
                borderRadius: 8,
              ),
              onPress: (v) {
                showModal.setState(!showModal.state);
                clickCount.setState(clickCount.state + 1);
              },
            ),
            
            DCFButton(
              buttonProps: DCFButtonProps(
                title: showNotifications.state ? "🔕 Hide Notifications" : "🔔 Show Notifications",
              ),
              layout: LayoutProps(height: 50),
              styleSheet: StyleSheet(
                backgroundColor: showNotifications.state ? Colors.orange : Colors.green,
                borderRadius: 8,
              ),
              onPress: (v) {
                showNotifications.setState(!showNotifications.state);
                clickCount.setState(clickCount.state + 1);
              },
            ),
          ],
        ),
        
        // Status Panel - Always Visible
        DCFView(
          layout: LayoutProps(
            marginBottom: 30,
            padding: 15,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Color(0xFFF5F5F5),
            borderRadius: 8,
          ),
          children: [
            DCFText(
              content: "📊 Current Status:",
              textProps: DCFTextProps(fontSize: 16, fontWeight: "bold"),
              layout: LayoutProps(marginBottom: 10, height: 25),
            ),
            DCFText(
              content: "• Modal Portal: ${showModal.state ? 'ACTIVE' : 'INACTIVE'}",
              textProps: DCFTextProps(fontSize: 14),
              layout: LayoutProps(marginBottom: 5, height: 20),
            ),
            DCFText(
              content: "• Notification Portals: ${showNotifications.state ? 'ACTIVE' : 'INACTIVE'}",
              textProps: DCFTextProps(fontSize: 14),
              layout: LayoutProps(marginBottom: 5, height: 20),
            ),
            DCFText(
              content: "• Button Clicks: ${clickCount.state}",
              textProps: DCFTextProps(fontSize: 14),
              layout: LayoutProps(height: 20),
            ),
          ],
        ),
        
        // Portal Target Areas
        DCFText(
          content: "📍 Portal Target Areas:",
          textProps: DCFTextProps(fontSize: 18, fontWeight: "bold"),
          layout: LayoutProps(marginBottom: 15, height: 25),
        ),
        
        // Modal Portal Target
        DCFView(
          layout: LayoutProps(
            marginBottom: 20,
            padding: 20,
            minHeight: 150, // Ensure minimum height
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.lightBlue,
            borderRadius: 8,
            borderWidth: 2,
            borderColor: Colors.blue,
          ),
          children: [
            DCFText(
              content: "Modal Area",
              textProps: DCFTextProps(fontSize: 16, fontWeight: "600", color: Colors.blue),
              layout: LayoutProps(marginBottom: 10, height: 25),
            ),
            DCFPortalTarget(
              targetId: 'modal-overlay',
              children: [
                DCFText(
                  content: "(Modal portal content will appear here when active)",
                  textProps: DCFTextProps(fontSize: 12, color: Color(0xFF999999)),
                  layout: LayoutProps(height: 20),
                ),
              ],
            ),
          ],
        ),
        
        // Notification Portal Target
        DCFView(
          layout: LayoutProps(
            marginBottom: 30,
            padding: 20,
            minHeight: 150, // Ensure minimum height
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.lightGreen,
            borderRadius: 8,
            borderWidth: 2,
            borderColor: Colors.green,
          ),
          children: [
            DCFText(
              content: "Notification Area",
              textProps: DCFTextProps(fontSize: 16, fontWeight: "600", color: Colors.green),
              layout: LayoutProps(marginBottom: 10, height: 25),
            ),
            DCFPortalTarget(
              targetId: 'notification-area',
              children: [
                DCFText(
                  content: "(Notification portals will appear here when active)",
                  textProps: DCFTextProps(fontSize: 12, color: Color(0xFF999999)),
                  layout: LayoutProps(height: 20),
                ),
              ],
            ),
          ],
        ),
        
        // Footer - Always Visible
        DCFText(
          content: "✨ This text always stays visible! "
          "The portal system allows content to be rendered in specific target areas "
          "without affecting the main component tree structure.",
          textProps: DCFTextProps(fontSize: 14, color: Color(0xFF999999)),
          layout: LayoutProps(marginTop: 20, height: 60),
        ),
        
        // Conditional Portal Content (Rendered at bottom but appears in targets above)
        ...renderPortalContent(showModal.state, showNotifications.state, clickCount.state),
      ],
    );
  }
  
  // Helper method to render portal content
  List<DCFComponentNode> renderPortalContent(bool showModal, bool showNotifications, int count) {
    List<DCFComponentNode> portals = [];
    
    if (showModal) {
      portals.add(
        DCFPortal(
          targetId: 'modal-overlay',
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 20,
                marginTop: 10,
                height: 100, // Explicit height
                width: 200,  // Explicit width
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.purple, // Make it very obvious
                borderRadius: 8,
                borderWidth: 3,
                borderColor: Colors.red,
              ),
              children: [
                DCFText(
                  content: "🎉 PORTAL CONTENT IS HERE!",
                  textProps: DCFTextProps(fontSize: 18, fontWeight: "bold", color: Colors.white),
                  layout: LayoutProps(marginBottom: 10, height: 25),
                ),
                DCFText(
                  content: "If you see this, portals work!",
                  textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                  layout: LayoutProps(marginBottom: 10, height: 20),
                ),
                DCFText(
                  content: "Count: $count",
                  textProps: DCFTextProps(fontSize: 12, color: Colors.white),
                  layout: LayoutProps(height: 20),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    if (showNotifications) {
      // High priority notification
      portals.add(
        DCFPortal(
          targetId: 'notification-area',
          priority: 1,
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 15,
                marginTop: 10,
                height: 40, // Explicit height
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.red,
                borderRadius: 6,
              ),
              children: [
                DCFText(
                  content: "🚨 High Priority Alert!",
                  textProps: DCFTextProps(fontSize: 14, fontWeight: "bold", color: Colors.white),
                  layout: LayoutProps(height: 20),
                ),
              ],
            ),
          ],
        ),
      );
      
      // Low priority notification
      portals.add(
        DCFPortal(
          targetId: 'notification-area',
          priority: 0,
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 15,
                marginTop: 5,
                height: 40, // Explicit height
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.cyan,
                borderRadius: 6,
              ),
              children: [
                DCFText(
                  content: "ℹ️ Info Notification - Updates: $count",
                  textProps: DCFTextProps(fontSize: 14, color: Colors.white),
                  layout: LayoutProps(height: 20),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return portals;
  }
}
