"""Typed development-time event plans. Native backends emit ordinary control flow."""
from dataclasses import dataclass
from typing import Optional, Tuple, Union
from urllib.parse import urlsplit
from .ir import Expression, Reference, ScalarType, ABIType
from .device_ir import PermissionEffect,CameraFacingEffect,CapturePhotoEffect,LocationEffect
from .media_ir import PickPhotoEffect,ClearMediaEffect,MediaBody,MediaProjection,media_ref,photo_options

@dataclass(frozen=True)
class LogicCallEffect:
    function: str
    arguments: Tuple[Expression,...]
    target: str
    success: str
    failure: str

@dataclass(frozen=True)
class NativeOperationEffect:
    operation: str
    arguments: Tuple[Expression,...]
    target: str
    success: str
    failure: str

@dataclass(frozen=True)
class Projection:
    operation: str
    value: Reference
    @property
    def type(self): return ScalarType.INT
@dataclass(frozen=True)
class SetEffect:
    target: str
    value: Expression
@dataclass(frozen=True)
class NavigateEffect:
    action: str
@dataclass(frozen=True)
class InvokeEffect:
    action: str
@dataclass(frozen=True)
class CancelEffect: pass
@dataclass(frozen=True)
class ClearCollectionEffect:
    target: str
@dataclass(frozen=True)
class SecureEffect:
    operation: str
    key: str
    target: str
    failure: str
@dataclass(frozen=True)
class ResponseOutput:
    target: str
    path: Tuple[str,...]
    mode: str = "replace"
@dataclass(frozen=True)
class PathTemplate:
    parts: Tuple[Expression,...]
@dataclass(frozen=True)
class ClockEffect:
    target: str
    failure: str
@dataclass(frozen=True)
class ReadCollectionEffect:
    collection: str
    key: Reference
    outputs: Tuple[ResponseOutput,...]
    success: str
    failure: str
@dataclass(frozen=True)
class Timer:
    id: str
    interval_ms: int
    action: str
@dataclass(frozen=True)
class RequestEffect:
    id: str
    method: str
    path: Union[str,PathTemplate]
    body: Union[Tuple[Tuple[str,Expression],...],MediaBody]
    bearer: Optional[Reference]
    outputs: Tuple[ResponseOutput,...]
    success: str
    failure: str
    status_target: Optional[str] = None
Effect = Union[LogicCallEffect,NativeOperationEffect,PermissionEffect,CameraFacingEffect,CapturePhotoEffect,LocationEffect,ClockEffect,ReadCollectionEffect,PickPhotoEffect,ClearMediaEffect,SetEffect,NavigateEffect,InvokeEffect,CancelEffect,ClearCollectionEffect,SecureEffect,RequestEffect]
@dataclass(frozen=True)
class FlowCase:
    code: int
    effects: Tuple[Effect,...]
@dataclass(frozen=True)
class FlowAction:
    id: str
    function: Optional[str]
    arguments: Tuple[Union[Expression,Projection,MediaProjection],...]
    cases: Tuple[FlowCase,...]
    failure: Optional[str] = None
@dataclass(frozen=True)
class Transport:
    base_url: str
    development: bool = False


