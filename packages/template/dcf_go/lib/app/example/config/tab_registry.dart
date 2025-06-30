import 'package:dcf_go/app/example/features/navigation_demo/screens/navigation_demo.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcf_go/app/example/features/home/screens/home.dart';
import 'package:dcf_go/app/example/features/github/screens/gh_repo.dart';
import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcf_go/app/example/features/home/components/modal_test.dart';
class TabRegistry extends StatelessComponent {
  @override
  DCFComponentNode render() {
   return DCFFragment(
    children:[
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
        children: [App()],
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
        children: [ModalTest()],
      ),

      DCFScreen(
        name: "navigation_demo",
        presentationStyle: DCFPresentationStyle.tab,
        tabConfig: DCFTabConfig(
          title: "Navigation",
          icon: "square.stack",
          index: 2,
        ),
        navigationCommand: publicDetailScreenCommand.state,
        onAppear: (data) => print("✅ Navigation demo screen appeared: $data"),
        onActivate:
            (data) => print("🟢 Navigation demo screen activated: $data"),
        onNavigationEvent: (data) {
          print("🚀 Navigation demo navigation event: $data");
          publicDetailScreenCommand.setState(null);
        },
        onReceiveParams:
            (data) => print("📨 Navigation demo received params: $data"),
        children: [NavigationDemo()],
      ),

      DCFScreen(
        name: "test_gh",
        presentationStyle: DCFPresentationStyle.tab,
        tabConfig: DCFTabConfig(title: "Github", icon: "lightbulb", index: 3),
        onAppear: (data) => print("✅ Github screen appeared: $data"),
        onActivate: (data) => print("🟢 Github screen activated: $data"),
        children: [
          DCFView(layout: LayoutProps(flex: 1), children: [GHRepo()]),
        ],
      ),
    ]
   );
  }
  
  
}
