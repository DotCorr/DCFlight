import dataclasses
import unittest
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from dcflight.ir import Application,Node,Literal,ScalarType,Style,State,Reference
from dcflight.registry import Registry
from dcflight.navigation_ir import RoutedApplication,Route,NavigationAction
from dcflight.backends.ios_routed import generate


def text(value):return Literal(value,ScalarType.STRING)
def node(id,kind,props=None,children=(),action=None,style=None):return Node(id,kind,tuple((k,text(v)) for k,v in (props or {}).items()),tuple(children),action,style)
def fixture():
    routes=(Route(id='first',title='Authored title',presentation='page',body=node('firstBody','column',children=[node('wording','text',{'text':'One authored sentence'}),node('go','button',{'text':'Continue'},action='forward'),node('open','button',{'text':'Show details'},action='show')],style=Style(gap=13,padding=17))),Route(id='second',title='Another title',presentation='page',body=node('secondBody','button',{'text':'Return'},action='back')),Route(id='modal',title='Authored modal',presentation='sheet',body=node('modalBody','button',{'text':'Close'},action='close')))
    actions=tuple(NavigationAction(id=id,operation=op,route=route) for id,op,route in [('forward','push','second'),('replace','replace','second'),('back','back',None),('show','present','modal'),('close','dismiss',None)])
    base=Application('com.example.routed','Authored sample',(),(),node('host','navigationStack',{'initialRoute':'first'}))
    return RoutedApplication(**vars(base),routes=routes,navigation_actions=actions)


