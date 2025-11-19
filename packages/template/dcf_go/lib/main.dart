import 'dart:ui' as ui;
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold, Colors;
import 'package:flutter/painting.dart' show MemoryImage;
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';

void main() async {
  DCFLogger.setLevel(DCFLogLevel.info);
  DCFLogger.info('Starting Flutter Widget Demo App...', 'App');
  
  await DCFlight.go(app: PureNativeAndFlutterMixApp());
}

// Create style and layout registries outside render() - they don't consume state
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
    final controllerRef = useRef<FlutterEarthGlobeController?>(null);
    
    // Initialize controller once
    if (controllerRef.current == null) {
      controllerRef.current = FlutterEarthGlobeController(
        rotationSpeed: rotationSpeed.state,
        isBackgroundFollowingSphereRotation: true,
      );
      
      controllerRef.current!.onLoaded = () async {
        final surfaceImage = await _createDefaultSphereImage();
        // Convert ui.Image to bytes and use MemoryImage
        final byteData = await surfaceImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          final imageProvider = MemoryImage(bytes);
          controllerRef.current!.loadSurface(imageProvider);
        }
      };
    } else {
      // Update rotation speed if it changed
      controllerRef.current!.rotationSpeed = rotationSpeed.state;
    }
    
    return DCFView(
      layout: _layouts['root'],
      styleSheet: _styles['root'],
      children: [
        // Flutter Widget Adaptor - 3D Globe Example
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
        
        // Controls Panel
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
              styleSheet: _styles['titleText'],
              layout: _layouts['title'],
            ),

            // Rotation Speed Control
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
                      },
                      styleSheet: _styles['decrementButton'],
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
                      },
                      styleSheet: _styles['incrementButton'],
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
            
            // Toggle Rotation Button
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
            
            // Info
            DCFView(
              layout: _layouts['infoBox'],
              styleSheet: _styles['infoBox'],
              children: [
                DCFText(
                  content: "Using WidgetToDCFAdaptor\n3D Globe with Flutter\nInteractive & Rotating\nState management working",
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

/// Creates a default sphere image for the globe
/// This is a simple programmatic image - in production you'd use an actual Earth texture
Future<ui.Image> _createDefaultSphereImage() async {
  // Create a simple colored sphere image
  // In a real app, you'd load an actual Earth texture image
  // For now, we'll create a placeholder
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final size = ui.Size(512, 512);
  
  // Draw a simple gradient sphere
  final center = ui.Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2 - 10;
  
  // Draw gradient circle (simplified Earth-like appearance)
  final paint = ui.Paint()
    ..shader = ui.Gradient.radial(
      center,
      radius,
      [
        const ui.Color(0xFF4A90E2), // Ocean blue
        const ui.Color(0xFF2E5C8A), // Darker blue
      ],
      [0.0, 1.0],
    );
  
  canvas.drawCircle(center, radius, paint);
  
  // Convert to image
  final picture = recorder.endRecording();
  return await picture.toImage(size.width.toInt(), size.height.toInt());
}

