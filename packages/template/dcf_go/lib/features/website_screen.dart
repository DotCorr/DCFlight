import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

class WebsiteScreen extends StatefulComponent {
  @override
  List<Object?> get props => [];

  @override
  DCFComponentNode render() {
    final selectedIndexWeb = useState(0);
    return DCFSafeArea(
      layout: LayoutProps(flex: 1),

      children: [
        DCFView(
          layout: LayoutProps(
            height: 50,
            width: "100%",
            flexDirection: YogaFlexDirection.row,
            alignContent: YogaAlign.center,
            alignItems: YogaAlign.center,
            justifyContent: YogaJustifyContent.spaceBetween,
          ),
          children: [
            DCFSegmentedControl(
              layout: LayoutProps(height: 40, width: "40%"),
              segmentedControlProps: DCFSegmentedControlProps(
                selectedIndex: selectedIndexWeb.state,
                segments: [
                  DCFSegmentItem(title: "Android"),
                  DCFSegmentItem(title: "IOS"),
                  DCFSegmentItem(title: "DCFlight"),
                ],
              ),
              onSelectionChange: (v) {
                selectedIndexWeb.setState(v["selectedIndex"]);
              },
            ),

            DCFGestureDetector(
              layout: LayoutProps(height: 40, width: 40),

              onTap: (v) {
                AppNavigation.dismissModal();
              },
              children: [
                DCFIcon(
                  iconProps: DCFIconProps(name: DCFIcons.x, adaptive: false),
                  layout: LayoutProps(height: 40, width: 40),
                ),
              ],
            ),
          ],
          styleSheet: DCFStyleSheet(backgroundColor: Colors.amber),
        ),
        DCFWebView(
          webViewProps: DCFWebViewProps(
            source:
                selectedIndexWeb.state == 0
                    ? "https://developer.android.com/compose"
                    : selectedIndexWeb.state == 1
                    ? "https://developer.apple.com/tutorials/swiftui/"
                    : "https://www.dotcorr.com",
            loadMode: DCFWebViewLoadMode.url,
          ),
          layout: LayoutProps(flex: 1),
        ),
      ],
    );
  }
}
