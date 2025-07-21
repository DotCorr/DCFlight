import '../features/navigation_demo/screens/navigation_demo.dart';
import 'package:dcflight/dcflight.dart';
import '../features/home/screens/home.dart';
import '../features/github/screens/gh_repo.dart';
import 'global_state.dart';
import '../features/profile/screens/profile.dart';

class TabRegistry extends StatefulComponent {
  // Instantiate screen components once to preserve their state and avoid re-renders
  final _homeScreen = App();
  final _profileScreen = Profile();
  final _navDemoScreen = NavigationDemo();
  final _githubScreen = GHRepo();

  @override
  DCFComponentNode render() {
    final popOverScreenCommand = useStore(publicPopOverScreenCommand);  
    
    return DCFFragment(
      children: [
        DCFScreen(
          name: "test_home",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfigSVG.withSVGPackage(
            title: "Home",
            badge: "hello world",
            package: "dcf_primitives",
            iconName: DCFIcons.house,
            index: 0,
            size: 24.0,
            tintColor: Colors.blue,
          ),
          onAppear: (data) => print("✅ Home screen appeared: $data"),
          onActivate: (data) => print("🟢 Home screen activated: $data"),
          children: [_homeScreen],
        ),
        DCFScreen(
          name: "test_profile",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfigSVG.withSVGPackage(
            title: "Profile",
            package: "dcf_primitives",
            iconName: DCFIcons.info,
            index: 1,
            size: 24.0,
            tintColor: Colors.blue,
          ),
          onAppear: (data) => print("✅ Profile screen appeared: $data"),
          onActivate: (data) => print("🟢 Profile screen activated: $data"),
          children: [_profileScreen],
        ),

        DCFScreen(
          name: "navigation_demo",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfig(
            title: "Navigation",
            icon: "square.stack",
            index: 2,
          ),

          navigationBarConfig: DCFNavigationBarConfig(
            title: "Navigation Demo",
            largeTitleDisplayMode: true,
            suffixActions: [
           
              DCFPushHeaderActionConfig.withSFSymbolOnly(
                symbolName: "gear",
                actionId: "settings_action",
              ),
              DCFPushHeaderActionConfig.withSVGPackage(
               iconName: DCFIcons.plus,
                package: "dcf_primitives",
                title: "Add",
                size: 24.0,
                actionId: "add_action",
              ),
            ],
            prefixActions: [
              DCFPushHeaderActionConfig.withSVGPackage(
                title: "Help",
                package: "dcf_primitives",
                iconName: DCFIcons.info,
                actionId: "help_action",
              ),
            ],
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
          // 🎯 NEW: Handle header action presses
          onHeaderActionPress: (data) {
            print("🎯 Navigation demo header action pressed: $data");
            final actionId = data['actionId'] as String?;
            switch (actionId) {
              case 'settings_action':
                print("Settings gear tapped!");
                // Add your settings action here
                break;
              case 'add_action':
                print("Add plus tapped!");
                
                popOverScreenCommand.setState(
              NavigationPresets.pushTo("universal_pop_over"),
            );
                break;
              case 'help_action':
                print("Help info tapped!");
                // Add your help action here
                break;
            }
          },
          children: [_navDemoScreen],
        ),

        DCFScreen(
          name: "test_gh",
          presentationStyle: DCFPresentationStyle.tab,
          tabConfig: DCFTabConfigSVG.withSVGPackage(
            title: "Github",
            package: "dcf_primitives",
            iconName: DCFIcons.github,
            index: 3,
            size: 24.0,
            tintColor: Colors.blue,
          ),
          // 🎯 You can also add navigation bar config to other tabs if needed
          navigationBarConfig: DCFNavigationBarConfig(
            title: "GitHub Repos",
            largeTitleDisplayMode: true,
            suffixActions: [
              DCFPushHeaderActionConfig.withSFSymbolOnly(
                symbolName: "arrow.clockwise",
                actionId: "refresh_action",
              ),
            ],
          ),
          onAppear: (data) => print("✅ Github screen appeared: $data"),
          onActivate: (data) => print("🟢 Github screen activated: $data"),
          onHeaderActionPress: (data) {
            print("🎯 GitHub header action pressed: $data");
            final actionId = data['actionId'] as String?;
            if (actionId == 'refresh_action') {
              print("Refreshing GitHub repos!");
              // Add your refresh logic here
            }
          },
          children: [_githubScreen],
        ),
      ],
    );
  }
}
