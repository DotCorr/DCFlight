"""Compile shared route/UI trees to ordinary SwiftUI views and navigation state.

Only OS navigation mechanics live here. Copy, routes, destinations, controls and
styles originate in the canonical input; no social-screen templates are used.
"""
import re
from ..ir import Application, Node, Literal, ScalarType
from . import Artifact, HEADER
from .common import expression, symbol, expand
from .ios import IOS as PrimitiveIOS
from .ios_presentation import render as presentation, ICONS, color, Presentation, render_button


def quote(value):
    return expression(Literal(value,ScalarType.STRING),'ios')


def identifier(value):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',value):
        raise ValueError('Invalid routed native identifier: '+str(value))
    return value


def generate(app,registry):
    if app.theme is not None:
        raise ValueError('Routed app theme tokens are not implemented; use authored node styles')
    if app.service is not None:
        raise ValueError('Routed service effects are not implemented; declare supported typed effects first')
    routes={route.id:route for route in app.routes}
    navigation={action.id:action for action in app.navigation_actions}
    flows={action.id:action for action in getattr(app,'flow_actions',())}
    collections={item.name:item for item in getattr(app,'collections',())}
    from ..collection_ir import FieldReference
    if not routes or len(routes)!=len(app.routes) or len(navigation)!=len(app.navigation_actions):
        raise ValueError('Routes must be nonempty and routing identities unique')
    for value in list(routes)+list(navigation):identifier(value)
    if app.root.capability not in ('navigationStack','tabs'):
        raise ValueError('Routed root must be a navigationStack or tabs')
    for action in navigation.values():
        if action.operation not in ('push','replace','resetRoot','back','present','dismiss'):
            raise ValueError('Unsupported navigation action: '+str(action.operation))
        if action.operation in ('back','dismiss'):
            if action.route is not None:raise ValueError('Back/dismiss cannot target a route')
        else:
            if action.route not in routes:raise ValueError('Unknown target route')
            expected=('sheet','fullScreen') if action.operation=='present' else ('page',)
            if routes[action.route].presentation not in expected:raise ValueError('Navigation presentation mismatch')
    for route in routes.values():
        if route.presentation not in ('page','sheet','fullScreen'):raise ValueError('Unsupported route presentation')
    dummy=Node('routedPlaceholder','text',(('text',Literal('',ScalarType.STRING)),),())
    base=Application(app.id,app.name,app.states,app.actions,dummy,logic=app.logic,theme=app.theme,modules=app.modules)
    files=PrimitiveIOS().generate(base,registry)
    del files['ios/App/Generated/Nodes/n_routedPlaceholder.swift']
    def put(path,content,ownership='generated'):
        files['ios/'+path]=Artifact(HEADER+content,ownership)
    put('App/User/AppMain.swift','''import SwiftUI
@main struct AppMain: App {
    @StateObject private var model = AppModel()
    var body: some Scene { WindowGroup { RootView(model: model) } }
}
''','user')
    media_modifier='.background(NativePhotoPresenter(request: model.nativePhotoRequest).frame(width: 0, height: 0))' if getattr(app,'media_states',()) else ''
    root_model = '@ObservedObject var' if media_modifier else 'let'
    put('App/Generated/RootView.swift','import SwiftUI\nstruct RootView: View {\n    '+root_model+' model: AppModel\n    var body: some View { '+symbol(app.root.id)+'(model: model)'+media_modifier+' }\n}\n')
    cases='\n'.join('    case r_'+route.id for route in app.routes)
    tab_routes=[route.id for route in app.routes if route.body.capability=='tabs' and not route.title]
    owns_stacks=' || '.join('self == .r_'+route for route in tab_routes) or 'false'
    methods=[]
    for action in navigation.values():
        target='.r_'+action.route if action.route else None
        body={'back':'if !path.isEmpty { path.removeLast() }','dismiss':'dismissalRequested = true'}.get(action.operation)
        if action.operation=='resetRoot':body='resetRoot?('+target+')'
        if action.operation=='push':body='path.append('+target+')'
        if action.operation=='replace':body='if path.isEmpty { root = '+target+' } else { path[path.count - 1] = '+target+' }'
        if action.operation=='present':body=('sheet' if routes[action.route].presentation=='sheet' else 'fullScreen')+' = '+target
        methods.append('    func a_'+action.id+'() { '+body+' }')
    dispatch='    func navigate(_ action: String) {\n        switch action {\n'+'\n'.join('        case '+quote(action.id)+': a_'+action.id+'()' for action in navigation.values())+'\n        default: assertionFailure("routing.unknownAction")\n        }\n    }\n'
    reset_cases='\n'.join('            case '+quote(action.id)+': rootReset?(.r_'+action.route+')' for action in navigation.values() if action.operation=='resetRoot')
    weak_dispatch='    var flowNavigation: (String) -> Void {\n        let rootReset = resetRoot\n        return { [weak self] action in\n            switch action {\n'+reset_cases+'\n            default: self?.navigate(action)\n            }\n        }\n    }\n'
    initial_appearance='\n        .onAppear { router.resetRoot = rootReset; '+('model.startInitialFlow(router.flowNavigation); ' if getattr(app,'initial_action',None) else '')+('model.startSharedTimers()' if getattr(app,'timers',()) else '')+' }'
    put('App/Generated/NavigationRouter.swift','''import SwiftUI
enum AppRoute: Hashable, Identifiable {
'''+cases+'''
    var id: Self { self }
    var ownsNavigationStacks: Bool { '''+owns_stacks+''' }
}
@MainActor final class NavigationRouter: ObservableObject {
    @Published var root: AppRoute
    @Published var path: [AppRoute] = []
    @Published var sheet: AppRoute?
    @Published var fullScreen: AppRoute?
    @Published var dismissalRequested = false
    var resetRoot: ((AppRoute) -> Void)?
    func reset(to route: AppRoute) { sheet = nil; fullScreen = nil; path = []; root = route; dismissalRequested = false }
    init(initial: AppRoute) { root = initial }
'''+ '\n'.join(methods)+'\n'+dispatch+weak_dispatch+'''
}
private struct AuthoredRootResetKey: EnvironmentKey {
    static let defaultValue: ((AppRoute) -> Void)? = nil
}
private struct AuthoredModalDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
extension EnvironmentValues {
    var authoredRootReset: ((AppRoute) -> Void)? {
        get { self[AuthoredRootResetKey.self] }
        set { self[AuthoredRootResetKey.self] = newValue }
    }
    var authoredModalDismiss: (() -> Void)? {
        get { self[AuthoredModalDismissKey.self] }
        set { self[AuthoredModalDismissKey.self] = newValue }
    }
}
struct NativeRouteHost: View {
    let model: AppModel
    @StateObject private var router: NavigationRouter
    @Environment(\.authoredModalDismiss) private var inheritedDismiss
    @Environment(\.authoredRootReset) private var inheritedRootReset
    private let dismissModal: (() -> Void)?
    private let navigationSurface: Color?
    init(model: AppModel, initial: AppRoute, dismissModal: (() -> Void)? = nil, navigationSurface: Color? = nil) {
        self.navigationSurface = navigationSurface
        self.model = model
        self.dismissModal = dismissModal
        _router = StateObject(wrappedValue: NavigationRouter(initial: initial))
    }
    private var rootReset: (AppRoute) -> Void { inheritedRootReset ?? { [weak router] route in router?.reset(to: route) } }
    var body: some View {
        Group {
            if router.root.ownsNavigationStacks && router.path.isEmpty {
                RouteContent(model: model, route: router.root).environmentObject(router)
            } else {
                stackedContent
            }
        }
        .environmentObject(router)
        .environment(\.authoredRootReset, rootReset)
        .environment(\.authoredModalDismiss, dismissModal ?? inheritedDismiss)
        .sheet(item: $router.sheet) { route in NativeRouteHost(model: model, initial: route, dismissModal: { router.sheet = nil }, navigationSurface: navigationSurface) }
        .fullScreenCover(item: $router.fullScreen) { route in NativeRouteHost(model: model, initial: route, dismissModal: { router.fullScreen = nil }, navigationSurface: navigationSurface) }
        .onChange(of: router.dismissalRequested) { _, requested in
            if requested { (dismissModal ?? inheritedDismiss)?(); router.dismissalRequested = false }
        }'''+initial_appearance+'''
    }
    private var stackedContent: some View {
        NavigationStack(path: $router.path) {
            RouteContent(model: model, route: router.root)
                .environmentObject(router)
                .modifier(AuthoredNavigationSurface(surface: navigationSurface))
                .navigationDestination(for: AppRoute.self) { route in
                    RouteContent(model: model, route: route).environmentObject(router).modifier(AuthoredNavigationSurface(surface: navigationSurface))
                }
        }
    }
}
private struct AuthoredNavigationSurface: ViewModifier {
    let surface: Color?
    @ViewBuilder func body(content: Content) -> some View {
        if let surface {
            content.toolbarBackground(surface, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        } else { content }
    }
}
''')
    from ..navigation_ir import RouteViewportAlignment
    viewport_alignment = {RouteViewportAlignment.TOP_START: 'topLeading'}
    switches='\n'.join('        case .r_'+route.id+': '+symbol(route.body.id)+'(model: model).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .'+viewport_alignment[route.viewport_alignment]+')'+('.navigationTitle('+quote(route.title)+').navigationBarTitleDisplayMode(.'+('large' if route.title_display.value=='large' else 'inline')+')' if route.title else '') for route in app.routes)
    put('App/Generated/RouteContent.swift','import SwiftUI\nstruct RouteContent: View {\n    let model: AppModel\n    let route: AppRoute\n    var body: some View {\n        switch route {\n'+switches+'\n        }\n    }\n}\n')
    def walk(node,scope=None):
        yield node,scope
        if node.capability=='nativeMap':
            if scope is not None:raise ValueError('Nested map annotation scope is unsupported')
            yield from walk(node.children[0],node.props()['collection'].value)
            for child in node.children[1:]:yield from walk(child,scope)
            return
        if node.capability=='repeat':
            if scope is not None:raise ValueError('Nested repeat is unsupported')
            scope=node.props()['collection'].value
        for child in node.children:yield from walk(child,scope)
    nodes=list(walk(app.root))
    for route in app.routes:nodes.extend(walk(route.body))
    seen=set()
    for node,scope in nodes:
        identifier(node.id)
        from ..navigation_appearance import validate_node
        validate_node(node)
        if node.id in seen:raise ValueError('Routed node identities must be globally unique: '+node.id)
        seen.add(node.id);props=node.props();declarations=''
        def scoped_expression(expr,target='ios'):
            if isinstance(expr,FieldReference):
                if expr.collection!=scope:raise ValueError('Field reference outside its repeated row')
                return 'item.f_'+identifier(expr.field)
            return expression(expr,target,render=scoped_expression)
        def child_source(child):
            return symbol(child.id)+'(model: model'+(', item: item' if scope else '')+')'
        child_content='\n'.join(child_source(child) for child in node.children)
        if scope is not None:declarations+='    let item: Collection_'+identifier(scope)+'\n'

        if node.capability in ('navigationStack','tabs','tab'):
            allowed={'navigationStack':{'initialRoute'},'tabs':set(),'tab':{'title','icon'}}[node.capability]
            if set(props)-allowed:raise ValueError('Unsupported navigation properties: '+node.id)
            if node.style is not None or node.motion is not None or node.visible_when is not None or node.action is not None or getattr(node,'enabled_when',None) is not None:
                raise ValueError('Navigation host presentation/actions require explicit shared routing semantics: '+node.id)
        elif node.style is not None:
            style=node.style
            if style.gap is not None and node.capability not in ('row','column','card','repeat'):
                raise ValueError('gap is unsupported for '+node.capability)
            if style.align is not None and node.capability not in ('row','column','card','repeat','text','counter','textField','secureField') and not (style.width is not None or style.height is not None or style.max_width is not None or style.fill):
                raise ValueError('align requires an authored frame for '+node.capability)

        if node.capability=='cameraPreview':
            resource=props['resource'].value
            body='NativeCameraPreview(camera: model.camera_'+identifier(resource)+', active: '+scoped_expression(props['active'])+', ready: $model.s_'+props['ready'].name+', fill: '+('true' if props['fit'].value=='fill' else 'false')+', label: '+scoped_expression(props['accessibilityLabel'])+') { '+child_source(node.children[0])+' } failure: { '+child_source(node.children[1])+' }'
        elif node.capability=='nativeMap':
            collection=collections[props['collection'].value];region=props['region']
            declarations+='    @EnvironmentObject private var router: NavigationRouter\n'
            content=symbol(node.children[0].id)+'(model: model, item: item).environmentObject(router)'
            if node.action:
                content='Button { model.s_'+props['selection'].name+'=item.f_'+collection.key+';model.f_'+node.action+'(router.flowNavigation) } label: { '+content+' }.buttonStyle(.plain)'
            items='model.c_'+collection.name+'.map { item in NativeMapItem(id: String(item.f_'+collection.key+'), latitude: item.f_'+props['latitudeField'].value+', longitude: item.f_'+props['longitudeField'].value+', title: item.f_'+props['titleField'].value+', content: AnyView('+content+')) }'
            reg='NativeMapRegion(latitude: '+str(region.latitude_e6)+', longitude: '+str(region.longitude_e6)+', latitudeSpan: '+str(region.latitude_span_e6)+', longitudeSpan: '+str(region.longitude_span_e6)+')'
            body='NativeAuthoredMap(items: '+items+', region: '+reg+') { '+child_source(node.children[1])+' } failure: { '+child_source(node.children[2])+' }'
        elif node.capability in ('localImage','remoteImage'):
            if len(node.children)!=2:raise ValueError('Media image requires loading and failure children')
            callbacks=' { '+child_source(node.children[0])+' } failure: { '+child_source(node.children[1])+' }'
            common=', fill: '+('true' if props['fit'].value=='fill' else 'false')+', label: '+scoped_expression(props['accessibilityLabel'])
            if node.capability=='localImage':
                body='NativeLocalImage(media: model.m_'+identifier(props['source'].name)+common+')'+callbacks
            else:
                from ..flow_ir import PathTemplate
                path=props['path'];transport=getattr(app,'transport',None)
                if transport is None:raise ValueError('Private media requires transport origin')
                if isinstance(path,PathTemplate):
                    pieces=[quote(transport.base_url.rstrip('/'))]
                    for part in path.parts:
                        pieces.append(quote(part.value) if isinstance(part,Literal) else 'NativeURLComponent.encode(String('+scoped_expression(part)+'))')
                    address=' + '.join(pieces)
                else:address=quote(transport.base_url.rstrip('/')+(path.value if isinstance(path,Literal) else path))
                body='NativeRemoteImage(address: '+address+', bearer: '+scoped_expression(props['bearer'])+', maxBytes: '+scoped_expression(props['maxBytes'])+', maxPixels: '+scoped_expression(props['maxDecodedPixels'])+', maxEdge: '+scoped_expression(props['maxEdge'])+common+')'+callbacks
        elif node.capability=='repeat':
            if set(props)-{'collection','selection'} or len(node.children)!=1 or not isinstance(props.get('collection'),Literal) or props['collection'].value not in collections:
                raise ValueError('Repeat requires an authored collection and one row template')
            collection=collections[props['collection'].value]
            row=symbol(node.children[0].id)+'(model: model, item: item)'
            selection=props.get('selection')
            if (selection is None)!=(node.action is None):raise ValueError('Selectable repeat requires selection and flow action')
            if selection is not None:
                from ..ir import Reference
                if not isinstance(selection,Reference) or node.action not in flows:raise ValueError('Repeat selection requires a state reference and flow action')
                declarations+='    @EnvironmentObject private var router: NavigationRouter\n'
                row='Button { model.s_'+selection.name+' = item.f_'+collection.key+'; model.f_'+node.action+'(router.flowNavigation) } label: { '+row+' }.buttonStyle(.plain)'
            body='ForEach(model.c_'+collection.name+', id: \\.f_'+collection.key+') { item in\n'+row+'\n}'
            style=node.style
            alignment={'start':'leading','center':'center','end':'trailing'}[(style.align if style and style.align else 'start')]
            body='VStack(alignment: .'+alignment+', spacing: '+str(style.gap if style and style.gap is not None else 0)+') {\n'+body+'\n}'
        elif node.capability=='navigationStack':
            initial=props.get('initialRoute')
            if not isinstance(initial,Literal) or initial.type!=ScalarType.STRING or initial.value not in routes or routes[initial.value].presentation!='page' or node.children:
                raise ValueError('navigationStack requires a literal initial page route and no children')
            appearance=node.navigation_appearance
            body='NativeRouteHost(model: model, initial: .r_'+initial.value+(', navigationSurface: '+color(appearance.surface) if appearance and appearance.surface is not None else '')+')'
            if appearance is not None:
                from ..navigation_appearance import NavigationAppearance
                if not isinstance(appearance,NavigationAppearance):raise ValueError('Expected NavigationAppearance')
                if appearance.accent is not None:body+='.tint('+color(appearance.accent)+')'

        elif node.capability=='tabs':
            if not node.children or any(child.capability!='tab' for child in node.children):raise ValueError('tabs requires tab children')
            declarations='    @State private var selection = '+quote(node.children[0].id)+'\n'
            children=[]
            for tab in node.children:
                p=tab.props()
                if any(not isinstance(p.get(key),Literal) or p[key].type!=ScalarType.STRING for key in ('title','icon')) or p['icon'].value not in ICONS:raise ValueError('Tab title/icon must be supported literals')
                children.append(symbol(tab.id)+'(model: model).tabItem { Label('+quote(p['title'].value)+', systemImage: '+quote(ICONS[p['icon'].value])+').accessibilityIdentifier('+quote('tab.'+tab.id)+') }.tag('+quote(tab.id)+')')
            body='TabView(selection: $selection) {\n'+'\n'.join(children)+'\n}'
            appearance=node.navigation_appearance
            if appearance is not None:
                from ..navigation_appearance import TabAppearance
                if not isinstance(appearance,TabAppearance):raise ValueError('Expected TabAppearance')
                if any(value is not None for value in vars(appearance).values()):
                    from .navigation_appearance import IOS_TABS
                    put('App/Generated/AuthoredNativeTabs.swift',IOS_TABS)
                    items=[]
                    for tab in node.children:
                        p=tab.props()
                        items.append('AuthoredTabItem(id: '+quote(tab.id)+', title: '+quote(p['title'].value)+', symbol: '+quote(ICONS[p['icon'].value])+', content: AnyView('+symbol(tab.id)+'(model: model)))')
                    native_color=lambda value:'UIColor('+color(value)+')' if value is not None else 'nil'
                    body='AuthoredNativeTabs(items: ['+', '.join(items)+'], selection: $selection, selectedForeground: '+native_color(appearance.selected_foreground)+', unselectedForeground: '+native_color(appearance.unselected_foreground)+', surface: '+native_color(appearance.surface)+')'

        elif node.capability=='tab':
            if len(node.children)!=1 or node.children[0].capability!='navigationStack':raise ValueError('tab requires one navigationStack child')
            body=symbol(node.children[0].id)+'(model: model)'
        else:
            if node.capability in ('camera','inbox','stories','friendMap','account'):raise ValueError('Whole-screen social capabilities are not supported in shared routing')
            mapping=registry.get(node.capability)
            if set(props)-set(mapping['properties']):raise ValueError('Unsupported primitive properties: '+node.id)
            values={key:scoped_expression(value,'ios') for key,value in props.items()}
            action='model.a_'+str(node.action)
            if node.action in flows:
                declarations+='    @EnvironmentObject private var router: NavigationRouter\n'
                action='{ model.f_'+node.action+'(router.flowNavigation) }'
            elif node.action in navigation:
                declarations+='    @EnvironmentObject private var router: NavigationRouter\n'
                action='router.a_'+node.action
            values.update(children=child_content,action=action)
            for key,spec in mapping['properties'].items():
                if spec.get('binding'):values['binding_'+key]='$model.s_'+props[key].name
            if node.capability=='native':values['symbol']='v_'+props['symbol'].value
            body=expand(mapping['targets']['ios']['expression'],values)
            if node.capability in ('textField','secureField') and node.style is not None:
                kind='TextField' if node.capability=='textField' else 'SecureField'
                foreground=color(node.style.color) if node.style.color else 'Color.primary'
                body=kind+'('+values['placeholder']+', text: '+values['binding_value']+', prompt: Text('+values['placeholder']+').foregroundColor('+foreground+'.opacity(0.5)))\n.textFieldStyle(.plain)'
        styled=(render_button(node,action,expression_fn=scoped_expression) if node.capability=='button' and node.style is not None else presentation(node,body,expression_fn=scoped_expression,children_source=child_content))
        if node.capability in ('localImage','remoteImage','cameraPreview') and props['fit'].value=='fill':styled=Presentation(styled.body+'\n.clipped()',styled.declarations)
        model_binding = 'let' if node.capability in ('navigationStack','tabs','tab') or 'model.' not in (declarations+styled.declarations+styled.body) else '@ObservedObject var'
        put('App/Generated/Nodes/'+symbol(node.id)+'.swift','import SwiftUI\nstruct '+symbol(node.id)+': View {\n    '+model_binding+' model: AppModel\n'+declarations+styled.declarations+'    var body: some View {\n'+styled.body+'\n    }\n}\n')
    from .ios_flow import enhance
    enhance(app,files)
    return files


class IOS:
    target='ios'
    generate=staticmethod(generate)
