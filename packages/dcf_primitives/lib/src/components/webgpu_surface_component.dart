/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';

import 'webview_component.dart';

/// Preset scene configurations for the WebGPU surface.
enum DCFWebGpuScene {
  cubeLogo,
  gridPulse,
}

/// WebGPU surface properties.
///
/// This component intentionally exposes a WebGPU-capable surface through WebView,
/// so browser-native GPU APIs can be used for drawing-intensive visuals.
class DCFWebGpuSurfaceProps {
  /// Built-in scene preset.
  final DCFWebGpuScene scene;

  /// Optional raw HTML escape hatch.
  ///
  /// Prefer typed props for consistency. If provided, this takes precedence.
  final String? html;

  /// Scene label shown in the status overlay.
  final String sceneLabel;

  /// Optional glyph rendered at scene center.
  final String centerGlyph;

  /// Base background color for the surface.
  final String backgroundColor;

  /// Accent color for scene wireframes/effects.
  final String accentColor;

  /// Text color for labels and glyph.
  final String textColor;

  /// Rotation speed multiplier for animated scene.
  final double rotationSpeed;

  /// Whether to show runtime status overlay.
  final bool showStatus;

  /// Enables JavaScript execution for rendering logic.
  final bool javaScriptEnabled;

  /// Whether user can zoom the surface.
  final bool allowsZoom;

  /// Whether scroll bounce is enabled.
  final bool bounces;

  /// Whether scroll is enabled.
  final bool scrollEnabled;

  /// Whether scroll indicators are visible.
  final bool showsScrollIndicators;

  const DCFWebGpuSurfaceProps({
    this.scene = DCFWebGpuScene.cubeLogo,
    this.html,
    this.sceneLabel = 'browser-native gpu surface',
    this.centerGlyph = 'DC',
    this.backgroundColor = '#080808',
    this.accentColor = '#7dd3fc',
    this.textColor = '#e5e5e5',
    this.rotationSpeed = 1.0,
    this.showStatus = true,
    this.javaScriptEnabled = true,
    this.allowsZoom = false,
    this.bounces = false,
    this.scrollEnabled = false,
    this.showsScrollIndicators = false,
  });

  static String _escapeJs(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
  }

