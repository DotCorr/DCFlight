import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcf_go/app/example/features/home/components/gradient.dart';
import 'package:dcf_go/app/example/features/home/components/portal_test.dart';
import 'package:dcf_go/app/example/features/home/pages/home.dart';
import 'package:dcf_go/app/example/features/profile/screens/profile.dart';
import 'package:dcflight/dcflight.dart';

class App extends StatefulComponent {
  // Instantiate componets that handle state (stateful components) once to to avoid re-instantiation
  // on every render.
  // By default the vdom is efficient and will only re-render the components that have changed but doing this 
  // adds up to make your app even more performant.
  final homePage = Home();
  final gradientTestPage = GradientTest();
  final profilePage = Profile();
  final portalTestPage = PortalTest();
  @override
  DCFComponentNode render() {
    final pagestateLocal = useStore(pagestate);

    return DCFFragment(
      children: [
        DCFView(
          layout: LayoutProps(flex: 8, flexDirection: YogaFlexDirection.column),
          children: [
            pagestateLocal.state == 0
                ? homePage
                : pagestateLocal.state == 1
                ? gradientTestPage
                : pagestateLocal.state == 2
                ? DCFView(children: [DCFText(content: "Test")])
                : pagestateLocal.state == 3
                ? Profile()
                : pagestateLocal.state == 4
                ? PortalTest()
                : DCFView(),
          ],
        ),
        DCFView(
          layout: LayoutProps(
            flex: 1,
            flexDirection: YogaFlexDirection.column,
            padding: EdgeInsets.all(16).vertical,
          ),
          children: [
            DCFDropdown(
              layout: LayoutProps(height: 40, width: '100%', marginBottom: 8),
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
        ),
      ],
    );
  }
}
