"""Typed shared routes and native navigation, independent of authoring language."""
from dataclasses import dataclass
from enum import Enum
from typing import Optional,Tuple
from .ir import Application,Node,Literal,ScalarType
from .flow_ir import FlowAction,Transport,lower_flows,Timer,lower_timers
from .collection_ir import Collection,lower_collections,lower_collection_ui
from .media_ir import MediaState,lower_media
from .device_ir import CameraResource,MapConfig,lower_device


class TitleDisplay(str, Enum):
    COMPACT = 'compact'
    LARGE = 'large'


class RouteViewportAlignment(str, Enum):
    TOP_START = "topStart"


@dataclass(frozen=True)
class Route:
    id: str
    title: str
    body: Node
    presentation: str = 'page'
    title_display: TitleDisplay = TitleDisplay.COMPACT
    viewport_alignment: RouteViewportAlignment = RouteViewportAlignment.TOP_START

    def __post_init__(self):
        if not isinstance(self.viewport_alignment, RouteViewportAlignment):
            raise ValueError('Route viewport requires canonical RouteViewportAlignment')
        if not isinstance(self.title_display, TitleDisplay):
            raise ValueError('Route title display requires canonical TitleDisplay')
        if self.title_display == TitleDisplay.LARGE and not self.title:
            raise ValueError('Large title display requires a nonempty title')


@dataclass(frozen=True)
class NavigationAction:
    id: str
    operation: str
    route: Optional[str] = None


@dataclass(frozen=True)
class RoutedApplication(Application):
    native_operations: tuple = ()
    camera_resources: Tuple[CameraResource,...] = ()
    permission_descriptions: Tuple[Tuple[str,str],...] = ()
    map_config: Optional[MapConfig] = None
    timers: Tuple[Timer,...] = ()
    media_states: Tuple[MediaState,...] = ()
    collections: Tuple[Collection,...] = ()
    routes: Tuple[Route,...] = ()
    navigation_actions: Tuple[NavigationAction,...] = ()
    flow_actions: Tuple[FlowAction,...] = ()
    transport: Optional[Transport] = None
    initial_action: Optional[str] = None

    def nodes(self):
        def walk(node):
            yield node
            for child in node.children:yield from walk(child)
        return tuple(node for root in (self.root,*(route.body for route in self.routes)) for node in walk(root))


