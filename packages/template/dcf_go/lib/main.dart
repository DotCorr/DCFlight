import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  await DCFlight.go(app: MyApp());
}

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: DCFStyleSheet(backgroundColor: Colors.red),
      children: [
        DCFText(
          content: "Hello, World! ${count.state}",
          textProps: DCFTextProps(color: Colors.amber, fontSize: 20),
          // styleSheet: DCFStyleSheet(backgroundColor: Colors.blue),
          layout: DCFLayout(
            height: 100,
            width: 100,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Click me"),
          onPress: (data) => count.setState(count.state + 1),
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}
