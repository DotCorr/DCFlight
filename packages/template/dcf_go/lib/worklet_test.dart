import 'package:dcflight/dcflight.dart';


class WorkletTest extends DCFStatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(

      layout: DCFLayout(
        width: '100%',
        height: '100%',
      ),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.white),
      children: [
        DCFText(content: "Worklet Test"),
        DCFButton(
          children: [
            DCFText(content: "Do something"),
          ],
          onPress: (data) {
            print("Button pressed");
          },
        )
      ],
    );
  }
}