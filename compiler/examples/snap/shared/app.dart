import 'package:dcflight_authoring/dcflight.dart';

// Product copy, forms, transitions and requests are authored once here.
// DC Dart selects validation/result branches; native generators execute effects.
const username = Ref<String>(name: 'username');
const password = Ref<String>(name: 'password');
const displayName = Ref<String>(name: 'displayName');
const token = Ref<String>(name: 'token');
const ready = Ref<bool>(name: 'ready');
const page = Style(padding: 24, gap: 16, fill: true, maxWidth: 560);
const heading = Style(fontSize: 40, fontWeight: 'bold', color: '#18191C');
const input = Style(fill: true, padding: 16, radius: 16, fontSize: 17,
    background: '#FFFFFF', color: '#18191C', borderColor: '#E4E5DD', borderWidth: 1);
const canvas = Style(background: '#F7F7F2', fill: true);
const primary =
    Style(fill: true, background: '#FFDD33', color: '#18191C', padding: 16, radius: 18, fontSize: 17, fontWeight: 'bold', align: 'center');
const secondary =
    Style(fill: true, background: '#EEEEEA', color: '#18191C', padding: 14, radius: 18, fontSize: 16, fontWeight: 'regular', align: 'center');

FlowCase message(int code, String text) => FlowCase(code: code, effects: [
      SetEffect(target: 'ready', value: true),
      SetEffect(target: 'message', value: text),
    ]);

FlowAction errors(String id, {bool clearSession = false}) => FlowAction(
      id: id,
      function: 'classifyFailure',
      arguments: [const Ref<int>(name: 'status')],
      cases: [
        message(0,
            'Could not reach the service. Check your connection and try again.'),
        FlowCase(code: 1, effects: [
          SetEffect(target: 'ready', value: true),
          SetEffect(
              target: 'message',
              value: clearSession
                  ? 'Your session expired. Please sign in again.'
                  : 'Username or password was not accepted.'),
          if (clearSession) ...[
            SetEffect(target: 'token', value: ''),
            ...clearPrivateData(),
            SetEffect(target: 'userId', value: ''),
            SetEffect(target: 'displayName', value: ''),
            SetEffect(target: 'password', value: ''),
            SecureEffect(
                operation: 'delete',
                key: 'session',
                target: 'token',
                failure: 'storageFailed'),
            NavigateEffect(action: 'showLogin'),
          ],
        ]),
        message(2, 'That username is already taken. Choose another.'),
        message(3,
            'Check your details. Usernames use letters, numbers and underscores.'),
        message(4, 'Too many attempts. Wait a minute before trying again.'),
        message(5,
            'The service could not complete this request. Please try again.'),
      ],
    );

FlowAction authenticate(bool registering) => FlowAction(
      id: registering ? 'register' : 'login',
      function: registering ? 'decideRegister' : 'decideLogin',
      failure: 'authInputFailed',
      arguments: [
        username,
        Length(password),
        if (registering) Length(displayName)
      ],
      cases: [
        message(0, 'Use 3–24 letters, numbers or underscores for your username.'),
        message(1, 'Use a password between 12 and 128 characters.'),
        if (registering)
          message(2, 'Use a display name between 1 and 60 characters.'),
        FlowCase(code: 3, effects: [
          LogicCallEffect(
              function: 'canonicalHandle',
              arguments: [username],
              target: 'canonicalUsername',
              success: registering ? 'sendRegister' : 'sendLogin',
              failure: 'authInputFailed'),
        ]),
      ],
    );

// Both requests consume only the validated shared logic result.
FlowAction sendAuthentication(bool registering) => FlowAction(
      id: registering ? 'sendRegister' : 'sendLogin',
      cases: [FlowCase(code: 0, effects: [
          SetEffect(target: 'ready', value: false),
          SetEffect(
              target: 'message',
              value: registering ? 'Creating your account…' : 'Signing in…'),
          RequestEffect(
              id: registering ? 'registerRequest' : 'loginRequest',
              method: 'POST',
              path: registering ? '/v1/auth/register' : '/v1/auth/login',
              body: {
                'username': const Ref<String>(name: 'canonicalUsername'),
                'password': password,
                if (registering) 'display_name': displayName
              },
              outputs: {
                'token': ['token'],
                'userId': ['user', 'id'],
                'displayName': ['user', 'display_name'],
                'username': ['user', 'username']
              },
              success: 'authenticated',
              failure: 'authFailed',
              statusTarget: 'status'),
      ])],
    );

List<Node> status(String prefix) => [
      Text.bind(const Ref<String>(name: 'message'), id: '${prefix}Status',
          visibleWhen: const BooleanNot(StringIsEmpty(Ref<String>(name: 'message')))),
    ];

Node authenticationForm(bool register) {
  final prefix = register ? 'register' : 'login';
  return Scroll(id: '${prefix}Scroll', style: canvas, children: [
    Column(id: '${prefix}Form', style: page, children: [
      Text('Snap', id: '${prefix}Brand', style: heading),
      Text(register ? 'A place for your people.' : 'Welcome back.',
          id: '${prefix}Subtitle'),
      if (register) ...[
        Text('Display name', id: '${prefix}NameLabel'),
        TextField(
            id: '${prefix}Name',
            value: displayName,
            style: input,
            placeholder: 'How friends see you',
            enabledWhen: ready),
      ],
      Text('Username', id: '${prefix}UsernameLabel'),
      TextField(
          id: '${prefix}Username',
          value: username,
          style: input,
          placeholder: 'Your username',
          enabledWhen: ready),
      Text('Password', id: '${prefix}PasswordLabel'),
      SecureField(
          id: '${prefix}Password',
          value: password,
          style: input,
          placeholder: 'At least 12 characters',
          enabledWhen: ready),
      ...status(prefix),
      Button(register ? 'Create account' : 'Sign in',
          id: '${prefix}Submit',
          action: prefix,
          style: primary,
          enabledWhen: ready),
      Button(
          register
              ? 'Already have an account? Sign in'
              : 'New here? Create an account',
          id: '${prefix}Switch',
          action: register ? 'openLogin' : 'openRegister',
          style: secondary,
          enabledWhen: ready),
      if (!register)
        Button('Restore saved session',
            id: 'restoreSession',
            action: 'restore',
            style: secondary,
            enabledWhen: ready),
    ])
  ]);
}