def lower_flows(data, base, navigation_ids, collections=(), media_states=(), camera_resources=(), permission_descriptions=(),native_operations=()):
    from .validate import keys, check, identifier, literal
    states={s.name:s.initial.type for s in base.states}
    collection_names={c.name for c in collections}
    def reference(raw, expected=None):
        keys(raw,('ref',),('ref',),'flow reference')
        name=identifier(raw['ref'],'flow reference')
        check(name in states,'Unknown flow state: '+name)
        check(expected is None or states[name]==expected,'Wrong flow reference type: '+name)
        return Reference(name,states[name])
    def expression(raw):
        return reference(raw) if isinstance(raw,dict) else literal(raw,'flow expression')
    def target(name,typ=None):
        identifier(name,'effect target')
        check(name in states and (typ is None or states[name]==typ),'Unknown or wrong type effect target: '+name)
        return name
    raw=data.get('flowActions',[])
    check(isinstance(raw,list) and len(raw)<=512,'flowActions: expected at most512 actions')
    ids=set()
    for action in raw:
        keys(action,('id','function','arguments','cases','failure'),('id','cases'),'flowAction')
        name=identifier(action['id'],'flowAction.id')
        check(name not in ids,'Duplicate flow action: '+name);ids.add(name)
    check(not ids.intersection(navigation_ids),'Flow and navigation identities must be distinct')
    original_ids={a.id for a in base.actions if a.operation!='native'}
    check(not ids.intersection(original_ids),'Flow and scalar action identities must be distinct')
    def flow_ref(name):
        check(isinstance(name,str) and name in ids,'Unknown flow action: '+str(name));return name
    transport=None
    if 'transport' in data:
        t=data['transport'];keys(t,('baseUrl','development'),('baseUrl',),'transport')
        check(type(t.get('development',False)) is bool,'transport.development requires boolean')
        check(isinstance(t['baseUrl'],str),'transport.baseUrl requires string')
        u=urlsplit(t['baseUrl'])
        check(u.scheme in ('https','http') and u.hostname and not u.username and not u.password and not u.query and not u.fragment and u.path in ('','/'),'transport requires an HTTP origin')
        try: u.port
        except ValueError: check(False,'Invalid transport port')
        check(u.scheme=='https' or (t.get('development',False) and u.hostname in ('localhost','127.0.0.1','::1')),'HTTP requires explicit loopback development')
        transport=Transport(t['baseUrl'].rstrip('/'),t.get('development',False))
    request_ids=set();invoke_edges={i:set() for i in ids};result=[]
    for a in raw:
        function=a.get('function');args=[];failure=None
        check(isinstance(a.get('arguments',[]),list),'flow arguments require array')
        for v in a.get('arguments',[]):
            if isinstance(v,dict) and set(v).intersection(('mediaBytes','mediaWidth','mediaHeight','hasMedia')):
                check(len(v)==1,'Media projection requires exactly one operation')
                op=next(iter(v));args.append(MediaProjection(op,media_ref(v[op],media_states)))
            elif isinstance(v,dict) and set(v).intersection(('length','utf8Length','flag')):
                check(len(v)==1,'Projection requires exactly one operation')
                op=next(iter(v));args.append(Projection(op,reference(v[op],ScalarType.BOOL if op=='flag' else ScalarType.STRING)))
            else: args.append(expression(v))
        signature=None
        if function is not None:
            check(base.logic is not None,'flow function requires DC Dart logic')
            signature=next((f for f in base.logic.functions if f.name==function),None)
            check(signature is not None,'Unknown DC Dart flow function')
            check(signature.returns in (ABIType.INT32,ABIType.UINT32),'Flow selector must return int32 or uint32')
            check(len(args)==len(signature.parameters),'Flow function argument count mismatch')
            if ABIType.UTF8 in signature.parameters:
                check('failure' in a,'UTF8 flow function requires failure action')
                failure=flow_ref(a['failure']);invoke_edges[a['id']].add(failure)
            else:check('failure' not in a,'Flow failure requires utf8 input')
            for value,typ in zip(args,signature.parameters):
                check(typ in (ABIType.INT32,ABIType.UINT32,ABIType.BOOL,ABIType.UTF8),'Flow scalar input does not accept native addresses')
                expected=ScalarType.STRING if typ==ABIType.UTF8 else ScalarType.BOOL if typ==ABIType.BOOL else ScalarType.INT
                check(value.type==expected,'Flow function argument type mismatch')
        else:
            check(not args,'Unconditional flow cannot have arguments')
            check('failure' not in a,'Unconditional flow cannot have failure action')
        cases=a['cases'];check(isinstance(cases,list) and 0<len(cases)<=128,'Flow requires1..128 cases')
        codes=set();lowered=[]
        for c in cases:
            keys(c,('code','effects'),('code','effects'),'flow case')
            code=c['code'];check(type(code) is int and -2147483648<=code<=2147483647 and code not in codes,'Duplicate or invalid flow case')
            if signature and signature.returns==ABIType.UINT32:check(code>=0,'Unsigned flow case cannot be negative')
            codes.add(code);effects=c['effects'];check(isinstance(effects,list) and len(effects)<=128,'effects require at most128 entries');out=[]
            for index,e in enumerate(effects):
                check(isinstance(e,dict) and 'op' in e,'effect requires operation');op=e['op']
                if op=='set':
                    keys(e,('op','target','value'),('op','target','value'),'set effect');v=expression(e['value']);out.append(SetEffect(target(e['target'],v.type),v))
                elif op=='logicCall':
                    keys(e,('op','function','arguments','target','success','failure'),('op','function','target','success','failure'),'logic call effect')
                    check(index==len(effects)-1,'Logic call effect must be last')
                    check(base.logic is not None,'Logic call requires DC Dart logic')
                    contract=next((f for f in base.logic.functions if f.name==e['function']),None)
                    check(contract is not None,'Unknown logic call function')
                    check(contract.returns==ABIType.UTF8,'Logic call effect currently requires UTF8 result')
                    raw_arguments=e.get('arguments',[]);check(isinstance(raw_arguments,list),'Logic call arguments require array')
                    values=tuple(expression(v) for v in raw_arguments)
                    scalar={ABIType.UTF8:ScalarType.STRING,ABIType.BOOL:ScalarType.BOOL,ABIType.INT32:ScalarType.INT,ABIType.UINT32:ScalarType.INT}
                    check(contract.returns in scalar and all(t in scalar for t in contract.parameters),'Logic call does not accept native addresses')
                    check(len(values)==len(contract.parameters) and all(v.type==scalar[t] for v,t in zip(values,contract.parameters)),'Logic call argument types differ')
                    for v,t in zip(values,contract.parameters):
                        if t==ABIType.UINT32 and not isinstance(v,Reference):check(v.value>=0,'Unsigned logic argument cannot be negative')
                    success=flow_ref(e['success']);failure=flow_ref(e['failure']);invoke_edges[a['id']].update((success,failure))
                    out.append(LogicCallEffect(contract.name,values,target(e['target'],scalar[contract.returns]),success,failure))
                elif op=='nativeOperation':
                    keys(e,('op','operation','arguments','target','success','failure'),('op','operation','target','success','failure'),'native operation effect')
                    check(index==len(effects)-1,'Native operation effect must be last')
                    contract=next((o for o in native_operations if o.name==e['operation']),None)
                    check(contract is not None,'Unknown native operation')
                    args=e.get('arguments',[]);check(isinstance(args,list),'Native operation arguments require array')
                    values=tuple(expression(v) for v in args)
                    check(len(values)==len(contract.parameters) and all(v.type==p.type for v,p in zip(values,contract.parameters)),'Native operation argument types differ')
                    success=flow_ref(e['success']);failure=flow_ref(e['failure'])
                    invoke_edges[a['id']].update((success,failure))
                    out.append(NativeOperationEffect(contract.name,values,target(e['target'],contract.result),success,failure))
                elif op=='navigate':
                    keys(e,('op','action'),('op','action'),'navigate effect');check(e['action'] in navigation_ids,'Unknown navigation action');out.append(NavigateEffect(e['action']))
                elif op=='invoke':
                    keys(e,('op','action'),('op','action'),'invoke effect');action=flow_ref(e['action']);invoke_edges[a['id']].add(action);out.append(InvokeEffect(action));check(index==len(effects)-1,'Invoke effect must be last')
                elif op in ('permission','cameraFacing','capturePhoto','location'):
                    check(index==len(effects)-1,'Device effect must be last')
                    if op=='permission':
                        keys(e,('op','capability','statusTarget','success','failure'),('op','capability','statusTarget','success','failure'),'permission effect')
                        check(e['capability'] in ('camera','location') and e['capability'] in dict(permission_descriptions),'Permission requires authored camera/location purpose')
                        out.append(PermissionEffect(e['capability'],target(e['statusTarget'],ScalarType.INT),flow_ref(e['success']),flow_ref(e['failure'])))
                    elif op=='location':
                        keys(e,('op','latitudeTarget','longitudeTarget','accuracyTarget','success','cancel','failure','timeoutMs'),('op','latitudeTarget','longitudeTarget','accuracyTarget','success','cancel','failure'),'location effect')
                        check('location' in dict(permission_descriptions),'Location requires authored permission purpose')
                        names=[target(e[k],ScalarType.INT) for k in ('latitudeTarget','longitudeTarget','accuracyTarget')];check(len(set(names))==3,'Location outputs must be distinct')
                        timeout=e.get('timeoutMs',15000);check(type(timeout) is int and 250<=timeout<=60000,'Location timeout requires250..60000ms')
                        out.append(LocationEffect(*names,flow_ref(e['success']),flow_ref(e['cancel']),flow_ref(e['failure']),timeout))
                    else:
                        check(isinstance(e.get('resource'),str) and e['resource'] in {c.id for c in camera_resources},'Unknown camera resource')
                        if op=='cameraFacing':
                            keys(e,('op','resource','facing','success','failure'),('op','resource','facing','success','failure'),'camera facing effect')
                            check(e['facing'] in ('front','back'),'Camera facing requires front/back')
                            out.append(CameraFacingEffect(e['resource'],e['facing'],flow_ref(e['success']),flow_ref(e['failure'])))
                        else:
                            keys(e,('op','resource','target','options','success','cancel','failure'),('op','resource','target','success','cancel','failure'),'capture photo effect')
                            ref=media_ref({'media':e['target']},media_states)
                            out.append(CapturePhotoEffect(e['resource'],ref.name,photo_options(e.get('options',{})),flow_ref(e['success']),flow_ref(e['cancel']),flow_ref(e['failure'])))
                elif op=='clock':
                    keys(e,('op','target','failure'),('op','target','failure'),'clock effect')
                    failure=flow_ref(e['failure']);invoke_edges[a['id']].add(failure)
                    out.append(ClockEffect(target(e['target'],ScalarType.INT),failure))
                elif op=='readCollection':
                    keys(e,('op','collection','key','outputs','success','failure'),('op','collection','key','outputs','success','failure'),'read collection effect')
                    check(index==len(effects)-1,'Read collection effect must be last')
                    collection=next((c for c in collections if c.name==e['collection']),None);check(collection is not None,'Unknown read collection')
                    fields={f.name:f.type for f in collection.fields};key=reference(e['key'],fields[collection.key])
                    check(isinstance(e['outputs'],dict) and e['outputs'],'Read collection requires outputs');outputs=[]
                    for state,field in e['outputs'].items():
                        check(isinstance(field,str) and field in fields,'Unknown selected record field');target(state,fields[field]);outputs.append(ResponseOutput(state,(field,)))
                    success=flow_ref(e['success']);failure=flow_ref(e['failure']);invoke_edges[a['id']].update((success,failure))
                    out.append(ReadCollectionEffect(collection.name,key,tuple(outputs),success,failure))
                elif op=='pickPhoto':
                    keys(e,('op','target','options','success','cancel','failure','source'),('op','target','success','cancel','failure'),'pick photo effect')
                    ref=media_ref({'media':e['target']},media_states)
                    check(e.get('source','library')=='library','Only library photo acquisition is currently supported')
                    check(index==len(effects)-1,'Pick photo effect must be last')
                    out.append(PickPhotoEffect(ref.name,photo_options(e.get('options',{})),flow_ref(e['success']),flow_ref(e['cancel']),flow_ref(e['failure'])))
                elif op=='clearMedia':
                    keys(e,('op','target'),('op','target'),'clear media effect')
                    out.append(ClearMediaEffect(media_ref({'media':e['target']},media_states).name))
                elif op=='clearCollection':
                    keys(e,('op','target'),('op','target'),'clear collection effect')
                    check(isinstance(e['target'],str) and e['target'] in collection_names,'Unknown collection target')
                    out.append(ClearCollectionEffect(e['target']))
                elif op=='cancelRequests':
                    keys(e,('op',),('op',),'cancel effect');out.append(CancelEffect())
                elif op=='secure':
                    keys(e,('op','operation','key','target','failure'),('op','operation','key','target','failure'),'secure effect')
                    check(e['operation'] in ('read','write','delete'),'Unknown secure operation');identifier(e['key'],'secure key')
                    failure=flow_ref(e['failure']);invoke_edges[a['id']].add(failure)
                    out.append(SecureEffect(e['operation'],e['key'],target(e['target'],ScalarType.STRING),failure))
                elif op=='request':
                    keys(e,('op','id','method','path','body','bearer','outputs','success','failure','statusTarget'),('op','id','method','path','success','failure'),'request effect')
                    check(transport is not None,'Request requires transport');check(index==len(effects)-1,'Request effect must be last')
                    rid=identifier(e['id'],'request.id');check(rid not in request_ids,'Request identities must be globally unique');request_ids.add(rid)
                    check(e['method'] in ('GET','POST','PUT','PATCH','DELETE'),'Unsupported HTTP method')
                    path=e['path']
                    def valid_segment(value):
                        return isinstance(value,str) and not any(ord(c)<33 or ord(c)==127 or 0xD800<=ord(c)<=0xDFFF or c=='\\' for c in value) and '#' not in value
                    if isinstance(path,list):
                        check(0<len(path)<=128 and isinstance(path[0],str) and path[0].startswith('/') and not path[0].startswith('//'),'Path template requires origin-relative literal first part')
                        parts=[]
                        for part in path:
                            if isinstance(part,dict):
                                value=reference(part);check(value.type in (ScalarType.STRING,ScalarType.INT),'Path reference requires string/int');parts.append(value)
                            else:
                                check(valid_segment(part),'Invalid literal path segment');parts.append(literal(part,'path'))
                        path=PathTemplate(tuple(parts))
                    else:
                        check(valid_segment(path) and path.startswith('/') and not path.startswith('//'),'Request path must be origin-relative')
                    body=e.get('body',{});check(isinstance(body,dict) and all(isinstance(k,str) and k for k in body),'Request body requires named scalar fields')
                    check(not body or e['method']!='GET','GET body is unsupported')
                    if 'mediaBody' in body:
                        keys(body,('mediaBody',),('mediaBody',),'media body')
                        body_value=MediaBody(media_ref(body['mediaBody'],media_states))
                    else:body_value=tuple((k,expression(v)) for k,v in body.items())
                    output=e.get('outputs',{});check(isinstance(output,dict),'Response outputs require target/path mapping');outputs=[]
                    for name,parts in output.items():
                        mode='replace'
                        if isinstance(parts,dict):
                            keys(parts,('path','mode'),('path','mode'),'collection output')
                            check(name in collection_names,'Response modes require collection target')
                            mode=parts['mode'];check(mode in ('replace','append'),'Unknown collection response mode')
                            parts=parts['path']
                        if name not in collection_names: target(name)
                        check(isinstance(parts,list) and 0<len(parts)<=16 and all(isinstance(p,str) and p for p in parts),'Response projection requires nonempty string path')
                        outputs.append(ResponseOutput(name,tuple(parts),mode))
                    status=target(e['statusTarget'],ScalarType.INT) if 'statusTarget' in e else None
                    check(status not in output,'Status target cannot also be a response output')
                    out.append(RequestEffect(rid,e['method'],path,body_value,reference(e['bearer'],ScalarType.STRING) if 'bearer' in e else None,tuple(outputs),flow_ref(e['success']),flow_ref(e['failure']),status))
                else:check(False,'Unsupported effect: '+str(op))
            lowered.append(FlowCase(code,tuple(out)))
        check(function is not None or codes=={0},'Unconditional flow requires exactly case0')
        result.append(FlowAction(a['id'],function,tuple(args),tuple(lowered),failure))
    active=set();done=set()
    def visit(i):
        check(i not in active,'Synchronous flow cycle: '+i)
        if i in done:return
        active.add(i)
        for dest in invoke_edges[i]:visit(dest)
        active.remove(i);done.add(i)
    for i in ids:visit(i)
    initial=flow_ref(data['initialAction']) if 'initialAction' in data else None
    return tuple(result),transport,initial


