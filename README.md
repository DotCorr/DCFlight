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

# DEV Status - Paused
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

import 'package:dcflight/dcflight.dart';
void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);

  await DCFlight.start(app: DCFView(
    layout: DCFLayout(flex: 1, justifyContent: YogaJustifyContent.center, alignItems: YogaAlign.center),
    styleSheet: DCFStyleSheet(backgroundColor: Colors.amber),
    children: [
    DCFText(content: "Hello World ✈️"),
  ]));
}

```

## ☕ Buy Me a Coffee

> **Your support fuels the grind. Every contribution keeps this journey alive.**

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://coff.ee/squirelboy360)

[https://coff.ee/squirelboy360\*\*](https://coff.ee/squirelboy360)
