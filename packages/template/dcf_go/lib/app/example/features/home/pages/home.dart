import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

class Home extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final selectedIndexWeb = useState<int>(2);
    return  DCFScrollView(
        layout: LayoutProps(
          flex: 1,
          padding: 16,
          gap: 2,
          alignContent: YogaAlign.spaceBetween,
          justifyContent: YogaJustifyContent.spaceBetween,
        ),
        children: [
          DCFSegmentedControl(
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
          DCFWebView(
            onLoadStart: (v) {
              print("WebView Load Start: $v");
            },
            onLoadEnd: (v) {
              print("WebView Load End: $v");
            },
            onLoadError: (v) {
              print("WebView Load Error: $v");
            },
            onLoadProgress: (v) {
              print("WebView Load Progress: $v");
            },
            onMessage: (v) {
              print("WebView Message: $v");
            },
            onNavigationStateChange: (v) {
              print("WebView Navigation State Change: $v");
            },
            webViewProps: DCFWebViewProps(
              source:
                  selectedIndexWeb.state == 0
                      ? "https://developer.android.com/compose"
                      : selectedIndexWeb.state == 1
                      ? "https://developer.apple.com/tutorials/swiftui/"
                      : "https://www.dotcorr.com",
              loadMode: DCFWebViewLoadMode.url,
       
            ),
            layout: LayoutProps(height: 500, width: "100%"),
          ),
          DCFView(
            layout: LayoutProps(height: 250, width: "100%"),
            children: [
              DCFText(
                content: "Welcome To DCFlight",
                textProps: DCFTextProps(
                  fontSize: 25,
                  color: Colors.black,
                  fontWeight: DCFFontWeight.bold,
                ),
              ),
              DCFButton(
                buttonProps: DCFButtonProps(title: "Go to Github"),
                layout: LayoutProps(height: 50, width: 200),
                styleSheet: StyleSheet(
                  backgroundColor: Colors.blue,
                  borderRadius: 8,
                ),
                onPress: (v) {
                  publicDetailScreenCommand.setState(
                   NavigationPresets.pushTo("test_gh")
                  );
                },
              ),
              DCFText(
                content: "Build native apps with Dart",
                textProps: DCFTextProps(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ],
      );
  }
}
