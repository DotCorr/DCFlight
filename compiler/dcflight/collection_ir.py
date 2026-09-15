"""Typed response collections; instantiated as ordinary native records, never runtime IR."""
from dataclasses import dataclass
from typing import Optional, Tuple
from .ir import ScalarType, Literal, FieldReference

@dataclass(frozen=True)
class CollectionField:
    name: str
    type: ScalarType
    default: Optional[Literal] = None

@dataclass(frozen=True)
class Collection:
    name: str
    key: str
    fields: Tuple[CollectionField, ...]


def lower_collections(raw, state_names):
    from .validate import keys, check, identifier, literal
    check(isinstance(raw,list) and len(raw)<=128,'collections requires at most 128 definitions')
    result=[]; names=set(state_names)
    for item in raw:
        keys(item,('name','key','fields'),('name','key','fields'),'collection')
        name=identifier(item['name'],'collection.name')
        check(name.casefold() not in {n.casefold() for n in names},'Duplicate collection/state name: '+name)
        names.add(name); fields=[]; seen=set()
        check(isinstance(item['fields'],dict) and 0<len(item['fields'])<=128,'Collection requires 1..128 fields')
        for fname,spec in item['fields'].items():
            identifier(fname,'collection field')
            check(fname.casefold() not in seen,'Duplicate collection field');seen.add(fname.casefold())
            keys(spec,('type','default'),('type',),'collection field')
            check(spec['type'] in ('string','int','bool'),'Unsupported collection field type')
            typ=ScalarType(spec['type']);default=literal(spec['default'],'field default') if 'default' in spec else None
            check(default is None or default.type==typ,'Wrong collection default type')
            fields.append(CollectionField(fname,typ,default))
        key=identifier(item['key'],'collection.key');field=next((f for f in fields if f.name==key),None)
        check(field is not None and field.type in (ScalarType.STRING,ScalarType.INT),'Collection key requires declared string/int field')
        check(field.default is None,'Collection key cannot have default')
        result.append(Collection(name,key,tuple(fields)))
    return tuple(result)


