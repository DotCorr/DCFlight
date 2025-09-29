
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

  // Store colors for each box to prevent flashing on Android
  final Map<int, Color> _boxColors = {};
  
  // Debouncing mechanism for buttons
  DateTime? _lastButtonPress;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  
  // Track if this is the first render to prevent Android flash
  bool _isFirstRender = true;

  bool _shouldAllowButtonPress() {
    final now = DateTime.now();
    if (_lastButtonPress == null || now.difference(_lastButtonPress!) > _debounceDelay) {
      _lastButtonPress = now;
      return true;
    }
    return false;
  }

  Color _getColorForBox(int index) {
    // Use cached color or generate new one
    if (!_boxColors.containsKey(index)) {
      _boxColors[index] = _colors[Random().nextInt(_colors.length)];
    }
    return _boxColors[index]!;
  }

  void _cleanupBoxColors(int currentCount) {
    // Remove colors for boxes that no longer exist
    _boxColors.removeWhere((key, value) => key >= currentCount);
  }

  @override
  DCFComponentNode render() {
    final boxCount = useState(4); // Start with 4 boxes - reset from the 53+ issue
    final gridDensity = useState(2.0); // Density slider (2-6 columns)
    
    // Clean up old box colors to prevent memory leaks
    _cleanupBoxColors(boxCount.state);
    
    // Mark first render as complete
    if (_isFirstRender) {
      _isFirstRender = false;
    }
    
    // Calculate box width based on screen and density
    final columns = gridDensity.state.round();
    // Account for margins (10px each side) instead of gap
    final boxWidth = (100 / columns) - 4; // Percentage width minus margins
    
    // Generate grid boxes with stable colors and proper Android rendering
    List<DCFComponentNode> gridBoxes = [];
    for (int i = 0; i < boxCount.state; i++) {
      gridBoxes.add(
        DCFView(
          key: 'grid_box_$i',
          styleSheet: DCFStyleSheet(
            backgroundColor: _getColorForBox(i), // Use stable color per box
          ),
          layout: DCFLayout(
            width: boxWidth,
            height: 100,
            // Use consistent margins instead of gap for better Android compatibility
            marginBottom: 10,
            marginRight: 10,
            flexDirection: YogaFlexDirection.column,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
          children: [
            DCFText(
              content: "${i + 1}",
              textProps: DCFTextProps(
                fontSize: 18,
                color: Colors.white,
                fontWeight: DCFFontWeight.bold,
                textAlign: DCFTextAlign.center,
              ),
              layout: DCFLayout(
                flex: 1,
                width: '100%',
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return DCFView(
      styleSheet: DCFStyleSheet(backgroundColor: Colors.amber,),
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
        
        // Grid Container - Android compatible layout without gap
        DCFView(
          layout: DCFLayout(
            flex: 1,
            width: '100%',
            flexDirection: YogaFlexDirection.row,
            flexWrap: YogaWrap.wrap,
            justifyContent: YogaJustifyContent.flexStart,
            alignContent: YogaAlign.flexStart,
            // Remove gap property for better Android compatibility
            // Use margin-based spacing instead
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
            
            // Add/Remove buttons - Always show both buttons for consistency
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
                  buttonProps: DCFButtonProps(
                    title: boxCount.state > 0 ? "Remove Box" : "Remove Box (0)",
                  ),
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

