import 'dart:ui' as ui;
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold, Colors;
import 'package:flutter/painting.dart' show MemoryImage;
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';

void main() async {
  await DCFlight.go(app: PureNativeAndFlutterMixApp());
}

// Style and layout registries - created once, reused across renders
// Using StyleSheet.create() for optimal performance (see StyleSheet.create() docs)
final _styles = DCFStyleSheet.create({
  'root': DCFStyleSheet(backgroundColor: DCFColors.black),
  'controlsPanel': DCFStyleSheet(
    backgroundColor: DCFTheme.current.surfaceColor,
    borderRadius: 20,
    elevation: 10,
  ),
  'titleText': DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
  'bodyText': DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
  'decrementButton': DCFStyleSheet(
    backgroundColor: const Color(0xFFFF5722),
    borderRadius: 8,
  ),
  'incrementButton': DCFStyleSheet(
    backgroundColor: const Color(0xFF4CAF50),
    borderRadius: 8,
  ),
  'buttonText': DCFStyleSheet(primaryColor: DCFColors.white),
  'toggleButton': DCFStyleSheet(
    backgroundColor: const Color(0xFF757575),
    borderRadius: 8,
  ),
  'toggleButtonActive': DCFStyleSheet(
    backgroundColor: const Color(0xFF4CAF50),
    borderRadius: 8,
  ),
  'infoBox': DCFStyleSheet(
    backgroundColor: const Color(0x3300FF00),
    borderRadius: 8,
  ),
  'infoText': DCFStyleSheet(primaryColor: DCFColors.green),
  'emptyStyle': DCFStyleSheet(),
});

final _layouts = DCFLayout.create({
  'root': DCFLayout(flex: 1),
  'flutterWidget': DCFLayout(
    flex: 1,
    width: "100%",
    height: "100%",
  ),
  'controlsPanel': DCFLayout(
    width: '100%',
    flexWrap: DCFWrap.wrap,
    padding: 20,
  ),
  'title': DCFLayout(marginBottom: 15),
  'controlSection': DCFLayout(
    marginHorizontal: 10,
    width: "100%",
    marginBottom: 15,
  ),
  'speedText': DCFLayout(marginBottom: 10),
  'buttonRow': DCFLayout(
    flexDirection: DCFFlexDirection.row,
    gap: 10,
  ),
  'smallButton': DCFLayout(
    width: 50,
    height: 40,
  ),
  'fullWidthButton': DCFLayout(
    width: "100%",
    height: 40,
  ),
  'infoBox': DCFLayout(padding: 10),
});

class PureNativeAndFlutterMixApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final rotationSpeed = useState<double>(0.05);
    final isRotating = useState<bool>(true);
    final buttonPressCount = useState<int>(0);
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
      layout: _layouts['root'],
      styleSheet: _styles['root'],
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
          layout: _layouts['flutterWidget'],
          styleSheet: _styles['emptyStyle'],
        ),
        DCFView(
          layout: _layouts['controlsPanel'],
          styleSheet: _styles['controlsPanel'],
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
              layout: _layouts['title'],
            ),
            DCFView(
              layout: _layouts['controlSection'],
              children: [
                DCFText(
                  content: "Rotation Speed: ${(rotationSpeed.state * 100).toStringAsFixed(0)}%",
                  textProps: DCFTextProps(
                    fontSize: 16,
                  ),
                  styleSheet: _styles['bodyText'],
                  layout: _layouts['speedText'],
                ),
                DCFView(
                  layout: _layouts['buttonRow'],
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
                      layout: _layouts['smallButton'],
                      children: [
                        DCFText(
                          content: "-",
                          textProps: DCFTextProps(
                            fontSize: 20,
                            fontWeight: DCFFontWeight.bold,
                          ),
                          styleSheet: _styles['buttonText'],
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
                      layout: _layouts['smallButton'],
                      children: [
                        DCFText(
                          content: "+",
                          textProps: DCFTextProps(
                            fontSize: 20,
                            fontWeight: DCFFontWeight.bold,
                          ),
                          styleSheet: _styles['buttonText'],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            DCFView(
              layout: _layouts['controlSection'],
              children: [
                DCFButton(
                  onPress: (DCFButtonPressData data) {
                    isRotating.setState(!isRotating.state);
                  },
                  styleSheet: isRotating.state ? _styles['toggleButtonActive'] : _styles['toggleButton'],
                  layout: _layouts['fullWidthButton'],
                  children: [
                    DCFText(
                      content: isRotating.state ? "Pause Rotation" : "Resume Rotation",
                      textProps: DCFTextProps(
                        fontSize: 16,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: _styles['buttonText'],
                    ),
                  ],
                ),
              ],
            ),
            DCFView(
              layout: _layouts['infoBox'],
              styleSheet: DCFStyleSheet(
                backgroundColor: Color.lerp(
                  const Color(0x3300FF00),
                  const Color(0x33FF0000),
                  (buttonPressCount.state % 10) / 10.0,
                )!,
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: "Using WidgetToDCFAdaptor\n3D Globe with Flutter\nInteractive & Rotating\nState management working\nButton presses: ${buttonPressCount.state}",
                  textProps: DCFTextProps(
                    fontSize: 12,
                  ),
                  styleSheet: _styles['infoText'],
                ),
              ],
            ),
              ],
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

