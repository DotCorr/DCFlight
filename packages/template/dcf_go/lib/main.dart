import 'package:dcflight/dcflight.dart';

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
              children: [DCFText(content: "1")],
            ),
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.blue),
              children: [DCFText(content: "2")],
            ),
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.green),
              children: [DCFText(content: "3")],
            ),
            DCFView(
              layout: DCFLayout(width: "45%", height: 100),
              styleSheet: DCFStyleSheet(backgroundColor: Colors.orange),
              children: [DCFText(content: "4")],
            ),
          ],
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}

