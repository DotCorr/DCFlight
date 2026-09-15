import unittest
from dcflight.navigation_ir import RoutedApplication,Route,NavigationAction
from dataclasses import replace
from dcflight.ir import Node,Literal,ScalarType,Style
from dcflight.backends.android_routed import AndroidRouted,quoted


def lit(value):return Literal(value,ScalarType.STRING)
def fixture():
    button=Node('next','button',(('text',lit('Authored next')),),(),action='go')
    body=Node('body','column',(),(Node('copy','text',(('text',lit('Authored heading')),),()),button),style=Style(padding=19,gap=7))
    stack=Node('stack','navigationStack',(('initialRoute',lit('home')),),())
    tab=Node('tab','tab',(('title',lit('Authored tab')),('icon',lit('camera'))),(stack,))
    return RoutedApplication(id='com.example.routes',name='Authored app',states=(),actions=(),root=Node('tabs','tabs',(),(tab,)),routes=(Route(id='home',title='Authored home',body=body,presentation='page'),Route(id='detail',title='Authored detail',body=Node('detailText','text',(('text',lit('Authored destination')),),()),presentation='page')),navigation_actions=(NavigationAction(id='go',operation='push',route='detail'),))

class AndroidRoutedTests(unittest.TestCase):
    def test_disabled_authored_control_preserves_palette_under_shared_opacity(self):
        from dcflight.ir import Reference,State
        app=fixture();button=replace(app.routes[0].body.children[1],style=Style(background='#FFDD33',color='#18191C'),enabled_when=Reference('ready',ScalarType.BOOL))
        app=replace(app,states=(State('ready',Literal(False,ScalarType.BOOL)),),routes=(replace(app.routes[0],body=replace(app.routes[0].body,children=(button,))),app.routes[1]))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('.alpha(if(model.s_ready) 1f else 0.45f)',source)
        self.assertIn('0.45f).then(Modifier.testTag("next").background(',source)
        self.assertIn('enabled=model.s_ready',source)
        self.assertIn('disabledContainerColor=Color(0xFFFFDD33)',source)
        self.assertIn('disabledContentColor=Color(0xFF18191C)',source)
    def test_native_navigation_from_authored_tree(self):
        files=AndroidRouted().generate(fixture(),None);source=files['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        for expected in ('NavigationBarItem(', 'NavigationBar {','NavHost(', 'rememberNavController()', 'Authored heading','Authored next','Authored tab','nav.navigate("detail")','.padding(19.dp)','Arrangement.spacedBy(7.dp)'):
            self.assertIn(expected,source)
        self.assertNotIn('Welcome back',source)
        self.assertNotIn('Snap',source)
        self.assertEqual('user',files['android/app/src/main/java/com/example/routes/MainActivity.kt'].ownership)
    def test_nested_tab_and_route_layouts_consume_applied_bar_padding(self):
        # This fixture nests a titled route scaffold inside a tab scaffold.
        # Each boundary must report its applied padding to downstream native layouts.
        source=AndroidRouted().generate(fixture(),None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertEqual(3, source.count('.consumeWindowInsets(padding)'))
        self.assertEqual(2, source.count('contentAlignment=Alignment.TopStart'))
        self.assertNotIn('Box(Modifier.padding(padding))', source)
        self.assertIn('.safeDrawingPadding()', source)

    def test_blank_title_keeps_native_back_navigation_when_pushed(self):
        app=fixture()
        app=replace(app,routes=tuple(replace(route,title='') for route in app.routes))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        # Both root and destination have blank titles; only live stack history
        # decides whether to show the native app bar and up affordance.
        self.assertEqual(2,source.count('Scaffold(topBar={ if(entry != null && nav.previousBackStackEntry != null) { TopAppBar('))
        self.assertNotIn('else { routeContent() }',source)
        # The route content must remain in a single composition location
        # while native navigation adds/removes the back bar.
        self.assertEqual(2,source.count('{ routeContent() }'))
        self.assertEqual(1,source.count('Authored destination'))
        self.assertIn('IconButton(onClick={nav.popBackStack()})',source)
        self.assertIn('nav.navigate("detail")',source)

    def test_filling_row_children_share_available_width(self):
        app=fixture()
        first=replace(app.routes[0].body.children[1],id='first',style=Style(fill=True,padding=14))
        second=replace(first,id='second')
        fixed=replace(first,id='fixed',style=Style(width=80))
        spacer=Node('space','spacer',(),(),style=Style(fill=True))
        row=Node('controls','row',(),(first,second,fixed,spacer),style=Style(gap=8))
        app=replace(app,routes=(replace(app.routes[0],body=row),app.routes[1]))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('Modifier.testTag("first").weight(1f)',source)
        self.assertIn('Modifier.testTag("second").weight(1f)',source)
        self.assertIn('Modifier.testTag("fixed").width(80.dp)',source)
        self.assertIn('Modifier.testTag("space").weight(1f)',source)
        self.assertNotIn('.weight(1f).weight(1f)',source)
        self.assertNotIn('testTag("first").fillMaxWidth()',source)
        column=replace(row,capability='column')
        app=replace(app,routes=(replace(app.routes[0],body=column),app.routes[1]))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('testTag("first").fillMaxWidth()',source)

    def test_kotlin_literals_escape_interpolation(self):
        self.assertEqual('"Price \\$1"',quoted('Price $1'))

    def test_authored_route_title_and_modal_contract(self):
        app=fixture();modal=Route('modal','Authored sheet',Node('dismissButton','button',(('text',lit('Authored dismiss')),),(),action='dismiss'),'sheet')
        app=replace(app,routes=app.routes+(modal,),navigation_actions=app.navigation_actions+(NavigationAction('dismiss','dismiss'),))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('TopAppBar(title={Text("Authored home")}',source)
        self.assertIn('nav.previousBackStackEntry != null',source)
        self.assertIn('ModalBottomSheet(',source)
        self.assertIn('dismissModal()',source)
        self.assertIn('rememberSaveable(saver=listSaver<AuthoredState, Any>',source)

    def test_one_ir_mutation_changes_copy_order_spacing_and_destination(self):
        app=fixture()
        before=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        original=app.routes[0].body
        renamed=replace(original.children[0],properties=(('text',lit('Changed shared wording $2')),))
        body=replace(original,children=(original.children[1],renamed),style=Style(padding=31,gap=13))
        changed=replace(app,routes=(replace(app.routes[0],body=body),app.routes[1]),navigation_actions=(NavigationAction('go','replace','home'),))
        after=AndroidRouted().generate(changed,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('Authored heading',before)
        self.assertNotIn('Authored heading',after)
        self.assertIn('Changed shared wording \\$2',after)
        self.assertLess(after.index('testTag("next")'),after.index('testTag("copy")'))
        self.assertIn('.padding(31.dp)',after)
        self.assertIn('Arrangement.spacedBy(13.dp)',after)
        self.assertIn('nav.navigate("home") { popUpTo(nav.currentDestination!!.id) { inclusive=true } }',after)

    def test_set_action_does_not_rewrite_authored_literal(self):
        from dcflight.ir import State,Action
        app=replace(fixture(),states=(State('name',lit('')),),actions=(Action('setName','set','name',lit('model.name and model.s_name')),))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('s_name = "model.name and model.s_name"',source)
        self.assertEqual('"\\u000c\\u0001"',quoted('\f\x01'))

    def test_field_placeholder_typography_and_control_color_survive(self):
        from dcflight.ir import State,Reference
        field=Node('field','textField',(('value',Reference('value',ScalarType.STRING)),('placeholder',lit('Shared prompt'))),(),style=Style(font_size=21,font_weight='bold',color='#11223380',align='end',border_color='#FF0000',border_width=0))
        app=fixture();app=replace(app,states=(State('value',lit('')),),routes=(replace(app.routes[0],body=field),app.routes[1]))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('BasicTextField(value=model.s_value',source)
        self.assertIn('if(model.s_value.isEmpty()) { Text("Shared prompt"',source)
        self.assertIn('singleLine=true,textStyle=',source)
        self.assertIn('TextStyle(color=Color(0x80112233),fontSize=21.sp,fontWeight=FontWeight.Bold,textAlign=androidx.compose.ui.text.style.TextAlign.End)',source)
        self.assertNotIn('.border(',source)
        self.assertIn('onValueChange={model.s_value=it}',source)

    def test_unframed_alignment_fails_instead_of_disappearing(self):
        icon=Node('alignedIcon','icon',(('name',lit('camera')),),(),style=Style(align='end'))
        app=fixture();app=replace(app,routes=(replace(app.routes[0],body=icon),app.routes[1]))
        with self.assertRaisesRegex(ValueError,'align requires an authored frame for icon'):
            AndroidRouted().generate(app,None)
        app=replace(app,routes=(replace(app.routes[0],body=replace(icon,style=Style(align='end',width=100))),app.routes[1]))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('.width(100.dp).wrapContentSize(Alignment.CenterEnd)',source)

    def test_explicit_field_chrome_and_framed_button_alignment(self):
        from dcflight.ir import State,Reference
        app=fixture()
        field=Node('styledInput','textField',(('value',Reference('value',ScalarType.STRING)),('placeholder',lit('Authored placeholder'))),(),style=Style(padding=9,radius=11,border_color='#123456',border_width=3,background='#FFFFFF'))
        button=replace(app.routes[0].body.children[1],style=Style(width=200,align='end'))
        body=replace(app.routes[0].body,children=(field,button))
        app=replace(app,states=(State('value',lit('')),),routes=(replace(app.routes[0],body=body),app.routes[1]))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('BasicTextField(value=model.s_value',source)
        self.assertNotIn('OutlinedTextField(',source)
        self.assertIn('.clip(RoundedCornerShape(11.dp)).background(Color(0xFFFFFFFF)).border(3.dp, Color(0xFF123456), RoundedCornerShape(11.dp)).padding(9.dp)',source)
        self.assertIn('modifier=Modifier.testTag("next").width(200.dp)',source)
        self.assertNotIn('.wrapContentSize(Alignment.CenterEnd)',source)
        self.assertIn('Text("Authored next",modifier=Modifier.fillMaxWidth(),textAlign=androidx.compose.ui.text.style.TextAlign.End)',source)

    def test_button_alignment_stays_inside_authored_surface(self):
        for alignment, native in (('start','Start'),('center','Center'),('end','End')):
            with self.subTest(alignment=alignment):
                app=fixture()
                button=replace(app.routes[0].body.children[1],style=Style(width=240,height=64,padding=12,background='#123456',align=alignment))
                app=replace(app,routes=(replace(app.routes[0],body=button),app.routes[1]))
                source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
                self.assertIn('testTag("next").width(240.dp).height(64.dp).background(Color(0xFF123456))',source)
                self.assertIn('contentPadding=PaddingValues(12.dp)',source)
                self.assertIn('Text("Authored next",modifier=Modifier.fillMaxWidth(),textAlign=androidx.compose.ui.text.style.TextAlign.'+native+')',source)
                self.assertNotIn('.wrapContentSize(',source)

    def test_global_reset_uses_explicit_root_controller(self):
        app=fixture()
        app=replace(app,navigation_actions=(NavigationAction('go','resetRoot','home'),))
        source=AndroidRouted().generate(app,None)['android/app/src/main/java/com/example/routes/AuthoredApplication.kt'].content
        self.assertIn('rootNav: NavHostController',source)
        self.assertIn('val rootNav=nav;',source)
        self.assertIn('route_home(model, nav, rootNav, navigationPort, dismissModal)',source)
        self.assertIn('rootNav.navigate("home") { popUpTo(rootNav.graph.id) { inclusive=true }; launchSingleTop=true }',source)