def lower_routed(data,registry):
    from .validate import check,keys,identifier,lower
    keys(data,('version','id','name','state','actions','logic','modules','root','routes','navigationActions','flowActions','transport','initialAction','collections','media','timers','cameraResources','permissionDescriptions','mapConfig','nativeOperations','sdkCatalog','nativeConfiguration'),
         ('version','id','name','root','routes'),'app')
    check(type(data['version']) is int and data['version']==2,'Expected routed authoring version2')
    from .native_operation import lower_contract
    operation_raw=data.get('nativeOperations',[])
    check(isinstance(operation_raw,list) and len(operation_raw)<=128,'nativeOperations requires at most128 entries')
    native_operations=tuple(lower_contract(v) for v in operation_raw)
    check(len({o.name.casefold() for o in native_operations})==len(native_operations),'Duplicate native operation')
    check(all(o.execution in ('main','worker') for o in native_operations),'App native operations require explicit main or worker execution')
    check(not native_operations or isinstance(data.get('sdkCatalog'),str) and bool(data['sdkCatalog']),'Native operations require sdkCatalog')
    routes_raw=data['routes'];nav_raw=data.get('navigationActions',[])
    check(isinstance(routes_raw,list) and 0<len(routes_raw)<=128,'routes: expected one to128 authored routes')
    check(isinstance(nav_raw,list) and len(nav_raw)<=512,'navigationActions: expected array')
    route_ids={};nav_ids=set();nav=[]
    for route in routes_raw:
        keys(route,('id','title','body','presentation','titleDisplay'),('id','title','body'),'route')
        identifier(route['id'],'route.id')
        check(route['id'] not in route_ids,'Duplicate route: '+route['id'])
        check(isinstance(route['title'],str),'route.title must be authored text')
        check(route.get('presentation','page') in ('page','sheet','fullScreen'),'Unsupported route presentation')
        check(route.get('titleDisplay','compact') in ('compact','large'),'Unsupported route title display')
        check(bool(route['title']) or route.get('titleDisplay','compact')=='compact','Large title display requires a nonempty title')
        route_ids[route['id']]=route
    flow_raw=data.get('flowActions',[])
    check(isinstance(flow_raw,list),'flowActions must be an array')
    flow_ids=[]
    for action in flow_raw:
        check(isinstance(action,dict) and 'id' in action,'Flow action requires id')
        flow_ids.append(identifier(action['id'],'flowAction.id'))
    check(len(flow_ids)==len(set(flow_ids)),'Duplicate flow action')
    original_actions=data.get('actions',[])
    check(isinstance(original_actions,list),'actions: expected array')
    action_ids={a.get('id') for a in original_actions if isinstance(a,dict) and isinstance(a.get('id'),str)}
    for action in original_actions:
        if isinstance(action,dict) and 'failure' in action:
            check(isinstance(action['failure'],str) and action['failure'] in action_ids,
                  'Scalar call failure must name an original scalar action')
    check(not set(flow_ids).intersection(action_ids),'Flow and scalar action identities must be distinct')
    action_ids.update(flow_ids)
    for action in nav_raw:
        keys(action,('id','op','route'),('id','op'),'navigationAction')
        identifier(action['id'],'navigationAction.id')
        check(action['id'] not in nav_ids|action_ids,'Duplicate action: '+action['id'])
        operation=action['op'];destination=action.get('route')
        check(operation in ('push','replace','resetRoot','back','present','dismiss'),'Unsupported navigation operation')
        if operation in ('push','replace','resetRoot','present'):
            check(isinstance(destination,str) and destination in route_ids,'Unknown navigation route')
            presentation=route_ids[destination].get('presentation','page')
            check((operation=='present')==(presentation!='page'),'Navigation action does not match route presentation')
        else:check('route' not in action,'Back/dismiss cannot have a route argument')
        nav.append(NavigationAction(action['id'],operation,destination));nav_ids.add(action['id'])
    common={k:v for k,v in data.items() if k in ('id','name','state','logic','modules','nativeConfiguration')}
    # Reuse scalar/action/type validation, then replace temporary navigation markers
    # with explicit typed navigation actions. No native escape hatch is introduced.
    common.update(version=1,actions=original_actions+[{'id':a.id,'op':'native'} for a in nav]+[{'id':i,'op':'native'} for i in flow_ids])
    check(isinstance(data.get('state',{}),dict),'state requires object')
    collections=lower_collections(data.get('collections',[]),data.get('state',{}))
    media_states=lower_media(data.get('media',[]),list(data.get('state',{}))+[c.name for c in collections])
    camera_resources,permission_descriptions,map_config=lower_device(data)
    validated=[]
    def ui(raw,depth=0):
        check(depth<=32,'Navigation nesting limit exceeded')
        check(isinstance(raw,dict),'Expected authored UI node')
        kind=raw.get('type')
        if kind in ('navigationStack','tabs','tab'):
            keys(raw,('id','type','props','children','appearance'),('id','type','props'),'navigation node')
            from .navigation_appearance import lower as lower_appearance
            appearance=lower_appearance(raw['appearance'],kind) if 'appearance' in raw else None
            identifier(raw['id'],'navigation node.id')
            props=raw['props'];children=raw.get('children',[])
            check(isinstance(children,list),'Navigation children must be an array')
            if kind=='navigationStack':
                keys(props,('initialRoute',),('initialRoute',),'navigationStack.props')
                route=props['initialRoute']
                check(isinstance(route,str) and route in route_ids and route_ids[route].get('presentation','page')=='page','navigationStack requires a declared page route')
                check(not children,'navigationStack uses declared routes, not inline children')
            elif kind=='tabs':
                keys(props,(),(),'tabs.props')
                check(1<=len(children)<=5 and all(isinstance(c,dict) and c.get('type')=='tab' for c in children),'tabs requires one to five authored tabs')
            else:
                from .presentation import ICONS
                keys(props,('title','icon'),('title','icon'),'tab.props')
                check(isinstance(props['title'],str) and isinstance(props['icon'],str) and props['icon'] in ICONS,'tab title/icon require supported literal values')
                check(len(children)==1 and isinstance(children[0],dict) and children[0].get('type')=='navigationStack','Each tab requires its own native navigation stack')
            return Node(raw['id'],kind,tuple((key,Literal(value,ScalarType.STRING)) for key,value in sorted(props.items())),tuple(ui(c,depth+1) for c in children),navigation_appearance=appearance)
        node=lower_collection_ui(raw,common,registry,collections,flow_ids,media_states,data.get("transport"),camera_resources,map_config)
        def walk(n):
            yield n
            for child in n.children:yield from walk(child)
        check(not any(n.capability in ('camera','inbox','stories','friendMap','account') for n in walk(node)),'Whole-screen platform templates are not allowed in routed authoring')
        return node
    root=ui(data['root'])
    routes=tuple(Route(r['id'],r['title'],ui(r['body']),r.get('presentation','page'),TitleDisplay(r.get('titleDisplay','compact'))) for r in routes_raw)
    # Even navigation-only definitions get the complete common type checks.
    base=lower({**common,'root':{'id':'validationRoot','type':'text','props':{'text':''}}},registry)
    flows,transport,initial=lower_flows(data,base,nav_ids,collections,media_states,camera_resources,permission_descriptions,native_operations)
    timers=lower_timers(data.get('timers',[]),flows)
    app=RoutedApplication(base.id,base.name,base.states,tuple(a for a in base.actions if a.id not in nav_ids and a.id not in flow_ids),root,
                          version=2,native_operations=native_operations,logic=base.logic,modules=base.modules,native_configuration=base.native_configuration,collections=collections,media_states=media_states,timers=timers,camera_resources=camera_resources,permission_descriptions=permission_descriptions,map_config=map_config,routes=routes,navigation_actions=tuple(nav),flow_actions=flows,transport=transport,initial_action=initial)
    if map_config is not None:
        check(any(m.id==map_config.android_module and m.platform=='android' for m in app.modules),'Map requires declared locked Android module')
    if camera_resources:check('camera' in dict(permission_descriptions),'Camera resource requires authored permission purpose')
    nodes=app.nodes();ids=[n.id.casefold() for n in nodes]
    check(len(ids)==len(set(ids)),'Node identities must be unique across all authored routes')
    check(len(nodes)<=4096,'Application node limit exceeded')
    check(root.capability in ('navigationStack','tabs'),'Routed app root must be native navigationStack or tabs')
    check(not any(a.operation=='resetRoot' for a in nav) or root.capability=='navigationStack','resetRoot requires one root navigationStack')
    # Prevent recursive host construction (a stack opening a route that contains itself).
    dependencies={r.id:set() for r in routes}
    def starts(node):
        if node.capability=='navigationStack':yield node.props()['initialRoute'].value
        for c in node.children:yield from starts(c)
    for route in routes:dependencies[route.id].update(starts(route.body))
    visiting=set();visited=set()
    def visit(route):
        check(route not in visiting,'Recursive initial navigation host: '+route)
        if route in visited:return
        visiting.add(route)
        for other in dependencies[route]:visit(other)
        visiting.remove(route);visited.add(route)
    for route in dependencies:visit(route)
    return app


