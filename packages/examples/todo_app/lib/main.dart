import 'dart:math' as math;

import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/dcflight.dart';

/// User-written shader script - this is the ONLY thing developers write
/// The canvas HTML, lifecycle, and bridge handlers are all managed by DCFWebGPUView
const String kLabGpuShaderScript = r'''
  // Detect GPU capability and run appropriate renderer
  (async function () {
    // Reference to native state (automatically updated by DCFWebGPUView bridge)
    const nativeState = window.nativeState;
    const canvas = document.getElementById('dcf-canvas');
    const emitToDcf = function(message, payload) {
      try {
        if (typeof postToDcf === 'function') {
          postToDcf(message, payload);
        }
      } catch (_) {}
    };

    const setCanvasStatus = function(text) {
      try {
        if (typeof setStatus === 'function') {
          setStatus(text);
          return;
        }
      } catch (_) {}
      const el = document.getElementById('dcf-canvas-status');
      if (el) {
        el.textContent = String(text);
      }
    };

    function clamp01(value) {
      return Math.max(0, Math.min(1, value));
    }

    function resizeCanvas() {
      const rect = canvas.getBoundingClientRect();
      const dpr = Math.max(1, window.devicePixelRatio || 1);
      const w = Math.max(1, Math.floor(rect.width * dpr));
      const h = Math.max(1, Math.floor(rect.height * dpr));
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }
      return { w, h };
    }

    async function runWebGpu() {
      if (!navigator.gpu) return false;
      const canvas = document.getElementById('dcf-canvas');
      const adapter = await navigator.gpu.requestAdapter();
      if (!adapter) return false;
      const device = await adapter.requestDevice();
      const context = canvas.getContext('webgpu');
      if (!context) return false;

      const format = navigator.gpu.getPreferredCanvasFormat();
      const uniformBuffer = device.createBuffer({
        size: 32,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
      });

      const shader = device.createShaderModule({
        code: `
struct Uniforms {
  time: f32, width: f32, height: f32, boost: f32, pointerX: f32, pointerY: f32, pad0: f32, pad1: f32,
}
@group(0) @binding(0) var<uniform> u: Uniforms;
struct VsOut { @builtin(position) position: vec4f, }
@vertex fn vs(@builtin(vertex_index) index: u32) -> VsOut {
  var points = array<vec2f, 3>(vec2f(-1.0, -1.0), vec2f(-1.0,  3.0), vec2f( 3.0, -1.0));
  return VsOut(vec4f(points[index], 0.0, 1.0));
}
fn hash(p: vec2f) -> f32 { return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453123); }
fn noise(p: vec2f) -> f32 {
  let i = floor(p); let f = fract(p);
  let a = hash(i); let b = hash(i + vec2f(1.0, 0.0)); let c = hash(i + vec2f(0.0, 1.0)); let d = hash(i + vec2f(1.0, 1.0));
  let u2 = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u2.x), mix(c, d, u2.x), u2.y);
}
@fragment fn fs(@builtin(position) pos: vec4f) -> @location(0) vec4f {
  let res = vec2f(u.width, u.height);
  var uv = (pos.xy / res) * 2.0 - vec2f(1.0, 1.0);
  uv.x *= u.width / max(1.0, u.height);
  let t = u.time * 0.55; let r = length(uv); let a = atan2(uv.y, uv.x);
  let ring = smoothstep(0.16, 0.0, abs(r - 0.42 + 0.04 * sin(a * 8.0 - t * 3.0)));
  let tunnel = 1.0 / (1.0 + 7.0 * r * r); let swirl = noise(vec2f(a * 2.1 + t * 0.7, r * 7.0 - t * 1.4));
  let pulse = 0.5 + 0.5 * sin(t * 3.4 + r * 18.0 - a * 4.0);
  let pointer = vec2f(u.pointerX * 2.0 - 1.0, (1.0 - u.pointerY) * 2.0 - 1.0);
  let cursorGlow = exp(-distance(uv, pointer) * 8.0);
  let boost = 1.0 + u.boost * 0.55;
  let cyan = vec3f(0.32, 0.86, 1.0); let magenta = vec3f(1.0, 0.26, 0.72); let deep = vec3f(0.01, 0.02, 0.06);
  var color = deep;
  color += cyan * tunnel * (0.55 + 0.45 * swirl) * boost;
  color += magenta * ring * (0.5 + pulse * 0.7) * boost;
  color += vec3f(1.0, 0.95, 0.85) * pow(max(0.0, 1.0 - r * 1.8), 8.0) * 0.55;
  color += vec3f(0.85, 0.95, 1.0) * cursorGlow * (0.22 + u.boost * 0.12);
  return vec4f(color, 1.0);
}`,
      });

      const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: { module: shader, entryPoint: 'vs' },
        fragment: { module: shader, entryPoint: 'fs', targets: [{ format }] },
        primitive: { topology: 'triangle-list' },
      });

      const bindGroup = device.createBindGroup({
        layout: pipeline.getBindGroupLayout(0),
        entries: [{ binding: 0, resource: { buffer: uniformBuffer } }],
      });

      let startTime = performance.now();
      function frame(ms) {
        const elapsed = ms - startTime;
        const size = resizeCanvas();
        context.configure({ device, format, alphaMode: 'opaque' });
        const uniforms = new Float32Array([
          elapsed * 0.001, size.w, size.h, nativeState.boost,
          nativeState.pointerX, nativeState.pointerY, 0.0, 0.0,
        ]);
        device.queue.writeBuffer(uniformBuffer, 0, uniforms);
        const encoder = device.createCommandEncoder();
        const pass = encoder.beginRenderPass({
          colorAttachments: [{
            view: context.getCurrentTexture().createView(),
            loadOp: 'clear', storeOp: 'store',
            clearValue: [0.01, 0.01, 0.03, 1.0],
          }],
        });
        pass.setPipeline(pipeline);
        pass.setBindGroup(0, bindGroup);
        pass.draw(3, 1, 0, 0);
        pass.end();
        device.queue.submit([encoder.finish()]);
        requestAnimationFrame(frame);
      }
      emitToDcf({ type: 'renderer', mode: 'webgpu' });
      requestAnimationFrame(frame);
      return true;
    }

    function runWebGl2() {
      const canvas = document.getElementById('dcf-canvas');
      const gl = canvas.getContext('webgl2', { antialias: true });
      if (!gl) return false;

      const vs = gl.createShader(gl.VERTEX_SHADER);
      gl.shaderSource(vs, `#version 300 es
void main() {
  vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`);
      gl.compileShader(vs);

      const fs = gl.createShader(gl.FRAGMENT_SHADER);
      gl.shaderSource(fs, `#version 300 es
precision highp float;
uniform float uTime; uniform vec2 uRes; uniform float uBoost; uniform vec2 uPointer;
out vec4 fragColor;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
void main() {
  vec2 uv = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
  uv.x *= uRes.x / max(1.0, uRes.y);
  float t = uTime * 0.55; float r = length(uv); float a = atan(uv.y, uv.x);
  float ring = smoothstep(0.16, 0.0, abs(r - 0.42 + 0.04 * sin(a * 8.0 - t * 3.0)));
  float tunnel = 1.0 / (1.0 + 7.0 * r * r);
  float swirl = noise(vec2(a * 2.1 + t * 0.7, r * 7.0 - t * 1.4));
  float pulse = 0.5 + 0.5 * sin(t * 3.4 + r * 18.0 - a * 4.0);
  vec2 pointer = vec2(uPointer.x * 2.0 - 1.0, (1.0 - uPointer.y) * 2.0 - 1.0);
  float cursorGlow = exp(-distance(uv, pointer) * 8.0);
  float boost = 1.0 + uBoost * 0.55;
  vec3 color = vec3(0.01, 0.02, 0.06);
  color += vec3(0.32, 0.86, 1.0) * tunnel * (0.55 + 0.45 * swirl) * boost;
  color += vec3(1.0, 0.26, 0.72) * ring * (0.5 + pulse * 0.7) * boost;
  color += vec3(1.0, 0.95, 0.85) * pow(max(0.0, 1.0 - r * 1.8), 8.0) * 0.55;
  color += vec3(0.85, 0.95, 1.0) * cursorGlow * (0.22 + uBoost * 0.12);
  fragColor = vec4(color, 1.0);
}`);
      gl.compileShader(fs);

      const program = gl.createProgram();
      gl.attachShader(program, vs);
      gl.attachShader(program, fs);
      gl.linkProgram(program);
      gl.useProgram(program);

      const timeLoc = gl.getUniformLocation(program, 'uTime');
      const resLoc = gl.getUniformLocation(program, 'uRes');
      const boostLoc = gl.getUniformLocation(program, 'uBoost');
      const pointerLoc = gl.getUniformLocation(program, 'uPointer');

      let startTime = performance.now();
      function frame(ms) {
        const elapsed = ms - startTime;
        const size = resizeCanvas();
        gl.viewport(0, 0, size.w, size.h);
        gl.uniform1f(timeLoc, elapsed * 0.001);
            gl.uniform2f(resLoc, size.w, size.h);
            gl.uniform1f(boostLoc, nativeState.boost);
            gl.uniform2f(pointerLoc, nativeState.pointerX, nativeState.pointerY);
            gl.drawArrays(gl.TRIANGLES, 0, 3);
            requestAnimationFrame(frame);
          }

          setCanvasStatus('WebGL2 shader');
          emitToDcf({ type: 'renderer', mode: 'webgl2' });
          requestAnimationFrame(frame);
          return true;
        }

        let isPointerDown = false;

        function syncPointer(event, type) {
          const rect = canvas.getBoundingClientRect();
          const x = event.clientX - rect.left;
          const y = event.clientY - rect.top;
          nativeState.pointerX = clamp01(x / Math.max(1, rect.width));
          nativeState.pointerY = clamp01(y / Math.max(1, rect.height));
          emitToDcf({ type, x, y, pointerX: nativeState.pointerX, pointerY: nativeState.pointerY });
        }

        canvas.addEventListener('pointerdown', function (event) {
          isPointerDown = true;
          syncPointer(event, 'pointerDown');
        });

        canvas.addEventListener('pointermove', function (event) {
          // Track drag on any pointer motion while down (works on Android WebView)
          if (isPointerDown) {
            syncPointer(event, 'pointerDrag');
          }
        });

        canvas.addEventListener('pointerup', function (event) {
          isPointerDown = false;
        });

        canvas.addEventListener('pointercancel', function (event) {
          isPointerDown = false;
        });

        try {
          const ranGpu = await runWebGpu();
          if (!ranGpu) {
              setCanvasStatus('WebGPU required');
              emitToDcf({ type: 'renderer', mode: 'error', message: 'WebGPU not available' });
              console.error('WebGPU not available on this device');
          }
        } catch (err) {
            setCanvasStatus('WebGPU error');
          emitToDcf({ type: 'renderer', mode: 'error', message: String(err) });
          console.error(err);
        }
      })();
''';

