import 'package:dcflight/dcflight.dart';

final publicDetailScreenCommand = Store<ScreenNavigationCommand?>(null);
final publicDeepScreenCommand = Store<ScreenNavigationCommand?>(null);
final publicModalScreenCommand = Store<ScreenNavigationCommand?>(null);
final publicOverlayLoadingCommand = Store<ScreenNavigationCommand?>(null);
final publicModalScreenInModalCommand = Store<ScreenNavigationCommand?>(null);
final pagestate = Store<int>(0);