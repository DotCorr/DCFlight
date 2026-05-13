/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:convert';

import 'package:dcflight/dcflight.dart';

/// WebView loading mode
enum DCFWebViewLoadMode {
  url,
  htmlString,
  localFile,
}

/// WebView content type
enum DCFWebViewContentType {
  html,
  pdf,
  markdown,
  text,
}

/// WebView navigation policy
enum DCFWebViewNavigationPolicy {
  allow,
  cancel,
  download,
}

/// Typed bridge event dispatched from JavaScript via `dcfMessage`.
///
/// When JavaScript sends a message with structure `{type: 'eventName', ...payload}`,
/// this class automatically parses it into a typed event.
///
/// **JavaScript sending events to Dart:**
/// ```javascript
/// // 1. JavaScript code in your HTML:
/// window.dcfBridge.postEvent('userClicked', {
///   buttonId: 'submit-btn',
///   timestamp: Date.now(),
/// });
///
/// // 2. Native handler receives: {type: 'userClicked', payload: {buttonId, timestamp}}
/// // 3. Dart receives as DCFWebViewBridgeEvent(type: 'userClicked', payload: {...})
/// ```
///
/// **Dart receiving typed events:**
/// ```dart
/// DCFWebView(
///   onBridgeEvent: (event) {
///     // event is strongly typed - no JSON.parse() needed!
///     if (event.type == 'userClicked') {
///       final buttonId = event.payload['buttonId'] as String?;
///       debugPrint('Button $buttonId was clicked');
///     }
///   },
///   ...
/// )
/// ```
class DCFWebViewBridgeEvent {
  final String type;
  final Map<String, dynamic> payload;

  const DCFWebViewBridgeEvent({
    required this.type,
    required this.payload,
  });

  factory DCFWebViewBridgeEvent.fromOnMessage(Map<dynamic, dynamic> event) {
    dynamic data = event['data'];

    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        data = decoded;
      } catch (_) {
        data = {'raw': data};
      }
    }

    if (data is! Map) {
      data = {'value': data};
    }

    final payload = <String, dynamic>{
      for (final entry in data.entries) entry.key.toString(): entry.value,
    };

    final type = payload['type']?.toString() ?? 'message';
    return DCFWebViewBridgeEvent(type: type, payload: payload);
  }
}

/// Callback signature for strongly typed bridge events.
typedef DCFWebViewBridgeEventHandler = void Function(DCFWebViewBridgeEvent event);

/// Controller for imperative WebView commands through DCFlight tunnel.
///
/// **What you can do:**
/// - `evaluateJavaScript()`: Run arbitrary JavaScript and get result
/// - `postMessage()`: Send typed messages (Dart → JavaScript)
/// - `reload()`: Reload current page
/// - `goBack()` / `goForward()`: Navigate history
///
/// **Example - Send commands from Dart to JavaScript:**
/// ```dart
/// final controller = DCFWebViewController();
///
/// // In a button callback:
/// onPressed: () async {
///   // 1. Send a command to JavaScript
///   await controller.postMessage({
///     'type': 'updateUser',
///     'name': 'Alice',
///     'score': 1500,
///   });
///
///   // 2. Execute arbitrary JavaScript
///   final result = await controller.evaluateJavaScript(
///     "document.getElementById('status').textContent"
///   );
///   debugPrint('Status: $result');
/// }
/// ```
///
/// **In your JavaScript (HTML string):**
/// ```html
/// <script>
///   // JavaScript receives messages from Dart
///   window.dcfBridge.onNativeMessage = (payload) => {
///     if (payload.type === 'updateUser') {
///       console.log(`User: ${payload.name}, Score: ${payload.score}`);
///       document.getElementById('status').textContent = 'Updated!';
///     }
///   };
/// </script>
/// ```
class DCFWebViewController {
  DCFComponentNode? _component;

  void attach(DCFComponentNode component) {
    _component = component;
  }

  int? get viewId => _component?.effectiveNativeViewId;

  /// Wait for the WebView to be mounted (get a native viewId)
  /// with optional timeout (default 5 seconds)
  Future<int> waitForMount({Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final id = viewId;
      if (id != null) return id;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    throw StateError(
      'WebView failed to mount within ${timeout.inMilliseconds}ms. '
      'Ensure the component is rendered and native initialization is complete.',
    );
  }

  Future<dynamic> invoke(String method, [Map<String, dynamic> params = const {}]) async {
    // Try to get viewId, but wait a bit if not available yet
    var resolvedViewId = viewId;
    if (resolvedViewId == null) {
      // Wait up to 500ms for the view to be mounted
      try {
        resolvedViewId = await waitForMount(timeout: const Duration(milliseconds: 500));
      } catch (e) {
        throw StateError(
          'WebView is not mounted yet. No native viewId available. '
          'This usually means the component is still initializing or not visible.',
        );
      }
    }

    return FrameworkTunnel.call('WebView', method, {
      'viewId': resolvedViewId,
      ...params,
    });
  }

  Future<dynamic> evaluateJavaScript(String script) => invoke('evaluateJavaScript', {
        'script': script,
      });

  Future<dynamic> postMessage(dynamic message) => invoke('postMessage', {
        'message': message,
      });

  Future<dynamic> reload() => invoke('reload');
  Future<dynamic> goBack() => invoke('goBack');
  Future<dynamic> goForward() => invoke('goForward');
}

/// WebView properties
class DCFWebViewProps {
  /// The URL to load or HTML string content
  final String source;