const query = Ref<String>(name: 'query');
const selectedUser = Ref<String>(name: 'selectedUser');
const selectedRequest = Ref<String>(name: 'selectedRequest');
const conversationId = Ref<String>(name: 'conversationId');
const draft = Ref<String>(name: 'draft');
const messageCursor = Ref<int>(name: 'messageCursor');
const privateCollections = ['searchResults', 'friends', 'requests', 'conversations', 'messages', 'stories', 'locations'];
List<Effect> clearPrivateData() => [
  for (final name in privateCollections) ClearCollectionEffect(target: name),
  for (final name in ['query', 'selectedUser', 'selectedRequest', 'conversationId', 'draft'])
    SetEffect(target: name, value: ''),
  SetEffect(target: 'messageCursor', value: 0),
  ClearMediaEffect(target: 'photo'),
  SetEffect(target:'cameraActive',value:false),SetEffect(target:'cameraReady',value:false),SetEffect(target:'locationConsent',value:false),
  SetEffect(target:'latitude',value:0),SetEffect(target:'longitude',value:0),SetEffect(target:'accuracy',value:0),SetEffect(target:'mapExpires',value:0),
  for(final name in ['photoCaption','uploadedMediaId','selectedStory','storyMediaId','storyCaption']) SetEffect(target:name,value:''),
  SetEffect(target:'storyVisible',value:false),
  SetEffect(target:'storyOwned',value:false),
  SetEffect(target:'storyExpires',value:0),
];
Collection peopleCollection(String name) => Collection(name: name, key: 'id', fields: {
  'id': CollectionField(type: 'string'),
  'username': CollectionField(type: 'string'),
  'display_name': CollectionField(type: 'string'),
});
FlowAction serviceRequest(String id, {required String method, required Object path,
    Object body = const <String,Object>{}, Map<String, Object> outputs = const {},
    String success = 'requestComplete', String pending = 'Loading…'}) => FlowAction(id: id, cases: [
  FlowCase(code: 0, effects: [
    SetEffect(target: 'ready', value: false), SetEffect(target: 'message', value: pending),
    RequestEffect(id: '${id}Request', method: method, path: path, body: body,
      bearer: token, outputs: outputs, success: success, failure: 'socialFailed', statusTarget: 'status')
  ])
]);
FlowAction openPage(String id, String navigation, {List<Effect> effects = const []}) => FlowAction(id: id, cases: [
  FlowCase(code: 0, effects: [CancelEffect(), SetEffect(target: 'ready', value: true),
    SetEffect(target: 'message', value: ''), ...effects, NavigateEffect(action: navigation)])
]);
Node collectionRows(String collection, String prefix, Ref<String> selection, String action) => Repeat(
  id: '${prefix}Repeat', collection: collection, selection: selection, action: action,
  child: Card(id: '${prefix}Card', style: const Style(fill: true, padding: 16, gap: 5, radius: 16, background: '#FFFFFF'), children: [
    Text.bind(FieldRef<String>(collection: collection, name: 'display_name'), id: '${prefix}Name', style: const Style(fontSize: 18, fontWeight: 'bold', color: '#18191C')),
    Text.bind(FieldRef<String>(collection: collection, name: 'username'), id: '${prefix}Username', style: const Style(fontSize: 14, color: '#72757E')),
  ]));