def schema_fields():
    """Shape schema complements cross-reference/ABI checks in lower_flows."""
    identifier={'type':'string','pattern':'^[A-Za-z][A-Za-z0-9_]*$'}
    def obj(p,r):return {'type':'object','properties':p,'required':r,'additionalProperties':False}
    ref=obj({'ref':identifier},['ref'])
    scalar={'oneOf':[{'type':'string'},{'type':'boolean'},{'type':'integer','minimum':-2147483648,'maximum':2147483647},ref]}
    effects=[obj({'op':{'const':'set'},'target':identifier,'value':scalar},['op','target','value'])]
    for op in ('navigate','invoke'):effects.append(obj({'op':{'const':op},'action':identifier},['op','action']))
    effects.append(obj({'op':{'const':'logicCall'},'function':identifier,'arguments':{'type':'array','items':scalar},'target':identifier,'success':identifier,'failure':identifier},['op','function','target','success','failure']))
    effects.append(obj({'op':{'const':'nativeOperation'},'operation':identifier,'arguments':{'type':'array','items':scalar},'target':identifier,'success':identifier,'failure':identifier},['op','operation','target','success','failure']))
    effects.append(obj({'op':{'const':'cancelRequests'}},['op']))
    effects.append(obj({'op':{'const':'clearCollection'},'target':identifier},['op','target']))
    effects.append(obj({'op':{'const':'secure'},'operation':{'enum':['read','write','delete']},'key':identifier,'target':identifier,'failure':identifier},['op','operation','key','target','failure']))
    effects.append(obj({'op':{'const':'request'},'id':identifier,'method':{'enum':['GET','POST','PUT','PATCH','DELETE']},'path':{'oneOf':[{'type':'string','pattern':'^/(?!/)'},{'type':'array','minItems':1,'maxItems':128,'items':{'oneOf':[{'type':'string'},ref]}}]},'body':{'type':'object','additionalProperties':scalar},'bearer':ref,'outputs':{'type':'object','additionalProperties':{'oneOf':[{'type':'array','minItems':1,'maxItems':16,'items':{'type':'string','minLength':1}},obj({'path':{'type':'array','minItems':1,'maxItems':16,'items':{'type':'string','minLength':1}},'mode':{'enum':['replace','append']}},['path','mode'])]}},'success':identifier,'failure':identifier,'statusTarget':identifier},['op','id','method','path','success','failure']))
    media=obj({'media':identifier},['media'])
    bounds={'maxEdge':(32,4096),'jpegQuality':(1,100),'maxInputBytes':(1,33554432),'maxOutputBytes':(1,8388608),'maxDecodedPixels':(1,40000000)}
    options=obj({k:{'type':'integer','minimum':v[0],'maximum':v[1]} for k,v in bounds.items()},[])
    effects.extend([
        obj({'op':{'const':'pickPhoto'},'target':identifier,'source':{'const':'library'},'options':options,'success':identifier,'cancel':identifier,'failure':identifier},['op','target','success','cancel','failure']),
        obj({'op':{'const':'clearMedia'},'target':identifier},['op','target']),
        obj({'op':{'const':'clock'},'target':identifier,'failure':identifier},['op','target','failure']),
        obj({'op':{'const':'readCollection'},'collection':identifier,'key':ref,'outputs':{'type':'object','minProperties':1,'additionalProperties':identifier},'success':identifier,'failure':identifier},['op','collection','key','outputs','success','failure'])])
    effects.extend([
        obj({'op':{'const':'permission'},'capability':{'enum':['camera','location']},'statusTarget':identifier,'success':identifier,'failure':identifier},['op','capability','statusTarget','success','failure']),
        obj({'op':{'const':'cameraFacing'},'resource':identifier,'facing':{'enum':['front','back']},'success':identifier,'failure':identifier},['op','resource','facing','success','failure']),
        obj({'op':{'const':'capturePhoto'},'resource':identifier,'target':identifier,'options':options,'success':identifier,'cancel':identifier,'failure':identifier},['op','resource','target','success','cancel','failure']),
        obj({'op':{'const':'location'},'latitudeTarget':identifier,'longitudeTarget':identifier,'accuracyTarget':identifier,'timeoutMs':{'type':'integer','minimum':250,'maximum':60000},'success':identifier,'cancel':identifier,'failure':identifier},['op','latitudeTarget','longitudeTarget','accuracyTarget','success','cancel','failure'])])
    request=next(e for e in effects if e['properties']['op'].get('const')=='request')
    request['properties']['body']={'oneOf':[request['properties']['body'],obj({'mediaBody':media},['mediaBody'])]}
    projections=[obj({op:ref},[op]) for op in ('length','utf8Length','flag')]+[obj({op:media},[op]) for op in ('mediaBytes','mediaWidth','mediaHeight','hasMedia')]
    return {'cameraResources':{'type':'array','maxItems':8,'items':obj({'id':identifier},['id'])},
            'permissionDescriptions':obj({c:{'type':'string','minLength':1,'maxLength':512} for c in ('camera','location')},[]),
            'mapConfig':obj({'androidModule':identifier,'styleUrl':{'type':'string'},'attribution':{'type':'string','minLength':1,'maxLength':2048}},['androidModule','styleUrl','attribution']),
            'media':{'type':'array','maxItems':32,'items':obj({'name':identifier},['name'])},
            'timers':{'type':'array','maxItems':16,'items':obj({'id':identifier,'intervalMs':{'type':'integer','minimum':250,'maximum':3600000},'action':identifier},['id','intervalMs','action'])},
            'transport':obj({'baseUrl':{'type':'string'},'development':{'type':'boolean'}},['baseUrl']),
            'initialAction':identifier,
            'flowActions':{'type':'array','maxItems':512,'items':obj({'id':identifier,'function':identifier,'failure':identifier,'arguments':{'type':'array','items':{'oneOf':[scalar,*projections]}},'cases':{'type':'array','minItems':1,'maxItems':128,'items':obj({'code':{'type':'integer','minimum':-2147483648,'maximum':2147483647},'effects':{'type':'array','maxItems':128,'items':{'oneOf':effects}}},['code','effects'])}},['id','cases'])}}