  /// Loading mode (URL, HTML string, or local file)
  final DCFWebViewLoadMode loadMode;

  /// Content type being loaded
  final DCFWebViewContentType contentType;

  /// Whether JavaScript is enabled
  final bool javaScriptEnabled;

  /// Whether the webview allows inline media playback
  final bool allowsInlineMediaPlayback;

  /// Whether media playback requires user action
  final bool mediaPlaybackRequiresUserAction;

  /// Whether the webview supports zoom
  final bool allowsZoom;

  /// Whether to show scroll indicators
  final bool showsScrollIndicators;

  /// Whether to bounce on scroll
  final bool bounces;

  /// Whether scrolling is enabled
  final bool scrollEnabled;

  /// Whether to automatically adjust content insets
  final bool automaticallyAdjustContentInsets;

  /// User agent string
  final String? userAgent;

  /// Create webview props
  const DCFWebViewProps({
    required this.source,
    this.loadMode = DCFWebViewLoadMode.url,
    this.contentType = DCFWebViewContentType.html,
    this.javaScriptEnabled = true,
    this.allowsInlineMediaPlayback = true,
    this.mediaPlaybackRequiresUserAction = true,
    this.allowsZoom = true,
    this.showsScrollIndicators = true,
    this.bounces = true,
    this.scrollEnabled = true,
    this.automaticallyAdjustContentInsets = true,
    this.userAgent,
  });

  /// Convert to props map
  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'loadMode': loadMode.name,
      'contentType': contentType.name,
      'javaScriptEnabled': javaScriptEnabled,
      'allowsInlineMediaPlayback': allowsInlineMediaPlayback,
      'mediaPlaybackRequiresUserAction': mediaPlaybackRequiresUserAction,
      'allowsZoom': allowsZoom,
      'showsScrollIndicators': showsScrollIndicators,
      'bounces': bounces,
      'scrollEnabled': scrollEnabled,
      'automaticallyAdjustContentInsets': automaticallyAdjustContentInsets,
      if (userAgent != null) 'userAgent': userAgent,
    };
  }
}