class IOSRoutedTests(unittest.TestCase):
    def test_route_content_binds_its_own_navigation_host(self):
        source=generate(fixture(),Registry())['ios/App/Generated/NavigationRouter.swift'].content
        self.assertIn('RouteContent(model: model, route: router.root)\n                .environmentObject(router)',source)
        self.assertIn('RouteContent(model: model, route: route).environmentObject(router)',source)

    def test_authored_content_style_and_direct_native_navigation(self):
        files=generate(fixture(),Registry());joined='\n'.join(a.content for a in files.values())
        self.assertIn('One authored sentence',joined)
        self.assertIn('spacing: 13',joined)
        self.assertIn('.padding(17)',joined)
        router=files['ios/App/Generated/NavigationRouter.swift'].content
        self.assertIn('NavigationStack(path: $router.path)',router)
        self.assertIn('.sheet(item: $router.sheet)',router)
        self.assertIn('.fullScreenCover(item: $router.fullScreen)',router)
        self.assertIn('path[path.count - 1] = .r_second',router)
        self.assertIn('router.a_forward',files['ios/App/Generated/Nodes/n_go.swift'].content)
        for forbidden in ['SocialSession','CameraScreen','InboxScreen','Your people','JSONSerialization']:
            self.assertNotIn(forbidden,joined)
        self.assertEqual(files['ios/App/User/AppMain.swift'].ownership,'user')

    def test_mutating_authored_copy_order_and_destination_changes_output(self):
        app=fixture();first=generate(app,Registry())
        route=app.routes[0];children=list(route.body.children)
        children[0]=dataclasses.replace(children[0],properties=(('text',text('Changed shared wording')),))
        app=dataclasses.replace(app,routes=(dataclasses.replace(route,body=dataclasses.replace(route.body,children=tuple(reversed(children)))),*app.routes[1:]))
        app=dataclasses.replace(app,navigation_actions=tuple(dataclasses.replace(a,route='first') if a.id=='forward' else a for a in app.navigation_actions))
        second=generate(app,Registry())
        self.assertNotEqual(first['ios/App/Generated/Nodes/n_wording.swift'],second['ios/App/Generated/Nodes/n_wording.swift'])
        self.assertIn('path.append(.r_first)',second['ios/App/Generated/NavigationRouter.swift'].content)
        body=second['ios/App/Generated/Nodes/n_firstBody.swift'].content
        self.assertLess(body.index('n_open('),body.index('n_wording('))

    def test_reject_bad_presentations_services_and_duplicate_nodes(self):
        app=dataclasses.replace(fixture(),navigation_actions=(NavigationAction(id='bad',operation='push',route='modal'),))
        with self.assertRaisesRegex(ValueError,'presentation'):generate(app,Registry())
        app=dataclasses.replace(fixture(),service=object())
        with self.assertRaisesRegex(ValueError,'effects'):generate(app,Registry())
        app=fixture();app=dataclasses.replace(app,routes=(*app.routes,Route(id='duplicate',title='',presentation='page',body=app.routes[0].body)))
        with self.assertRaisesRegex(ValueError,'globally unique'):generate(app,Registry())

    def test_tab_labels_and_independent_stacks_are_authored(self):
        app=fixture();app=dataclasses.replace(app,root=node('tabs','tabs',children=[node('one','tab',{'title':'First authored tab','icon':'chat'},[node('stackOne','navigationStack',{'initialRoute':'first'})]),node('two','tab',{'title':'Second authored tab','icon':'user'},[node('stackTwo','navigationStack',{'initialRoute':'second'})])]))
        files=generate(app,Registry())
        tabs=files['ios/App/Generated/Nodes/n_tabs.swift'].content
        self.assertIn('TabView(selection: $selection)',tabs)
        self.assertLess(tabs.index('First authored tab'),tabs.index('Second authored tab'))
        self.assertIn('initial: .r_first',files['ios/App/Generated/Nodes/n_stackOne.swift'].content)
        self.assertIn('initial: .r_second',files['ios/App/Generated/Nodes/n_stackTwo.swift'].content)

    def test_tab_container_route_uses_its_owned_stacks(self):
        app=fixture()
        tabs=node('tabs','tabs',children=[node('one','tab',{'title':'First','icon':'chat'},[node('inner','navigationStack',{'initialRoute':'first'})])])
        app=dataclasses.replace(app,routes=(*app.routes,Route(id='home',title='',presentation='page',body=tabs)))
        source=generate(app,Registry())['ios/App/Generated/NavigationRouter.swift'].content
        self.assertIn('var ownsNavigationStacks: Bool { self == .r_home }',source)
        self.assertIn('if router.root.ownsNavigationStacks && router.path.isEmpty',source)
        self.assertIn('private var stackedContent: some View',source)
        titled=dataclasses.replace(app,routes=(*app.routes[:-1],dataclasses.replace(app.routes[-1],title='Container title')))
        titled_source=generate(titled,Registry())['ios/App/Generated/NavigationRouter.swift'].content
        self.assertIn('var ownsNavigationStacks: Bool { false }',titled_source)
        plain=generate(fixture(),Registry())['ios/App/Generated/NavigationRouter.swift'].content
        self.assertIn('var ownsNavigationStacks: Bool { false }',plain)

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('swift'), 'Native SwiftUI toolchain required')
    def test_native_router_history_replace_and_presentation(self):
        code=generate(fixture(),Registry())['ios/App/Generated/NavigationRouter.swift'].content.split('struct NativeRouteHost: View')[0]
        code+='\nTask { @MainActor in\n    let router=NavigationRouter(initial:.r_first)\n    router.a_back();precondition(router.path.isEmpty)\n    router.a_forward();precondition(router.path == [.r_second])\n    router.a_forward();router.a_replace();precondition(router.path == [.r_second,.r_second])\n    router.a_back();precondition(router.path == [.r_second])\n    router.a_back();router.a_replace();precondition(router.root == .r_second && router.path.isEmpty)\n    router.a_show();precondition(router.sheet == .r_modal && router.fullScreen == nil)\n    router.a_close();precondition(router.dismissalRequested)\n    var disposed: NavigationRouter? = NavigationRouter(initial:.r_first)\n    weak var witness = disposed\n    let pending = disposed!.flowNavigation\n    disposed = nil;precondition(witness == nil);pending("forward")\n    let nested=NavigationRouter(initial:.r_second)\n    nested.resetRoot = { [weak router] route in router?.reset(to: route) }\n    router.path = [.r_second];router.fullScreen = .r_modal\n    nested.resetRoot?(.r_first)\n    precondition(router.root == .r_first && router.path.isEmpty && router.sheet == nil && router.fullScreen == nil && !router.dismissalRequested)\n    exit(0)\n}\nRunLoop.main.run()\n'
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'router.swift';path.write_text(code)
            result=subprocess.run(['swift',str(path)],capture_output=True,text=True,timeout=60)
            self.assertEqual(result.returncode,0,result.stderr)

    def test_styled_text_field_preserves_binding_placeholder_and_all_text_styles(self):
        app=fixture()
        field=Node('field','textField',(('value',Reference('entry',ScalarType.STRING)),('placeholder',text('Authored hint'))),(),style=Style(padding=9,width=220,height=48,max_width=240,color='#112233',background='#FFEEDD',border_color='#AA0000',border_width=2,radius=11,font_size=21,font_weight='bold',align='end',opacity=75))
        app=dataclasses.replace(app,states=(State('entry',text('Initial')),),routes=(dataclasses.replace(app.routes[0],body=field),*app.routes[1:]))
        source=generate(app,Registry())['ios/App/Generated/Nodes/n_field.swift'].content
        for fragment in ['TextField("Authored hint", text: $model.s_entry, prompt:', '.textFieldStyle(.plain)', '.padding(9)', 'width: 220, height: 48', 'maxWidth: 240', '@ScaledMetric(relativeTo: .body) private var authoredFontSize: Double = 21', '.font(.system(size: authoredFontSize, weight: .bold))', '.foregroundStyle(Color(', '.background(Color(', '.tint(Color(', 'cornerRadius: 11', 'lineWidth: 2', '.multilineTextAlignment(.trailing)', '.opacity(0.75)']:
            self.assertIn(fragment,source)
        changed=dataclasses.replace(field,properties=(('value',Reference('entry',ScalarType.STRING)),('placeholder',text('Changed hint'))),style=dataclasses.replace(field.style,font_size=18,align='start',padding=3))
        app=dataclasses.replace(app,routes=(dataclasses.replace(app.routes[0],body=changed),*app.routes[1:]))
        updated=generate(app,Registry())['ios/App/Generated/Nodes/n_field.swift'].content
        self.assertIn('TextField("Changed hint", text: $model.s_entry, prompt:',updated)
        self.assertIn('authoredFontSize: Double = 18',updated);self.assertIn('.padding(3)',updated)
        self.assertIn('.multilineTextAlignment(.leading)',updated)
        self.assertNotEqual(source,updated)

    def test_no_silently_ignored_canonical_properties(self):
        app=fixture()
        invalid=[node('bad','text',{'text':'x','keyboard':'email'}),node('bad','button',{'text':'x'},action='forward',style=Style(align='end')),node('bad','text',{'text':'x'},style=Style(gap=4))]
        for body in invalid:
            with self.subTest(body=body),self.assertRaisesRegex(ValueError,'Unsupported|unsupported|requires'):
                generate(dataclasses.replace(app,routes=(dataclasses.replace(app.routes[0],body=body),*app.routes[1:])),Registry())
        with self.assertRaisesRegex(ValueError,'presentation'):
            generate(dataclasses.replace(app,root=dataclasses.replace(app.root,style=Style(padding=4))),Registry())
        with self.assertRaisesRegex(ValueError,'theme tokens'):
            generate(dataclasses.replace(app,theme=object()),Registry())
