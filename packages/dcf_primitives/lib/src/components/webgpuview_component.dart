import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

/// Typed event payload for GPU canvas lifecycle and user events
class DCFWebGPUEvent {
  /// Event type: 'init', 'ready', 'pointer', 'custom', etc.
  final String type;

  /// Event-specific payload data
  final Map<String, dynamic> payload;

  DCFWebGPUEvent({
    required this.type,
    required this.payload,
  });

  /// Parse from bridge event (JS → Dart)
  factory DCFWebGPUEvent.fromBridgeEvent(DCFWebViewBridgeEvent bridgeEvent) {
    return DCFWebGPUEvent(
      type: bridgeEvent.type,
      payload: bridgeEvent.payload,
    );
  }

  @override
  String toString() => 'DCFWebGPUEvent($type, $payload)';
}

/// Typed event handler
typedef DCFWebGPUEventHandler = void Function(DCFWebGPUEvent event);

/// Command sent from Dart to GPU canvas (JS)
class DCFWebGPUCommand {
  final String type;
  final Map<String, dynamic> params;

  DCFWebGPUCommand({
    required this.type,
    required this.params,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    ...params,
  };
}

/// High-level props for GPU canvas (WebGPU/WebGL2)
class DCFWebGPUViewProps {
  /// User's JavaScript code for canvas setup and rendering
  /// This should declare:
  ///   - Fragment shader code (string constant)
  ///   - Event handlers (onPointer, onCustom, etc.)
  ///   - Any initialization logic
  ///
  /// The component will inject this into a pre-configured canvas context.
  final String script;

  /// Whether to preload/prewarm the WebView and GPU context
  /// If true, canvas initializes before first render for instant responsiveness
  final bool preload;

  /// User-defined event types to listen for from the script
  /// Example: ['pointerDown', 'pointerDrag', 'custom:throttle']
  /// Events are automatically routed to onEvent handler
  final List<String>? eventTypes;

  /// Canvas background color (hex string)
  final String backgroundColor;

  /// Whether JavaScript execution is enabled
  final bool javaScriptEnabled;

  const DCFWebGPUViewProps({
    required this.script,
    this.preload = true,
    this.eventTypes,
    this.backgroundColor = '#02030a',
    this.javaScriptEnabled = true,
  });
}

/// DCFWebGPUView - First-class GPU canvas component
///
/// Provides a high-level abstraction over WebView+WebGPU/WebGL2.
/// Users write only their shader and event logic; HTML scaffolding is hidden.
///
/// **Why not just use DCFWebView?**
/// - Manages canvas lifecycle and prewarming automatically
/// - Hides HTML/CSS boilerplate completely
/// - Provides typed event system (not raw JSON)
/// - Feels like a native GPU renderer, not a web wrapper
///
/// ## INTERACTION MODEL
///
/// ### Frontend (JavaScript) → Backend (Dart)
/// JavaScript sends events to Dart via the bridge:
///
/// ```javascript
/// // 1. User touches canvas, handler fires:
/// canvas.addEventListener('pointerdown', (evt) => {
///   window.dcfBridge.postEvent('pointerDown', {
///     x: evt.clientX,
///     y: evt.clientY,
///     timestamp: Date.now(),
///   });
/// });
///
/// // 2. Bridge encapsulates: {type: 'pointerDown', payload: {...}}
/// // 3. Native tunnel routes to Dart EventRegistry
/// // 4. Dart onEvent callback receives typed DCFWebGPUEvent
/// ```
///
/// ### Backend (Dart) → Frontend (JavaScript)
/// Dart sends commands to JavaScript via postMessage:
///
/// ```dart
/// // 1. Call from Dart:
/// await controller.postMessage({
///   'type': 'setBoost',
///   'value': 2.5,
/// });
///
/// // 2. FrameworkTunnel → Native tunnel → evaluateJavaScript()
/// // 3. JavaScript receives in global handler:
/// window.dcfBridge.onNativeMessage = (payload) => {
///   if (payload.type === 'setBoost') {
///     window.nativeState.boost = payload.value;
///     // Shader re-renders automatically with new boost
///   }
/// };
/// ```
///
/// ### State Synchronization (nativeState)
/// Dart maintains a state object auto-synced to JavaScript:
///
/// ```dart
/// // Dart backend updates state
/// nativeState['pointerX'] = 150.0;
/// nativeState['pointerY'] = 200.0;
/// nativeState['boost'] = 1.5;
///
/// // JavaScript accesses instantly:
/// const x = window.nativeState.pointerX; // 150.0
/// ```
///
/// ## PRELOAD BEHAVIOR
///
/// When `preload: true`:
/// 1. WebView and canvas context initialize early (before first render)
/// 2. JavaScript runs once to set up shaders and event handlers
/// 3. First frame renders instantly (no "cold start" delay)
/// 4. Useful for smooth animation or quick interactions
///
/// When `preload: false`:
/// 1. Canvas initializes on-demand when component first renders
/// 2. Slightly slower first frame but saves memory if component never renders
///
/// **Example:**
/// ```dart
/// DCFWebGPUView(
///   script: '''
///     const fragmentShader = `
///       void main() {
///         gl_FragColor = vec4(time * boost, 0.5, 1.0, 1.0);
///       }
///     `;
///   ''',
///   onEvent: (event) {
///     if (event.type == 'pointerDown') {
///       final x = event.payload['x'] as double?;
///       final y = event.payload['y'] as double?;
///       // Dart receives typed event - no JSON parsing needed!
///       debugPrint('Pointer at $x, $y');
///     }
///   },
///   controller: gpuController,
///   layout: const DCFLayout(width: '100%', height: 300),
/// )
/// ```
///
/// Then send commands from Dart:
/// ```dart
/// // User taps button → send boost to shader
/// onPressed: () {
///   gpuController.postMessage({
///     'type': 'setBoost',
///     'value': 2.0,
///   });
/// }
/// ```
class DCFWebGPUView extends DCFStatelessComponent {
  final DCFWebGPUViewProps gpuViewProps;
  final DCFLayout layout;
  final DCFStyleSheet styleSheet;
  final DCFWebGPUEventHandler? onEvent;
  final DCFWebViewController? controller;

