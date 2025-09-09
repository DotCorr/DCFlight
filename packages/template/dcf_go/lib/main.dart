
import 'package:dcflight/dcflight.dart';
import 'dart:math';

void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);

  await DCFlight.start(app: InteractiveGridApp());
}

class InteractiveGridApp extends DCFStatefulComponent {
  // Generate random colors for grid boxes
  final List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.yellow,
    Colors.indigo,
    Colors.cyan,
  ];

  // Debouncing mechanism for buttons
  DateTime? _lastButtonPress;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  bool _shouldAllowButtonPress() {
    final now = DateTime.now();
    if (_lastButtonPress == null || now.difference(_lastButtonPress!) > _debounceDelay) {
      _lastButtonPress = now;
      return true;
    }
    return false;
  }

  Color _getRandomColor() {
    return _colors[Random().nextInt(_colors.length)];
  }

  @override
  DCFComponentNode render() {
    final boxCount = useState(4); // Start with 4 boxes - reset from the 53+ issue
    final gridDensity = useState(2.0); // Density slider (2-6 columns)
    
    // Calculate box width based on screen and density
    final columns = gridDensity.state.round();
    final boxWidth = (100 / columns) - 2; // Percentage width minus gap
    
    // Generate grid boxes
    List<DCFComponentNode> gridBoxes = [];
    for (int i = 0; i < boxCount.state; i++) {
      gridBoxes.add(
        DCFView(
          key: 'grid_box_$i',
          styleSheet: DCFStyleSheet(
            backgroundColor: _getRandomColor(),
          ),
          layout: DCFLayout(
            width: boxWidth,
            height: 100,
            marginBottom: 10,
            marginRight: i % columns == columns - 1 ? 0 : 10, // No margin on last column
            flexDirection: YogaFlexDirection.column,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
          children: [
            DCFText(
              content: "${i + 1}",
              textProps: DCFTextProps(
                fontSize: 18, // Increased from 24 to be more visible in small boxes
                color: Colors.white,
                fontWeight: DCFFontWeight.bold,
                textAlign: DCFTextAlign.center,
              ),
              layout: DCFLayout(
                flex: 1, // Make sure text takes available space
                width: '100%',
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return DCFSafeArea(
      styleSheet: DCFStyleSheet(backgroundColor: Color(0xfff5f5f5)),
      layout: DCFLayout(
        flex: 1,
        padding: 20,
      ),
      children: [
        // Header
        DCFView(
          layout: DCFLayout(
            width: '100%',
            marginBottom: 20,
          ),
          children: [
            DCFText(
              content: "Interactive Grid Test",
              textProps: DCFTextProps(
                fontSize: 28,
                color: Colors.black,
                fontWeight: DCFFontWeight.bold,
                textAlign: DCFTextAlign.center,
              ),
            ),
            DCFText(
              content: "Boxes: ${boxCount.state} | Columns: $columns",
              textProps: DCFTextProps(
                fontSize: 16,
                color: Colors.grey,
                textAlign: DCFTextAlign.center,
              ),
            ),
          ],
        ),
        
        // Grid Container
        DCFView(
          layout: DCFLayout(
            flex: 1,
            width: '100%',
            flexDirection: YogaFlexDirection.row,
            flexWrap: YogaWrap.wrap,
            justifyContent: YogaJustifyContent.flexStart,
            alignContent: YogaAlign.flexStart,
            gap: 10, // This will test our gap implementation
          ),
          children: gridBoxes,
        ),
        
        // Controls at bottom
        DCFView(
          layout: DCFLayout(
            width: '100%',
            paddingTop: 20,
            flexDirection: YogaFlexDirection.column,
            alignItems: YogaAlign.center,
          ),
          children: [
            // Density label
            DCFText(
              content: "Grid Density: $columns columns",
              textProps: DCFTextProps(
                fontSize: 16,
                color: Colors.black,
                textAlign: DCFTextAlign.center,
              ),
            ),
            
            // Density slider (simulated with buttons for now)
            DCFView(
              layout: DCFLayout(
                flexDirection: YogaFlexDirection.row,
                marginTop: 10,
                marginBottom: 20,
              ),
              children: [
                DCFButton(
                  buttonProps: DCFButtonProps(title: "- Density"),
                  onPress: (v) {
                    if (!_shouldAllowButtonPress()) return;
                    if (gridDensity.state > 2) {
                      gridDensity.setState(gridDensity.state - 1);
                    }
                  },
                ),
                DCFView(layout: DCFLayout(width: 20)),
                DCFButton(
                  buttonProps: DCFButtonProps(title: "+ Density"),
                  onPress: (v) {
                    if (!_shouldAllowButtonPress()) return;
                    if (gridDensity.state < 6) {
                      gridDensity.setState(gridDensity.state + 1);
                    }
                  },
                ),
              ],
            ),
            
            // Add/Remove buttons
            DCFView(
              layout: DCFLayout(
                flexDirection: YogaFlexDirection.row,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Add Box"),
                  onPress: (v) {
                    if (!_shouldAllowButtonPress()) return;
                    boxCount.setState(boxCount.state + 1);
                  },
                ),
                DCFView(layout: DCFLayout(width: 20)),
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Remove Box"),
                  onPress: (v) {
                    if (!_shouldAllowButtonPress()) return;
                    if (boxCount.state > 0) {
                      boxCount.setState(boxCount.state - 1);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}