/// WebView component for loading dynamic content
///
/// ## What WebView can do:
///
/// 1. **Load HTML strings** - Embedded HTML with custom JavaScript
/// 2. **Load URLs** - Remote websites or local assets
/// 3. **Receive events from JavaScript** - Typed bridge events
/// 4. **Send commands to JavaScript** - Imperatively modify page
/// 5. **Evaluate JavaScript** - Execute code and get results
///
/// ## JavaScript ↔ Dart Communication
///
/// ### JavaScript → Dart (Events)
/// JavaScript sends events to Dart via `window.dcfBridge.postEvent()`:
///
/// ```javascript
/// // In your HTML/JavaScript:
/// document.getElementById('button').addEventListener('click', () => {
///   window.dcfBridge.postEvent('buttonClicked', {
///     id: 'myButton',
///     timestamp: Date.now(),
///   });
/// });
/// ```
///
/// Dart receives as typed events:
///
/// ```dart
/// DCFWebView(
///   onBridgeEvent: (event) {
///     if (event.type == 'buttonClicked') {
///       final id = event.payload['id'] as String?;
///       debugPrint('Button clicked: $id');
///     }
///   },
/// )
/// ```
///
/// ### Dart → JavaScript (Commands)
/// Dart sends commands via `controller.postMessage()`:
///
/// ```dart
/// final webViewController = DCFWebViewController();
///
/// // Send a command to JavaScript
/// await webViewController.postMessage({
///   'type': 'setTheme',
///   'theme': 'dark',
/// });
/// ```
///
/// JavaScript receives in `window.dcfBridge.onNativeMessage`:
///
/// ```javascript
/// window.dcfBridge.onNativeMessage = (payload) => {
///   if (payload.type === 'setTheme') {
///     document.body.className = payload.theme;
///   }
/// };
/// ```
///
/// ## Event Handlers Available
///
/// - **onLoadStart**: Called when page starts loading
/// - **onLoadEnd**: Called when page finishes loading
/// - **onLoadError**: Called if page fails to load
/// - **onMessage**: Raw message handler (low-level)
/// - **onBridgeEvent**: Typed bridge event handler (recommended)
/// - **onLoadProgress**: Called on loading progress updates
///
/// ## Complete Example: Interactive Web Form
///
/// ```dart
/// final controller = DCFWebViewController();
///
/// DCFWebView(
///   webViewProps: DCFWebViewProps(
///     source: '''
///       <!DOCTYPE html>
///       <html>
///         <body>
///           <input id="name" type="text" placeholder="Enter name">
///           <button onclick="sendData()">Submit</button>
///           <p id="result"></p>
///
///           <script>
///             function sendData() {
///               const name = document.getElementById('name').value;
///               window.dcfBridge.postEvent('formSubmit', { name });
///             }
///
///             window.dcfBridge.onNativeMessage = (payload) => {
///               if (payload.type === 'showResult') {
///                 document.getElementById('result').textContent =
///                   `Hello, ${payload.name}!`;
///               }
///             };
///           </script>
///         </body>
///       </html>
///     ''',
///     loadMode: DCFWebViewLoadMode.htmlString,
///   ),
///   controller: controller,
///   onBridgeEvent: (event) {
///     if (event.type == 'formSubmit') {
///       final name = event.payload['name'] as String?;
///       // Process in Dart
///       // Send result back to JavaScript
///       controller.postMessage({
///         'type': 'showResult',
///         'name': name,
///       });
///     }
///   },
/// )
/// ```
///
/// ## When to Use What
///
/// | Task | Solution |
/// |------|----------|
/// | Simple HTML viewing | Just use `DCFWebView` with HTML |
/// | Interactive forms | Use bridge events + typed handlers |
/// | GPU/WebGL canvas | Use `DCFWebGPUView` (higher-level) |
/// | Complex web apps | Use DCFWebView + controller imperatively |
/// | Deep native integration | Use controller.evaluateJavaScript() |
class DCFWebView extends DCFStatelessComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// The webview properties
  final DCFWebViewProps webViewProps;

  /// Optional imperative controller (evaluate JS, post message, reload, etc.)
  final DCFWebViewController? controller;

  /// The layout properties
  final DCFLayout layout;

  /// The style properties
  final DCFStyleSheet styleSheet;

  /// Event handlers
  final Map<String, dynamic>? events;

  /// Called when page loading starts
  final Function(Map<dynamic, dynamic>)? onLoadStart;

  /// Called when page loading finishes
  final Function(Map<dynamic, dynamic>)? onLoadEnd;

  /// Called when page loading fails
  final Function(Map<dynamic, dynamic>)? onLoadError;

  /// Called when navigation is about to happen
  final Function(Map<dynamic, dynamic>)? onNavigationStateChange;

  /// Called when a message is received from JavaScript
  final Function(Map<dynamic, dynamic>)? onMessage;

  /// Called when JavaScript message is decoded into a typed bridge event
  final DCFWebViewBridgeEventHandler? onBridgeEvent;

  /// Called when loading progress changes
  final Function(Map<dynamic, dynamic>)? onLoadProgress;

  /// Create a webview component
  DCFWebView({
    required this.webViewProps,
    this.controller,
    this.layout = const DCFLayout(
      height: 400,
      width: 300,
    ),
    this.styleSheet = const DCFStyleSheet(),
    this.onLoadStart,
    this.onLoadEnd,
    this.onLoadError,
    this.onNavigationStateChange,
    this.onMessage,
    this.onBridgeEvent,
    this.onLoadProgress,
    this.events,
    super.key,
  });

  @override
  DCFComponentNode render() {
    final eventMap = <String, dynamic>{
      ...(events ?? <String, dynamic>{}),
    };

    if (onLoadStart != null) {
      eventMap['onLoadStart'] = onLoadStart;
    }

    if (onLoadEnd != null) {
      eventMap['onLoadEnd'] = onLoadEnd;
    }

    if (onLoadError != null) {
      eventMap['onLoadError'] = onLoadError;
    }

    if (onNavigationStateChange != null) {
      eventMap['onNavigationStateChange'] = onNavigationStateChange;
    }

    if (onLoadProgress != null) {
      eventMap['onLoadProgress'] = onLoadProgress;
    }

    if (onMessage != null || onBridgeEvent != null) {
      eventMap['onMessage'] = (Map<dynamic, dynamic> raw) {
        onMessage?.call(raw);
        if (onBridgeEvent != null) {
          final bridgeEvent = DCFWebViewBridgeEvent.fromOnMessage(raw);
          onBridgeEvent!.call(bridgeEvent);
        }
      };
    }

    final element = DCFElement(
      type: 'WebView',
      elementProps: {
        ...webViewProps.toMap(),
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: [], // WebView is a leaf node
    );
    // Attach controller to the actual DCFElement so it receives the native viewId
    controller?.attach(element);
    return element;
  }
}

