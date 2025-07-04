import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcf_go/app/example/features/home/components/gradient.dart';
import 'package:dcf_go/app/example/features/home/components/portal_test.dart';
import 'package:dcf_go/app/example/features/home/pages/home.dart';
import 'package:dcf_go/app/example/features/profile/screens/profile.dart';
import 'package:dcflight/dcflight.dart';

class App extends StatefulComponent {
  // Instantiate componets that handle their inernal state (stateful components) once to to avoid re-instantiation
  // on every render or worse case state loss.
  // By default the vdom is efficient and will only re-render the components that have changed but doing this
  // adds up to make your app even more performant.
  final homePage = Home();
  final gradientTestPage = GradientTest();
  final profilePage = Profile();
  final portalTestPage = PortalTest();

  @override
  DCFComponentNode render() {
    final pagestateLocal = useStore(pagestate);
    final overlayCommand = useStore(publicOverlayLoadingCommand);

    useInsertionEffect(() {
      // refer to hooks docs:
      //*
      //   Why useInsertionEffect Works But useLayoutEffect Doesn't
      // The Problem this Solves:
      // useLayoutEffect runs after component + children mount → Still too early for navigation
      // useInsertionEffect runs after entire tree is complete → Perfect timing for navigation

      // Your navigation issue specifically needs the complete component tree because:

      // Screen registration happens during component mounting
      // Navigation commands need all screens to exist
      // Only useInsertionEffect waits for the full tree initialization
      //*
      overlayCommand.setState(
        NavigationPresets.presentOverlay("overlay_loading")
      );
      print(
        "Hey flutter dev. Effect is like init state but that can mutate if its dependencies state. You can override componentDidMount and componentDidMount if you dont want to use effects (mutate if and only if dependecy(state or changeable value) changes).",
      );
      return null;
    }, dependencies: []);

    return DCFView(
      layout: LayoutProps(
        flex: 1,
        flexDirection: YogaFlexDirection.column,
        // padding: 16,
        // gap: 16,
      ),
      children: [
        DCFView(
          layout: LayoutProps(
            height: "80%",
            width: "100%",
            flexDirection: YogaFlexDirection.column,
          ),
          children: [
            pagestateLocal.state == 0
                ? homePage
                : pagestateLocal.state == 1
                ? gradientTestPage
                : pagestateLocal.state == 2
                ? gradientTestPage
                : pagestateLocal.state == 3
                ? profilePage
                : pagestateLocal.state == 4
                ? portalTestPage
                : DCFView(),
          ],
        ),

        DCFDropdown(
          styleSheet: StyleSheet(
            backgroundColor: Colors.amber,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: Colors.grey,
          ),
          layout: LayoutProps(height: "5%", width: '100%'),
          onValueChange: (v) {
            pagestateLocal.setState(int.parse(v['value']));
          },
          onClose: (v) {
            print("Dropdown closed with value: ${v['value']}");
          },
          onOpen: (v) {
            print("Dropdown opened with value: ${v['value']}");
          },
          dropdownProps: DCFDropdownProps(
            items: [
              DCFDropdownMenuItem(title: "Home", value: "0"),
              DCFDropdownMenuItem(title: "Gradient Test", value: "1"),
              DCFDropdownMenuItem(title: "Really Long List", value: "2"),
              DCFDropdownMenuItem(title: "Modal & Alert Test", value: "3"),
              DCFDropdownMenuItem(title: "Portal Test", value: "4"),
            ],
            selectedValue: pagestateLocal.state.toString(),
          ),
        ),
      ],
    );
  }
}