def schema(registry):
    """Authoring schema; graph/type constraints are additionally checked by lowering."""
    import copy
    base=copy.deepcopy(registry.schema())
    from .predicate_schema import CONDITION_REF, definitions as predicate_definitions
    base['$defs'].update(predicate_definitions(fields=True))
    identifier={'type':'string','pattern':'^[A-Za-z][A-Za-z0-9_]*$'}
    def obj(properties,required):
        return {'type':'object','additionalProperties':False,'properties':properties,'required':required}
    stack=obj({'id':identifier,'type':{'const':'navigationStack'},'props':obj({'initialRoute':identifier},['initialRoute']),
               'children':{'type':'array','maxItems':0}},['id','type','props'])
    from .navigation_appearance import schema as appearance_schema
    stack['properties']['appearance']=appearance_schema('navigationStack')
    from .presentation import ICONS
    tab=obj({'id':identifier,'type':{'const':'tab'},'props':obj({'title':{'type':'string'},'icon':{'enum':list(ICONS)}},['title','icon']),
             'children':{'type':'array','items':stack,'minItems':1,'maxItems':1}},['id','type','props','children'])
    tabs=obj({'id':identifier,'type':{'const':'tabs'},'props':obj({},[]),
              'children':{'type':'array','items':tab,'minItems':1,'maxItems':5}},['id','type','props','children'])
    tabs['properties']['appearance']=appearance_schema('tabs')
    base['$id']='https://dcflight.dev/schema/app-v2.json'
    base['properties']['version']={'const':2}
    from .native_operation import schema as operation_schema
    base['properties']['nativeOperations']={'type':'array','maxItems':128,'items':operation_schema()}
    base['properties']['sdkCatalog']={'type':'string','minLength':1}
    base['properties'].pop('service',None);base['properties'].pop('theme',None)
    base['$defs']['node']['oneOf']=[n for n in base['$defs']['node']['oneOf'] if n['properties']['type']['const'] not in ('tabs','tab','camera','inbox','stories','friendMap','account')]
    base['$defs']['navigation']={'oneOf':[stack,tabs]}
    base['properties']['root']={'$ref':'#/$defs/navigation'}
    base['properties']['routes']={'type':'array','minItems':1,'maxItems':128,'items':obj({
        'id':identifier,'title':{'type':'string'},'presentation':{'enum':['page','sheet','fullScreen']},'titleDisplay':{'enum':['compact','large'],'default':'compact'},
        'body':{'oneOf':[{'$ref':'#/$defs/node'},{'$ref':'#/$defs/navigation'}]}},['id','title','body'])}
    base['properties']['navigationActions']={'type':'array','maxItems':512,'items':{'oneOf':[
        obj({'id':identifier,'op':{'enum':['push','replace','resetRoot','present']},'route':identifier},['id','op','route']),
        obj({'id':identifier,'op':{'enum':['back','dismiss']}},['id','op'])]}}
    from .flow_ir import schema_fields
    base['properties'].update(schema_fields())
    fieldref=obj({'field':obj({'collection':identifier,'name':identifier},['collection','name'])},['field'])
    for node in base['$defs']['node']['oneOf']:
        kind=node['properties']['type']['const']
        entry=registry.get(kind)
        for name,shape in node['properties']['props']['properties'].items():
            if 'oneOf' in shape and not entry['properties'][name].get('binding'):
                shape['oneOf'].append(fieldref)
    repeat=obj({'id':identifier,'type':{'const':'repeat'},'props':obj({'collection':identifier,'selection':obj({'ref':identifier},['ref'])},['collection']),
                'action':identifier,'children':{'type':'array','minItems':1,'maxItems':1,'items':{'$ref':'#/$defs/node'}}},['id','type','props','children'])
    base['$defs']['node']['oneOf'].append(repeat)
    mediaref=obj({'media':identifier},['media']);stateref=obj({'ref':identifier},['ref'])
    for kind in ('localImage','remoteImage'):
        props={'fit':{'enum':['fit','fill']},'accessibilityLabel':{'type':'string'}}
        required=['accessibilityLabel']
        if kind=='localImage':props['source']=mediaref;required.append('source')
        else:
            props.update({'path':{'oneOf':[{'type':'string'},{'type':'array','minItems':1,'maxItems':128,'items':{'oneOf':[{'type':'string'},stateref,fieldref]}}]},'bearer':stateref,
                          **{k:{'type':'integer','minimum':1,'maximum':v} for k,v in [('maxBytes',8388608),('maxDecodedPixels',40000000),('maxEdge',4096)]}})
            required.extend(['path','bearer'])
        from .presentation import style_schema,MOTION_SCHEMA
        style=style_schema();style['properties'].pop('gap');style['properties'].pop('fontSize');style['properties'].pop('fontWeight');style['properties'].pop('color')
        image=obj({'id':identifier,'type':{'const':kind},'props':obj(props,required),'children':{'type':'array','minItems':2,'maxItems':2,'items':{'$ref':'#/$defs/node'}},
                   'style':style,'motion':MOTION_SCHEMA,'visibleWhen':CONDITION_REF,'enabledWhen':CONDITION_REF},['id','type','props','children'])
        base['$defs']['node']['oneOf'].append(image)

    region=obj({k:{'type':'integer','minimum':lo,'maximum':hi} for k,lo,hi in [('latitudeE6',-85051128,85051128),('longitudeE6',-180000000,180000000),('latitudeSpanE6',1,180000000),('longitudeSpanE6',1,360000000)]},['latitudeE6','longitudeE6','latitudeSpanE6','longitudeSpanE6'])
    for kind in ('cameraPreview','nativeMap'):
        if kind=='cameraPreview':
            props={'resource':identifier,'active':stateref,'ready':stateref,'fit':{'enum':['fit','fill']},'accessibilityLabel':{'type':'string'}};required=['resource','active','ready','accessibilityLabel'];count=2
        else:
            props={'collection':identifier,'latitudeField':identifier,'longitudeField':identifier,'titleField':identifier,'region':region,'selection':stateref};required=['collection','latitudeField','longitudeField','titleField','region'];count=3
        shape={'id':identifier,'type':{'const':kind},'props':obj(props,required),'children':{'type':'array','minItems':count,'maxItems':count,'items':{'$ref':'#/$defs/node'}},'style':style,'motion':MOTION_SCHEMA,'visibleWhen':CONDITION_REF,'enabledWhen':CONDITION_REF}
        if kind=='nativeMap':shape['action']=identifier
        base['$defs']['node']['oneOf'].append(obj(shape,['id','type','props','children']))
    field_types=[]
    for typ,json_type in (('string','string'),('int','integer'),('bool','boolean')):
        default={'type':json_type}
        if typ=='int':default.update(minimum=-2147483648,maximum=2147483647)
        field_types.append(obj({'type':{'const':typ},'default':default},['type']))
    base['properties']['collections']={'type':'array','maxItems':128,'items':obj({'name':identifier,'key':identifier,
        'fields':{'type':'object','minProperties':1,'maxProperties':128,'propertyNames':identifier,'additionalProperties':{'oneOf':field_types}}},['name','key','fields'])}
    base['required'].append('routes')
    return base