Node socialPage(String prefix, String title, List<Node> children) => Scroll(id: '${prefix}Scroll', style: canvas, children: [
  Column(id: '${prefix}Body', style: page, children: [Text(title, id: '${prefix}Title', style: heading), ...status(prefix), ...children])
]);
List<FlowAction> socialFlows() => [
  FlowAction(id: 'requestComplete', cases: [message(0, 'Updated.')]),
  FlowAction(id: 'friendRequested', cases: [message(0, 'Friend request sent. They can accept it in People.')]),
  FlowAction(id: 'friendAccepted', cases: [FlowCase(code: 0, effects: [SetEffect(target: 'message', value: 'Friend added.'), InvokeEffect(action: 'refreshRequests')])]),
  FlowAction(id: 'socialFailed', function: 'classifyFailure', arguments: [const Ref<int>(name: 'status')], cases: [
    message(0, 'Could not reach the service. Try refreshing.'),
    FlowCase(code: 1, effects: [InvokeEffect(action: 'sessionFailed')]),
    message(2, 'That request already exists or has already been handled.'),
    message(3, 'Check your input and try again.'),
    message(4, 'Too many requests. Wait a minute and try again.'),
    message(5, 'This action is unavailable. Refresh your friends and try again.'),
  ]),
  FlowAction(id: 'searchPeople', function: 'decideSearch', arguments: [Length(query)], cases: [
    message(0, 'Type 2–24 username characters to search.'),
    FlowCase(code: 1, effects: [InvokeEffect(action: 'searchPeopleRequestFlow')]),
  ]),
  serviceRequest('searchPeopleRequestFlow', method: 'GET', path: ['/v1/users?q=', query], outputs: {'searchResults': ['users']}),
  serviceRequest('requestFriend', method: 'POST', path: '/v1/friend-requests', body: {'user_id': selectedUser}, success: 'friendRequested'),
  serviceRequest('refreshFriends', method: 'GET', path: '/v1/friends', outputs: {'friends': ['friends']}),
  serviceRequest('refreshRequests', method: 'GET', path: '/v1/friend-requests?direction=incoming', outputs: {'requests': ['requests']}),
  serviceRequest('acceptFriend', method: 'POST', path: ['/v1/friend-requests/', selectedRequest, '/accept'], success: 'friendAccepted'),
  serviceRequest('refreshChats', method: 'GET', path: '/v1/conversations', outputs: {'conversations': ['conversations']}),
  serviceRequest('startChat', method: 'POST', path: '/v1/conversations', body: {'user_id': selectedUser}, outputs: {'conversationId': ['id']}, success: 'openConversation'),
  FlowAction(id: 'openConversation', cases: [FlowCase(code: 0, effects: [
    CancelEffect(), ClearCollectionEffect(target: 'messages'), SetEffect(target: 'draft', value: ''),
    SetEffect(target: 'messageCursor', value: 0), NavigateEffect(action: 'showConversation'), InvokeEffect(action: 'loadMessages')
  ])]),
  FlowAction(id: 'firstMessages', cases: [FlowCase(code: 0, effects: [ClearCollectionEffect(target: 'messages'), SetEffect(target: 'messageCursor', value: 0), InvokeEffect(action: 'loadMessages')])]),
  serviceRequest('loadMessages', method: 'GET', path: ['/v1/conversations/', conversationId, '/messages?after=', messageCursor],
    outputs: {'messages': ResponseCollection(path: ['messages'], mode: 'append'), 'messageCursor': ['next_after']}, success: 'messagesLoaded'),
  FlowAction(id: 'messagesLoaded', cases: [message(0, 'Messages loaded. Load more to check for newer messages.')]),
  FlowAction(id: 'sendMessage', function: 'decideMessage', arguments: [Length(draft)], cases: [
    message(0, 'Write a message between 1 and 2,000 characters.'),
    FlowCase(code: 1, effects: [InvokeEffect(action: 'sendMessageRequestFlow')]),
  ]),
  serviceRequest('sendMessageRequestFlow', method: 'POST', path: ['/v1/conversations/', conversationId, '/messages'], body: {'text': draft}, success: 'messageSent', pending: 'Sending…'),
  FlowAction(id: 'messageSent', cases: [FlowCase(code: 0, effects: [SetEffect(target: 'draft', value: ''), InvokeEffect(action: 'loadMessages')])]),
];

const photo = MediaRef(name: 'photo');
const photoCaption = Ref<String>(name: 'photoCaption');
const uploadedMediaId = Ref<String>(name: 'uploadedMediaId');
const selectedStory = Ref<String>(name: 'selectedStory');
const storyMediaId = Ref<String>(name: 'storyMediaId');
const storyVisible = Ref<bool>(name: 'storyVisible');
FlowAction pickPhoto(bool forStory) => FlowAction(id: forStory ? 'pickStoryPhoto' : 'pickMessagePhoto', cases: [FlowCase(code: 0,effects: [
  CancelEffect(),SetEffect(target:'ready',value:false),SetEffect(target:'photoIntent',value:forStory?1:0),
  SetEffect(target:'photoCaption',value:''),SetEffect(target:'message',value:'Choose one photo from your library.'),
  PickPhotoEffect(target:'photo',success:'photoPicked',cancel:'photoCancelled',failure:'photoFailed'),
])]);
List<FlowAction> mediaFlows() => [
  pickPhoto(false),pickPhoto(true),
  FlowAction(id:'photoPicked',cases:[FlowCase(code:0,effects:[SetEffect(target:'ready',value:true),SetEffect(target:'message',value:''),NavigateEffect(action:'showComposer')])]),
  FlowAction(id:'photoCancelled',cases:[message(0,'Photo selection cancelled.')]),
  FlowAction(id:'photoFailed',cases:[message(0,'That photo could not be prepared. Choose a still image under 32 MB.')]),
  FlowAction(id:'closeComposer',cases:[FlowCase(code:0,effects:[CancelEffect(),ClearMediaEffect(target:'photo'),SetEffect(target:'photoCaption',value:''),SetEffect(target:'ready',value:true),NavigateEffect(action:'closePhoto')])]),
  FlowAction(id:'uploadPhoto',function:'decidePhoto',arguments:[MediaMetadata.bytes(photo),Length(photoCaption),const Ref<int>(name:'photoIntent')],cases:[
    message(0,'Choose a photo first.'),message(1,'This photo is larger than 8 MB. Choose another.'),
    message(2,'Keep story captions within 240 characters and message captions within 2,000.'),
    FlowCase(code:3,effects:[InvokeEffect(action:'uploadPhotoRequestFlow')]),
    message(4,'Choose where to share your photo again.'),
  ]),
  serviceRequest('uploadPhotoRequestFlow',method:'POST',path:'/v1/media',body:MediaBody(photo),outputs:{'uploadedMediaId':['id']},success:'photoUploaded',pending:'Uploading your photo…'),
  FlowAction(id:'photoUploaded',function:'decidePhotoDestination',arguments:[const Ref<int>(name:'photoIntent')],cases:[
    FlowCase(code:0,effects:[InvokeEffect(action:'sendPhotoMessage')]),FlowCase(code:1,effects:[InvokeEffect(action:'publishStory')]),
    message(2,'Choose where to share your photo again.'),
  ]),
  serviceRequest('sendPhotoMessage',method:'POST',path:['/v1/conversations/',conversationId,'/messages'],body:{'media_id':uploadedMediaId,'text':photoCaption},success:'photoMessageSent',pending:'Sending your photo…'),
  FlowAction(id:'photoMessageSent',cases:[FlowCase(code:0,effects:[ClearMediaEffect(target:'photo'),SetEffect(target:'photoCaption',value:''),NavigateEffect(action:'closePhoto'),InvokeEffect(action:'loadMessages')])]),
  serviceRequest('publishStory',method:'POST',path:'/v1/stories',body:{'media_id':uploadedMediaId,'caption':photoCaption},success:'storyPublished',pending:'Publishing your story…'),
  FlowAction(id:'storyPublished',cases:[FlowCase(code:0,effects:[ClearMediaEffect(target:'photo'),SetEffect(target:'photoCaption',value:''),NavigateEffect(action:'closePhoto'),InvokeEffect(action:'refreshStories')])]),
  serviceRequest('refreshStories',method:'GET',path:'/v1/stories',outputs:{'stories':['stories']}),
  FlowAction(id:'openStory',cases:[FlowCase(code:0,effects:[ReadCollectionEffect(collection:'stories',key:selectedStory,outputs:{'storyMediaId':'media_id','storyExpires':'expires_at','storyCaption':'caption','storyOwned':'is_owner'},success:'storySelected',failure:'storyMissing')])]),
  FlowAction(id:'storySelected',cases:[FlowCase(code:0,effects:[SetEffect(target:'storyVisible',value:true),SetEffect(target:'message',value:''),NavigateEffect(action:'showStory'),InvokeEffect(action:'storyTick')])]),
  serviceRequest('deleteStory',method:'DELETE',path:['/v1/stories/',selectedStory],success:'storyDeleted'),
  FlowAction(id:'storyDeleted',cases:[FlowCase(code:0,effects:[SetEffect(target:'storyVisible',value:false),SetEffect(target:'storyMediaId',value:''),SetEffect(target:'storyCaption',value:''),NavigateEffect(action:'closePhoto'),InvokeEffect(action:'refreshStories')])]),
  FlowAction(id:'storyMissing',cases:[message(0,'This story is no longer in the list. Refresh stories.')]),
  FlowAction(id:'storyTick',cases:[FlowCase(code:0,effects:[ClockEffect(target:'clockNow',failure:'clockUnavailable'),InvokeEffect(action:'storyExpiry')])]),
  FlowAction(id:'storyExpiry',function:'decideStoryExpiry',arguments:[Flag(storyVisible),const Ref<int>(name:'clockNow'),const Ref<int>(name:'storyExpires')],cases:[
    FlowCase(code:0,effects:[]),FlowCase(code:1,effects:[SetEffect(target:'storyVisible',value:false),SetEffect(target:'storyMediaId',value:''),SetEffect(target:'storyCaption',value:''),SetEffect(target:'message',value:'This story has expired.')]),
  ]),
  FlowAction(id:'clockUnavailable',cases:[FlowCase(code:0,effects:[SetEffect(target:'storyVisible',value:false),SetEffect(target:'storyMediaId',value:''),ClearCollectionEffect(target:'locations'),SetEffect(target:'mapExpires',value:0),SetEffect(target:'message',value:'The device clock cannot safely display expiring stories or locations.')])]),
];

