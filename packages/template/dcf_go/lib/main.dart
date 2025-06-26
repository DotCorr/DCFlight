import 'package:dcf_go/app/app.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: ScreenAPITest());
}

// Temporary test for Screen API
class ScreenAPITest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final currentTab = useState<int>(0);
    return DCFFragment(
      children: [
        DCFScreen(
          visible: currentTab.state == 0,
          name: "test_home",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfig(title: "Home", icon: "house", index: 0),
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          onActivate: (data) => print("🟢 Home screen activated: $data"),
          children: [App()],
        ),

        DCFScreen(
          visible: currentTab.state == 1,
          name: "test_profile",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfig(title: "Profile", icon: "person", index: 1),
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          onActivate: (data) => print("🟢 Profile screen activated: $data"),
          children: [
            DCFView(
              layout: LayoutProps(
                flex: 1,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                padding: 20,
              ),
              children: [
                DCFText(
                  content: "Profile Screen",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                  ),
                ),
                DCFText(
                  content: "Screen API Test - Tab 2",
                  textProps: DCFTextProps(fontSize: 16),
                ),
              ],
            ),
          ],
        ),

        DCFScreen(
          visible: currentTab.state == 2,
          name: "test_settings",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfig(title: "Settings", icon: "gear", index: 2),
          onAppear: (data) => print("✅ Settings screen appeared: $data"),
          onActivate: (data) => print("🟢 Settings screen activated: $data"),
          children: [
            DCFView(
              styleSheet: StyleSheet(
                backgroundColor: Colors.red,
              ),
              layout: LayoutProps(
                flex: 1,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                padding: 20,
              ),
              children: [
                DCFText(
                  content: "Settings Screen",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                  ),
                ),
                DCFText(
                  content: "Screen API Test - Tab 3",
                  textProps: DCFTextProps(fontSize: 16),
                ),
              ],
            ),
          ],
        ),

        // Tab navigator that coordinates the screens
        DCFTabNavigator(
          lazyLoad: true,
          onTabLongPress: (v){
            print("🔍 Tab long pressed: ${v["selectedIndex"]}");
          },
     
          screens: ["test_home", "test_profile", "test_settings"],
          selectedIndex: currentTab.state,
          tabBarStyle: DCFTabBarStyle(
            // backgroundColor: Colors.white,
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
