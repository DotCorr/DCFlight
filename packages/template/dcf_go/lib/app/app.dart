import 'package:dcf_go/app/examples/gradient.dart';
import 'package:dcf_go/app/examples/really_long_list.dart';
import 'package:dcf_go/app/examples/home.dart';
import 'package:dcf_go/app/examples/modal_test.dart';
import 'package:dcf_go/app/examples/portal_test.dart';
import 'package:dcflight/dcflight.dart';

final pagestate = Store<int>(0);

// Test comment for hydration
class App extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final pagestateLocal = useStore(pagestate);

    // Removed DCFPortalProvider wrapper to test modal rendering
    return DCFScrollView(
     
      layout: LayoutProps(flex: 1,marginBottom: 10),
      children: [
        // Main App Content
        DCFSafeAreaView(
          layout: LayoutProps(flex: 1, padding: 8),
          children: [
            DCFView(
              layout: LayoutProps(
                flex: 1,
                flexDirection: YogaFlexDirection.column,
              ),
              children: [
                pagestateLocal.state == 0
                    ? Home()
                    : pagestateLocal.state == 1
                    ? GradientTest()
                    : pagestateLocal.state == 2
                    ? ReallyLongList()
                    : pagestateLocal.state == 3
                    ? ModalTest()
                    : pagestateLocal.state == 4
                    ? PortalTest()
                    : DCFView(),
              ],
            ),

            DCFDropdown(
              layout: LayoutProps(height: 40, marginBottom: 8),
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
