import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';
import 'package:flutter/widgets.dart';

void main() async {
  DCFLogger.setLevel(DCFLogLevel.info);
  DCFLogger.info('Starting Flutter Widget Demo App...', 'App');
  
  await DCFlight.go(app: FlutterWidgetDemoApp());
}

class FlutterWidgetDemoApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final counter = useState<int>(0);
    final colorIndex = useState<int>(0);
    
    // Color palette that cycles
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];
    
    return DCFView(
      layout: DCFLayout(
        flex: 1,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.black,
      ),
      children: [
        // Flutter Widget Adaptor - Custom Paint Example
        WidgetToDCFAdaptor.builder(
          widgetBuilder: () {
            final currentColor = colors[colorIndex.state % colors.length];

            return Container(
              color: DCFColors.black,
              child: CustomPaint(
                painter: _CounterPainter(
                  count: counter.state,
                  color: currentColor,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${counter.state}',
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: currentColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tap to increment',
                        style: TextStyle(
                          fontSize: 18,
                          color: DCFColors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            width: '100%',
            flexWrap: DCFWrap.wrap,
            padding: 20,
          ),
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFTheme.current.surfaceColor,
            borderRadius: 20,
            elevation: 10,
          ),
          children: [
            DCFText(
              content: "Flutter Widget Demo",
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

            // Counter Controls
            DCFView(
              layout: DCFLayout(
                marginHorizontal: 10,
                width: "100%",
                flexDirection: DCFFlexDirection.row,
                justifyContent: DCFJustifyContent.spaceBetween,
                alignItems: DCFAlign.center,
                marginBottom: 15,
              ),
              children: [
                DCFText(
                  content: "Counter:",
                  textProps: DCFTextProps(
                    fontSize: 16,
                  ),
                  styleSheet: DCFStyleSheet(
                    primaryColor: DCFTheme.current.textColor,
                  ),
                  layout: DCFLayout(marginRight: 10),
            ),
                DCFView(
                  layout: DCFLayout(
                    flexDirection: DCFFlexDirection.row,
                    gap: 10,
                  ),
                  children: [
                    DCFButton(
                      onPress: (DCFButtonPressData data) {
                        counter.setState(counter.state - 1);
                      },
                      styleSheet: DCFStyleSheet(
                        backgroundColor: const Color(0xFFFF5722),
                        borderRadius: 8,
                      ),
                      layout: DCFLayout(
                        width: 50,
                        height: 40,
                      ),
                      children: [
                        DCFText(
                          content: "-",
                          textProps: DCFTextProps(
                            fontSize: 20,
                            fontWeight: DCFFontWeight.bold,
                          ),
              styleSheet: DCFStyleSheet(
                            primaryColor: DCFColors.white,
              ),
            ),
                      ],
                    ),
                    DCFButton(
                      onPress: (DCFButtonPressData data) {
                        counter.setState(counter.state + 1);
                      },
                      styleSheet: DCFStyleSheet(
                        backgroundColor: const Color(0xFF4CAF50),
                        borderRadius: 8,
                      ),
              layout: DCFLayout(
                        width: 50,
                height: 40,
                      ),
                      children: [
                        DCFText(
                          content: "+",
                          textProps: DCFTextProps(
                            fontSize: 20,
                            fontWeight: DCFFontWeight.bold,
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
            
            // Color Change Button
            DCFView(
              layout: DCFLayout(
                marginHorizontal: 10,
                width: "100%",
                marginBottom: 15,
              ),
              children: [
                DCFButton(
                  onPress: (DCFButtonPressData data) {
                    colorIndex.setState(colorIndex.state + 1);
                  },
                      styleSheet: DCFStyleSheet(
                    backgroundColor: colors[colorIndex.state % colors.length],
                    borderRadius: 8,
                  ),
                  layout: DCFLayout(
                    width: "100%",
                    height: 40,
                ),
                  children: [
                    DCFText(
                      content: "Change Color",
                      textProps: DCFTextProps(
                        fontSize: 16,
                        fontWeight: DCFFontWeight.bold,
                      ),
                      styleSheet: DCFStyleSheet(
                        primaryColor: DCFColors.white,
                      ),
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
                  content: "Using WidgetToDCFAdaptor\nCustomPaint with Flutter\nState management working\nInteractive widgets",
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

class _CounterPainter extends CustomPainter {
  final int count;
  final Color color;
  
  _CounterPainter({
    required this.count,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 3;
    
    // Draw animated circles based on count
    for (int i = 0; i < count.abs().clamp(0, 20); i++) {
      final circleRadius = radius * 0.3;
      final x = center.dx + (radius * 0.7) * (i.isEven ? 1 : -1) * (i % 3 == 0 ? 0.5 : 1.0);
      final y = center.dy + (radius * 0.7) * (i % 2 == 0 ? 1 : -1) * (i % 3 == 1 ? 0.5 : 1.0);
      
      final paint = Paint()
        ..color = color.withOpacity(0.3 + (i % 3) * 0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), circleRadius, paint);
    }
    
    // Draw main circle
    final mainPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, radius, mainPaint);
  }
  
  @override
  bool shouldRepaint(_CounterPainter oldDelegate) {
    return oldDelegate.count != count || oldDelegate.color != color;
  }
}
