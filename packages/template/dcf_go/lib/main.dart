import 'dart:ui' as ui;
import 'package:dcf_go/style.dart';
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcf_reanimated/dcf_reanimated.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold, Colors;
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';

void main() async {
  await DCFlight.go(app: PureNativeAndFlutterMixApp());
}


class PureNativeAndFlutterMixApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final rotationSpeed = useState<double>(0.05);
    final isRotating = useState<bool>(true);
    final buttonPressCount = useState<int>(0);
    final showConfetti = useState<bool>(false);
    final controllerRef = useRef<FlutterEarthGlobeController?>(null);
    
    if (controllerRef.current == null) {
      controllerRef.current = FlutterEarthGlobeController(
        rotationSpeed: rotationSpeed.state,
        isBackgroundFollowingSphereRotation: true,
      );
      
      controllerRef.current!.onLoaded = () async {
        final surfaceImage = await _createDefaultSphereImage();
        final byteData = await surfaceImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          controllerRef.current!.loadSurface(MemoryImage(bytes));
        }
      };
    } else {
      controllerRef.current!.rotationSpeed = rotationSpeed.state;
    }
    
    return DCFView(
      layout: layouts['root'],
      styleSheet: styles['root'],
      children: [
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: FlutterEarthGlobe(
                    controller: controllerRef.current!,
                    radius: 150,
                  ),
                ),
              ),
            );
          },
          layout: layouts['flutterWidget'],
          styleSheet: styles['emptyStyle'],
        ),
        DCFView(
          layout: layouts['controlsPanel'],
          styleSheet: styles['controlsPanel'],
          children: [
            DCFText(
              content: "3D Globe Demo",
              textProps: DCFTextProps(
                fontSize: 20,
                fontWeight: DCFFontWeight.bold,
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: buttonPressCount.state % 3 == 0 
                  ? DCFColors.white 
                  : buttonPressCount.state % 3 == 1 
                    ? DCFColors.green 
                    : DCFColors.blue,
              ),
              layout: layouts['title'],
            ),
            DCFView(
              layout: layouts['controlSection'],
              children: [
                DCFText(
                  content: "Rotation Speed: ${(rotationSpeed.state * 100).toStringAsFixed(0)}%",
                  textProps: DCFTextProps(
                    fontSize: 16,
                  ),
                  styleSheet: styles['bodyText'],
                  layout: layouts['speedText'],
                ),
                DCFView(
                  layout: layouts['buttonRow'],
                  children: [
                    DCFButton(
                      onPress: (DCFButtonPressData data) {
                        rotationSpeed.setState((rotationSpeed.state - 0.01).clamp(0.0, 0.2));
                        buttonPressCount.setState(buttonPressCount.state + 1);
                      },
                      styleSheet: DCFStyleSheet(
                        backgroundColor: Color.lerp(
                          const Color(0xFFFF5722),
                          const Color(0xFF4CAF50),
                          (rotationSpeed.state / 0.2).clamp(0.0, 1.0),
                        )!,
                        borderRadius: 8,
                      ),
                      layout: layouts['smallButton'],
                      children: [
                        DCFText(
                          content: "-",
                          textProps: DCFTextProps(
                            fontSize: 20,
                            fontWeight: DCFFontWeight.bold,
                          ),
                          styleSheet: styles['buttonText'],
                        ),
                      ],
                    ),
                    DCFButton(
                      onPress: (DCFButtonPressData data) {
                        rotationSpeed.setState((rotationSpeed.state + 0.01).clamp(0.0, 0.2));
                        buttonPressCount.setState(buttonPressCount.state + 1);
                      },
                      styleSheet: DCFStyleSheet(
                        backgroundColor: Color.lerp(
                          const Color(0xFF4CAF50),
                          const Color(0xFFFF5722),
                          (rotationSpeed.state / 0.2).clamp(0.0, 1.0),
                        )!,
                        borderRadius: 8,
                      ),
                      layout: layouts['smallButton'],
                      children: [
                        DCFText(
                          content: "+",
                          textProps: DCFTextProps(
                            fontSize: 20,
                            fontWeight: DCFFontWeight.bold,
                          ),
                          styleSheet: styles['buttonText'],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            DCFView(
              layout: layouts['controlSection'],
              children: [
                DCFButton(
                  onPress: (DCFButtonPressData data) {
                    isRotating.setState(!isRotating.state);
                  },
                  styleSheet: isRotating.state ? styles['toggleButtonActive'] : styles['toggleButton'],
                  layout: layouts['fullWidthButton'],
                  children: [
                    DCFText(
                      content: isRotating.state ? "Pause Rotation" : "Resume Rotation",
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
            DCFView(
              layout: layouts['controlSection'],
              children: [
                ReanimatedView(
                  animatedStyle: Reanimated.bounce(
                    bounceScale: 1.1,
                    duration: 300,
                    repeat: false,
                  ),
                  children: [
                    DCFButton(
                      onPress: (DCFButtonPressData data) {
                        showConfetti.setState(true);
                        buttonPressCount.setState(buttonPressCount.state + 1);
                      },
                      styleSheet: DCFStyleSheet(
                        backgroundColor: const Color(0xFFFF6B6B),
                        borderRadius: 12,
                      ),
                      layout: layouts['fullWidthButton'],
                      children: [
                        DCFText(
                          content: "🎉 Celebrate! 🎉",
                          textProps: DCFTextProps(
                            fontSize: 18,
                            fontWeight: DCFFontWeight.bold,
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
        ),
        // Confetti overlay - shows when button is pressed
        if (showConfetti.state)
          DCFConfetti(
            particleCount: 75,
            duration: 3000,
            onComplete: () {
              showConfetti.setState(false);
            },
            layout: DCFLayout(
              position: DCFPositionType.absolute,
              absoluteLayout: AbsoluteLayout(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
              ),
            ),
          ),
      ],
    );
  }
}

Future<ui.Image> _createDefaultSphereImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final size = ui.Size(512, 512);
  final center = ui.Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2 - 10;
  
  // Draw base ocean gradient
  final oceanPaint = ui.Paint()
    ..shader = ui.Gradient.radial(
      center,
      radius,
      [
        const ui.Color(0xFF4A90E2),
        const ui.Color(0xFF2E5C8A),
      ],
      [0.0, 1.0],
    );
  canvas.drawCircle(center, radius, oceanPaint);
  
  // Draw continents (simplified landmasses)
  final landPaint = ui.Paint()..color = const ui.Color(0xFF2D5016);
  
  // Draw some continent shapes
  final path1 = ui.Path()
    ..addOval(ui.Rect.fromLTWH(150, 100, 120, 80));
  canvas.drawPath(path1, landPaint);
  
  final path2 = ui.Path()
    ..addOval(ui.Rect.fromLTWH(250, 200, 100, 90));
  canvas.drawPath(path2, landPaint);
  
  final path3 = ui.Path()
    ..addOval(ui.Rect.fromLTWH(100, 300, 140, 100));
  canvas.drawPath(path3, landPaint);
  
  final path4 = ui.Path()
    ..addOval(ui.Rect.fromLTWH(300, 350, 110, 70));
  canvas.drawPath(path4, landPaint);
  
  // Add some cloud-like white areas
  final cloudPaint = ui.Paint()..color = const ui.Color(0x88FFFFFF);
  final cloudPath1 = ui.Path()
    ..addOval(ui.Rect.fromLTWH(180, 150, 60, 40));
  canvas.drawPath(cloudPath1, cloudPaint);
  
  final cloudPath2 = ui.Path()
    ..addOval(ui.Rect.fromLTWH(280, 250, 50, 35));
  canvas.drawPath(cloudPath2, cloudPaint);
  
  // Add atmosphere glow
  final glowPaint = ui.Paint()
    ..color = const ui.Color(0x33FFFFFF)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 20);
  canvas.drawCircle(center, radius + 5, glowPaint);
  
  final picture = recorder.endRecording();
  return await picture.toImage(size.width.toInt(), size.height.toInt());
}

