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
  // Hey flutter devs,
  // this is a very important note to take.
  // This framework prioritizes performance and memory management. 
  // Most of these optimisations are done by the vdom and the framework itself.
  // But you can also help the framework by instantiating components that handle their own state
  // outside the render method to avoid re-instantiation on every render.
  // This is because the vdom is efficient and will only re-render the components that have changed,
  // but doing this adds up to make your app even more performant.
  // Notice how we are using the same DeepScreen component for both the push and modal screen but differnt instances.
  // this is because vdom does not trigger rerender cause the component is the same.
  // To fix this; reinstantiate the component outside the render method or use useMemo to access the component in the render method if you are super paranoid.
  // Else fan fact: use them, directly in the render method. As long as the state done change it would still be reconciled but with no change so no rerender.
  // So it doe snot really matter.
  final _deepScreenInModal = DeepScreen();

  final _modalScreen = ModalScreen();
  @override
  DCFComponentNode render() {
    final detailsCommand = useStore(publicDetailScreenCommand);
    final deepScreenCommand = useStore(publicDeepScreenCommand);
    final modalScreenCommand = useStore(publicModalScreenCommand);
    final overlayLoadingCommand = useStore(publicOverlayLoadingCommand);
    final modalScreenInModalCommand = useStore(publicModalScreenInModalCommand);

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
          onAppear: (data) => print("✅ Deep screen appeared: $data"),
          onNavigationEvent: (data) {
            print("🚀 Deep navigation event: $data");
            modalScreenInModalCommand.setState(null);
          },
          onReceiveParams: (data) => print("📨 Deep received params: $data"),
          children: [_deepScreenInModal],
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
      ],
    );
  }
}
