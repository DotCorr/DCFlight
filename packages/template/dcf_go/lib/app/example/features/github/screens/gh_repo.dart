import 'package:dcflight/dcflight.dart';

// no useMemo here as this is a stateless component
// This should give you a hang over things(stateful->useMemo(not compulsory but safe), stateless->no useMemo)
class GHRepo extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFWebView(
      layout: LayoutProps(flex: 1),
      onLoadStart: (v) => print("WebView Load Start: $v"),
      onLoadEnd: (v) => print("WebView Load End: $v"),
      onLoadError: (v) => print("WebView Load Error: $v"),
      onLoadProgress: (v) => print("WebView Load Progress: $v"),
      onMessage: (v) => print("WebView Message: $v"),
      onNavigationStateChange:
          (v) => print("WebView Navigation State Change: $v"),
      webViewProps: DCFWebViewProps(
        source: "https://www.github.com/dotcorr/dcflight",
        loadMode: DCFWebViewLoadMode.url,
      ),
    );
  }
}
