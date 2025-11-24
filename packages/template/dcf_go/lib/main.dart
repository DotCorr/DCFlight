import 'package:dcf_go/style.dart';
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart';

void main() async {
  await DCFlight.go(app: ReanimatedSkiaGPUDemo());
}

/// Demo app showcasing Reanimated, Skia Canvas, and GPU rendering
class ReanimatedSkiaGPUDemo extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final showConfetti = useState<bool>(false);
    final canvasAnimation = useState<int>(0);
    final isAnimating = useState<bool>(false);

    return DCFView(
      layout: layouts['root'],
      children: [
        // Confetti overlay (absolute positioned - MUST be sibling of ScrollView, not child)
        if (showConfetti.state)
          DCFConfetti(
            config: ConfettiConfig(
              particleCount: 100,
              startVelocity: 8, // Pixels per tick (realistic launch speed)
              spread: 360, // Full circle spread
              angle: 270, // Shoot upward
              gravity: 0.3, // Downward acceleration per tick
              drift: 0.1, // Horizontal drift per tick
              decay: 0.97, // Velocity retained per tick (97%)
              // ticks: 300, // Lifetime in ticks (5 seconds at 60fps)

              colors: [
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.yellow,
                Colors.purple,
                const Color(0xFFFF6B6B),
                Colors.orange,
                Colors.pink,
                DCFColors.amber,
                DCFColors.brown,
                DCFColors.cyan,
                DCFColors.deepPurple,
              ],
              scalar: 1.0, // Increased from 1.0 to make particles bigger
            ),
            onComplete: () {
              showConfetti.setState(false);
            },
            layout: layouts['confettiOverlay'],
            styleSheet: styles['confettiOverlay'],
          ),
        DCFScrollView(
          layout: layouts['root'],
          styleSheet: styles['root'],
          children: [
            // Header
            DCFView(
              layout: layouts['header'],
              styleSheet: styles['header'],
              children: [
                DCFText(
                  content: "🎨 DCFlight Demo",
                  textProps: DCFTextProps(
                    fontSize: 28,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['titleText'],
                  layout: layouts['title'],
                ),
                DCFText(
                  content: "Reanimated • Skia Canvas • GPU Rendering",
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: styles['subtitleText'],
                  layout: layouts['subtitle'],
                ),
              ],
            ),

            // Reanimated Section
            DCFView(
              layout: layouts['section'],
              styleSheet: styles['section'],
              children: [
                DCFText(
                  content: "⚡ Reanimated - UI Thread Animations",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['sectionTitle'],
                  layout: layouts['sectionTitle'],
                ),
                ReanimatedView(
                  styleSheet: styles['animatedBox'],
                  animatedStyle: Reanimated.bounce(
                    bounceScale: 1.2,
                    duration: 1000,
                    repeat: true,
                  ),
                  autoStart: isAnimating.state,
                  children: [
                    DCFView(
                      layout: layouts['animatedBox'],

                      children: [
                        DCFText(
                          content: "60fps\nPure Native",
                          textProps: DCFTextProps(
                            fontSize: 16,
                            fontWeight: DCFFontWeight.bold,
                          ),
                          styleSheet: styles['boxText'],
                        ),
                      ],
                    ),
                  ],
                ),
                DCFButton(
                  onPress: (DCFButtonPressData data) {
                    isAnimating.setState(!isAnimating.state);
                  },
                  styleSheet: styles['demoButton'],
                  layout: layouts['button'],
                  children: [
                    DCFText(
                      content:
                          isAnimating.state
                              ? "Stop Animation"
                              : "Start Animation",
                      textProps: DCFTextProps(
                        fontSize: 14,
                        textAlign: DCFTextAlign.center,
                      ),
                      styleSheet: styles['buttonText'],
                    ),
                  ],
                ),
              ],
            ),

            // NEW: Declarative Canvas Animation (RN Skia Pattern)
            DCFView(
              layout: layouts['section'],
              styleSheet: styles['section'],
              children: [
                DCFText(
                  content: "✨ Declarative Canvas (RN Skia Pattern)",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['sectionTitle'],
                  layout: layouts['sectionTitle'],
                ),
                DCFText(
                  content: "AnimatedValue + Declarative Components",
                  textProps: DCFTextProps(fontSize: 12),
                  styleSheet: styles['descText'],
                ),
                // _DeclarativeAnimationDemo(),
              ],
            ),

            // Skia Canvas Section
            DCFView(
              layout: layouts['section'],
              styleSheet: styles['section'],
              children: [
                DCFText(
                  content: "🎨 Skia Canvas - GPU 2D Drawing",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['sectionTitle'],
                  layout: layouts['sectionTitle'],
                ),
                DCFCanvas(
                  key: 'static-canvas',
                  backgroundColor: const Color(0xFF1a1a2e),
                  layout: layouts['canvasBox'],
                  size: const Size(300, 300),
                  onPaint: (canvas, size) {
                    // Draw a green circle using Flutter's Canvas API
                    final paint =
                        Paint()
                          ..color = const Color(0xFF00FF00)
                          ..style = PaintingStyle.fill;
                    canvas.drawCircle(
                      Offset(size.width / 2, size.height / 2),
                      50,
                      paint,
                    );
                  
                  },
                ),
                DCFButton(
                  onPress: (DCFButtonPressData data) {
                    canvasAnimation.setState(canvasAnimation.state + 1);
                  },
                  styleSheet: styles['demoButton'],
                  layout: layouts['button'],
                  children: [
                    DCFText(
                      content:
                          "Redraw Canvas (Frame: ${canvasAnimation.state})",
                      textProps: DCFTextProps(fontSize: 14),
                      styleSheet: styles['buttonText'],
                    ),
                  ],
                ),
              ],
            ),

            // GPU/Confetti Section
            DCFView(
              layout: layouts['section'],
              styleSheet: styles['section'],
              children: [
                DCFText(
                  content: "🚀 GPU Rendering - Particle Effects",
                  textProps: DCFTextProps(
                    fontSize: 18,
                    fontWeight: DCFFontWeight.bold,
                  ),
                  styleSheet: styles['sectionTitle'],
                  layout: layouts['sectionTitle'],
                ),
                DCFView(
                  layout: layouts['gpuDemoBox'],
                  styleSheet: styles['gpuDemoBox'],
                  children: [
                    DCFText(
                      content: "Tap to celebrate!",
                      textProps: DCFTextProps(fontSize: 16),
                      styleSheet: styles['boxText'],
                    ),
                  ],
                ),
                DCFButton(
                  onPress: (DCFButtonPressData data) {
                    showConfetti.setState(true);
                    // Auto-hide after animation
                    Future.delayed(const Duration(milliseconds: 3000), () {
                      showConfetti.setState(false);
                    });
                  },
                  styleSheet: styles['demoButton'],
                  layout: layouts['button'],
                  children: [
                    DCFText(
                      content: "🎉 Launch Confetti",
                      textProps: DCFTextProps(
                        fontSize: 16,
                        fontWeight: DCFFontWeight.bold,
                        textAlign: DCFTextAlign.center,
                      ),
                      styleSheet: styles['buttonText'],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

