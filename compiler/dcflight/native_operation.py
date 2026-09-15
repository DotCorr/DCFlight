"""Shared scalar contracts backed by reviewed platform-specific SDK sequences.

These are development-time adapters. Native source contains direct SDK calls,
not an operation registry, dispatcher or runtime implementation of this module.
"""
from dataclasses import dataclass
from typing import Tuple
from .ir import ScalarType
from .native_sequence import emit_sequence,validate_sequence_structure

NATIVE_OPERATION_MAX_STRING_BYTES = 8388608


@dataclass(frozen=True)
class OperationParameter:
    name: str
    type: ScalarType


@dataclass(frozen=True)
class OperationContract:
    name: str
    parameters: Tuple[OperationParameter,...]
    result: ScalarType
    throws: bool
    execution: str = "caller"
    suspends: bool = False


_TYPES = {'ios': {ScalarType.STRING:'String',ScalarType.INT:'Int32',ScalarType.BOOL:'Bool'},
          'android': {ScalarType.STRING:'java.lang.String',ScalarType.INT:'int',ScalarType.BOOL:'boolean'}}


def lower_contract(value):
    if not isinstance(value,dict) or set(value)-{'name','parameters','result','throws','implementations','execution','suspends'} or not {'name','result','implementations'}<=set(value):
        raise ValueError('Invalid native operation contract')
    from .platforms.android_api import JavaValue
    from .platforms.ios_api import parse_cli_value
    def name(raw):
        if not isinstance(raw,str) or raw.startswith('dcfLocal'):
            raise ValueError('Invalid native operation identifier')
        JavaValue.reference(raw,'int');parse_cli_value({'ref':raw,'type':'Int32'})
        return raw
    operation=name(value['name'])
    raw=value.get('parameters',[])
    if not isinstance(raw,list) or len(raw)>64:raise ValueError('Expected at most64 operation parameters')
    params=[];names=set()
    for item in raw:
        if not isinstance(item,dict) or set(item)!={'name','type'}:raise ValueError('Invalid operation parameter')
        identity=name(item['name'])
        if identity in names:raise ValueError('Duplicate operation parameter')
        names.add(identity)
        try:typ=ScalarType(item['type'])
        except (ValueError,TypeError):raise ValueError('Unsupported canonical operation parameter type')
        params.append(OperationParameter(identity,typ))
    try:result=ScalarType(value['result'])
    except (ValueError,TypeError):raise ValueError('Unsupported canonical operation result type')
    throws=value.get('throws',False)
    if type(throws) is not bool:raise ValueError('throws must be boolean')
    suspends=value.get('suspends',False)
    if type(suspends) is not bool:raise ValueError('suspends must be boolean')
    execution=value.get('execution','caller')
    if execution not in ('caller','main','worker'):raise ValueError('Operation execution requires caller, main or worker')
    implementations=value['implementations']
    if not isinstance(implementations,dict) or set(implementations)!={'ios','android'}:
        raise ValueError('Shared operation requires both ios and android implementations')
    return OperationContract(operation,tuple(params),result,throws,execution,suspends)