def lower_timers(raw,flows):
    from .validate import keys,check,identifier
    check(isinstance(raw,list) and len(raw)<=16,'timers require at most16 declarations')
    actions={f.id:f for f in flows};result=[];names=set()
    def inspect(name,seen):
        if name in seen:return
        seen.add(name)
        if actions[name].failure is not None:inspect(actions[name].failure,seen)
        for case in actions[name].cases:
            for effect in case.effects:
                check(isinstance(effect,(ClockEffect,SetEffect,ClearMediaEffect,ClearCollectionEffect,ReadCollectionEffect,InvokeEffect)),'Timer flow contains unsupported UI/network/resource effect')
                if isinstance(effect,InvokeEffect):inspect(effect.action,seen)
                if isinstance(effect,ClockEffect):inspect(effect.failure,seen)
                if isinstance(effect,ReadCollectionEffect):inspect(effect.success,seen);inspect(effect.failure,seen)
    for item in raw:
        keys(item,('id','intervalMs','action'),('id','intervalMs','action'),'timer');name=identifier(item['id'],'timer.id')
        check(name not in names,'Duplicate timer');names.add(name)
        interval=item['intervalMs'];check(type(interval) is int and 250<=interval<=3600000,'Timer interval requires250..3600000 milliseconds')
        check(isinstance(item['action'],str) and item['action'] in actions,'Unknown timer action');inspect(item['action'],set())
        result.append(Timer(name,interval,item['action']))
    return tuple(result)
