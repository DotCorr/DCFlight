import 'package:dcf_go/style.dart';
import 'package:dcf_primitives/dcf_primitives.dart' hide DCFCanvas;
import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' show Colors;

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
              animatedStyle: Reanimated.bounce(
                bounceScale: 1.2,
                duration: 1000,
                repeat: true,
              ),
              autoStart: isAnimating.state,
              children: [
                DCFView(
                  layout: layouts['animatedBox'],
                  styleSheet: styles['animatedBox'],
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
                  content: isAnimating.state ? "Stop Animation" : "Start Animation",
                  textProps: DCFTextProps(fontSize: 14),
                  styleSheet: styles['buttonText'],
                ),
              ],
            ),
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
              onPaint: (SkiaCanvas canvas, Size size) {
                // Draw a simple animated circle to demonstrate Skia rendering
                final centerX = size.width / 2;
                final centerY = size.height / 2;
                final radius = 50.0;
                
                // Create paint for the circle
                final paint = SkiaPaint();
                // paint.color = const Color(0xFF00FF00);
                // paint.style = SkiaPaintStyle.fill;
                
                // Draw circle (this is a placeholder - actual Skia drawing would happen natively)
                // In production, this would call native Skia canvas methods
                canvas.drawCircle(centerX, centerY, radius, paint);
              },
              repaintOnFrame: true,
              backgroundColor: const Color(0xFF1a1a2e),
              layout: layouts['canvasBox'],
            ),
            DCFButton(
              onPress: (DCFButtonPressData data) {
                canvasAnimation.setState(canvasAnimation.state + 1);
              },
              styleSheet: styles['demoButton'],
              layout: layouts['button'],
              children: [
                DCFText(
                  content: "Redraw Canvas (Frame: ${canvasAnimation.state})",
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
                      ),
                      styleSheet: styles['buttonText'],
                    ),
                  ],
                ),
              ],
            ),

        // Confetti overlay (absolute positioned)
        if (showConfetti.state)
          DCFConfetti(
            particleCount: 100,
            duration: 3000,
            config: const ConfettiConfig(
              gravity: 9.8,
              initialVelocity: 80.0,
              spread: 360.0,
              colors: [
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.yellow,
                Colors.purple,
                Colors.cyan,
                Colors.orange,
                Colors.pink,
              ],
              minSize: 5.0,
              maxSize: 12.0,
            ),
            onComplete: () {
              showConfetti.setState(false);
            },
            layout: layouts['confettiOverlay'],
            ),
          ],
        );
  }
}
