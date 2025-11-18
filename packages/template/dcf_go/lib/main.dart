import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  DCFLogger.setLevel(DCFLogLevel.info);
  DCFLogger.info('Starting Canvas Demo App...', 'App');
  
  await DCFlight.go(app: CanvasDemoApp());
}

class CanvasDemoApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final animationValue = useState<double>(0.0);
    final repaintOnFrame = useState<bool>(true);
    final backgroundColor = useState<Color>(DCFColors.black);
    
    // Animation loop
    if (repaintOnFrame.state) {
      // Use a timer or animation controller to update animationValue
      // For now, we'll use a simple counter
    }
    
    return DCFView(
      layout: DCFLayout(
        flex: 1,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFTheme.current.backgroundColor,
      ),
      children: [
        // Canvas using WidgetToDCFAdaptor - directly embeds Flutter's rendering pipeline
        // Use builder() to ensure widget rebuilds when state changes
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            return LayoutBuilder(
              builder: (context, constraints) {
                // Ensure we have valid constraints (handle initial 0x0 case)
                final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0 
                    ? constraints.maxWidth 
                    : 402.0; // Use actual screen width as fallback
                final height = constraints.maxHeight.isFinite && constraints.maxHeight > 0 
                    ? constraints.maxHeight 
                    : 614.0; // Use actual screen height as fallback
                
                return SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    size: Size(width, height),
                    painter: _DemoPainter(
                      animationValue: animationValue.state,
                      repaintOnFrame: repaintOnFrame.state,
                    ),
                    child: Container(
                      color: backgroundColor.state,
                      width: width,
                      height: height,
                    ),
                  ),
                );
              },
            );
          },
          layout: DCFLayout(
            flex: 1,
            width: "100%",
            height: "100%",
          ),
          styleSheet: DCFStyleSheet(),
        ),
        
        // Controls Panel
        DCFView(
          layout: DCFLayout(
            padding: 20,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFTheme.current.surfaceColor,
            borderRadius: 20,
            elevation: 10,
          ),
          children: [
            DCFText(
              content: "Canvas Controls",
              textProps: DCFTextProps(
                fontSize: 20,
                fontWeight: DCFFontWeight.bold,
              ),
              styleSheet: DCFStyleSheet(
                primaryColor: DCFTheme.current.textColor,
              ),
              layout: DCFLayout(
                marginBottom: 15,
              ),
            ),
            
            // Repaint toggle
            DCFView(
              layout: DCFLayout(
                flexDirection: DCFFlexDirection.row,
                justifyContent: DCFJustifyContent.spaceBetween,
                alignItems: DCFAlign.center,
                marginBottom: 15,
              ),
              children: [
                DCFText(
                  content: "Animate: ${repaintOnFrame.state ? 'ON' : 'OFF'}",
                  textProps: DCFTextProps(
                    fontSize: 14,
                  ),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFTheme.current.textColor,
                  ),
                ),
                DCFToggle(
                  value: repaintOnFrame.state,
                  onValueChange: (DCFToggleValueData data) {
                    repaintOnFrame.setState(data.value);
                  },
                ),
              ],
            ),
            
            // Background color picker
            DCFView(
              layout: DCFLayout(
                marginBottom: 15,
              ),
              children: [
                DCFText(
                  content: "Background Color",
                  textProps: DCFTextProps(
                    fontSize: 14,
                  ),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFTheme.current.textColor,
                  ),
                  layout: DCFLayout(
                    marginBottom: 8,
                  ),
                ),
                DCFView(
                  layout: DCFLayout(
                    flexDirection: DCFFlexDirection.row,
                    gap: 10,
                  ),
                  children: [
                    _ColorButton(
                      color: DCFColors.black,
                      label: "Black",
                      isSelected: backgroundColor.state == DCFColors.black,
                      onPress: () => backgroundColor.setState(DCFColors.black),
                    ),
                    _ColorButton(
                      color: DCFColors.blue,
                      label: "Blue",
                      isSelected: backgroundColor.state == DCFColors.blue,
                      onPress: () => backgroundColor.setState(DCFColors.blue),
                    ),
                    _ColorButton(
                      color: DCFColors.purple,
                      label: "Purple",
                      isSelected: backgroundColor.state == DCFColors.purple,
                      onPress: () => backgroundColor.setState(DCFColors.purple),
                    ),
                  ],
                ),
              ],
            ),
            
            // Info
            DCFView(
              layout: DCFLayout(
                padding: 10,
              ),
              styleSheet: DCFStyleSheet(
                backgroundColor: const Color(0x3300FF00),
                borderRadius: 8,
              ),
              children: [
                DCFText(
                  content: "Using WidgetToDCFAdaptor\nDirect Flutter rendering pipeline\n(Impeller/Skia via CustomPaint)",
                  textProps: DCFTextProps(
                    fontSize: 12,
                  ),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for the demo - uses Flutter's dart:ui Canvas API directly
class _DemoPainter extends CustomPainter {
  final double animationValue;
  final bool repaintOnFrame;
  
  _DemoPainter({
    required this.animationValue,
    required this.repaintOnFrame,
  });
  
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Direct drawing using Flutter's Canvas API (Impeller/Skia)
    final paint = ui.Paint()
      ..color = DCFColors.blue
      ..style = ui.PaintingStyle.fill;
    
    final center = ui.Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 3;
    
    // Draw animated circle
    final animatedRadius = radius * (0.5 + 0.5 * math.sin(animationValue));
    canvas.drawCircle(center, animatedRadius, paint);
    
    // Draw rotating lines
    paint.color = DCFColors.red;
    paint.strokeWidth = 3;
    for (int i = 0; i < 8; i++) {
      final angle = (animationValue + i * math.pi / 4) % (2 * math.pi);
      final endX = center.dx + math.cos(angle) * radius * 1.5;
      final endY = center.dy + math.sin(angle) * radius * 1.5;
      canvas.drawLine(center, ui.Offset(endX, endY), paint);
    }
    
    // Draw text using Flutter's text rendering
    final textStyle = ui.TextStyle(
      color: DCFColors.white,
      fontSize: 24,
      fontWeight: ui.FontWeight.bold,
    );
    
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
    ))
      ..pushStyle(textStyle)
      ..addText('Flutter Canvas\n(Impeller/Skia)\nvia WidgetToDCFAdaptor');
    
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    
    canvas.drawParagraph(
      paragraph,
      ui.Offset(
        (size.width - paragraph.maxIntrinsicWidth) / 2,
        size.height * 0.8,
      ),
    );
  }
  
  @override
  bool shouldRepaint(_DemoPainter oldDelegate) {
    return repaintOnFrame || oldDelegate.animationValue != animationValue;
  }
}

class _ColorButton extends DCFStatelessComponent {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onPress;
  
  _ColorButton({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onPress,
  });
  
  @override
  DCFComponentNode render() {
    return DCFButton(
      children: [
        DCFText(
          content: label,
          textProps: DCFTextProps(
            fontSize: 12,
          ),
          styleSheet: DCFStyleSheet(
            primaryColor: DCFColors.white,
          ),
        ),
      ],
      onPress: (data) => onPress(),
      layout: DCFLayout(
        flex: 1,
        height: 35,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: color,
        borderRadius: 8,
        borderWidth: isSelected ? 3 : 1,
        borderColor: isSelected ? DCFColors.white : DCFColors.darkGray,
      ),
    );
  }
}
