import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  // Set log level to see all logs (default is warning)
  // Options: none, error, warning, info, debug, verbose
  DCFLogger.setLevel(DCFLogLevel.info);

  // Optional: Set identifiers for log isolation
  // DCFLogger.setProjectId('my-project');
  // DCFLogger.setInstanceId('instance-1');

  // Log app startup (tag defaults to 'DCFlight' if not provided)
  DCFLogger.info('Starting DCFlight app...', 'App');

  // Example of all log levels (tag is optional, defaults to 'DCFlight'):
  // DCFLogger.error('Error message', error: errorObject, stackTrace: stackTrace, tag: 'MyTag');
  // DCFLogger.warning('Warning message', 'MyTag');
  // DCFLogger.info('Info message', 'MyTag');
  // DCFLogger.debug('Debug message', 'MyTag');
  // DCFLogger.verbose('Verbose message', 'MyTag');

  // Or without tag (uses default 'DCFlight'):
  // DCFLogger.info('Simple message');
  // DCFLogger.debug('Debug message');

  await DCFlight.go(app: MyApp());
}

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    final sliderVal = useState<double>(0.0);

    final name = useState<String>("");
    final isDarkMode = useState<bool>(DCFTheme.isDarkMode);

    return DCFView(
      layout: DCFLayout(flex: 1, gap: 10),
      styleSheet: DCFStyleSheet(backgroundColor: DCFColors.red),
      children: [
        DCFImage(
          imageProps: DCFImageProps(
            source:
                "https://avatars.githubusercontent.com/u/205313423?s=400&u=23a520c2d386edf2466223ba05f5f44a4a9ddf42&v=4",
          ),
          layout: DCFLayout(width: 100, height: 100),
          styleSheet: DCFStyleSheet(backgroundColor: DCFColors.pink),
        ),

        DCFText(content: "Count: ${count.state}"),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Click me"),
          onPress:
              (data) => {
                count.setState(count.state + 1),
                DCFLogger.info("Button pressed"),
              },
        ),
        DCFText(content: "Hello World"),
        DCFText(content: "Hello World"),
        DCFText(content: "Hello World"),
        DCFText(content: "Hello World"),
        DCFText(content: "Hello World"),
        DCFTextInput(
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.orange,
            borderRadius: 10,
          ),
          layout: DCFLayout(padding: 5, margin: 10, width: "95%", height: 50),
          value: name.state,
          onBlur: (data) => name.setState(data.isBlurred.toString()),
        ),
        DCFText(content: "Hello World"),
      ],
    );
  }
}
