```
-▬▬.◙.▬▬‐        
   ▂▄▄▓▄▄▂        
◢◤ █▀▀████▄▄▄◢◤   
█▄ █ █▄ ███▀▀▀▀▀▀╬ 
◥█████◤           
══╩══╩══           

██████╗  ██████╗███████╗██╗     ██╗ ██████╗ ██╗  ██╗████████╗
██╔══██╗██╔════╝██╔════╝██║     ██║██╔════╝ ██║  ██║╚══██╔══╝
██║  ██║██║     █████╗  ██║     ██║██║  ███╗███████║   ██║   
██║  ██║██║     ██╔══╝  ██║     ██║██║   ██║██╔══██║   ██║   
██████╔╝╚██████╗██║     ███████╗██║╚██████╔╝██║  ██║   ██║   
╚═════╝  ╚═════╝╚═╝     ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
```

# DEV Status - Resumed
Currently took a break from mobile dev due to changing global dynamics. I have decided to focus on AI projects for internal or private use and commercial use. As of 19th August 2025, i have resumed this project but as a side project.

### DCFlight was a Side Project which means if this is public rn you can contribute. Fully validated and works but not completed. Contribitions are welcomed.


## 📌 Key Points

DCFlight in short is a framework that renders actual native UI. It uses the flutter engine (Flutter engine here provides us the runtime and some utilities to initialize DCFlight. More like Hermes in react native). As seen below DCFlight:

```swift
import dcflight

@main
@objc class AppDelegate: DCFAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

It diverges from the flutter abstraction for UI rendering and renders the root view that dcflight depends on to render native UI. No platform views and no absurd abstractions. As a bonus you can still render a flutter Widget by using the `WidgetToDCFAdaptor` without impacting performance.

## 📝 Dart Example

```dart
import 'package:dcf_go/app/example/config/global_state.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: Home());
}

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

```

## ☕ Buy Me a Coffee

> **Your support fuels the grind. Every contribution keeps this journey alive.**

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://coff.ee/squirelboy360)

[https://coff.ee/squirelboy360\*\*](https://coff.ee/squirelboy360)