def emit_operation(api,value,*,targets=('ios','android')):
    contract=lower_contract(value)
    if not isinstance(targets,(list,tuple)) or not targets or any(not isinstance(t,str) or t not in ('ios','android') for t in targets) or len(set(targets))!=len(targets):
        raise ValueError('Choose distinct supported native operation targets')
    requested=tuple(targets)
    # The shared contract and implementation envelopes remain required for both
    # platforms; SDK lookup, availability proof and source emission are scoped.
    for platform in ('ios','android'):
        impl=value['implementations'][platform]
        if not isinstance(impl,dict) or set(impl)-{'steps','return','iosVersion','androidSdkSha256','androidMinSdk','androidCompileSdk'} or not {'steps','return'}<=set(impl):
            raise ValueError('Operation implementation requires steps and return')
        if platform=='android' and 'iosVersion' in impl:raise ValueError('iOS version on Android implementation')
        if platform=='ios' and set(impl)&{'androidSdkSha256','androidMinSdk','androidCompileSdk'}:raise ValueError('Android SDK identity on iOS implementation')
        if 'iosVersion' in impl and (not isinstance(impl['iosVersion'],list) or len(impl['iosVersion'])!=2 or any(type(v) is not int or v<0 for v in impl['iosVersion'])):raise ValueError('Invalid iOS operation version')
        if 'androidSdkSha256' in impl:
            import re
            if not isinstance(impl['androidSdkSha256'],str) or not re.fullmatch('[0-9a-f]{64}',impl['androidSdkSha256']):raise ValueError('Invalid Android SDK identity')
        from .android_deployment_validation import levels
        levels(impl)
        names=validate_sequence_structure(platform,[{'name':p.name,'type':_TYPES[platform][p.type]} for p in contract.parameters],impl['steps'],contract.throws)
        returned=impl['return']
        if not isinstance(returned,dict) or set(returned)!={'ref'} or not isinstance(returned['ref'],str):raise ValueError('Operation return must reference a typed binding')
        if returned['ref'] not in names:raise ValueError('Operation return references an unknown binding')
    targets={}
    for platform in requested:
        implementation=value['implementations'][platform]
        if not isinstance(implementation,dict) or set(implementation)-{'steps','return','iosVersion','androidSdkSha256','androidMinSdk','androidCompileSdk'} or not {'steps','return'}<=set(implementation):
            raise ValueError('Operation implementation requires steps and return')
        if platform=='android' and 'iosVersion' in implementation:raise ValueError('iOS version on Android implementation')
        if platform=='ios' and set(implementation)&{'androidSdkSha256','androidMinSdk','androidCompileSdk'}:raise ValueError('Android SDK identity on iOS implementation')
        inputs=[{'name':p.name,'type':_TYPES[platform][p.type]} for p in contract.parameters]
        seq={'platform':platform,'inputs':inputs,'steps':implementation['steps'],'allowThrows':contract.throws}
        if platform=='ios':
            seq['allowThrows']=contract.throws
            seq['allowAsync']=contract.suspends
            if contract.execution=='main':seq['actorContext']='main'
            elif contract.execution=='worker':seq['actorContext']='nonisolated'
            if 'iosVersion' in implementation:seq['iosVersion']=implementation['iosVersion']
        else:
            seq.update({k:implementation[k] for k in ('androidMinSdk','androidCompileSdk') if k in implementation})
            seq['executionContext']=contract.execution if contract.execution in ('main','worker') else 'unknown'
            if 'androidSdkSha256' in implementation:seq['androidSdkSha256']=implementation['androidSdkSha256']
        emitted=emit_sequence(api,seq)
        returned=implementation['return']
        if not isinstance(returned,dict) or set(returned)!={'ref'} or not isinstance(returned['ref'],str):
            raise ValueError('Operation return must reference a typed binding')
        symbols={p['name']:p['type'] for p in inputs+emitted['bindings']}
        expected=_TYPES[platform][contract.result]
        if symbols.get(returned['ref'])!=expected:
            raise ValueError(f'{platform} operation result must be {expected}; implicit coercion is not supported')
        returned_name=next((b['nativeName'] for b in emitted['bindings'] if b['name']==returned['ref']),returned['ref'])
        class_name='NativeOperation_'+contract.name
        if platform=='ios':
            parameters=', '.join('_ `'+p.name+'`: '+_TYPES[platform][p.type] for p in contract.parameters)
            suffix=(' async' if contract.suspends else '')+(' throws' if contract.throws else '')
            declaration='\n'.join('import '+i for i in emitted['imports'])+'\n'
            declaration+=('@MainActor\n' if contract.execution=='main' else '')
            isolation='nonisolated ' if contract.execution=='worker' else ''
            declaration+=f'enum {class_name} {{\n    {isolation}static func invoke({parameters}){suffix} -> {expected} {{\n'
            body=emitted['source']+'\nreturn `'+returned_name+'`'
            extension='swift'
        else:
            parameters=', '.join(_TYPES[platform][p.type]+' '+p.name for p in contract.parameters)
            suffix=' throws Throwable' if contract.throws else ''
            declaration=f'public final class {class_name} {{\n    public static {expected} invoke({parameters}){suffix} {{\n'
            body=emitted['source']+'\nreturn '+returned_name+';'
            extension='java'
        source=declaration+'\n'.join('        '+line for line in body.splitlines())+'\n    }\n}\n'
        targets[platform]={'fileName':class_name+'.'+extension,'source':source,'apiIds':emitted['apiIds'],'apiCalls':emitted['apiCalls'],'nativeDependencies':emitted['nativeDependencies'],
                           'conditionalAvailability':emitted['conditionalAvailability'],
                           'versionAvailability':emitted['versionAvailability'],
                           'invocation':'async' if platform=='ios' and contract.suspends else 'sync'}
    return {'contract':{'name':contract.name,'parameters':[{'name':p.name,'type':p.type.value} for p in contract.parameters],'result':contract.result.value,'throws':contract.throws,'execution':contract.execution,'suspends':contract.suspends},
            'targets':targets,'compilerRuntimeDependency':None,
            'scope':'Scalar native implementations; target invocation metadata records sync or async shape. Standalone callers own scheduling. Routed apps dispatch declared main/worker operations through NativeOperationEffect with authored completion flows.'}


