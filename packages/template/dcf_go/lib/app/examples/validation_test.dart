// Test for store usage validation system

import 'package:dcflight/dcflight.dart';

/// Test app that demonstrates validation warnings
class ValidationTestApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: LayoutProps(flex: 1,gap: 10,alignContent: YogaAlign.spaceBetween,justifyContent: YogaJustifyContent.spaceBetween),
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

            DCFGestureDetector(
              children: [
                DCFText(
                  content: "🔗 Tap here to open Apple.com (using GestureDetector)",
                  textProps: DCFTextProps(
                    fontSize: 16, 
                    color: Colors.blue
                  ),
                )
              ],
              onTap: (data) {
                print("Opening Apple.com in external browser...");
                // You can add url_launcher package or platform channel to open URLs
              },
              layout: LayoutProps(height: 50, width: "100%", padding: 10),
            ),
          ],
        ),
      ],
    );
  }
}
