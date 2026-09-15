import 'package:dcflight_authoring/dcflight.dart';

// Ordinary developer Dart: composition and configuration happen at development time.
App buildApp() => App(
  id: 'com.dotcorr.snap', name: 'Snap',
  modules: [NativeModule(id: 'maplibre', platform: 'android', lock: 'native-modules/maplibre/module.lock.json')],
  service: const Service(baseUrl: 'http://localhost:8765', development: true),
  theme: const Theme(accent: '#FFDD33', background: '#F7F7F2',
    surface: '#FFFFFF', text: '#18191C', muted: '#72757E', radius: 24, padding: 20),
  logic: const Logic(source: 'logic.dart', prelude: 'prelude.dart', functions: [
    LogicFunction(name:'canSendMessage',parameters:['uint32','uint32'],returns:'uint32'),
    LogicFunction(name:'canUploadPhoto',parameters:['uint32'],returns:'uint32'),
    LogicFunction(name:'remainingStorySeconds',parameters:['uint32'],returns:'uint32'),
    LogicFunction(name:'shouldPublishLocation',parameters:['uint32','uint32'],returns:'uint32'),
  ]),
  root: Tabs(id: 'mainTabs', children: [
    Tab(id:'cameraTab',title:'Camera',icon:'camera',child:const Camera(id:'camera')),
    Tab(id:'chatTab',title:'Chat',icon:'chat',child:const Inbox(id:'inbox')),
    Tab(id:'storiesTab',title:'Stories',icon:'story',child:const Stories(id:'stories')),
    Tab(id:'mapTab',title:'Map',icon:'map',child:const FriendMap(id:'friendMap')),
    Tab(id:'accountTab',title:'You',icon:'user',child:const Account(id:'account')),
  ]),
);
