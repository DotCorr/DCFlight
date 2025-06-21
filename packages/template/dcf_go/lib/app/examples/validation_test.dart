// Test for store usage validation system

import 'package:dcflight/dcflight.dart';

/// Test app that demonstrates validation warnings
class ValidationTestApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: LayoutProps(flex: 1),
      // ADD EVENT HANDLERS SO EVENTS GET REGISTERED
      onContentSizeChange: (v) {
        print("Content size changed: $v");
      },
      onScroll: (v) {
        print("Scrolled to: $v");
      },
      children: [
        DCFSegmentedControl(segmentedControlProps: DCFSegmentedControlProps(
          segments: [
            DCFSegmentItem(title: "One", ),
            DCFSegmentItem(title: "Two"),
            DCFSegmentItem(title: "Three"),
          ],
           
        ),onSelectionChange: (v) {
          print("selected index changed: $v");
        },),
        DCFWebView(
          webViewProps: DCFWebViewProps(
            source: "https://www.google.com",
            loadMode: DCFWebViewLoadMode.url,
          ),
          layout: LayoutProps(height: 500, width: "100%"),
        ),
        DCFWebView(
          webViewProps: DCFWebViewProps(
            source: "https://httpbin.org/html",
            loadMode: DCFWebViewLoadMode.url,
          ),
          layout: LayoutProps(height: 500, width: "100%"),
        ),
        DCFView(
          layout: LayoutProps(flex: 1),
          children: [
            DCFText(
              content: "This is a test app for validation warnings",
              textProps: DCFTextProps(fontSize: 20, color: Colors.black),
            ),
            DCFText(
              content: "Check the console for validation messages",
              textProps: DCFTextProps(fontSize: 16, color: Colors.grey),
            ),

            DCFUrlWrapperView(
              children: [
                DCFText(
                  content: "🔗 Tap here to open Apple.com (native browser)",
                  textProps: DCFTextProps(
                    fontSize: 16, 
                    color: Colors.blue
                  ),
                )
              ],
              urlWrapperProps: DCFUrlWrapperProps(
                url: "https://www.apple.com",
                detectPress: true,
              ),
              layout: LayoutProps(height: 50, width: "100%", padding: 10),
            ),
          ],
        ),
      ],
    );
  }
}