def schema():
    def obj(props,required):return {'type':'object','additionalProperties':False,'properties':props,'required':required}
    name={'type':'string','pattern':'^[A-Za-z_][A-Za-z0-9_]*$'}
    ref=obj({'ref':name},['ref'])
    native_type={'type':'string','minLength':1,'maxLength':4096}
    value={'oneOf':[ref,obj({'literal':{'type':['string','number','boolean','null','array','object']}},['literal']),obj({'null':{'type':'string'}},['null']),obj({'class':native_type},['class']),obj({'array':{'type':'array'},'type':{'type':'string'}},['array','type'])]}
    step=obj({'id':{'type':'string'},'scope':{'type':'string'},'bind':name,'receiver':ref,'arguments':{'type':'array','items':value},'set':value,'constructedType':native_type,'variant':{'type':'string','pattern':'^swift-v1:[0-9a-f]{64}$'},'typeArguments':{'type':'array','minItems':1,'maxItems':32,'items':native_type}},['id'])
    step={'oneOf':[step,obj({'project':obj({'ref':name,'index':{'type':'integer','minimum':0,'maximum':31}},['ref','index']),'bind':name},['project','bind']),
                   obj({'unwrap':ref,'bind':name,'message':{'type':'string','maxLength':4096}},['unwrap','bind','message'])]}
    impl=obj({'steps':{'type':'array','minItems':1,'maxItems':1024,'items':step},'return':ref,'iosVersion':{'type':'array','minItems':2,'maxItems':2,'items':{'type':'integer','minimum':0}},'androidMinSdk':{'type':'integer','minimum':1,'maximum':999},'androidCompileSdk':{'type':'integer','minimum':1,'maximum':999},'androidSdkSha256':{'type':'string','pattern':'^[0-9a-f]{64}$'}},['steps','return'])
    impl['dependentRequired']={'androidMinSdk':['androidCompileSdk'],'androidCompileSdk':['androidMinSdk']}
    return obj({'name':name,'parameters':{'type':'array','maxItems':64,'items':obj({'name':name,'type':{'enum':['string','int','bool']}},['name','type'])},'result':{'enum':['string','int','bool']},'throws':{'type':'boolean'},'suspends':{'type':'boolean'},'execution':{'enum':['caller','main','worker']},'implementations':obj({'ios':impl,'android':impl},['ios','android'])},['name','result','implementations'])
