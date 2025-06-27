import 'package:dcf_go/app/app.dart';
import 'package:dcf_go/app/examples/modal_test.dart';
import 'package:dcf_go/app/examples/really_long_list.dart';
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
          children: [ModalTest()],
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
              styleSheet: StyleSheet(backgroundColor: Colors.red),
              layout: LayoutProps(
                flex: 1,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
                padding: 20,
              ),
              children: [ReallyLongList()],
            ),
          ],
        ),

        // Tab navigator that coordinates the screens
        DCFTabNavigator(
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
