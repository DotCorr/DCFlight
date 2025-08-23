import 'package:dcf_go/config/navigation/stack_registry.dart';
import 'package:dcf_screens/dcf_screens.dart';
import 'package:dcflight/dcflight.dart';

void main() {
  DCFlight.start(app: MyStackApp());
}

class MyStackApp extends StatelessComponent {
  @override
  DCFComponentNode render() {
    return DCFStackNavigationRoot(
      initialScreen: "home",
      screenRegistryComponents: StackScreenRegistry(),
    );
  }

  @override
  List<Object?> get props => [];
}

