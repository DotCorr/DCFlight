"""Authored UI trees lowered directly to native Compose/Navigation, without screen templates."""
from html import escape
from . import Artifact, HEADER
from .android_presentation import PATHS, color
from ..ir import Reference, ScalarType, StringIsEmpty, BooleanNot, BooleanAll, BooleanAny, walk_expression
from ..presentation import DISABLED_OPACITY
from .android_flow import AndroidFlow,NAVIGATION
from . import android_media,android_motion,android_device,android_camera,android_map


def quoted(value):
    escapes={'"':'\\"', '\\':'\\\\', '$':'\\$', '\n':'\\n', '\r':'\\r', '\t':'\\t'}
    return '"'+''.join(escapes.get(char, '\\u%04x' % ord(char) if ord(char)<32 or 0xD800<=ord(char)<=0xDFFF else char) for char in value)+'"' 


class AndroidRouted:
    target = 'android'

    def generate(self, app, registry):
        self.app=app
        self.flow=AndroidFlow(app,quoted)
        self.native_model=bool(android_device.needed(app) or self.flow.actions or getattr(app,'media_states',()) or any(n.capability=='remoteImage' for n in app.nodes()))
        files={}
        def put(path,text,user=False):files['android/'+path]=Artifact(text,'user' if user else 'generated')
        put('settings.gradle',"pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name='NativeApp'\ninclude ':app'\n",True)
        put('build.gradle',"plugins { id 'com.android.application' version '8.9.2' apply false; id 'org.jetbrains.kotlin.android' version '2.1.20' apply false; id 'org.jetbrains.kotlin.plugin.compose' version '2.1.20' apply false }\n",True)
        put('gradle.properties','android.useAndroidX=true\n',True)
        put('app/build.gradle',"plugins { id 'com.android.application'; id 'org.jetbrains.kotlin.android'; id 'org.jetbrains.kotlin.plugin.compose' }\nandroid { namespace '"+app.id+"'; defaultConfig { applicationId '"+app.id+"'; versionCode 1; versionName '1.0' }; buildFeatures { compose true }; compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }; kotlinOptions { jvmTarget='17' } }\ndependencies { implementation platform('androidx.compose:compose-bom:2025.04.01'); implementation 'androidx.compose.material3:material3'; implementation 'androidx.compose.ui:ui'; implementation 'androidx.activity:activity-compose:1.10.1'; implementation 'androidx.navigation:navigation-compose:2.8.9' }\n",True)
        files['android/app/build.gradle']=Artifact(files['android/app/build.gradle'].content+"\napply from: 'native-versions.gradle'\n", files['android/app/build.gradle'].ownership)
        gradle_path='android/app/build.gradle'
        native_config="\nandroid { packaging { jniLibs { keepDebugSymbols += ['**/*.so'] } } }\n"
        if getattr(app,'logic',None):native_config+="android { defaultConfig { ndk { abiFilters 'arm64-v8a' } } }\n"
        files[gradle_path]=Artifact(files[gradle_path].content+native_config,'user')
        put('app/src/main/AndroidManifest.xml','<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="'+escape(app.name,quote=True)+'" android:theme="@android:style/Theme.Material.Light.NoActionBar"><activity android:name=".MainActivity" android:exported="true"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>\n',True)
        java='app/src/main/java/'+app.id.replace('.','/')+'/'
        # Extension imports are required for the native Activity entry point.
        files['android/'+java+'MainActivity.kt']=Artifact(HEADER+'package '+app.id+'\nimport androidx.activity.compose.setContent\nclass MainActivity : androidx.activity.ComponentActivity() { override fun onCreate(state: android.os.Bundle?) { super.onCreate(state); androidx.core.view.WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = true; androidx.core.view.WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightNavigationBars = true; setContent { AuthoredApplication() } } }\n','user')
        collections=getattr(app,'collections',())
        records='\n'.join('data class Record_'+c.name+'('+','.join('val v_'+f.name+':'+{ScalarType.STRING:'String',ScalarType.INT:'Int',ScalarType.BOOL:'Boolean'}[f.type] for f in c.fields)+')' for c in collections)
        states='\n'.join('var s_'+s.name+' by mutableStateOf('+self.expr(s.initial)+')' for s in app.states)
        states+='\n'+'\n'.join('var c_'+c.name+' by mutableStateOf<List<Record_'+c.name+'>>(emptyList())' for c in collections)
        states+='\n'+'\n'.join('var m_'+v.name+' by mutableStateOf<NativePhoto?>(null)' for v in getattr(app,'media_states',()))
        actions=[]
        for a in app.actions:
            target='s_'+str(a.target)
            if a.operation=='increment':body=target+'++'
            elif a.operation=='toggle':body=target+' = !'+target
            elif a.operation=='set':body=target+' = '+self.expr(a.value, owner='')
            elif a.operation=='call':
                body=target+' = SharedLogic.f_'+a.function+'('+','.join(self.expr(value,owner='this.') for value in a.arguments)+')'
                if a.failure:
                    body='try { '+body+' } catch (error: SharedLogic.InputFailure) { a_'+a.failure+'(); return }'
            else:raise ValueError('Routed Android action not yet supported: '+str(a.operation))
            actions.append('fun a_'+a.id+'() { '+body+' }')
        state_saver='listSaver<AuthoredState, Any>(save={listOf<Any>('+','.join('it.s_'+v.name for v in app.states)+')},restore={values -> AuthoredState().also { restored -> '+ ';'.join('restored.s_'+v.name+' = values['+str(i)+'] as '+{ScalarType.STRING:'String',ScalarType.INT:'Int',ScalarType.BOOL:'Boolean'}[v.initial.type] for i,v in enumerate(app.states))+' }})'
        model_declaration='class AuthoredState(private val context: android.content.Context) : androidx.lifecycle.ViewModel()' if self.native_model or collections else 'class AuthoredState'
        model_creation='val context=androidx.compose.ui.platform.LocalContext.current.applicationContext; val model:AuthoredState=androidx.lifecycle.viewmodel.compose.viewModel(factory=object: androidx.lifecycle.ViewModelProvider.Factory { override fun <T:androidx.lifecycle.ViewModel> create(modelClass:Class<T>):T=AuthoredState(context) as T })' if self.native_model or collections else 'val model = rememberSaveable(saver='+state_saver+') { AuthoredState() }'
        source=HEADER+'package '+app.id+'\n'+IMPORTS+'\n'+records+'\n'+(NAVIGATION if self.flow.actions or getattr(app,'media_states',()) or android_device.needed(app) else '')+'\n'+model_declaration+' {\n'+states+'\n'+'\n'.join(actions)+'\n'+self.flow.members()+'\n}\n@OptIn(ExperimentalMaterial3Api::class) @Composable fun AuthoredApplication() { '+model_creation+'; '+self.media_launcher()+' val dismissModal: () -> Unit = {}; MaterialTheme { Surface(modifier=Modifier.fillMaxSize().safeDrawingPadding()) { '+self.node(app.root,root=True)+' } } }\n'
        from ..navigation_ir import RouteViewportAlignment
        viewport_alignment = {RouteViewportAlignment.TOP_START: 'TopStart'}
        for route in app.routes:
            body=self.node(route.body)
            # A blank title suppresses title chrome at the root, not the native
            # way back from a pushed page. Observe the entry to update on pops.
            content='val routeContent: @Composable () -> Unit = { '+body+' }; '
            navigation='entry != null && nav.previousBackStackEntry != null'
            bar=('LargeTopAppBar' if route.title_display.value=='large' else 'TopAppBar')+'(title={Text('+quoted(route.title)+')}, colors=TopAppBarDefaults.'+('largeTopAppBarColors' if route.title_display.value=='large' else 'topAppBarColors')+'(containerColor=navigationSurface ?: Color.Unspecified, scrolledContainerColor=navigationSurface ?: Color.Unspecified, navigationIconContentColor=navigationAccent ?: Color.Unspecified, actionIconContentColor=navigationAccent ?: Color.Unspecified), navigationIcon={ if('+navigation+') { IconButton(onClick={nav.popBackStack()}) { Icon(painterResource(R.drawable.app_icon_back),contentDescription="Navigate up") } } })'
            # Keep route content at one Compose call site. Branching between
            # Scaffold/content when stack history changes recreates remembered
            # scroll and input state on the outgoing blank-title destination.
            top_bar=bar if route.title else 'if('+navigation+') { '+bar+' }'
            scaffold='Scaffold(topBar={ '+top_bar+' }) { padding -> Box(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding), contentAlignment=Alignment.'+viewport_alignment[route.viewport_alignment]+') { routeContent() } }'
            body=content+'val entry by nav.currentBackStackEntryAsState(); '+scaffold
            source+='@OptIn(ExperimentalMaterial3Api::class) @Composable fun route_'+route.id+'(model: AuthoredState, nav: NavHostController, rootNav: NavHostController, navigationPort: (String)->Unit, dismissModal: () -> Unit, navigationAccent: Color? = null, navigationSurface: Color? = null) { '+body+' }\n'
        put(java+'AuthoredApplication.kt',source)
        for name,path in PATHS.items():put('app/src/main/res/drawable/app_icon_'+name+'.xml','<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="@android:color/transparent" android:strokeColor="#000000" android:strokeWidth="1.8" android:pathData="'+path+'"/></vector>')
        files.update(self.flow.artifacts())
        files.update(android_media.artifacts(app))
        files.update(android_device.artifacts(app))
        files.update(android_camera.artifacts(app))
        files.update(android_map.artifacts(app))
        if self.native_model:
            manifest='android/app/src/main/AndroidManifest.xml'
            content=files[manifest].content.replace('<application ', '<application android:allowBackup="false" ')
            permissions=[]
            if any(k=='camera' for k,_ in getattr(app,'permission_descriptions',())):permissions.append('android.permission.CAMERA')
            if any(k=='location' for k,_ in getattr(app,'permission_descriptions',())):permissions.extend(('android.permission.ACCESS_COARSE_LOCATION','android.permission.ACCESS_FINE_LOCATION'))
            for permission in permissions:content=content.replace('<application ', '<uses-permission android:name="'+permission+'"/><application ')
            if getattr(app,'transport',None):content=content.replace('<application ', '<uses-permission android:name="android.permission.INTERNET"/><application ')
            if getattr(app,'transport',None) and app.transport.development:
                content=content.replace('<application ', '<application android:networkSecurityConfig="@xml/network_security_config" ')
                files['android/app/src/main/res/xml/network_security_config.xml']=Artifact('<network-security-config><base-config cleartextTrafficPermitted="false"/><domain-config cleartextTrafficPermitted="true"><domain>10.0.2.2</domain></domain-config></network-security-config>')
            files[manifest]=Artifact(content,'user')
        return files

    def media_launcher(self):
        permission='val permissionLauncher=androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestMultiplePermissions()) { result -> model.devices.permissionResult(result) }; val permissionRequest=model.devices.permissionRequest; LaunchedEffect(permissionRequest) { permissionRequest?.let { capability -> if(model.devices.permissionLaunched()) { try { permissionLauncher.launch(model.devices.permissions(capability)) } catch(error:Exception) { model.devices.permissionFailed() } } } };' if android_device.needed(self.app) else ''
        if not getattr(self.app,'media_states',()):return permission
        return permission+'val picker=androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia()) { uri -> model.media.selected(uri) }; val pickRequest=model.media.launchRequest; LaunchedEffect(pickRequest) { pickRequest?.let { if(model.media.markLaunched(it)) { try { picker.launch(androidx.activity.result.PickVisualMediaRequest(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageOnly)) } catch(error:Exception) { model.media.launchFailed() } } } };'

    def navigation_binding(self,node):
        if not self.flow.actions:return 'val navigationPort: (String)->Unit='+self.flow_navigation()+'; '
        return 'val navigationPort=remember(nav){model.navigationPort('+quoted(node.id)+')}; val hostContext=androidx.compose.ui.platform.LocalContext.current; DisposableEffect(navigationPort,nav) { navigationPort.attach('+self.flow_navigation()+'); onDispose { var context=hostContext; while(context is android.content.ContextWrapper && context !is android.app.Activity)context=context.baseContext; navigationPort.detach((context as? android.app.Activity)?.isChangingConfigurations == true) } }; '

    def expr(self,value,owner='model.'):
        if isinstance(value,StringIsEmpty):return '('+self.expr(value.value,owner)+').isEmpty()'
        if isinstance(value,BooleanNot):return '(!'+self.expr(value.value,owner)+')'
        if isinstance(value,(BooleanAll,BooleanAny)):
            operator=' && ' if isinstance(value,BooleanAll) else ' || '
            return '('+operator.join(self.expr(child,owner) for child in value.values)+')'
        if type(value).__name__=='FieldReference':return 'row_'+value.collection+'.v_'+value.field
        if isinstance(value,Reference):return owner+'s_'+value.name
        if value.type==ScalarType.STRING:return quoted(value.value)
        if value.type==ScalarType.BOOL:return str(value.value).lower()
        return str(value.value)

    def flow_navigation(self):
        return '{ navigationAction -> when(navigationAction) { '+ ';'.join(quoted(a.id)+' -> { '+self.action(a.id)+' }' for a in self.app.navigation_actions)+' else -> error("unknown_navigation_action") } }'

    def action(self,name):
        if any(a.id==name for a in self.flow.actions):return 'model.f_'+name+'(navigationPort)'
        action=next((a for a in self.app.navigation_actions if a.id==name),None)
        if action is None:return 'model.a_'+name+'()'
        if action.operation=='resetRoot':return 'rootNav.navigate('+quoted(action.route)+') { popUpTo(rootNav.graph.id) { inclusive=true }; launchSingleTop=true }'
        if action.operation=='dismiss':return 'dismissModal()'
        if action.operation=='back':return 'nav.popBackStack()'
        if action.operation=='replace':return 'nav.navigate('+quoted(action.route)+') { popUpTo(nav.currentDestination!!.id) { inclusive=true } }'
        return 'nav.navigate('+quoted(action.route)+')'

    def modifier(self,node,parent=None):
        s=node.style;out='Modifier.testTag('+quoted(node.id)+')'
        if not s:return out
        if s.max_width is not None:out+='.widthIn(max='+str(s.max_width)+'.dp)'
        if s.width is not None:out+='.width('+str(s.width)+'.dp)'
        elif s.fill and parent!='row':out+='.fillMaxWidth()'
        if s.height is not None:out+='.height('+str(s.height)+'.dp)'
        if s.opacity is not None:out+='.alpha('+str(s.opacity/100)+'f)'
        radius=str(s.radius or 0)+'.dp'
        if s.radius is not None:out+='.clip(RoundedCornerShape('+radius+'))'
        if s.background:out+='.background(Color('+color(s.background)+'))'
        if s.border_color and s.border_width!=0:out+='.border('+str(s.border_width if s.border_width is not None else 1)+'.dp, Color('+color(s.border_color)+'), RoundedCornerShape('+radius+'))'
        if s.padding is not None and node.capability!='button':out+='.padding('+str(s.padding)+'.dp)'
        if s.align and node.capability not in ('row','column','card','repeat','text','counter','textField','secureField'):
            framed=s.width is not None or s.height is not None or s.max_width is not None or s.fill is True
            if not framed:raise ValueError('align requires an authored frame for '+node.capability)
            if node.capability!='button':
                out+='.wrapContentSize(Alignment.'+{'start':'CenterStart','center':'Center','end':'CenterEnd'}[s.align]+')'
        return out

    def typography(self,style):
        if style is None:return ''
        values=[]
        if style.color:values.append('color=Color('+color(style.color)+')')
        if style.font_size is not None:values.append('fontSize='+str(style.font_size)+'.sp')
        if style.font_weight:values.append('fontWeight=FontWeight.'+{'regular':'Normal','medium':'Medium','semibold':'SemiBold','bold':'Bold'}[style.font_weight])
        if style.align:values.append('textAlign=androidx.compose.ui.text.style.TextAlign.'+{'start':'Start','center':'Center','end':'End'}[style.align])
        return ','.join(values)

    def text_style(self,style):
        # Text merges unspecified parameters into LocalTextStyle. Clear the
        # inherited Material line height on the style itself before merging a
        # different authored font size, so native font metrics determine lines.
        return 'LocalTextStyle.current'+('.copy(lineHeight=TextUnit.Unspecified)' if style is not None and style.font_size is not None else '')

    def node(self,node,parent=None,root=False):
        from ..navigation_appearance import validate_node
        validate_node(node)
        p=node.props();kind=node.capability;m=self.modifier(node,parent);s=node.style
        if getattr(node,'enabled_when',None) is not None and kind not in ('button','textField','secureField','toggle'):raise ValueError('enabledWhen is not supported for '+kind)
        if node.enabled_when is not None:m='Modifier.alpha(if('+self.expr(node.enabled_when)+') 1f else '+str(DISABLED_OPACITY)+'f).then('+m+')'
        if parent=='row' and s is not None and s.fill and s.width is None:m+='.weight(1f)'
        elif kind=='spacer' and parent in ('row','column','card') and (s is None or (s.width if parent=='row' else s.height) is None):m+='.weight(1f)'
        if node.motion and (kind in ('navigationStack','tabs','repeat') or (kind=='spacer' and '.weight(' in m)):raise ValueError('Routed Android motion is not supported for '+kind)
        if kind=='navigationStack':
            appearance=node.navigation_appearance
            from ..navigation_appearance import NavigationAppearance
            if appearance is not None and not isinstance(appearance,NavigationAppearance):raise ValueError('Expected NavigationAppearance')
            accent=('Color('+color(appearance.accent)+')') if appearance and appearance.accent is not None else 'null'
            surface=('Color('+color(appearance.surface)+')') if appearance and appearance.surface is not None else 'null'
            routes=[]
            for route in self.app.routes:
                call='route_'+route.id+'(model, nav, rootNav, navigationPort, '+('{nav.popBackStack()}' if route.presentation in ('sheet','fullScreen') else 'dismissModal')+(', '+accent+', '+surface if appearance is not None else '')+')'
                if route.presentation=='sheet':body='dialog('+quoted(route.id)+') { ModalBottomSheet(onDismissRequest={nav.popBackStack()}) { '+call+' } }'
                elif route.presentation=='fullScreen':body='dialog('+quoted(route.id)+', dialogProperties=DialogProperties(usePlatformDefaultWidth=false)) { Surface(Modifier.fillMaxSize()) { '+call+' } }'
                else:body='composable('+quoted(route.id)+') { '+call+' }'
                routes.append(body)
            initial='LaunchedEffect(model,nav) { if(!model.initialDispatched) { model.initialDispatched=true; model.f_'+self.app.initial_action+'(navigationPort) } }; ' if getattr(self.app,'initial_action',None) else ''
            result='run { val nav=rememberNavController(); '+('val rootNav=nav; ' if root else '')+self.navigation_binding(node)+initial+'NavHost(navController=nav,startDestination='+self.expr(p['initialRoute'])+',modifier='+m+') { '+'\n'.join(routes)+' } }'
        elif kind=='tabs':
            appearance=node.navigation_appearance
            from ..navigation_appearance import TabAppearance
            if appearance is not None and not isinstance(appearance,TabAppearance):raise ValueError('Expected TabAppearance')
            colors=[]
            if appearance and appearance.selected_foreground is not None:colors.extend(key+'='+('Color('+color(appearance.selected_foreground)+')') for key in ('selectedIconColor','selectedTextColor'))
            if appearance and appearance.unselected_foreground is not None:colors.extend(key+'='+('Color('+color(appearance.unselected_foreground)+')') for key in ('unselectedIconColor','unselectedTextColor'))
            item_colors=',colors=NavigationBarItemDefaults.colors('+','.join(colors)+')' if colors else ''
            bar_colors='(containerColor='+('Color('+color(appearance.surface)+')')+')' if appearance and appearance.surface is not None else ''
            tabs=[];bodies=[]
            for i,tab in enumerate(node.children):
                tp=tab.props();tabs.append('NavigationBarItem(selected=selected=='+str(i)+',onClick={selected='+str(i)+'},icon={Icon(painterResource(R.drawable.app_icon_'+tp['icon'].value+'),contentDescription=null)},label={Text('+self.expr(tp['title'])+')}'+item_colors+')')
                bodies.append(str(i)+' -> holder.SaveableStateProvider('+quoted(tab.id)+') { '+self.node(tab.children[0],root=root)+' }')
            result='run { var selected by rememberSaveable { mutableIntStateOf(0) }; val holder=rememberSaveableStateHolder(); Scaffold(modifier='+m+',bottomBar={NavigationBar'+bar_colors+' { '+';'.join(tabs)+' }}) { padding -> Box(Modifier.padding(padding).consumeWindowInsets(padding)) { when(selected) { '+';'.join(bodies)+' } } } }'
        elif kind in ('column','row','card'):
            widget='Row' if kind=='row' else 'Column';params='modifier='+m
            params+=', '+('horizontalArrangement' if kind=='row' else 'verticalArrangement')+'=Arrangement.spacedBy('+str(s.gap if s and s.gap is not None else 0)+'.dp)'
            if s and s.align:params+=', '+('verticalAlignment=Alignment.'+{'start':'Top','center':'CenterVertically','end':'Bottom'}[s.align] if kind=='row' else 'horizontalAlignment=Alignment.'+{'start':'Start','center':'CenterHorizontally','end':'End'}[s.align])
            result=widget+'('+params+') { '+';'.join(self.node(c,kind,root=root) for c in node.children)+' }'
        elif kind=='repeat':
            collection=next(c for c in self.app.collections if c.name==p['collection'].value)
            row='row_'+collection.name
            child=self.node(node.children[0])
            if node.action:
                selection=p['selection']
                child='Box(Modifier.fillMaxWidth().clickable(role=Role.Button) { model.s_'+selection.name+'='+row+'.v_'+collection.key+'; '+self.action(node.action)+' }) { '+child+' }'
            params=',verticalArrangement=Arrangement.spacedBy('+str(s.gap if s and s.gap is not None else 0)+'.dp)'
            if s and s.align:params+=',horizontalAlignment=Alignment.'+{'start':'Start','center':'CenterHorizontally','end':'End'}[s.align]
            result='Column('+m+params+') { model.c_'+collection.name+'.forEach { '+row+' -> key('+quoted(node.id)+','+row+'.v_'+collection.key+') { '+child+' } } }'
        elif kind=='scroll':result='Column('+m+'.verticalScroll(rememberScrollState())) { '+self.node(node.children[0],root=root)+' }'
        elif kind in ('text','counter'):
            v=self.expr(p['text' if kind=='text' else 'value']);v=v if kind=='text' else '('+v+').toString()';params=''
            if s and s.color:params+=',color=Color('+color(s.color)+')'
            if s and s.font_size is not None:params+=',fontSize='+str(s.font_size)+'.sp'
            if s and s.font_size is not None:params+=',style='+self.text_style(s)
            if s and s.font_weight:params+=',fontWeight=FontWeight.'+{'regular':'Normal','medium':'Medium','semibold':'SemiBold','bold':'Bold'}[s.font_weight]
            if s and s.align:params+=',textAlign=androidx.compose.ui.text.style.TextAlign.'+{'start':'Start','center':'Center','end':'End'}[s.align]
            result='Text('+v+',modifier='+m+params+')'
        elif kind=='button':
            params=(',enabled='+self.expr(node.enabled_when)) if getattr(node,'enabled_when',None) is not None else '';text_params=''
            if s:
                colors=[]
                if s.background:colors.append('containerColor=Color('+color(s.background)+')')
                if s.color:colors.append('contentColor=Color('+color(s.color)+')')
                if node.enabled_when is not None:
                    if s.background:colors.append('disabledContainerColor=Color('+color(s.background)+')')
                    if s.color:colors.append('disabledContentColor=Color('+color(s.color)+')')
                if colors:params+=',colors=ButtonDefaults.buttonColors('+','.join(colors)+')'
                if s.radius is not None:params+=',shape=RoundedCornerShape('+str(s.radius)+'.dp)'
                if s.padding is not None:params+=',contentPadding=PaddingValues('+str(s.padding)+'.dp)'
                if s.font_size is not None:text_params+=',fontSize='+str(s.font_size)+'.sp'
                if s.font_size is not None:text_params+=',style='+self.text_style(s)
                if s.font_weight:text_params+=',fontWeight=FontWeight.'+{'regular':'Normal','medium':'Medium','semibold':'SemiBold','bold':'Bold'}[s.font_weight]
                if s.align:
                    # Align inside the interactive frame, without shrinking or
                    # relocating the native Button surface and hit region.
                    text_params+=',modifier=Modifier.fillMaxWidth(),textAlign=androidx.compose.ui.text.style.TextAlign.'+{'start':'Start','center':'Center','end':'End'}[s.align]
            result='Button(onClick={'+(self.action(node.action) if node.action else '')+'},modifier='+m+params+') { Text('+self.expr(p['text'])+text_params+') }'
        elif kind in ('textField','secureField'):
            typography=self.typography(s)
            text_style=self.text_style(s)+('.merge(androidx.compose.ui.text.TextStyle('+typography+'))' if typography else '')
            bound=self.expr(p['value']);change='{model.s_'+p['value'].name+'=it}'
            secure=',visualTransformation=androidx.compose.ui.text.input.PasswordVisualTransformation(),keyboardOptions=androidx.compose.foundation.text.KeyboardOptions(keyboardType=androidx.compose.ui.text.input.KeyboardType.Password)' if kind=='secureField' else ''
            enabled=(',enabled='+self.expr(node.enabled_when)) if getattr(node,'enabled_when',None) is not None else ''
            if s is not None:
                # Explicit IR chrome owns the frame, padding, border and shape.
                # The native editing primitive adds no second Material outline.
                result='BasicTextField(value='+bound+',onValueChange='+change+',modifier='+m+',singleLine=true'+secure+enabled+',textStyle='+text_style+',decorationBox={ inner -> Box { if('+bound+'.isEmpty()) { Text('+self.expr(p['placeholder'])+',modifier=Modifier.alpha(0.5f),style='+text_style+') }; inner() } })'
            else:
                result='OutlinedTextField(value='+bound+',onValueChange='+change+',modifier='+m+',singleLine=true'+secure+enabled+',placeholder={Text('+self.expr(p['placeholder'])+')})'
        elif kind=='toggle':
            typography=self.typography(s);text_params=','+typography if typography else ''
            if s and s.font_size is not None:text_params+=',style='+self.text_style(s)
            enabled=self.expr(node.enabled_when) if getattr(node,'enabled_when',None) is not None else 'true'
            result='Row(modifier='+m+'.toggleable(enabled='+enabled+',value='+self.expr(p['value'])+',role=Role.Switch,onValueChange={model.s_'+p['value'].name+'=it}),verticalAlignment=Alignment.CenterVertically) { Text('+self.expr(p['text'])+',modifier=Modifier.weight(1f)'+text_params+'); Switch(checked='+self.expr(p['value'])+',enabled='+enabled+',onCheckedChange=null) }'
        elif kind=='nativeMap':
            collection=next(c for c in self.app.collections if c.name==p['collection'].value);config=self.app.map_config;region=p['region'];row='row_'+collection.name
            references=set()
            def visit_annotation(n):
                values=[value for _,value in n.properties]
                values.extend((n.visible_when,getattr(n,'enabled_when',None)))
                for value in values:
                    for expression_node in walk_expression(value):
                        if isinstance(expression_node,Reference):references.add(expression_node.name)
                for child in n.children:visit_annotation(child)
            visit_annotation(node.children[0])
            annotation_keys='listOf<Any>('+','.join('model.s_'+name for name in sorted(references))+')'
            select='{'+row+' -> '+('model.s_'+p['selection'].name+'='+row+'.v_'+collection.key+'; '+self.action(node.action) if node.action else '')+'}'
            result='NativeMap(rows=model.c_'+collection.name+',annotationKeys='+annotation_keys+',keyOf={it.v_'+collection.key+'.toString()},latitude={it.v_'+p['latitudeField'].value+'},longitude={it.v_'+p['longitudeField'].value+'},title={it.v_'+p['titleField'].value+'},centerLatitude='+str(region.latitude_e6)+',centerLongitude='+str(region.longitude_e6)+',latitudeSpan='+str(region.latitude_span_e6)+',longitudeSpan='+str(region.longitude_span_e6)+',styleUrl='+quoted(config.style_url)+',attribution='+quoted(config.attribution)+',modifier='+m+',onSelect='+select+',annotation={'+row+' -> '+self.node(node.children[0])+'},loading={'+self.node(node.children[1])+'},failure={'+self.node(node.children[2])+'})'
        elif kind=='cameraPreview':
            result='NativeCameraPreview(model.camera_'+p['resource'].value+',active='+self.expr(p['active'])+',fit='+self.expr(p['fit'])+',label='+self.expr(p['accessibilityLabel'])+',modifier='+m+',readyChanged={model.s_'+p['ready'].name+'=it},loading={'+self.node(node.children[0])+'},failure={'+self.node(node.children[1])+'})'
        elif kind=='localImage':
            source='model.m_'+p['source'].name
            result='Box('+m+') { val photo='+source+'; if(photo==null) { '+self.node(node.children[0])+' } else { val bitmap=remember(photo){android.graphics.BitmapFactory.decodeByteArray(photo.bytes,0,photo.bytes.size)}; if(bitmap==null) { '+self.node(node.children[1])+' } else { Image(bitmap=bitmap.asImageBitmap(),contentDescription='+self.expr(p['accessibilityLabel'])+',contentScale=androidx.compose.ui.layout.ContentScale.'+('Crop' if p['fit'].value=='fill' else 'Fit')+',modifier=Modifier) } } }'
        elif kind=='remoteImage':
            path=p['path'];path=quoted(path) if isinstance(path,str) else self.expr(path) if type(path).__name__!='PathTemplate' else '+'.join(self.expr(v) if type(v).__name__=='Literal' else 'NativePath.segment('+self.expr(v)+'.toString())' for v in path.parts)
            bearer=self.expr(p['bearer'])
            result='Box('+m+') { val mediaPath=runCatching { '+path+' }.getOrNull(); if(mediaPath==null) { '+self.node(node.children[1])+' } else key(mediaPath,'+bearer+') { NativeRemoteImage(path=mediaPath,bearer='+bearer+',maxBytes='+self.expr(p['maxBytes'])+',maxPixels='+self.expr(p['maxDecodedPixels'])+',maxEdge='+self.expr(p['maxEdge'])+',modifier=Modifier,fit=androidx.compose.ui.layout.ContentScale.'+('Crop' if p['fit'].value=='fill' else 'Fit')+',label='+self.expr(p['accessibilityLabel'])+',loading={'+self.node(node.children[0])+'},failure={'+self.node(node.children[1])+'}) } }'
        elif kind=='icon':result='Icon(painterResource(R.drawable.app_icon_'+p['name'].value+'),contentDescription=null,modifier='+m+(',tint=Color('+color(s.color)+')' if s and s.color else '')+')'
        elif kind=='divider':result='HorizontalDivider(modifier='+m+(',color=Color('+color(s.color)+')' if s and s.color else '')+')'
        elif kind=='progress':result='CircularProgressIndicator(modifier='+m+(',color=Color('+color(s.color)+')' if s and s.color else '')+')'
        elif kind=='native':result='androidx.compose.ui.viewinterop.AndroidView(factory={ context -> UserViews.v_'+p['symbol'].value+'(context,model) },modifier='+m+')'
        elif kind=='spacer':result='Spacer('+m+')'
        elif kind=='progressBar':result='LinearProgressIndicator(progress={'+self.expr(p['value'])+'.toFloat()/100f},modifier='+m+(',color=Color('+color(s.color)+')' if s and s.color else '')+')'
        else:raise ValueError('Routed Android primitive not yet supported: '+kind)
        return android_motion.wrap(node,result,self.expr)


IMPORTS='''
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.semantics.Role
import androidx.compose.material3.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.DialogProperties
import androidx.navigation.NavHostController
import androidx.navigation.compose.*
'''
