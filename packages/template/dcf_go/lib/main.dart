import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';

void main() async {
  DCFlight.setLogLevel(DCFLogLevel.debug);
  await DCFlight.start(app: MyGridApp());
}

class MyGridApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        padding: 20,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.grey[100]),
      children: [
        // Simple 2x2 Grid
        DCFView(
          layout: DCFLayout(
            flexDirection: YogaFlexDirection.row,
            flexWrap: YogaWrap.wrap,
            // gap: 10,
          ),
          children: [
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.red),
              children: [
                DCFText(
                  content: "1",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: 'center',
                  ),
                )
              ],
            ),
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.blue),
              children: [
                DCFText(
                  content: "2",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: 'center',
                  ),
                )
              ],
            ),
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.green),
              children: [
                DCFText(
                  content: "3",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: 'center',
                  ),
                )
              ],
            ),
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.orange),
              children: [
                DCFText(
                  content: "4",
                  textProps: DCFTextProps(
                    fontSize: 24,
                    fontWeight: DCFFontWeight.bold,
                    color: Colors.white,
                    textAlign: 'center',
                  ),
                )
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

