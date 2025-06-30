import 'package:dcf_go/app/app.dart';
import 'package:dcf_go/app/examples/modal_test.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyApp());
}

class MyApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final currentTab = useState<int>(0);
    final navigationDemoCommand = useState<ScreenNavigationCommand?>(null);
    final detailScreenCommand = useState<ScreenNavigationCommand?>(null);
    final deepScreenCommand = useState<ScreenNavigationCommand?>(null);
    final modalScreenCommand = useState<ScreenNavigationCommand?>(null);

    return DCFFragment(
      children: [
        // ✅ FIXED: Create all tab screen containers (for tab bar configuration)
        // But only add children to the active tab
        DCFScreen(
          name: "test_home",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfigSVG.withSVGPackage(
            title: "Home",
            package: "dcf_primitives",
            iconName: DCFIcons.house,
            index: 0,
            size: 24.0,
            tintColor: Colors.blue,
          ),
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          onActivate: (data) => print("🟢 Home screen activated: $data"),
          // Only add children if this is the active tab
          children: currentTab.state == 0 ? [App()] : [],
        ),

        DCFScreen(
          name: "test_profile",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfigSVG.withSVGPackage(
            title: "Profile",
            package: "dcf_primitives",
            iconName: DCFIcons.accessibility,
            index: 1,
            size: 24.0,
          ),
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          onActivate: (data) => print("🟢 Profile screen activated: $data"),
          // Only add children if this is the active tab
          children: currentTab.state == 1 ? [ModalTest()] : [],
        ),

        DCFScreen(
          name: "navigation_demo",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfig(title: "Navigation", icon: "square.stack", index: 2),
          navigationCommand: navigationDemoCommand.state,
          onAppear: (data) => print("✅ Navigation demo screen appeared: $data"),
          onActivate: (data) => print("🟢 Navigation demo screen activated: $data"),
          onNavigationEvent: (data) {
            print("🚀 Navigation demo navigation event: $data");
            navigationDemoCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Navigation demo received params: $data"),
          // Only add children if this is the active tab
          children: currentTab.state == 2 ? [
            DCFView(
              layout: LayoutProps(
                flex: 1,
                padding: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                gap: 20,
              ),
              children: [
                DCFText(
                  content: "Navigation Demo",
                  textProps: DCFTextProps(
                    fontSize: 28,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                DCFText(
                  content: "Test push navigation with screen commands:",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Push to Detail Screen"),
                  layout: LayoutProps(height: 50, width: 250),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.blue,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    navigationDemoCommand.setState(ScreenNavigationCommand(
                      pushTo: PushToScreenCommand(
                        screenName: "detail_screen",
                        params: {"from": "navigation_demo", "timestamp": DateTime.now().toString()}
                      )
                    ));
                  },
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Present Modal Screen"),
                  layout: LayoutProps(height: 50, width: 250),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.green,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    navigationDemoCommand.setState(ScreenNavigationCommand(
                      presentModal: PresentModalCommand(
                        screenName: "modal_screen",
                        presentationStyle: "pageSheet",
                        params: {"modalType": "demo"}
                      )
                    ));
                  },
                ),
              ],
            ),
          ] : [],
        ),

        DCFScreen(
          name: "test_gh",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfig(title: "Github", icon: "lightbulb", index: 3),
          onAppear: (data) => print("✅ Github screen appeared: $data"),
          onActivate: (data) => print("🟢 Github screen activated: $data"),
          // Only add children if this is the active tab
          children: currentTab.state == 3 ? [
            DCFView(
              layout: LayoutProps(flex: 1),
              children: [
                DCFWebView(
                  layout: LayoutProps(flex: 1),
                  onLoadStart: (v) => print("WebView Load Start: $v"),
                  onLoadEnd: (v) => print("WebView Load End: $v"),
                  onLoadError: (v) => print("WebView Load Error: $v"),
                  onLoadProgress: (v) => print("WebView Load Progress: $v"),
                  onMessage: (v) => print("WebView Message: $v"),
                  onNavigationStateChange:
                      (v) => print("WebView Navigation State Change: $v"),
                  webViewProps: DCFWebViewProps(
                    source: "https://www.github.com/dotcorr/dcflight",
                    loadMode: DCFWebViewLoadMode.url,
                  ),
                ),
              ],
            ),
          ] : [],
        ),

        // Push Screens - These are always available for navigation
        DCFScreen(
          name: "detail_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Detail Screen",
            backButtonTitle: "Back",
            largeTitleDisplayMode: true,
          ),
          navigationCommand: detailScreenCommand.state,
          onAppear: (data) => print("✅ Detail screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Detail navigation event: $data");
            detailScreenCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Detail received params: $data"),
          children: [
            DCFView(
              layout: LayoutProps(
                flex: 1,
                padding: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                gap: 20,
              ),
              children: [
                DCFText(
                  content: "Detail Screen",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                DCFText(
                  content: "This screen was pushed using ScreenNavigationCommand",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Push Another Screen"),
                  layout: LayoutProps(height: 50, width: 200),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.purple,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    detailScreenCommand.setState(ScreenNavigationCommand(
                      pushTo: PushToScreenCommand(
                        screenName: "deep_screen",
                        params: {"level": "deep", "source": "detail_screen"}
                      )
                    ));
                  },
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Pop Back"),
                  layout: LayoutProps(height: 50, width: 200),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.red,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    detailScreenCommand.setState(ScreenNavigationCommand(
                      pop: PopScreenCommand(
                        result: {"message": "Returned from detail screen"}
                      )
                    ));
                  },
                ),
              ],
            ),
          ],
        ),

        DCFScreen(
          name: "deep_screen",
          presentationStyle: DCFPresentationStyle.push,
          pushConfig: DCFPushConfig(
            title: "Deep Screen",
            backButtonTitle: "Detail",
          ),
          navigationCommand: deepScreenCommand.state,
          onAppear: (data) => print("✅ Deep screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Deep navigation event: $data");
            deepScreenCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Deep received params: $data"),
          children: [
            DCFView(
              layout: LayoutProps(
                flex: 1,
                padding: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                gap: 20,
              ),
              children: [
                DCFText(
                  content: "Deep Screen",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                DCFText(
                  content: "This is deep in the navigation stack",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Pop to Root"),
                  layout: LayoutProps(height: 50, width: 200),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.red,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    deepScreenCommand.setState(ScreenNavigationCommand(
                      popToRoot: PopToRootCommand()
                    ));
                  },
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Pop to Detail"),
                  layout: LayoutProps(height: 50, width: 200),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.cyan,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    deepScreenCommand.setState(ScreenNavigationCommand(
                      popTo: PopToScreenCommand(screenName: "detail_screen")
                    ));
                  },
                ),
              ],
            ),
          ],
        ),

        // Modal Screen
        DCFScreen(
          name: "modal_screen",
          presentationStyle: DCFPresentationStyle.modal,
          modalConfig: DCFModalConfig(
            detents: ["medium", "large"],
            showDragIndicator: true,
            isDismissible: true,
          ),
          navigationCommand: modalScreenCommand.state,
          onAppear: (data) => print("✅ Modal screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Modal navigation event: $data");
            modalScreenCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Modal received params: $data"),
          children: [
            DCFView(
              layout: LayoutProps(
                flex: 1,
                padding: 20,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                gap: 20,
              ),
              children: [
                DCFText(
                  content: "Modal Screen",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                DCFText(
                  content: "This screen was presented modally",
                  textProps: DCFTextProps(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Dismiss Modal"),
                  layout: LayoutProps(height: 50, width: 200),
                  styleSheet: StyleSheet(
                    backgroundColor: Colors.red,
                    borderRadius: 8,
                  ),
                  onPress: (v) {
                    modalScreenCommand.setState(ScreenNavigationCommand(
                      dismissModal: DismissModalCommand(
                        result: {"dismissed": true, "timestamp": DateTime.now().toString()}
                      )
                    ));
                  },
                ),
              ],
            ),
          ],
        ),

        // Tab Navigator - This coordinates the screens above
        DCFTabNavigator(
          lazyLoad: true,
          screens: ["test_home", "test_profile", "navigation_demo", "test_gh"],
          selectedIndex: currentTab.state,
          tabBarStyle: DCFTabBarStyle(
            selectedTintColor: Colors.blue,
            unselectedTintColor: Colors.grey,
            translucent: true,
          ),
          onTabChange: (data) {
            final newIndex = data["selectedIndex"] as int;
            currentTab.setState(newIndex);
            print("🔄 Tab changed to index: $newIndex");
          },
          onTabPress: (data) {
            print("👆 Tab pressed: ${data["selectedIndex"]}");
          },
        ),
      ],
    );
  }
}