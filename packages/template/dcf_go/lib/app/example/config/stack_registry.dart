import 'package:dcf_go/app/example/features/navigation_demo/pages/deep_screen.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/details.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/modal_screen.dart'
    show ModalScreen;
import 'package:dcflight/dcflight.dart';
import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:flutter/cupertino.dart';

class StackRegistry extends StatefulComponent {
  // Instantiate screen components once OUTSIDE the render method to avoid re-renders/wrap useMemo if you need to render in render method to access things like state but stay safe.
  final _detailsScreen = Details();
  final _deepScreen = DeepScreen();
  final _modalScreen = ModalScreen();
  @override
  DCFComponentNode render() {
    final detailsCommand = useStore(publicDetailScreenCommand);
    final deepScreenCommand = useStore(publicDeepScreenCommand);
    final modalScreenCommand = useStore(publicModalScreenCommand);
    final overlayLoadingCommand = useStore(publicOverlayLoadingCommand);

    return DCFFragment(
      children: [
        DCFScreen(
          name: "overlay_loading",
          onNavigationEvent: (data) {
            print("✅ Overlay loading appeared: $data");
            overlayLoadingCommand.setState(null);
          },
          presentationStyle: DCFPresentationStyle.overlay,
          navigationCommand: overlayLoadingCommand.state,
          overlayConfig: DCFOverlayConfig(
            overlayBackgroundColor: Colors.black.withOpacity(0.5),
            dismissOnTap: false,
            blocksInteraction: true,
            title: "Hey there loading something sweet",
          ),
          children: [
            (DCFView(
              layout: LayoutProps(
                height: 100,
                width: 100,
                alignItems: YogaAlign.center,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFSpinner(animating: true, color: CupertinoColors.activeBlue),
              ],
            )),
          ],
        ),

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
