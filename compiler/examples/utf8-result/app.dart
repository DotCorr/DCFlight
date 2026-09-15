import 'package:dcflight_authoring/dcflight.dart';
// Review fixture only. Snap's authoritative app and backend are unchanged.
App buildApp() => App(
  version:2,id:'com.dotcorr.utf8result',name:'Shared handle normalization',
  state:{'username':'QA_User','canonical':'','status':'Ready'},
  logic:Logic(source:'logic.dart',prelude:'../snap-shared/prelude.dart',functions:[
    LogicFunction(name:'canonicalHandle',parameters:['utf8'],returns:'utf8',maxOutputBytes:24),
  ]),
  root:NavigationStack(id:'navigation',initialRoute:'home'),
  routes:[Screen(id:'home',title:'Shared handle',body:Column(id:'content',children:[
    TextField(id:'username',value:Ref<String>(name:'username'),placeholder:'Username'),
    Text.bind(Ref<String>(name:'canonical'),id:'canonical'),
    Text.bind(Ref<String>(name:'status'),id:'status'),
    Button('Normalize',id:'normalizeButton',action:'normalize'),
  ]))],
  flowActions:[
    FlowAction(id:'normalize',cases:[FlowCase(code:0,effects:[
      LogicCallEffect(function:'canonicalHandle',arguments:[Ref<String>(name:'username')],
        target:'canonical',success:'accepted',failure:'rejected'),
    ])]),
    FlowAction(id:'accepted',cases:[FlowCase(code:0,effects:[SetEffect(target:'status',value:'Canonical handle ready')])]),
    FlowAction(id:'rejected',cases:[FlowCase(code:0,effects:[SetEffect(target:'status',value:'Use 3–24 ASCII letters, digits or underscores')])]),
  ],
);