const cameraActive=Ref<bool>(name:'cameraActive');
const cameraReady=Ref<bool>(name:'cameraReady');
const locationConsent=Ref<bool>(name:'locationConsent');
List<FlowAction> deviceFlows()=>[
  FlowAction(id:'startCamera',cases:[FlowCase(code:0,effects:[SetEffect(target:'ready',value:false),PermissionEffect(capability:'camera',statusTarget:'cameraPermission',success:'cameraPermissionGranted',failure:'cameraPermissionDenied')])]),
  FlowAction(id:'cameraPermissionGranted',cases:[FlowCase(code:0,effects:[SetEffect(target:'cameraActive',value:true),SetEffect(target:'ready',value:true),SetEffect(target:'message',value:'Frame a moment to share with your friends.')])]),
  FlowAction(id:'cameraPermissionDenied',cases:[message(0,'Camera is unavailable on this device. Check permissions or choose a library photo.')]),
  FlowAction(id:'stopCamera',cases:[FlowCase(code:0,effects:[SetEffect(target:'cameraActive',value:false),SetEffect(target:'cameraReady',value:false),SetEffect(target:'ready',value:true)])]),
  FlowAction(id:'frontCamera',cases:[FlowCase(code:0,effects:[CameraFacingEffect(resource:'mainCamera',facing:'front',success:'cameraSwitched',failure:'cameraSwitchFailed')])]),
  FlowAction(id:'backCamera',cases:[FlowCase(code:0,effects:[CameraFacingEffect(resource:'mainCamera',facing:'back',success:'cameraSwitched',failure:'cameraSwitchFailed')])]),
  FlowAction(id:'cameraSwitched',cases:[message(0,'Camera changed.')]),
  FlowAction(id:'cameraSwitchFailed',cases:[message(0,'That camera is unavailable on this device.')]),
  FlowAction(id:'captureStory',function:'decideCapture',arguments:[Flag(cameraReady),Flag(ready)],cases:[
    FlowCase(code:0,effects:[SetEffect(target:'message',value:'Start the camera and wait until the preview is ready.')]),
    FlowCase(code:1,effects:[SetEffect(target:'photoIntent',value:1),SetEffect(target:'photoCaption',value:''),SetEffect(target:'ready',value:false),CapturePhotoEffect(resource:'mainCamera',target:'photo',success:'photoPicked',cancel:'photoCancelled',failure:'photoFailed')]),
  ]),
  openPage('openPeople','showPeople'),
  FlowAction(id:'mapTick',cases:[FlowCase(code:0,effects:[ClockEffect(target:'clockNow',failure:'clockUnavailable'),InvokeEffect(action:'mapExpiry')])]),
  FlowAction(id:'mapExpiry',function:'decideMapExpiry',arguments:[const Ref<int>(name:'clockNow'),const Ref<int>(name:'mapExpires')],cases:[FlowCase(code:0,effects:[]),FlowCase(code:1,effects:[ClearCollectionEffect(target:'locations'),SetEffect(target:'mapExpires',value:0),SetEffect(target:'message',value:'Cached map locations expired. Refresh to see current locations.')])]),
  serviceRequest('refreshMap',method:'GET',path:'/v1/map',outputs:{'locations':['locations'],'mapExpires':['expires_at']}),
  FlowAction(id:'shareLocation',cases:[FlowCase(code:0,effects:[SetEffect(target:'locationConsent',value:true),SetEffect(target:'ready',value:false),PermissionEffect(capability:'location',statusTarget:'locationPermission',success:'locationPermissionGranted',failure:'locationPermissionDenied')])]),
  FlowAction(id:'locationPermissionGranted',cases:[FlowCase(code:0,effects:[LocationEffect(latitudeTarget:'latitude',longitudeTarget:'longitude',accuracyTarget:'accuracy',success:'locationMeasured',cancel:'locationCancelled',failure:'locationFailed')])]),
  FlowAction(id:'locationPermissionDenied',cases:[FlowCase(code:0,effects:[SetEffect(target:'locationConsent',value:false),SetEffect(target:'ready',value:true),SetEffect(target:'message',value:'Location access was not granted. No new location was shared.')])]),
  FlowAction(id:'locationCancelled',cases:[message(0,'Location request cancelled.')]),
  FlowAction(id:'locationFailed',cases:[message(0,'Could not get a fresh location. Try again outside or check device settings.')]),
  FlowAction(id:'locationMeasured',function:'decideLocation',arguments:[Flag(locationConsent),const Ref<int>(name:'accuracy')],cases:[
    message(0,'Location sharing is off. No new location was shared.'),message(1,'This location is not accurate enough. Try again before sharing.'),
    FlowCase(code:2,effects:[InvokeEffect(action:'publishLocation')]),
  ]),
  serviceRequest('publishLocation',method:'PUT',path:'/v1/location',body:{'enabled':true,'latitude_e6':const Ref<int>(name:'latitude'),'longitude_e6':const Ref<int>(name:'longitude')},success:'locationShared',pending:'Sharing your location with friends…'),
  FlowAction(id:'locationShared',cases:[message(0,'Your last location is shared with friends for one hour. Refresh sharing to send a newer location.')]),
  FlowAction(id:'stopSharing',cases:[FlowCase(code:0,effects:[CancelEffect(),SetEffect(target:'locationConsent',value:false),SetEffect(target:'latitude',value:0),SetEffect(target:'longitude',value:0),SetEffect(target:'accuracy',value:0),SetEffect(target:'ready',value:false),RequestEffect(id:'stopSharingRequest',method:'PUT',path:'/v1/location',bearer:token,body:{'enabled':false},success:'sharingStopped',failure:'stopSharingFailed',statusTarget:'status')])]),
  FlowAction(id:'sharingStopped',cases:[message(0,'Location sharing stopped. Your shared coordinates were removed.')]),
  FlowAction(id:'stopSharingFailed',cases:[message(0,'Could not confirm removal. Your last shared location may remain visible until its one-hour expiry; retry Stop sharing.')]),
];

