import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';
import 'dart:math';

void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);
  await DCFlight.start(app: InteractiveGridApp());
}

class InteractiveGridApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final boxCount = useState(4);
    final gridDensity = useState(2.0);
    
    final columns = gridDensity.state.round();
    final boxWidth = (100 / columns) - 2;
    
    List<DCFComponentNode> gridBoxes = [];
    for (int i = 0; i < boxCount.state; i++) {
      gridBoxes.add(
        DCFView(
          styleSheet: DCFStyleSheet(
            backgroundColor: Colors.indigo.shade400,
            borderRadius: 20,
          ),
          layout: DCFLayout(
            width: boxWidth,
            height: 100,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
          children: [
            DCFText(
              content: "${i + 1}",
              textProps: DCFTextProps(
                textAlign: DCFTextAlign.center,
                fontSize: 24,
                color: Colors.white,
                fontWeight: DCFFontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return DCFView(
      styleSheet: DCFStyleSheet(
        backgroundColor: Colors.green.shade400,
      ),
      layout: DCFLayout(
        flex: 1,
        padding: 20,
        paddingTop: 100,
      ),
      children: [
        // Header
        DCFText(
          content: "Grid Test",
          textProps: DCFTextProps(
            fontSize: 28,
            fontWeight: DCFFontWeight.bold,
          ),
          layout: DCFLayout(marginBottom: 10),
        ),
        
        DCFText(
          content: "${boxCount.state} boxes • $columns columns",
          textProps: DCFTextProps(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          layout: DCFLayout(marginBottom: 20),
        ),
        
        // Slider for box count
        DCFSlider(
          value: boxCount.state.toDouble() / 100,
          onValueChange: (DCFSliderValueData data) {
            print(data.value);
            final int newBoxCount = (data.value * 100).round();
            boxCount.setState(newBoxCount);
          },
        ),
        
        // Grid
        DCFView(
          layout: DCFLayout(
            flex: 1,
            width: '100%',
            flexDirection: YogaFlexDirection.row,
            flexWrap: YogaWrap.wrap,
            justifyContent: YogaJustifyContent.flexStart,
            alignContent: YogaAlign.flexStart,
            gap: 10,
          ),
          children: gridBoxes,
        ),
        
        // Controls
        DCFView(
          layout: DCFLayout(
            width: '100%',
            paddingTop: 20,
            gap: 15,
          ),
          children: [
            // Density controls
            DCFView(
              layout: DCFLayout(
                flexDirection: YogaFlexDirection.row,
                justifyContent: YogaJustifyContent.center,
                gap: 10,
              ),
              children: [
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Less Columns"),
                  onPress: (v) {
                    if (gridDensity.state > 2) {
                      gridDensity.setState(gridDensity.state - 1);
                    }
                  },
                ),
                DCFButton(
                  buttonProps: DCFButtonProps(title: "More Columns"),
                  onPress: (v) {
                    if (gridDensity.state < 6) {
                      gridDensity.setState(gridDensity.state + 1);
                    }
                  },
                ),
              ],
            ),
            
            // Box controls
            DCFView(
              layout: DCFLayout(
                flexDirection: YogaFlexDirection.row,
                justifyContent: YogaJustifyContent.center,
                gap: 10,
              ),
              children: [
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Add Box"),
                  onPress: (v) {
                    boxCount.setState(boxCount.state + 1);
                  },
                ),
                DCFButton(
                  buttonProps: DCFButtonProps(title: "Remove Box"),
                  onPress: (v) {
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