  /// Build HTML from typed props. Raw HTML is supported as a fallback.
  String toHtml() {
    if (html != null && html!.trim().isNotEmpty) {
      return html!;
    }

    final escapedLabel = _escapeJs(sceneLabel);
    final escapedGlyph = _escapeJs(centerGlyph);
    final escapedBg = _escapeJs(backgroundColor);
    final escapedAccent = _escapeJs(accentColor);
    final escapedText = _escapeJs(textColor);

    final sceneToken = scene == DCFWebGpuScene.gridPulse ? 'gridPulse' : 'cubeLogo';
    final speed = rotationSpeed <= 0 ? 0.2 : rotationSpeed;
    final statusDisplay = showStatus ? 'block' : 'none';

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      :root {
        --bg0: $escapedBg;
        --bg1: #121212;
        --line: #2a2a2a;
        --ink: $escapedText;
        --accent: $escapedAccent;
      }
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: radial-gradient(circle at 20% 20%, var(--bg1), var(--bg0) 70%);
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      }
      canvas {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        display: block;
        min-width: 1px;
        min-height: 1px;
      }
      #boot {
        position: absolute;
        inset: 0;
        display: grid;
        place-items: center;
        pointer-events: none;
        color: var(--ink);
        background:
          radial-gradient(circle at 50% 45%, rgba(125, 211, 252, 0.14), transparent 40%),
          radial-gradient(circle at 18% 20%, rgba(255, 255, 255, 0.06), transparent 25%),
          radial-gradient(circle at 82% 78%, rgba(255, 255, 255, 0.04), transparent 22%),
          linear-gradient(180deg, rgba(10, 10, 10, 0.98), rgba(4, 4, 4, 0.98));
        opacity: 1;
        transition: opacity 180ms ease;
      }
      #boot.ready { opacity: 0; }
      #bootCard {
        width: min(84%, 360px);
        aspect-ratio: 1.25;
        border-radius: 18px;
        border: 1px solid rgba(125, 211, 252, 0.30);
        background:
          linear-gradient(90deg, rgba(125, 211, 252, 0.14) 1px, transparent 1px),
          linear-gradient(180deg, rgba(125, 211, 252, 0.14) 1px, transparent 1px),
          rgba(0, 0, 0, 0.72);
        background-size: 22px 22px, 22px 22px, auto;
        box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.04) inset;
        position: relative;
        overflow: hidden;
      }
      #bootCard::before {
        content: '';
        position: absolute;
        inset: 18% 14%;
        border-radius: 999px;
        border: 1px solid rgba(125, 211, 252, 0.15);
      }
      #bootCard::after {
        content: '$escapedGlyph';
        position: absolute;
        inset: 0;
        display: grid;
        place-items: center;
        font-size: 42px;
        font-weight: 600;
        letter-spacing: 0.04em;
        color: rgba(229, 229, 229, 0.9);
      }
      #status {
        position: absolute;
        left: 10px;
        bottom: 8px;
        display: $statusDisplay;
        color: var(--ink);
        font-size: 11px;
        letter-spacing: 0.2px;
        padding: 4px 8px;
        border: 1px solid var(--line);
        background: rgba(0, 0, 0, 0.55);
      }
      .ok { color: var(--accent); }
    </style>
  </head>
  <body>
    <canvas id="surface"></canvas>
    <div id="boot">
      <div id="bootCard"></div>
    </div>
    <div id="status">checking gpu...</div>
    <script>
      (function () {
        const canvas = document.getElementById('surface');
        const status = document.getElementById('status');
        const boot = document.getElementById('boot');
        const ctx = canvas.getContext('2d');
        const scene = '$sceneToken';
        const sceneLabel = '$escapedLabel';
        const glyph = '$escapedGlyph';
        const speed = ${speed.toStringAsFixed(4)};
        let bootHidden = false;

        function resize() {
          const dpr = Math.max(1, window.devicePixelRatio || 1);
          const w = Math.max(1, window.innerWidth);
          const h = Math.max(1, window.innerHeight);
          canvas.width = Math.floor(w * dpr);
          canvas.height = Math.floor(h * dpr);
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        }

        resize();
        window.addEventListener('resize', resize);

        const hasWebGpu = !!(navigator && navigator.gpu);
        status.innerHTML = hasWebGpu
          ? '<span class="ok">WebGPU ready</span> - ' + sceneLabel
          : 'WebGPU unavailable - Canvas fallback rendering';

        const points = [
          [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
          [-1, -1,  1], [1, -1,  1], [1, 1,  1], [-1, 1,  1],
        ];
        const edges = [
          [0,1],[1,2],[2,3],[3,0],
          [4,5],[5,6],[6,7],[7,4],
          [0,4],[1,5],[2,6],[3,7],
        ];

        function rotateY(p, a) {
          const c = Math.cos(a), s = Math.sin(a);
          return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c];
        }

        function rotateX(p, a) {
          const c = Math.cos(a), s = Math.sin(a);
          return [p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c];
        }

        function project(p, w, h, scale, zOffset) {
          const z = p[2] + zOffset;
          const inv = 1 / Math.max(0.15, z);
          return [
            w * 0.5 + p[0] * scale * inv,
            h * 0.5 + p[1] * scale * inv,
          ];
        }

        let t = 0;
        function draw() {
          const w = window.innerWidth;
          const h = window.innerHeight;
          ctx.clearRect(0, 0, w, h);

          if (!bootHidden) {
            boot.classList.add('ready');
            bootHidden = true;
          }

          if (scene === 'gridPulse') {
            const cell = Math.max(16, Math.min(w, h) * 0.08);
            const pulse = 0.5 + Math.sin(t * speed * 2.0) * 0.5;
            ctx.strokeStyle = 'rgba(125, 211, 252,' + (0.2 + pulse * 0.5).toFixed(2) + ')';
            ctx.lineWidth = 1;
            for (let x = 0; x <= w; x += cell) {
              ctx.beginPath();
              ctx.moveTo(x, 0);
              ctx.lineTo(x, h);
              ctx.stroke();
            }
            for (let y = 0; y <= h; y += cell) {
              ctx.beginPath();
              ctx.moveTo(0, y);
              ctx.lineTo(w, y);
              ctx.stroke();
            }
          }

          ctx.strokeStyle = 'rgba(125, 211, 252, 0.85)';
          ctx.lineWidth = 1.2;

          const transformed = points.map((p) => {
            const y = rotateY(p, t * 0.9 * speed);
            return rotateX(y, 0.55 + Math.sin(t * 0.5 * speed) * 0.15);
          });

          const projected = transformed.map((p) => project(p, w, h, Math.min(w, h) * 0.85, 3.7));

          for (const [a, b] of edges) {
            const p1 = projected[a];
            const p2 = projected[b];
            ctx.beginPath();
            ctx.moveTo(p1[0], p1[1]);
            ctx.lineTo(p2[0], p2[1]);
            ctx.stroke();
          }

          ctx.font = '600 28px ui-monospace, SFMono-Regular, Menlo, monospace';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = 'rgba(229, 229, 229, 0.92)';
          ctx.fillText(glyph, w * 0.5, h * 0.5);

          t += 0.016;
          requestAnimationFrame(draw);
        }

        requestAnimationFrame(draw);
      })();
    </script>
  </body>
