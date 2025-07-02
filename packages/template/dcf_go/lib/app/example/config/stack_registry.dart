import 'package:dcf_go/app/example/features/navigation_demo/pages/deep_screen.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/details.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/modal_screen.dart'
    show ModalScreen;
import 'package:dcflight/dcflight.dart';
import 'package:dcf_go/app/example/config/global_state.dart';

class StackRegistry extends StatefulComponent {


  @override
  DCFComponentNode render() {
  // Instantiate screen components once OUTSIDE the render method to avoid re-renders/wrap useMemo if you need to render in render method.
  final _detailsScreen = useMemo(() => Details(), []);
  final _deepScreen = useMemo(() => DeepScreen(), []);
  final _modalScreen = useMemo(() => ModalScreen(), []);

    final detailsCommand = useStore(publicDetailScreenCommand);
    final deepScreenCommand = useStore(publicDeepScreenCommand);
    final modalScreenCommand = useStore(publicModalScreenCommand);

    // Per Rule 1, the UI tree of a StatefulComponent must be memoized.
    // The dependency array includes all the navigation commands, so this tree
    // is only rebuilt when a navigation event actually occurs.
    return useMemo(() {
      return DCFFragment(
        children: [
          DCFScreen(
            name: "detail_screen",
            presentationStyle: DCFPresentationStyle.push,
            pushConfig: DCFPushConfig(
              title: "Detail Screen",
              backButtonTitle: "Go back",
              largeTitleDisplayMode: true,
            ),
            navigationCommand: detailsCommand.state,
            onAppear: (data) => print("✅ Detail screen appeared: $data"),
            onNavigationEvent: (data) {
              print("🚀 Detail navigation event: $data");
              // dispose the command to avoid memory leaks
              detailsCommand.setState(null);
            },
            onReceiveParams: (data) =>
                print("📨 Detail received params: $data"),
            children: [_detailsScreen],
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
            onReceiveParams: (data) =>
                print("📨 Deep received params: $data"),
            children: [_deepScreen],
          ),
          DCFScreen(
            name: "modal_screen",
            presentationStyle: DCFPresentationStyle.push,
            navigationCommand: modalScreenCommand.state,
            onAppear: (data) => print("✅ Modal screen appeared: $data"),
            onNavigationEvent: (data) {
              print("🚀 Modal navigation event: $data");
              modalScreenCommand.setState(null);
            },
            onReceiveParams: (data) =>
                print("📨 Modal received params: $data"),
            children: [_modalScreen],
          ),
        ],
      );
    }, [
      detailsCommand.state,
      deepScreenCommand.state,
      modalScreenCommand.state
    ]);
  }
}
