import 'package:dcf_go/app/example/features/navigation_demo/pages/deep_screen.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/details.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pages/modal_screen.dart';
import 'package:dcf_go/app/example/features/navigation_demo/pop_overs/info.dart';
import 'package:dcflight/dcflight.dart';
import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:flutter/cupertino.dart';

class StackRegistry extends StatefulComponent {
  // Instantiate screen components once OUTSIDE the render method to avoid re-renders/wrap useMemo if you need to render in render method to access things like state but stay safe.
  final _detailsScreen = Details();
  final _deepScreen = DeepScreen();
  final _popOverScreen = PopOverScreen();
  // Hey flutter devs,
  // this is a very important note to take.
  // This framework prioritizes performance and memory management.
  // Most of these optimisations are done by the vdom and the framework itself.
  // But you can also help the framework by instantiating components that handle their own state
  // outside the render method to avoid re-instantiation on every render.
  final _deepScreenInModal = DeepScreen();

  final _modalScreen = ModalScreen();
  @override
  DCFComponentNode render() {
    final detailsCommand = useStore(publicDetailScreenCommand);
    final deepScreenCommand = useStore(publicDeepScreenCommand);
    final modalScreenCommand = useStore(publicModalScreenCommand);
    final overlayLoadingCommand = useStore(publicOverlayLoadingCommand);
    final modalScreenInModalCommand = useStore(publicModalScreenInModalCommand);
    final popOverScreenCommand = useStore(publicPopOverScreenCommand);

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
          name: "deep_screen_in_modal",
          presentationStyle: DCFPresentationStyle.modal,
          navigationCommand: modalScreenInModalCommand.state,
          // modalConfig: DCFModalConfig(detents: [DCFModalDetent.large]),
          onAppear: (data) => print("✅ Deep screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Deep navigation event: $data");
            modalScreenInModalCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Deep received params: $data"),
          children: [
            DCFSafeArea(children: [_deepScreenInModal]),
          ],
        ),

        DCFScreen(
          name: "modal_screen",
          presentationStyle: DCFPresentationStyle.modal,

          navigationCommand: modalScreenCommand.state,
          onAppear: (data) => print("✅ Modal screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Modal navigation event: $data");
            modalScreenCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Modal received params: $data"),
          children: [_modalScreen],
        ),

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
            dismissOnTap: true,
            blocksInteraction: true,
          ),
          children: [
            // Normally you use this with portals so you app only has one overlay in its lifecycle
            (DCFView(
              styleSheet: StyleSheet(backgroundColor: Colors.transparent),
              layout: LayoutProps(
                flex: 1,
                alignItems: YogaAlign.center,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFSpinner(
                  animating: true,
                  color: CupertinoColors.systemRed,
                  style: "medium",
                  layout: LayoutProps(width: "50", height: "50"),
                  styleSheet: StyleSheet(
                    borderRadius: 25,
                    backgroundColor: Colors.white,
                  ),
                ),

                DCFButton(
                  buttonProps: DCFButtonProps(title: "Close Overlay"),
                  onPress: (v) {
                    overlayLoadingCommand.setState(
                      NavigationPresets.dismissOverlay,
                    );
                  },
                  layout: LayoutProps(marginTop: 16, width: "80%"),
                ),
              ],
            )),
          ],
        ),
        DCFScreen(
          name: "universal_pop_over",
          presentationStyle: DCFPresentationStyle.popover,

          popoverConfig: DCFPopoverConfig(
            title: "Portaled Content",
            dismissOnOutsideTap: true,
          ),
          navigationCommand: popOverScreenCommand.state,
          onAppear: (data) => print("✅ Detail screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Detail navigation event: $data");
            // dispose the command to avoid memory leaks
            popOverScreenCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Detail received params: $data"),
          children: [_popOverScreen],
        ),
      ],
    );
  }
}