App buildApp() => RoutedApp(
      id: 'com.dotcorr.snapshared',
      name: 'Snap',
      state: {
        'username': '',
        'canonicalUsername': '',
        'password': '',
        'displayName': '',
        'token': '',
        'revocationToken': '',
        'userId': '',
        'message': '',
        'ready': true,
        'status': 0,
        'query': '', 'selectedUser': '', 'selectedRequest': '', 'conversationId': '', 'draft': '', 'messageCursor': 0,
        'photoCaption':'','uploadedMediaId':'','photoIntent':0,'selectedStory':'','storyMediaId':'','storyCaption':'','storyExpires':0,'clockNow':0,'storyVisible':false,'storyOwned':false,
        'cameraActive':false,'cameraReady':false,'cameraPermission':0,'locationPermission':0,'locationConsent':false,'latitude':0,'longitude':0,'accuracy':0,'mapExpires':0
      },
      cameraResources: const [CameraResource(id:'mainCamera')],
      permissionDescriptions: const {'camera':'Take a photo to share with your friends on Snap.','location':'Share a location you choose with accepted friends for one hour.'},
      mapConfig: const MapConfig(androidModule:'maplibre',styleUrl:'https://tiles.openfreemap.org/styles/liberty',attribution:'OpenFreeMap https://openfreemap.org/ · © OpenMapTiles https://openmaptiles.org/ · Data from OpenStreetMap https://www.openstreetmap.org/copyright'),
      modules: const [NativeModule(id:'maplibre',platform:'android',lock:'../native-modules/maplibre-compose/module.lock.json')],
      media: const [MediaState(name:'photo')],
      timers: const [Timer(id:'storyClock',intervalMs:1000,action:'storyTick'),Timer(id:'mapClock',intervalMs:1000,action:'mapTick')],
      collections: [
        Collection(name:'locations',key:'id',fields:{'id':CollectionField(type:'string'),'display_name':CollectionField(type:'string'),'username':CollectionField(type:'string'),'latitude_e6':CollectionField(type:'int'),'longitude_e6':CollectionField(type:'int')}),
        Collection(name:'stories',key:'id',fields:{'id':CollectionField(type:'string'),'media_id':CollectionField(type:'string'),'caption':CollectionField(type:'string'),'expires_at':CollectionField(type:'int'),'is_owner':CollectionField(type:'bool'),'display_name':CollectionField(type:'string'),'username':CollectionField(type:'string')}),
        for (final name in ['searchResults','friends','requests','conversations']) peopleCollection(name),
        Collection(name: 'messages', key: 'id', fields: {
          'id': CollectionField(type: 'int'), 'sender': CollectionField(type: 'string'),
          'text': CollectionField(type: 'string'), 'has_media':CollectionField(type:'bool'), 'sender_display_name': CollectionField(type: 'string'), 'media_id': CollectionField(type: 'string', defaultValue: ''),
        }),
      ],
      transport:
          const Transport(baseUrl: 'http://localhost:8765', development: true),
      initialAction: 'restore',
      logic: const Logic(
          source: 'logic.dart',
          prelude: 'prelude.dart',
          functions: [
            LogicFunction(name:'decideMapExpiry',parameters:['uint32','uint32'],returns:'uint32'),
            LogicFunction(name:'decideCapture',parameters:['uint32','uint32'],returns:'uint32'),
            LogicFunction(name:'decideLocation',parameters:['uint32','uint32'],returns:'uint32'),
            LogicFunction(name:'decidePhoto',parameters:['uint32','uint32','uint32'],returns:'uint32'),
            LogicFunction(name:'decidePhotoDestination',parameters:['uint32'],returns:'uint32'),
            LogicFunction(name:'decideStoryExpiry',parameters:['uint32','uint32','uint32'],returns:'uint32'),
            LogicFunction(name: 'decideSearch', parameters: ['uint32'], returns: 'uint32'),
            LogicFunction(name: 'decideMessage', parameters: ['uint32'], returns: 'uint32'),
            LogicFunction(name: 'canonicalHandle', parameters: ['utf8'],
                returns: 'utf8', maxOutputBytes: 24),
            LogicFunction(
                name: 'decideLogin',
                parameters: ['utf8', 'uint32'],
                returns: 'uint32'),
            LogicFunction(
                name: 'decideRegister',
                parameters: ['utf8', 'uint32', 'uint32'],
                returns: 'uint32'),
            LogicFunction(
                name: 'decideProfile',
                parameters: ['uint32'],
                returns: 'uint32'),
            LogicFunction(
                name: 'classifyFailure',
                parameters: ['uint32'],
                returns: 'uint32'),
            LogicFunction(
                name: 'decideRestore',
                parameters: ['uint32'],
                returns: 'uint32'),
          ]),
      navigationActions: const [NavigationAction.push('people',id:'showPeople'),
        NavigationAction.push('composer',id:'showComposer'),NavigationAction.back(id:'closePhoto'),NavigationAction.push('story',id:'showStory'),
        NavigationAction.resetRoot('login', id: 'showLogin'),
        NavigationAction.replace('register', id: 'showRegister'),
        NavigationAction.resetRoot('home', id: 'showHome'),
        NavigationAction.push('conversation', id: 'showConversation'),
      ],
      flowActions: [
        ...socialFlows(),...mediaFlows(),...deviceFlows(),
        authenticate(false),
        authenticate(true),
        sendAuthentication(false),
        sendAuthentication(true),
        errors('authFailed'),
        FlowAction(id: 'authInputFailed', cases: [message(0, 'Check your account details and try again.')]),
        errors('sessionFailed', clearSession: true),
        FlowAction(id: 'openLogin', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'message', value: ''),
            SetEffect(target: 'password', value: ''),
            NavigateEffect(action: 'showLogin')
          ])
        ]),
        FlowAction(id: 'openRegister', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'message', value: ''),
            SetEffect(target: 'password', value: ''),
            NavigateEffect(action: 'showRegister')
          ])
        ]),
        FlowAction(id: 'storageFailed', cases: [
          message(0,
              'Secure storage is unavailable. Unlock the device and try again.')
        ]),
        FlowAction(id: 'restore', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'ready', value: false),
            SetEffect(target: 'message', value: 'Checking your saved session…'),
            SecureEffect(
                operation: 'read',
                key: 'session',
                target: 'token',
                failure: 'storageFailed'),
            InvokeEffect(action: 'restoreDecision'),
          ])
        ]),
        FlowAction(
            id: 'restoreDecision',
            function: 'decideRestore',
            arguments: [
              Length(token)
            ],
            cases: [
              message(0, ''),
              FlowCase(code: 1, effects: [
                RequestEffect(
                    id: 'restoreRequest',
                    method: 'GET',
                    path: '/v1/me',
                    bearer: token,
                    outputs: {
                      'userId': ['id'],
                      'username': ['username'],
                      'displayName': ['display_name']
                    },
                    success: 'restored',
                    failure: 'sessionFailed',
                    statusTarget: 'status')
              ]),
            ]),
        FlowAction(id: 'authenticated', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'password', value: ''),
            SecureEffect(
                operation: 'write',
                key: 'session',
                target: 'token',
                failure: 'storageFailed'),
            InvokeEffect(action: 'restored'),
          ])
        ]),
        FlowAction(id: 'restored', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'ready', value: true),
            SetEffect(target: 'message', value: ''),
            ...clearPrivateData(),
            NavigateEffect(action: 'showHome')
          ])
        ]),
        FlowAction(id: 'saveProfile', function: 'decideProfile', arguments: [
          Length(displayName)
        ], cases: [
          message(2, 'Use a display name between 1 and 60 characters.'),
          FlowCase(code: 3, effects: [
            SetEffect(target: 'ready', value: false),
            SetEffect(target: 'message', value: 'Saving your profile…'),
            RequestEffect(
                id: 'profileRequest',
                method: 'PATCH',
                path: '/v1/me',
                bearer: token,
                body: {'display_name': displayName},
                outputs: {
                  'displayName': ['display_name']
                },
                success: 'profileSaved',
                failure: 'sessionFailed',
                statusTarget: 'status')
          ]),
        ]),
        FlowAction(id: 'profileSaved', cases: [message(0, 'Profile saved.')]),
        FlowAction(id: 'logout', cases: [
          FlowCase(code: 0, effects: [
            CancelEffect(),
            SetEffect(target: 'revocationToken', value: token),
            SetEffect(target: 'password', value: ''),
            SecureEffect(
                operation: 'delete',
                key: 'session',
                target: 'token',
                failure: 'logoutStorageFailed'),
            SetEffect(target: 'token', value: ''),
            ...clearPrivateData(),
            SetEffect(target: 'userId', value: ''),
            SetEffect(target: 'displayName', value: ''),
            SetEffect(target: 'ready', value: true),
            SetEffect(target: 'message', value: 'Signing out…'),
            NavigateEffect(action: 'showLogin'),
            RequestEffect(
                id: 'logoutRequest',
                method: 'POST',
                path: '/v1/auth/logout',
                bearer: const Ref<String>(name: 'revocationToken'),
                success: 'loggedOut',
                failure: 'logoutFailed',
                statusTarget: 'status'),
          ])
        ]),
        FlowAction(id: 'loggedOut', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'revocationToken', value: ''),
            SetEffect(target: 'message', value: 'Signed out.')
          ])
        ]),
        FlowAction(id: 'logoutFailed', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'revocationToken', value: ''),
            SetEffect(
                target: 'message',
                value:
                    'Signed out on this device. The service could not confirm revocation; the old session expires within seven days.')
          ])
        ]),
        FlowAction(id: 'logoutStorageFailed', cases: [
          FlowCase(code: 0, effects: [
            SetEffect(target: 'ready', value: true),
            SetEffect(
                target: 'message',
                value:
                    'Could not clear secure storage. Unlock this device and try signing out again.')
          ])
        ]),
      ],
      root: NavigationStack(id: 'appNavigation', initialRoute: 'login'),
      screens: [
        Screen(id:'cameraCapture',title:'',body:socialPage('cameraCapture','Here. Now.',[
          CameraPreview(id:'liveCamera',resource:'mainCamera',active:cameraActive,ready:cameraReady,accessibilityLabel:'Live camera preview',style:const Style(fill:true,height:360,radius:24,background:'#18191C'),loading:Text('Start the camera to frame a photo.',id:'cameraLoading',style:const Style(fill:true,padding:24,align:'center',fontSize:17,color:'#D0D1D5')),failure:Text('Camera is unavailable on this device. Check permissions or choose a library photo.',id:'cameraUnavailable',style:const Style(fill:true,padding:24,align:'center',fontSize:17,color:'#FFFFFF'))),
          Button('Start camera',id:'startCameraButton',action:'startCamera',style:secondary,enabledWhen:ready),
          Button('Capture a story',id:'captureStoryButton',action:'captureStory',style:primary,enabledWhen:cameraReady),
          Row(id:'cameraFacing',style:const Style(gap:8),children:[Button('Front camera',id:'cameraFront',action:'frontCamera',style:secondary,enabledWhen:cameraReady),Button('Back camera',id:'cameraBack',action:'backCamera',style:secondary,enabledWhen:cameraReady)]),
          Button('Choose a library photo',id:'cameraLibrary',action:'pickStoryPhoto',style:secondary,enabledWhen:ready),
          Button('Stop camera',id:'cameraStop',action:'stopCamera',style:secondary),
        ])),
        Screen(id:'map',title:'',body:socialPage('map','Somewhere close.',[
          Text('Only accepted friends can see a location you explicitly share. Each update expires after one hour.',id:'mapPrivacy'),
          NativeMap(id:'friendsNativeMap',collection:'locations',latitudeField:'latitude_e6',longitudeField:'longitude_e6',titleField:'display_name',region:const MapRegion(latitudeE6:0,longitudeE6:0,latitudeSpanE6:160000000,longitudeSpanE6:360000000),style:const Style(fill:true,height:360,radius:20),annotation:Card(id:'friendPin',style:const Style(padding:8,radius:12,background:'#FFDD33'),children:[Text.bind(const FieldRef<String>(collection:'locations',name:'display_name'),id:'friendPinName',style:const Style(fontSize:14,fontWeight:'bold',color:'#18191C'))]),loading:Text('Loading map…',id:'mapLoading'),failure:Text('Map unavailable. Check your connection and retry.',id:'mapFailure')),
          Button('Refresh friends on map',id:'mapRefresh',action:'refreshMap',style:secondary,enabledWhen:ready),
          Button('Share my location for one hour',id:'mapShare',action:'shareLocation',style:primary,enabledWhen:ready),
          Button('Stop sharing',id:'mapStopSharing',action:'stopSharing',style:secondary),
        ])),
        Screen(id:'composer',title:'Share a photo',titleDisplay:TitleDisplay.compact,body:socialPage('composer','A little moment.',[
          LocalImage(id:'photoPreview',source:photo,accessibilityLabel:'Your selected photo',style:const Style(fill:true,height:300,radius:20,align:'center',background:'#18191C'),loading:Text('Choose a photo to preview.',id:'photoPreviewEmpty',style:const Style(fill:true,padding:24,align:'center',fontSize:17,color:'#D0D1D5')),failure:Text('Photo preview unavailable.',id:'photoPreviewFailure',style:const Style(fill:true,padding:24,align:'center',fontSize:17,color:'#FFFFFF'))),
          TextField(id:'photoCaptionInput',value:photoCaption,placeholder:'Add a caption',style:input,enabledWhen:ready),
          Button('Share photo',id:'sharePreparedPhoto',action:'uploadPhoto',style:primary,enabledWhen:ready),
          Button('Cancel',id:'cancelPhoto',action:'closeComposer',style:secondary,enabledWhen:ready),
        ])),
        Screen(id:'stories',title:'',body:socialPage('stories','Life, lately.',[
          Text('Stories are visible to friends for 24 hours.',id:'storiesExplanation'),
          Button('Choose a story photo',id:'storyChoosePhoto',action:'pickStoryPhoto',style:primary,enabledWhen:ready),
          Button('Refresh stories',id:'storiesRefresh',action:'refreshStories',style:secondary,enabledWhen:ready),
          collectionRows('stories','storyRow',selectedStory,'openStory'),
        ])),
        Screen(id:'story',title:'Story',body:socialPage('storyView','A moment shared.',[
          RemoteImage(id:'storyPhoto',path:['/v1/media/',storyMediaId],bearer:token,accessibilityLabel:'Shared story photo',visibleWhen:storyVisible,style:const Style(fill:true,height:380,radius:20),loading:Text('Loading story…',id:'storyPhotoLoading'),failure:Text('This photo is unavailable or expired.',id:'storyPhotoFailure')),
          Text.bind(const Ref<String>(name:'storyCaption'),id:'storyPhotoCaption',visibleWhen:storyVisible),
          Button('Delete my story',id:'deleteOwnStory',action:'deleteStory',style:secondary,enabledWhen:ready,visibleWhen:const Ref<bool>(name:'storyOwned')),
        ])),
        Screen(id: 'home', title: '', body: Tabs(id: 'homeTabs', children: [
          Tab(id:'cameraTab',title:'Camera',icon:'camera',child:NavigationStack(id:'cameraNavigation',initialRoute:'cameraCapture')),
          Tab(id: 'chatTab', title: 'Chat', icon: 'chat', child: NavigationStack(id: 'chatNavigation', initialRoute: 'chats')),
          Tab(id:'storiesTab',title:'Stories',icon:'image',child:NavigationStack(id:'storiesNavigation',initialRoute:'stories')),
          Tab(id:'mapTab',title:'Map',icon:'map',child:NavigationStack(id:'mapNavigation',initialRoute:'map')),
          Tab(id: 'youTab', title: 'You', icon: 'settings', child: NavigationStack(id: 'youNavigation', initialRoute: 'profile')),
        ])),
        Screen(id: 'people', title: '', body: socialPage('people', 'Your people', [
          Text('Search a username. Tap a result to send a friend request.', id: 'peopleInstructions'),
          TextField(id: 'peopleQuery', value: query, placeholder: 'Username', style: input, enabledWhen: ready),
          Button('Search people', id: 'peopleSearch', action: 'searchPeople', style: primary, enabledWhen: ready),
          collectionRows('searchResults','searchResult',selectedUser,'requestFriend'),
          Text('Friend requests', id: 'requestsHeading', style: const Style(fontSize: 22, fontWeight: 'bold')),
          Text('Tap an incoming request to accept.', id: 'requestsInstructions'),
          Button('Refresh requests', id: 'requestsRefresh', action: 'refreshRequests', style: secondary, enabledWhen: ready),
          collectionRows('requests','requestRow',selectedRequest,'acceptFriend'),
          Text('Friends', id: 'friendsHeading', style: const Style(fontSize: 22, fontWeight: 'bold')),
          Text('Tap a friend to start a conversation.', id: 'friendsInstructions'),
          Button('Refresh friends', id: 'friendsRefresh', action: 'refreshFriends', style: secondary, enabledWhen: ready),
          collectionRows('friends','friendRow',selectedUser,'startChat'),
        ])),
        Screen(id: 'chats', title: '', body: socialPage('chats', 'Good company.', [
          Button('Find and manage friends',id:'chatsPeople',action:'openPeople',style:secondary,enabledWhen:ready),
          Text('Your conversations. Refresh to check for updates.', id: 'chatsInstructions'),
          Button('Refresh chats', id: 'chatsRefresh', action: 'refreshChats', style: primary, enabledWhen: ready),
          collectionRows('conversations','conversationRow',conversationId,'openConversation'),
        ])),
        Screen(id: 'conversation', title: 'Conversation', body: socialPage('conversation', 'Keep in touch.', [
          Text('Messages are oldest first. Load more to check for new messages. Delivery means saved by the service.', id: 'conversationInstructions'),
          Row(id: 'messagePages', style: const Style(gap: 8), children: [
            Button('Reload history', id: 'messagesFirst', action: 'firstMessages', style: secondary, enabledWhen: ready),
            Button('Load more', id: 'messagesNext', action: 'loadMessages', style: secondary, enabledWhen: ready),
          ]),
          Repeat(id: 'messageRows', collection: 'messages', child: Card(id: 'messageCard', style: const Style(padding: 16, gap: 6, fill: true, radius: 16, background: '#FFFFFF'), children: [
            Text.bind(const FieldRef<String>(collection: 'messages', name: 'sender_display_name'), id: 'messageSender', style: const Style(fontSize: 12, color: '#72757E')),
            RemoteImage(id:'messagePhoto',path:['/v1/media/',const FieldRef<String>(collection:'messages',name:'media_id')],bearer:token,accessibilityLabel:'Photo sent in this conversation',visibleWhen:const FieldRef<bool>(collection:'messages',name:'has_media'),style:const Style(fill:true,height:260,radius:16),loading:Text('Loading photo…',id:'messagePhotoLoading'),failure:Text('Photo unavailable.',id:'messagePhotoFailure')),
            Text.bind(const FieldRef<String>(collection: 'messages', name: 'text'), id: 'messageBody', style: const Style(fontSize: 17, color: '#18191C')),
          ])),
          TextField(id: 'messageDraft', value: draft, placeholder: 'Write a message', style: input, enabledWhen: ready),
          Button('Choose a photo',id:'messageChoosePhoto',action:'pickMessagePhoto',style:secondary,enabledWhen:ready),
          Button('Send message', id: 'messageSend', action: 'sendMessage', style: primary, enabledWhen: ready),
        ])),
        Screen(id: 'login', title: '', body: authenticationForm(false)),
        Screen(id: 'register', title: '', body: authenticationForm(true)),
        Screen(
            id: 'profile',
            title: 'Your profile',
            body: Scroll(id: 'profileScroll', style: canvas, children: [
              Column(id: 'profileBody', style: page, children: [
                Text('Your corner of Snap', id: 'profileTitle', style: heading),
                Text.bind(username, id: 'profileUsername'),
                Text('Display name', id: 'profileNameLabel'),
                TextField(
                    id: 'profileName',
                    value: displayName,
                    placeholder: 'How friends see you',
                    style: input,
                    enabledWhen: ready),
                ...status('profile'),
                Button('Save profile',
                    id: 'profileSave',
                    action: 'saveProfile',
                    style: primary,
                    enabledWhen: ready),
                Button('Sign out',
                    id: 'profileLogout', action: 'logout', style: secondary),
              ])
            ])),
      ],
    );
