import 'package:dcflight/dcflight.dart';

class PopOverScreen extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFText(
          content: "This is a pop over screen",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
