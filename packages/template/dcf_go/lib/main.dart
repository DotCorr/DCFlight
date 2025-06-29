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

    return DCFFragment(
      children: [
        DCFScreen(
          visible: currentTab.state == 0,
          name: "test_home",
          presentationStyle: DCFPresentationStyle.tab,
          // Use SVG from app bundle
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
          children: [App()],
        ),
        
        DCFScreen(
          visible: currentTab.state == 1,
          name: "test_profile",
          presentationStyle: DCFPresentationStyle.tab,
          // Use SVG from package
          tabConfig: DCFTabConfigSVG.withSVGPackage(
            title: "Profile", 
            package: "dcf_primitives", 
            iconName: DCFIcons.personStanding, 
            index: 1,
            size: 24.0,
          ),
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          onActivate: (data) => print("🟢 Profile screen activated: $data"),
          children: [ModalTest()],
        ),
        
        DCFScreen(
          visible: currentTab.state == 2,
          name: "test_gh",
          presentationStyle: DCFPresentationStyle.tab,
          // Use SF Symbol (existing way still works)
          tabConfig: DCFTabConfig(title: "Github", icon: "lightbulb", index: 2),
          onAppear: (data) => print("✅ Settings screen appeared: $data"),
          onActivate: (data) => print("🟢 Settings screen activated: $data"),
          children: [
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
                  onNavigationStateChange: (v) => print("WebView Navigation State Change: $v"),
                  webViewProps: DCFWebViewProps(
                    source: "https://www.github.com/dotcorr/dcflight",
                    loadMode: DCFWebViewLoadMode.url,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Your existing tab navigator works the same
        DCFTabNavigator(
          screens: ["test_home", "test_profile", "test_gh"],
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