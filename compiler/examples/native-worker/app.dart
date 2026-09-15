import 'package:dcflight_authoring/dcflight.dart';

// The verification harness supplies a catalog containing these actual SDK APIs.
App buildApp() => App(
  version: 2, id: 'com.dotcorr.nativeworker', name: 'Native worker operation',
  sdkCatalog: 'sdk.sqlite', state: {'identifier': '', 'status': 'Ready'},
  nativeOperations: [NativeOperation(name: 'newIdentifier',
    execution: NativeExecution.worker, result: NativeScalar.string,
    ios: NativeImplementation(steps: [
      NativeCall('s:10Foundation4UUIDVACycfc', scope: 'Foundation', bind: 'uuid'),
      NativeCall('s:10Foundation4UUIDV10uuidStringSSvp', scope: 'Foundation', receiver: NativeRef('uuid'), bind: 'text'),
    ], result: NativeRef('text')),
    android: NativeImplementation(steps: [
      NativeCall('java.util.UUID#randomUUID()', bind: 'uuid'),
      NativeCall('java.util.UUID#toString()', receiver: NativeRef('uuid'), bind: 'text'),
    ], result: NativeRef('text')),
  )],
  root: NavigationStack(id: 'stack', initialRoute: 'home'),
  routes: [Screen(id: 'home', title: 'Native worker operation', body: Column(id:'content', children:[
    Text.bind(Ref<String>(name:'identifier'), id:'identifier'),
    Text.bind(Ref<String>(name:'status'), id:'status'),
    Button('Generate identifier', id:'generateButton', action:'generate'),
  ]))],
  flowActions: [
    FlowAction(id:'generate', cases:[FlowCase(code:0,effects:[
      NativeOperationEffect(operation:'newIdentifier',target:'identifier',success:'accepted',failure:'rejected'),
    ])]),
    FlowAction(id:'accepted',cases:[FlowCase(code:0,effects:[SetEffect(target:'status',value:'Created natively')])]),
    FlowAction(id:'rejected',cases:[FlowCase(code:0,effects:[SetEffect(target:'status',value:'Could not create an identifier')])]),
  ],
);