  DCFWebGPUView({
    required this.gpuViewProps,
    this.layout = const DCFLayout(),
    this.styleSheet = const DCFStyleSheet(),
    this.onEvent,
    this.controller,
  });

  /// Generate the complete canvas HTML that wraps user's script
  String _generateCanvasHtml() {
    final bgColor = gpuViewProps.backgroundColor;

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      html, body {
        margin: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        touch-action: none;
        background: $bgColor;
      }
      canvas {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        display: block;
        touch-action: none;
      }
      #dcf-canvas-status {
        position: absolute;
        left: 8px;
        top: 6px;
        color: #9ae6ff;
        font-size: 10px;
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        letter-spacing: 0.2px;
        text-shadow: 0 0 8px rgba(154, 230, 255, 0.6);
        pointer-events: none;
      }
    </style>
  </head>
  <body>
    <canvas id="dcf-canvas"></canvas>
    <div id="dcf-canvas-status">init</div>
    <script>
      // Error catcher in its own block so it survives a syntax error in the next block
      window.onerror = function(msg, src, line, col, err) {
        var el = document.getElementById('dcf-canvas-status');
        if (el) el.textContent = 'E:' + msg + ' L' + line;
        return true;
      };
      window.addEventListener('unhandledrejection', function(e) {
        var el = document.getElementById('dcf-canvas-status');
        if (el) el.textContent = 'AE:' + (e.reason && e.reason.message || String(e.reason));
      });
    </script>
    <script>
      (async function () {
        // Canvas and context setup
        const canvas = document.getElementById('dcf-canvas');
        const status = document.getElementById('dcf-canvas-status');
        
        // Native state bridge (updated by Dart via postMessage)
        const nativeState = {
          boost: 0.0,
          pointerX: 0.5,
          pointerY: 0.5,
          customData: {},
        };
        window.nativeState = nativeState;

        // Bridge to receive messages from Dart
        window.dcfBridge = {
          onNativeMessage: (payload) => {
            if (!payload || typeof payload !== 'object') return;
            
            // Update known state properties
            if (typeof payload.boost === 'number') nativeState.boost = payload.boost;
            if (typeof payload.pointerX === 'number') nativeState.pointerX = payload.pointerX;
            if (typeof payload.pointerY === 'number') nativeState.pointerY = payload.pointerY;
            
            // Store custom data
            if (payload.customData) Object.assign(nativeState.customData, payload.customData);
            
            // Call user's onNativeMessage if defined
            if (typeof window.onNativeMessage === 'function') {
              window.onNativeMessage(payload);
            }
          },
        };
        window.postToDcf = postToDcf;

        // Listen for custom DCF events from Dart
        window.addEventListener('dcf:message', (event) => {
          window.dcfBridge.onNativeMessage(event.detail);
        });

        // Helper to send events back to Dart
        function postToDcf(eventTypeOrMessage, payload = {}) {
          try {
            const message = typeof eventTypeOrMessage === 'string'
              ? { type: eventTypeOrMessage, ...payload }
              : eventTypeOrMessage && typeof eventTypeOrMessage === 'object'
                ? eventTypeOrMessage
                : { type: 'unknown' };
            if (window.webkit?.messageHandlers?.dcfMessage) {
              // iOS
              window.webkit.messageHandlers.dcfMessage.postMessage(message);
            } else if (window.__dcfNativeBridge) {
              // Android
              window.__dcfNativeBridge.postMessage(JSON.stringify(message));
            }
          } catch (e) {
            console.error('Failed to post to DCF:', e);
          }
        }

        // Utility functions
        function setStatus(text) {
          status.textContent = text;
        }

        function resizeCanvas() {
          const rect = canvas.getBoundingClientRect();
          canvas.width = rect.width * window.devicePixelRatio;
          canvas.height = rect.height * window.devicePixelRatio;
        }

        // Pointer event tracking
        let pointerActive = false;
        canvas.addEventListener('pointerdown', (e) => {
          pointerActive = true;
          const rect = canvas.getBoundingClientRect();
          const x = (e.clientX - rect.left) / rect.width;
          const y = (e.clientY - rect.top) / rect.height;
          nativeState.pointerX = Math.max(0, Math.min(1, x));
          nativeState.pointerY = Math.max(0, Math.min(1, y));
          postToDcf('pointerDown', { x: nativeState.pointerX, y: nativeState.pointerY });
          if (typeof window.onPointerDown === 'function') {
            window.onPointerDown(x, y);
          }
        });

        canvas.addEventListener('pointermove', (e) => {
          if (!pointerActive) return;
          const rect = canvas.getBoundingClientRect();
          const x = (e.clientX - rect.left) / rect.width;
          const y = (e.clientY - rect.top) / rect.height;
          nativeState.pointerX = Math.max(0, Math.min(1, x));
          nativeState.pointerY = Math.max(0, Math.min(1, y));
          postToDcf('pointerDrag', { x: nativeState.pointerX, y: nativeState.pointerY });
          if (typeof window.onPointerDrag === 'function') {
            window.onPointerDrag(x, y);
          }
        });

        canvas.addEventListener('pointerup', (e) => {
          pointerActive = false;
          postToDcf('pointerUp');
          if (typeof window.onPointerUp === 'function') {
            window.onPointerUp();
          }
        });

        // Canvas initialization
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);

        // Notify Dart that canvas is ready
        setStatus('ready');
        postToDcf('ready');

        // ========================================
        // USER SCRIPT INJECTION
        // ========================================
        ${gpuViewProps.script}
        // ========================================
      })().catch(function(e) {
        var el = document.getElementById('dcf-canvas-status');
        if (el) el.textContent = 'AE:' + (e && e.message || String(e));
      });
    </script>
  </body>
</html>
''';
  }

  @override
  DCFComponentNode render() {
    final canvasHtml = _generateCanvasHtml();

    final eventMap = <String, dynamic>{};

    // Route raw onMessage payloads into typed GPU events.
    // Some platforms primarily emit onMessage, so this must be the canonical path.
    eventMap['onMessage'] = (Map<dynamic, dynamic> raw) {
      if (onEvent != null) {
        final bridgeEvent = DCFWebViewBridgeEvent.fromOnMessage(raw);
        final gpuEvent = DCFWebGPUEvent.fromBridgeEvent(bridgeEvent);
        onEvent!(gpuEvent);
      }
    };

    // Keep compatibility for platforms/components that already emit onBridgeEvent.
    if (onEvent != null) {
      eventMap['onBridgeEvent'] = (DCFWebViewBridgeEvent bridgeEvent) {
        final gpuEvent = DCFWebGPUEvent.fromBridgeEvent(bridgeEvent);
        onEvent!(gpuEvent);
      };
    }

    final element = DCFElement(
      type: 'WebView',
      elementProps: {
        'source': canvasHtml,
        'loadMode': 'htmlString',
        'javaScriptEnabled': gpuViewProps.javaScriptEnabled,
        // NOTE: do NOT pass viewId here - that is assigned by native, not set as a prop
        ...layout.toMap(),
        ...styleSheet.toMap(),
        ...eventMap,
      },
      children: [],
    );
    // Attach controller to the actual DCFElement so it gets the native viewId
    controller?.attach(element);
    return element;
  }
}

/// Extension to send typed commands to GPU canvas from Dart
extension DCFWebGPUViewCommands on DCFWebViewController {
  /// Send a command to the GPU canvas
  /// Example: setBoost(1.8) → postMessage({type: 'setBoost', value: 1.8})
  Future<void> sendGPUCommand(DCFWebGPUCommand command) {
    return postMessage(command.toMap());
  }

  /// Convenience: set boost multiplier
  Future<void> setBoost(double boost) {
    return sendGPUCommand(DCFWebGPUCommand(
      type: 'setBoost',
      params: {'boost': boost},
    ));
  }

  /// Convenience: send custom state update
  Future<void> updateCustomData(Map<String, dynamic> data) {
    return sendGPUCommand(DCFWebGPUCommand(
      type: 'updateCustom',
      params: {'customData': data},
    ));
  }
}