void main() async {
  await DCFlight.go(app: AppRoot());
}

/// App Root - Handles navigation between landing page and StyleSheet examples
class AppRoot extends DCFStatefulComponent {
  AppRoot({super.key});

  @override
  DCFComponentNode render() {
    final showExamples = useState<bool>(true);
    final webViewController = useState<DCFWebViewController>(DCFWebViewController());
    final bridgeRenderer = useState<String>('boot');
    final bridgePointer = useState<String>('x: -, y: -');

    if (showExamples.state) {
      return DCFScrollView(
        layout: const DCFLayout(width: '100%', height: '100%'),
        styleSheet: DCFStyleSheet(backgroundColor: DCFColors.black),
        showsScrollIndicator: false,
        scrollContent: [
          DCFView(
            layout: const DCFLayout(
              width: '100%',
              minHeight: '100%',
              paddingHorizontal: 24,
              paddingVertical: 24,
              gap: 20,
            ),
            children: [
              DCFButton(
                layout: const DCFLayout(
                  alignSelf: DCFAlign.flexStart,
                  paddingHorizontal: 14,
                  paddingVertical: 10,
                ),
                styleSheet: DCFStyleSheet(
                  backgroundColor: DCFColors.gray900,
                  borderRadius: 4,
                  borderWidth: 1,
                  borderColor: DCFColors.gray700,
                ),
                onPress: (_) => showExamples.setState(false),
                children: [
                  DCFText(
                    content: "← Back",
                    textProps: DCFTextProps(fontSize: 14),
                    styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                  ),
                ],
              ),
              DCFText(
                content: "The Lab",
                textProps: DCFTextProps(
                  fontSize: 36,
                  fontWeight: DCFFontWeight.medium,
                  letterSpacing: -1,
                ),
                styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
              ),
              DCFView(
                layout: const DCFLayout(width: '100%', gap: 8),
                children: [
                  DCFView(
                    layout: DCFLayout(
                      width: '100%',
                      flexDirection: DCFFlexDirection.row,
                      justifyContent: DCFJustifyContent.spaceBetween,
                    ),
                    children: [
                      DCFText(
                        content: 'Renderer: ${bridgeRenderer.state}',
                        textProps: DCFTextProps(fontSize: 12),
                        styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray700),
                      ),
                      DCFText(
                        content: bridgePointer.state,
                        textProps: DCFTextProps(fontSize: 12),
                        styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray700),
                      ),
                    ],
                  ),
                  DCFButton(
                    layout: const DCFLayout(
                      alignSelf: DCFAlign.flexStart,
                      paddingHorizontal: 10,
                      paddingVertical: 6,
                    ),
                    styleSheet: DCFStyleSheet(
                      backgroundColor: DCFColors.gray900,
                      borderWidth: 1,
                      borderColor: DCFColors.gray700,
                      borderRadius: 4,
                    ),
                    onPress: (_) async {
                      await webViewController.state.setBoost(1.8);
                    },
                    children: [
                      DCFText(
                        content: 'Send Boost From Dart',
                        textProps: DCFTextProps(fontSize: 12),
                        styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
                      ),
                    ],
                  ),
                  DCFWebGPUView(
                    controller: webViewController.state,
                    gpuViewProps: DCFWebGPUViewProps(
                      script: kLabGpuShaderScript,
                      preload: true,
                    ),
                    onEvent: (event) {
                      // Debug log all events
                      print('🎨 GPU Event: type=${event.type}, payload=${event.payload}');
                      
                      if (event.type == 'renderer') {
                        bridgeRenderer.setState(event.payload['mode']?.toString() ?? 'unknown');
                      } else if (event.type == 'pointerDown' || event.type == 'pointerDrag') {
                        final x = event.payload['x'];
                        final y = event.payload['y'];
                        String format(dynamic value) {
                          if (value is num) {
                            return value.toStringAsFixed(1);
                          }
                          return value?.toString() ?? '-';
                        }
                        bridgePointer.setState('x: ${format(x)}, y: ${format(y)}');
                      } else if (event.type == 'ready') {
                        print('✅ Canvas Ready!');
                      }
                    },
                    layout: const DCFLayout(width: '100%', height: 260),
                    styleSheet: DCFStyleSheet(
                      borderWidth: 1,
                      borderColor: DCFColors.gray700,
                      borderRadius: 12,
                      backgroundColor: DCFColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return DCFView(layout: DCFLayout(width: '100%', height: '100%'), children: [
      // Content wrapper - this changes when navigating

      DotCorrLanding(
        // key: 'landing-screen',
        onToggleExamples: () {
          showExamples.setState(true);
        },
      )
    ]);
  }
}

/// DotCorr Landing Page - Matching Web Design
class DotCorrLanding extends DCFStatelessComponent {
  final VoidCallback? onToggleExamples;

  DotCorrLanding({this.onToggleExamples, super.key});

  @override
  DCFComponentNode render() {
    return DCFScrollView(
      layout: DCFLayout(width: '100%', height: '100%'),
      showsScrollIndicator: false,
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.white),
      scrollContent: [
        NavigationBar(onToggleExamples: onToggleExamples),
        HeroSection(onEnterLab: onToggleExamples),
        // EcosystemSection(),
        BuildersAndMachinesSection(),
        TechnologyEcosystemSection(),
        AboutSection(),
        Footer(),
      ],
    );
  }
}

class NavigationBar extends DCFStatelessComponent {
  final VoidCallback? onToggleExamples;

  NavigationBar({this.onToggleExamples, super.key});

  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    final safeAreaTop = screenUtils.safeAreaTop;

    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 16 + safeAreaTop,
        paddingBottom: 16,
        paddingHorizontal: 24,
        flexDirection: DCFFlexDirection.row,
        justifyContent: DCFJustifyContent.spaceBetween,
        alignItems: DCFAlign.center,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.white,
        borderBottomWidth: 1,
        borderBottomColor: DCFColors.gray100,
      ),
      children: [
        // Logo Area - CRITICAL: Add flexShrink to prevent overflow
        DCLogo(size: 20),
        // Links - CRITICAL: Add flexShrink and minWidth: 0 to prevent overflow
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 24,
            flexShrink: 1, // Allow shrinking to prevent overflow
            flexGrow: 0, // Don't grow
            minWidth: 0, // CRITICAL: Allow shrinking below content size
          ),
          children: [
            DCFText(
              content: "The Lab",
              textProps: DCFTextProps(
                fontSize: 14,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line with truncation
              ),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(
                flexShrink: 1, // Allow text to shrink
                minWidth: 0, // CRITICAL: Allow shrinking below content size
              ),
            ),
            // GitHub Icon placeholder (text for now)
            DCFText(
              content: "GitHub",
              textProps: DCFTextProps(
                fontSize: 14,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line with truncation
              ),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
              layout: DCFLayout(
                flexShrink: 1, // Allow text to shrink
                minWidth: 0, // CRITICAL: Allow shrinking below content size
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HeroSection extends DCFStatelessComponent {
  final VoidCallback? onEnterLab;

  HeroSection({this.onEnterLab, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 128, // pt-32 = 128px (matches web)
        paddingBottom: 80, // pb-20 = 80px (matches web)
        paddingHorizontal: 24,
        flexDirection: DCFFlexDirection.column,
        gap: 48,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.white),
      children: [
        // Main content row (left text + right visual)
        DCFView(
          layout: DCFLayout(
            width: '100%',
            flexDirection: DCFFlexDirection.column,
            gap: 48,
          ),
          children: [
            // Left Content
            DCFView(
              layout: DCFLayout(width: '100%', gap: 32),
              children: [
                DCFView(
                  layout: DCFLayout(
                    width: '100%',
                    gap: 24,
                  ),
                  children: [
                    // Split text to match web styling - "For The" in gray
                    DCFView(
                      layout: DCFLayout(
                        width:
                            '100%', // CRITICAL: Constrain width to prevent overflow
                        flexDirection: DCFFlexDirection.column,
                        gap: 0,
                      ),
                      children: [
                        DCFText(
                          content: "Building",
                          textProps: DCFTextProps(
                            fontSize: 48,
                            fontWeight: DCFFontWeight.medium,
                            lineHeight: 1.1,
                            letterSpacing: -1.5,
                          ),
                          styleSheet: DCFStyleSheet(
                            primaryColor: DCFColors.black,
                          ),
                        ),
                        DCFText(
                          content: "Infrastructure",
                          textProps: DCFTextProps(
                            fontSize: 48,
                            fontWeight: DCFFontWeight.medium,
                            lineHeight: 1.1,
                            letterSpacing: -1.5,
                          ),
                          styleSheet: DCFStyleSheet(
                            primaryColor: DCFColors.black,
                          ),
                        ),
                        DCFView(
                          layout: DCFLayout(
                            width:
                                '100%', // CRITICAL: Constrain row width to prevent overflow
                            flexDirection: DCFFlexDirection.row,
                            gap: 0,
                            flexWrap:
                                DCFWrap.wrap, // Allow wrapping on small devices
                          ),
                          children: [
                            DCFText(
                              // Layout constraints (flexShrink, minWidth) are now applied automatically
                              // by DCFText component to prevent overflow - no need to specify manually
                              content: "For The ",
                              textProps: DCFTextProps(
                                fontSize: 48,
                                fontWeight: DCFFontWeight.medium,
                                lineHeight: 1.1,
                                letterSpacing: -1.5,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: DCFColors.gray300,
                              ),
                            ),
                            DCFText(
                              // Layout constraints (flexShrink, minWidth) are now applied automatically
                              // by DCFText component to prevent overflow - no need to specify manually
                              content: "Inevitable.",
                              textProps: DCFTextProps(
                                fontSize: 48,
                                fontWeight: DCFFontWeight.medium,
                                lineHeight: 1.1,
                                letterSpacing: -1.5,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: DCFColors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Use the same stable typewriter path on both platforms
                    // until worklet cursor rendering matches native text parity.
                    DCFView(
                      layout: DCFLayout(
                        width: '100%', // CRITICAL: Constrain width to prevent overflow
                        height: 80, // h-20 = 80px (matches web)
                        justifyContent: DCFJustifyContent.center,
                        alignItems: DCFAlign.flexStart,
                        marginBottom: 40, // mb-10 = 40px (matches web)
                        overflow: DCFOverflow.hidden, // Clip content that exceeds bounds
                      ),
                      children: [
                        TypewriterEffect(),
                      ],
                    ),

                    // Button
                    DCFView(
                      layout: DCFLayout(
                        flexDirection: DCFFlexDirection.row,
                        alignItems: DCFAlign.center,
                      ),
                      children: [
                        DCFButton(
                          layout: DCFLayout(
                            paddingHorizontal: 32,
                            paddingVertical: 16,
                            flexDirection: DCFFlexDirection.row,
                            alignItems: DCFAlign.center,
                            gap: 12,
                          ),
                          styleSheet: DCFStyleSheet(
                            backgroundColor: DCFColors.black,
                            borderRadius: 2, // Small radius like web
                          ),
                          onPress: (data) {
                            onEnterLab?.call();
                          },
                          children: [
                            DCFText(
                              content: "Enter The Lab",
                              textProps: DCFTextProps(
                                fontSize: 16,
                                fontWeight: DCFFontWeight.medium,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: DCFColors.white,
                              ),
                            ),
                            DCFText(
                              content: "→",
                              textProps: DCFTextProps(
                                fontSize: 16,
                                fontWeight: DCFFontWeight.medium,
                              ),
                              styleSheet: DCFStyleSheet(
                                primaryColor: DCFColors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  ],
                ),
              ],
            ),

            // Right Visual (3D Box effect using Reanimated)
            DCFView(
              layout: DCFLayout(
                width: '100%',
                height: 400, // Fixed height container for the visual
                alignItems: DCFAlign.center,
                justifyContent: DCFJustifyContent.center,
              ),
              children: [InfrastructureVisual()],
            ),
          ],
        ),
      ],
    );
  }
}

/// Typewriter Effect Component
///
/// CURRENT IMPLEMENTATION: Uses Dart timers and state (runs on Dart thread)
/// - 2-12% CPU usage
/// - Bridge calls for every character update
/// - Can be blocked by Dart thread operations
///
/// FUTURE: Will migrate to worklet-based implementation (runs on UI thread)
/// - <1% CPU usage expected
/// - Zero bridge calls during animation
/// - 60fps guaranteed, cannot be blocked
class TypewriterEffect extends DCFStatefulComponent {
  late final int _startMs = DateTime.now().millisecondsSinceEpoch;

  _TypewriterFrame _computeFrame(int elapsedMs, List<String> words) {
    const int typeMsPerChar = 85;
    const int deleteMsPerChar = 50;
    const int holdFullWordMs = 1200;
    const int holdEmptyMs = 220;

    int cycleMs = 0;
    for (final word in words) {
      cycleMs += (word.length * typeMsPerChar) +
          holdFullWordMs +
          (word.length * deleteMsPerChar) +
          holdEmptyMs;
    }

    if (cycleMs <= 0) {
      return const _TypewriterFrame('', true);
    }

    int t = elapsedMs % cycleMs;

    for (final word in words) {
      final typeDuration = word.length * typeMsPerChar;
      final deleteDuration = word.length * deleteMsPerChar;

      if (t < typeDuration) {
        final chars = (t ~/ typeMsPerChar) + 1;
        final visible = chars.clamp(1, word.length);
        return _TypewriterFrame(word.substring(0, visible), true);
      }
      t -= typeDuration;

      if (t < holdFullWordMs) {
        return _TypewriterFrame(word, true);
      }
      t -= holdFullWordMs;

      if (t < deleteDuration) {
        final charsToDelete = t ~/ deleteMsPerChar;
        final remaining = (word.length - charsToDelete).clamp(1, word.length);
        return _TypewriterFrame(word.substring(0, remaining), false);
      }
      t -= deleteDuration;

      if (t < holdEmptyMs) {
        return const _TypewriterFrame('', false);
      }
      t -= holdEmptyMs;
    }

    return const _TypewriterFrame('', true);
  }

  @override
  DCFComponentNode render() {
    final words = [
      "Build for Mobile.",
      "Build for Web.",
      "Build for AI.",
      "Build for AGI.",
      "Build for The Future.",
    ];

    final forceRebuild = useState<int>(0);

    // Periodic pump to force rebuild, avoiding state-update stalls on iOS.
    useEffect(() {
      int tick = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        tick += 1;
        forceRebuild.setState(tick);
      });
      return () => timer.cancel();
    }, dependencies: []);

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _startMs;
    final frame = _computeFrame(elapsedMs, words);
    final cursorVisible = ((elapsedMs ~/ 450) % 2) == 0;
    final cursorChar = (cursorVisible || frame.keepCursorOn) ? '|' : ' ';

    // Keep the text block width stable while rendering the cursor inline with
    // the text so it stays attached to the active word.
    final longestWord = words.reduce((a, b) => a.length > b.length ? a : b);
    final estimatedWidth = longestWord.length * 13.0;

    return DCFView(
      layout: DCFLayout(
        flexDirection: DCFFlexDirection.row,
        alignItems: DCFAlign.center,
        width: estimatedWidth + 12,
        minWidth: estimatedWidth + 12,
        maxWidth: estimatedWidth + 12,
      ),
      children: [
        DCFText(
          content: "\$ ${frame.text}$cursorChar",
          textProps: DCFTextProps(
            fontSize: 20,
            fontFamily: 'monospace',
            numberOfLines: 1,
            textAlign: DCFTextAlign.left,
          ),
          layout: DCFLayout(
            width: estimatedWidth + 12,
            minWidth: estimatedWidth + 12,
            maxWidth: estimatedWidth + 12,
            flexShrink: 1,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
        ),
      ],
    );
  }
}

class _TypewriterFrame {
  final String text;
  final bool keepCursorOn;

  const _TypewriterFrame(this.text, this.keepCursorOn);
}

/// Worklet-based Typewriter Effect (runs on UI thread)
///
/// This is the optimized version that runs entirely on the UI thread with zero bridge calls.
/// It uses AnimatedText component with a worklet function.
@Worklet()
String typewriterWorklet(
  double elapsed,
  List<String> words,
  double typeSpeed,
  double deleteSpeed,
  double pauseDuration,
) {
  // Calculate total time per word cycle
  double totalTimePerCycle = 0;
  for (String word in words) {
    totalTimePerCycle += (word.length * typeSpeed / 1000.0) +
        pauseDuration / 1000.0 +
        (word.length * deleteSpeed / 1000.0);
  }

  // Find current word and position based on elapsed time
  double cycleTime = elapsed % totalTimePerCycle;
  int wordIndex = 0;
  double accumulatedTime = 0;

  for (int i = 0; i < words.length; i++) {
    String word = words[i];
    double wordTypeTime = word.length * typeSpeed / 1000.0;
    double wordPauseTime = pauseDuration / 1000.0;
    double wordDeleteTime = word.length * deleteSpeed / 1000.0;
    double wordTotalTime = wordTypeTime + wordPauseTime + wordDeleteTime;

    if (cycleTime <= accumulatedTime + wordTotalTime) {
      wordIndex = i;
      break;
    }
    accumulatedTime += wordTotalTime;
  }

  String currentWord = words[wordIndex];
  double wordStartTime = accumulatedTime;
  double wordTypeTime = currentWord.length * typeSpeed / 1000.0;
  double wordPauseTime = pauseDuration / 1000.0;

  double relativeTime = cycleTime - wordStartTime;

  String visibleText;
  bool keepCursorOn;

  if (relativeTime < wordTypeTime) {
    // Typing phase
    int charIndex = (relativeTime / (typeSpeed / 1000.0)).floor() + 1;
    int visibleChars = math.max(1, math.min(charIndex, currentWord.length));
    visibleText = currentWord.substring(0, visibleChars);
    keepCursorOn = true;
  } else if (relativeTime < wordTypeTime + wordPauseTime) {
    // Pause phase - show full word
    visibleText = currentWord;
    keepCursorOn = true;
  } else {
    // Deleting phase
    double deleteStartTime = wordTypeTime + wordPauseTime;
    double deleteElapsed = relativeTime - deleteStartTime;
    int charsToDelete = (deleteElapsed / (deleteSpeed / 1000.0)).floor();
    int remainingChars = math.max(1, currentWord.length - charsToDelete);
    visibleText = currentWord.substring(
      0,
      math.min(remainingChars, currentWord.length),
    );
    keepCursorOn = false;
  }

  final elapsedMs = (elapsed * 1000).floor();
  final cursorVisible = ((elapsedMs ~/ 450) % 2) == 0;
  final cursorChar = (cursorVisible || keepCursorOn) ? '|' : ' ';
  return r'$ ' + visibleText + cursorChar;
}

/// Worklet-based typewriter effect using AnimatedText
class TypewriterEffectWorklet extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final words = [
      "Build for Mobile.",
      "Build for Web.",
      "Build for AI.",
      "Build for AGI.",
      "Build for The Future.",
    ];
    final longestWord = words.reduce((a, b) => a.length > b.length ? a : b);
    final estimatedWidth = longestWord.length * 13.0;

    return DCFView(
      layout: DCFLayout(
        flexDirection: DCFFlexDirection.row,
        alignItems: DCFAlign.center,
        width: estimatedWidth + 12,
        minWidth: estimatedWidth + 12,
        maxWidth: estimatedWidth + 12,
      ),
      children: [
        AnimatedText(
          worklet: typewriterWorklet,
          layout: DCFLayout(
            width: estimatedWidth + 12,
            minWidth: estimatedWidth + 12,
            maxWidth: estimatedWidth + 12,
            flexShrink: 1,
          ),
          initialText: '\$ ',
          workletConfig: {
            'words': words,
            'typeSpeed': 85.0,
            'deleteSpeed': 50.0,
            'pauseDuration': 1200.0,
          },
          textProps: DCFTextProps(
            fontSize: 20,
            fontFamily: "monospace",
            numberOfLines: 1,
            textAlign: DCFTextAlign.left,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray600),
        ),
      ],
    );
  }
}

class InfrastructureVisual extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final size = 200.0;

    // Temporary native-safe visual while Motion/Reanimated low-level behavior
    // is being phased out in favor of native animation APIs and WebGPU effects.
    return DCFView(
      layout: DCFLayout(
        width: size,
        height: size,
        alignItems: DCFAlign.center,
        justifyContent: DCFJustifyContent.center,
      ),
      children: [
        // Base (Black background)
        DCFView(
          layout: DCFLayout(
            width: size,
            height: size,
            position: DCFPositionType.absolute,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.black,
            borderWidth: 1,
            borderColor: DCFColors.gray900,
          ),
        ),

        // Tower (static placeholder)
        DCFView(
          layout: DCFLayout(
            width: size * 0.35,
            height: size * 0.35,
            position: DCFPositionType.absolute,
            absoluteLayout: AbsoluteLayout(top: size * 0.15, left: size * 0.15),
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.white,
            shadowColor: DCFColors.white,
            shadowRadius: 20,
            shadowOpacity: 0.4,
          ),
          children: [],
        ),
      ],
    );
  }
}

class BuildersAndMachinesSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingVertical: 128, // py-32 = 128px (matches web)
        paddingHorizontal: 24,
        flexDirection: DCFFlexDirection.column,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray50),
      children: [
        // Header section - mb-20 = 80px
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 80,
            flexDirection: DCFFlexDirection.column,
            gap: 32,
          ),
          children: [
            DCFText(
              layout: DCFLayout(width: '100%'),
              content: "Infrastructure for\nBuilders & Machines",
              textProps: DCFTextProps(
                fontSize: 48, // text-5xl = 48px (matches web)
                fontWeight: DCFFontWeight.medium,
                letterSpacing: -1,
                lineHeight: 1.1,
                numberOfLines:
                    0, // Allow unlimited lines - CRITICAL for multi-line text
              ),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
            ),
            DCFText(
              content:
                  "We provide the tools to build native applications today and the cognitive architecture for the intelligent systems of tomorrow.",
              textProps: DCFTextProps(
                fontSize: 20, // text-xl = 20px (matches web)
                lineHeight: 1.6,
              ),
              styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray500),
            ),
          ],
        ),
        // Cards - gap-8 = 32px
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.column,
            gap: 32, // gap-8 = 32px (matches web)
          ),
          children: [
            _buildCard(
              "For Builders",
              "Direct access to native platform capabilities. Write Dart once, render true native UI components. No abstractions, no compromises.",
              DCFColors.white,
              DCFColors.black,
              "Explore DCFlight",
            ),
            _buildCard(
              "For Machines",
              "The cognitive layer for artificial intelligence. We build the foundational systems required to support autonomous agents and AGI.",
              DCFColors.black,
              DCFColors.white,
              "Explore DCCortex",
            ),
          ],
        ),
      ],
    );
  }

  DCFComponentNode _buildCard(
    String title,
    String desc,
    Color bg,
    Color text,
    String linkText,
  ) {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        padding: 40, // p-10 = 40px (matches web)
        flexDirection: DCFFlexDirection.column,
        alignItems: DCFAlign.flexStart, // Align items to start
        flexShrink: 0, // Don't shrink - let content define height
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: bg,
        borderWidth: bg == DCFColors.white ? 1 : 0,
        borderColor:
            bg == DCFColors.white ? DCFColors.gray200 : DCFColors.transparent,
        borderRadius: 8,
        shadowColor: DCFColors.black,
        shadowOpacity: bg == DCFColors.white ? 0.05 : 0.3,
        shadowRadius: bg == DCFColors.white ? 4 : 12,
        shadowOffsetX: 0,
        shadowOffsetY: bg == DCFColors.white ? 1 : 4,
      ),
      children: [
        // Icon - matches web w-12 h-12 = 48px
        DCFView(
          layout: DCFLayout(
            width: 48,
            height: 48,
            alignItems: DCFAlign.center,
            justifyContent: DCFJustifyContent.center,
            marginBottom: 24, // mb-6 = 24px
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor:
                bg == DCFColors.white ? DCFColors.black : DCFColors.white,
            borderRadius: 4,
          ),
          children: [
            DCFText(
              content: bg == DCFColors.white ? "📱" : "🧠",
              textProps: DCFTextProps(
                fontSize: 24,
                textAlign: DCFTextAlign.center,
              ),
              styleSheet: DCFStyleSheet(
                primaryColor:
                    bg == DCFColors.white ? DCFColors.white : DCFColors.black,
              ),
            ),
          ],
        ),
        // Title - text-2xl font-bold mb-3
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 12, // mb-3 = 12px
          ),
          children: [
            DCFText(
              content: title,
              textProps: DCFTextProps(
                fontSize: 24, // text-2xl = 24px
                fontWeight: DCFFontWeight.bold,
                textAlign: DCFTextAlign.left, // Left align text
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: text,
              ),
            ),
          ],
        ),
        // Description - mb-8 - CRITICAL: Must have width: 100% to wrap properly
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 32, // mb-8 = 32px
            flexShrink: 0, // Don't shrink
          ),
          children: [
            DCFText(
              content: desc,
              textProps: DCFTextProps(
                fontSize: 16,
                lineHeight: 1.5,
                numberOfLines:
                    0, // Allow unlimited lines - CRITICAL for multi-line text
                textAlign: DCFTextAlign.left, // Left align text
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: text == DCFColors.black
                    ? DCFColors.gray500
                    : DCFColors.gray300,
              ),
              // Remove explicit width - let text size naturally based on parent constraints
              // Yoga will automatically constrain it to parent's available width (after padding)
            ),
          ],
        ),
        // Link - inline-flex items-center gap-2
        DCFView(
          layout: DCFLayout(
            flexDirection: DCFFlexDirection.row,
            alignItems: DCFAlign.center,
            gap: 8, // gap-2 = 8px
            justifyContent:
                DCFJustifyContent.flexStart, // Align to start (left)
          ),
          children: [
            DCFText(
              content: linkText,
              textProps: DCFTextProps(
                fontSize: 16,
                fontWeight: DCFFontWeight.medium,
                numberOfLines: 1, // Single line for link
                textAlign: DCFTextAlign.left, // Left align text
              ),
              styleSheet: DCFStyleSheet(primaryColor: text),
              layout: DCFLayout(
                flexShrink:
                    0, // Text should not shrink - let it truncate if needed
              ),
            ),
            DCFText(
              content: "→",
              textProps: DCFTextProps(
                fontSize: 16,
                textAlign: DCFTextAlign.left, // Left align arrow
              ),
              styleSheet: DCFStyleSheet(primaryColor: text),
              layout: DCFLayout(
                flexShrink: 0, // Arrow should not shrink
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TechnologyEcosystemSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingVertical: 80,
        paddingHorizontal: 24,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.white),
      children: [
        DCFText(
          content: "Built for the Modern Stack",
          textProps: DCFTextProps(
            fontSize: 32,
            fontWeight: DCFFontWeight.bold,
            letterSpacing: -1,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.black),
        ),
      ],
    );
  }
}

class AboutSection extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingVertical: 80,
        paddingHorizontal: 24,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.gray900),
      children: [
        DCFText(
          content: "Designing the Cognitive Future",
          textProps: DCFTextProps(
            fontSize: 32,
            fontWeight: DCFFontWeight.bold,
            letterSpacing: -1,
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.white),
        ),
      ],
    );
  }
}

class Footer extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    final screenUtils = ScreenUtilities.instance;
    final safeAreaBottom = screenUtils.safeAreaBottom;

    return DCFView(
      layout: DCFLayout(
        width: '100%',
        paddingTop: 48,
        paddingBottom: 32 + safeAreaBottom,
        paddingHorizontal: 24,
        gap: 40,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.white),
      children: [
        DCFText(
          content: "© 2025 DotCorr. All rights reserved.",
          textProps: DCFTextProps(fontSize: 14),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.gray500),
        ),
      ],
    );
  }
}