</html>
''';
  }
}

/// Exposed WebGPU surface component backed by DCFWebView.
class DCFWebGpuSurface extends DCFStatefulComponent
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.low;

  final DCFWebGpuSurfaceProps webGpuProps;
  final String _htmlSource;
  final String _webViewKey;
  final DCFLayout layout;
  final DCFStyleSheet styleSheet;
  final bool fillWidth;
  final bool fillHeight;
  final bool fillScrollContent;

  DCFWebGpuSurface({
    required this.webGpuProps,
    this.layout = const DCFLayout(width: '100%', height: 180),
    this.styleSheet = const DCFStyleSheet(),
    this.fillWidth = false,
    this.fillHeight = false,
    this.fillScrollContent = false,
    String? webViewKey,
    super.key,
  })  : _htmlSource = webGpuProps.toHtml(),
        _webViewKey = webViewKey ??
            'webgpu-${webGpuProps.scene.name}-${webGpuProps.sceneLabel.hashCode}-${webGpuProps.centerGlyph.hashCode}-${layout.hashCode}-${styleSheet.hashCode}-${fillWidth ? 1 : 0}-${fillHeight ? 1 : 0}-${fillScrollContent ? 1 : 0}';

  @override
  DCFComponentNode render() {
    final mergedLayout = layout.copyWith(
      width: fillWidth ? '100%' : layout.width,
      minWidth: fillWidth ? '100%' : layout.minWidth,
      alignSelf: fillWidth ? DCFAlign.stretch : layout.alignSelf,
      height: fillHeight ? '100%' : layout.height,
      minHeight: fillHeight ? '100%' : layout.minHeight,
      flexGrow: fillScrollContent ? 1 : layout.flexGrow,
      flexShrink: fillScrollContent ? 0 : layout.flexShrink,
    );

    return DCFWebView(
      layout: mergedLayout,
      styleSheet: styleSheet,
      webViewProps: DCFWebViewProps(
        source: _htmlSource,
        loadMode: DCFWebViewLoadMode.htmlString,
        contentType: DCFWebViewContentType.html,
        javaScriptEnabled: webGpuProps.javaScriptEnabled,
        allowsZoom: webGpuProps.allowsZoom,
        bounces: webGpuProps.bounces,
        scrollEnabled: webGpuProps.scrollEnabled,
        showsScrollIndicators: webGpuProps.showsScrollIndicators,
        mediaPlaybackRequiresUserAction: false,
      ),
      key: _webViewKey,
    ).renderedNode;
  }
}