def lower_collection_ui(raw, common, registry, collections, flow_ids, media_states=(), transport=None, camera_resources=(), map_config=None):
    """Reuse scalar validation, then replace private validation-only references.

    No synthesized state or placeholder capability survives into canonical IR.
    """
    from dataclasses import replace
    from .ir import Literal, Reference, Node, map_expression
    from .validate import check, keys, identifier, lower
    by_name={c.name:c for c in collections}; synthesized={}; fields={}; repeats={}; images={}; devices={}
    states=common.get('state',{})
    check(isinstance(states,dict),'state requires object')
    reserved=set(states)
    def reserve(v):
        if isinstance(v,dict):
            if isinstance(v.get('ref'),str):reserved.add(v['ref'])
            for child in v.values():reserve(child)
        elif isinstance(v,list):
            for child in v:reserve(child)
    reserve(raw)
    def value(v,scope,writable=False,depth=0):
        check(depth <= 36, 'Expression nesting exceeds 36')
        if isinstance(v,list):return [value(item,scope,writable,depth+1) for item in v]
        if isinstance(v,dict) and 'field' not in v:
            return {key:value(item,scope,writable,depth+1) for key,item in v.items()}
        if not isinstance(v,dict) or 'field' not in v:return v
        keys(v,('field',),('field',),'row reference')
        f=v['field'];keys(f,('collection','name'),('collection','name'),'row field')
        check(scope is not None and f['collection']==scope,'Field reference outside its repeated row')
        field=next((x for x in by_name[scope].fields if x.name==f['name']),None)
        check(field is not None,'Unknown collection field')
        check(not writable,'Collection row fields are read-only')
        key='CollectionValidationField'+str(len(fields))
        while key in reserved or key in synthesized:key+='X'
        fields[key]=FieldReference(scope,field.name,field.type)
        synthesized[key]={ScalarType.STRING:'',ScalarType.INT:0,ScalarType.BOOL:False}[field.type]
        return {'ref':key}
    def prepare(node,scope=None,depth=0):
        check(depth<=100,'UI nesting exceeds 100')
        check(isinstance(node,dict),'Expected authored UI node')
        if node.get('type') in ('cameraPreview','nativeMap'):
            from .device_ir import map_region
            from .validate import literal
            kind=node['type'];keys(node,('id','type','props','children','style','motion','visibleWhen','enabledWhen','action'),('id','type','props','children'),'device view')
            nid=identifier(node['id'],'device view.id');props=node['props'];children=node['children'];typed={};action=node.get('action')
            check(not set(node.get('style',{})).intersection(('gap','fontSize','fontWeight','color')),'Device view does not accept text/container style')
            def state_ref(raw,typ):
                keys(raw,('ref',),('ref',),'device state reference');name=raw['ref']
                check(isinstance(name,str) and name in states and literal(states[name],'device state').type==typ,'Wrong/unknown device state reference')
                return Reference(name,typ)
            if kind=='cameraPreview':
                keys(props,('resource','active','ready','fit','accessibilityLabel'),('resource','active','ready','accessibilityLabel'),'camera preview')
                check(isinstance(props['resource'],str) and props['resource'] in {c.id for c in camera_resources},'Unknown camera preview resource')
                check(action is None,'Camera preview has no implicit action');check(props.get('fit','fill') in ('fit','fill'),'Invalid camera fit')
                check(isinstance(props['accessibilityLabel'],str),'Camera requires authored accessibility label')
                typed={'resource':literal(props['resource'],'resource'),'active':state_ref(props['active'],ScalarType.BOOL),'ready':state_ref(props['ready'],ScalarType.BOOL),'fit':literal(props.get('fit','fill'),'fit'),'accessibilityLabel':literal(props['accessibilityLabel'],'label')}
                check(typed['active'].name!=typed['ready'].name,'Camera active/ready states must differ')
                check(isinstance(children,list) and len(children)==2,'Camera preview requires loading/failure children')
                prepared_children=[prepare(c,scope,depth+1) for c in children]
            else:
                check(scope is None,'Nested map/repeat annotations unsupported');check(map_config is not None,'Native map requires explicit provider config')
                keys(props,('collection','latitudeField','longitudeField','titleField','region','selection'),('collection','latitudeField','longitudeField','titleField','region'),'native map')
                name=props['collection'];check(isinstance(name,str) and name in by_name,'Unknown map collection');collection=by_name[name];fields_by_name={f.name:f.type for f in collection.fields}
                for key,typ in [('latitudeField',ScalarType.INT),('longitudeField',ScalarType.INT),('titleField',ScalarType.STRING)]:
                    check(isinstance(props[key],str) and fields_by_name.get(props[key])==typ,'Wrong map field type');typed[key]=literal(props[key],key)
                typed['collection']=literal(name,'collection');typed['region']=map_region(props['region'])
                check(('selection' in props)==(action is not None),'Map selection/action must both be present')
                if action is not None:
                    check(isinstance(action,str) and action in flow_ids,'Map selection requires declared flow action')
                    typed['selection']=state_ref(props['selection'],fields_by_name[collection.key])
                check(isinstance(children,list) and len(children)==3,'Map requires annotation/loading/failure children')
                def annotation(n):
                    check(isinstance(n,dict) and n.get('type') in ('text','icon','row','column','card'),'Unsupported map annotation capability')
                    check('action' not in n and 'motion' not in n,'Map annotations do not support actions or motion')
                    check(isinstance(n.get('children',[]),list),'Annotation children must be array')
                    for child in n.get('children',[]):annotation(child)
                annotation(children[0])
                prepared_children=[prepare(children[0],name,depth+1),prepare(children[1],None,depth+1),prepare(children[2],None,depth+1)]
            devices[nid]=(kind,tuple(typed.items()),action)
            prepared={**node,'type':'column','props':{},'children':prepared_children};prepared.pop('action',None)
            for key in ('visibleWhen','enabledWhen'):
                if key in node:prepared[key]=value(node[key],scope)
            return prepared
        if node.get('type') in ('localImage','remoteImage'):
            from .media_ir import media_ref
            from .flow_ir import PathTemplate
            from .validate import literal
            keys(node,('id','type','props','children','style','motion','visibleWhen','enabledWhen'),('id','type','props','children'),'media image')
            nid=identifier(node['id'],'image.id');props=node['props'];remote=node['type']=='remoteImage'
            check(not set(node.get('style',{})).intersection(('gap','fontSize','fontWeight','color')),'Image style does not accept text/container properties')
            allowed=('path','bearer','maxBytes','maxDecodedPixels','maxEdge','fit','accessibilityLabel') if remote else ('source','fit','accessibilityLabel')
            keys(props,allowed,('path','bearer','accessibilityLabel') if remote else ('source','accessibilityLabel'),'media image props')
            check(props.get('fit','fit') in ('fit','fill'),'Unsupported media image fit')
            check(isinstance(props['accessibilityLabel'],str),'Media accessibility label requires authored literal')
            typed={'fit':literal(props.get('fit','fit'),'fit'),'accessibilityLabel':literal(props['accessibilityLabel'],'image label')}
            if remote:
                check(transport is not None,'Remote image requires transport')
                bearer=props['bearer'];keys(bearer,('ref',),('ref',),'image bearer')
                check(isinstance(bearer['ref'],str) and bearer['ref'] in states and type(states[bearer['ref']]) is str,'Image bearer requires string state')
                typed['bearer']=Reference(bearer['ref'],ScalarType.STRING)
                path=props['path'];parts=path if isinstance(path,list) else [path]
                check(0<len(parts)<=128 and isinstance(parts[0],str) and parts[0].startswith('/') and not parts[0].startswith('//'),'Image path requires origin-relative literal first part')
                decoded=[]
                for part in parts:
                    if isinstance(part,dict):
                        transformed=value(part,scope)
                        keys(transformed,('ref',),('ref',),'image path reference');name=transformed['ref']
                        if name in fields:ref=fields[name]
                        else:
                            check(isinstance(name,str) and name in states,'Unknown image path state');ref=Reference(name,literal(states[name],'image path state').type)
                        check(ref.type in (ScalarType.STRING,ScalarType.INT),'Image path requires string/int reference');decoded.append(ref)
                    else:
                        check(isinstance(part,str) and not any(ord(c)<33 or ord(c)==127 or c=='\\' or c=='#' for c in part),'Invalid image path segment');decoded.append(literal(part,'image path'))
                typed['path']=PathTemplate(tuple(decoded)) if isinstance(path,list) else path
                for key,maximum,default in [('maxBytes',8388608,8388608),('maxDecodedPixels',40000000,20000000),('maxEdge',4096,2048)]:
                    v=props.get(key,default);check(type(v) is int and 1<=v<=maximum,'Invalid image decode bound');typed[key]=literal(v,key)
            else:typed['source']=media_ref(props['source'],media_states)
            children=node['children'];check(isinstance(children,list) and len(children)==2,'Media image requires loading and failure child nodes')
            images[nid]=(node['type'],tuple(typed.items()))
            prepared={**node,'type':'column','props':{},'children':[prepare(c,scope,depth+1) for c in children]}
            for key in ('visibleWhen','enabledWhen'):
                if key in node:prepared[key]=value(node[key],scope)
            return prepared
        if node.get('type')=='repeat':
            check(scope is None,'Nested repeat is unsupported')
            keys(node,('id','type','props','children','action'),('id','type','props','children'),'repeat')
            nid=identifier(node['id'],'repeat.id');props=node['props']
            keys(props,('collection','selection'),('collection',),'repeat.props')
            name=props['collection'];check(isinstance(name,str) and name in by_name,'Unknown repeated collection')
            children=node['children'];check(isinstance(children,list) and len(children)==1,'Repeat requires exactly one child row')
            check(('selection' in props)==('action' in node),'Repeat selection/action must both be present')
            selection=None
            if 'selection' in props:
                selection=props['selection'];keys(selection,('ref',),('ref',),'repeat selection')
                keyfield=next(f for f in by_name[name].fields if f.name==by_name[name].key)
                selected=selection['ref'];check(isinstance(selected,str) and selected in states,'Unknown repeat selection state')
                from .validate import literal
                check(literal(states[selected],'selection').type==keyfield.type,'Repeat selection must match key type')
                check(isinstance(node['action'],str) and node['action'] in flow_ids,'Repeat requires a declared flow action')
                selection=Reference(selected,keyfield.type)
            repeats[nid]=(name,selection,node.get('action'))
            return {'id':nid,'type':'column','props':{},'children':[prepare(children[0],name,depth+1)]}
        result=dict(node)
        props=node.get('props',{})
        check(isinstance(props,dict),'Node props must be object')
        entry=registry.get(node.get('type'))
        result['props']={k:value(v,scope,entry.get('properties',{}).get(k,{}).get('binding',False)) for k,v in props.items()}
        for key in ('visibleWhen','enabledWhen'):
            if key in node:result[key]=value(node[key],scope)
        if 'children' in node:
            check(isinstance(node['children'],list),'Node children require array')
            result['children']=[prepare(c,scope,depth+1) for c in node['children']]
        return result
    prepared=prepare(raw)
    app=lower({**common,'state':{**states,**synthesized},'root':prepared},registry)
    def expression(v):return map_expression(v,lambda leaf: fields.get(leaf.name,leaf) if isinstance(leaf,Reference) else leaf)
    def restore(node):
        children=tuple(restore(c) for c in node.children)
        if node.id in devices:
            kind,props,action=devices[node.id]
            return replace(node,capability=kind,properties=props,action=action,children=children,visible_when=expression(node.visible_when),enabled_when=expression(node.enabled_when))
        if node.id in images:
            kind,props=images[node.id]
            return replace(node,capability=kind,properties=props,children=children,visible_when=expression(node.visible_when),enabled_when=expression(node.enabled_when))
        if node.id in repeats:
            name,selection,action=repeats[node.id]
            props=[('collection',Literal(name,ScalarType.STRING))]
            if selection is not None:props.append(('selection',selection))
            return Node(node.id,'repeat',tuple(props),children,action)
        return replace(node,properties=tuple((k,expression(v)) for k,v in node.properties),children=children,
                       visible_when=expression(node.visible_when),enabled_when=expression(node.enabled_when))
    return restore(app.root)
