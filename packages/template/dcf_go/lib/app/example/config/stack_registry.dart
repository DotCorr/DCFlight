import 'package:dcf_go/app/example/features/navigation_demo/pages/deep_screen.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/details.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/modal_screen.dart'
    show ModalScreen;
import 'package:dcflight/dcflight.dart';
import 'package:dcf_go/app/example/config/global_state.dart';

class StackRegistry extends StatefulComponent {
  // Instantiate screen components once to preserve their state and avoid re-renders.
  final _detailsScreen = Details();
  final _deepScreen = DeepScreen();
  final _modalScreen = ModalScreen();

  @override
  DCFComponentNode render() {
    final detailsCommand = useStore(publicDetailScreenCommand);
    final deepScreenCommand = useStore(publicDeepScreenCommand);
    final modalScreenCommand = useStore(publicModalScreenCommand);

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
            detailsCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Detail received params: $data"),
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
          onReceiveParams: (data) => print("📨 Deep received params: $data"),
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
          onReceiveParams: (data) => print("📨 Modal received params: $data"),
          children: [_modalScreen],
        ),
      ],
    );
  }
}
