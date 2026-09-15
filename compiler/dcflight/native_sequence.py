"""Development-time straight-line native calls with checked local dataflow.

This is an explicit platform escape hatch, not shared application logic or a
runtime instruction format. Every call is lowered by the SDK signature emitter.
"""
from __future__ import annotations
from dataclasses import dataclass


@dataclass(frozen=True)
class NativeBinding:
    name: str
    native_type: str
    mutable: bool = False


@dataclass(frozen=True)
class NativeStatement:
    api_id: str | None
    source: str
    binding: NativeBinding | None
    variant: str | None = None


def validate_sequence_structure(platform,inputs,steps,allow_throws=False):
    """SDK-free grammar and local-reference checks shared by all emission paths.

    Native result types, optional/tuple element types and API availability still
    require selected-platform SDK validation; this pass never claims that proof.
    """
    if platform not in ('ios','android'):raise ValueError('Unsupported sequence platform')
    if not isinstance(steps,list) or not 1<=len(steps)<=1024:raise ValueError('Native sequence requires 1..1024 steps')
    if not isinstance(inputs,list) or len(inputs)>256:raise ValueError('Invalid sequence inputs')
    names=set()
    def name(value):
        if not isinstance(value,str) or value.startswith('dcfLocal'):raise ValueError('Invalid or reserved native local name')
        if platform=='ios':
            from .platforms.ios_api import parse_cli_value
            parse_cli_value({'ref':value,'type':'Int32'})
        else:
            from .platforms.android_api import JavaValue
            JavaValue.reference(value,'int')
        return value
    def bind(value):
        name(value)
        if value in names:raise ValueError('Duplicate native binding: '+value)
        names.add(value)
    def literal(value,depth=0,budget=None):
        import math
        if budget is None:budget=[4096]
        budget[0]-=1
        if depth>16 or budget[0]<0:raise ValueError('Native literal exceeds depth16 or4096 nodes')
        if value is None or type(value) in (bool,int):return
        if type(value) is float and math.isfinite(value):return
        if isinstance(value,str):
            if any(0xD800<=ord(c)<=0xDFFF for c in value):raise ValueError('Native literal requires valid Unicode')
            return
        if isinstance(value,list):
            for item in value:literal(item,depth+1,budget)
            return
        if isinstance(value,dict) and all(isinstance(k,str) for k in value):
            for k,v in value.items():literal(k,depth+1,budget);literal(v,depth+1,budget)
            return
        raise ValueError('Invalid native literal')
    def reference(value):
        if not isinstance(value,dict) or set(value)!={'ref'}:raise ValueError('Expected native reference')
        name(value['ref'])
        if value['ref'] not in names:raise ValueError('Unknown or forward native reference: '+value['ref'])
    def value(item):
        if not isinstance(item,dict):raise ValueError('Expected structured native value')
        if 'ref' in item:reference(item);return
        if set(item)=={'literal'}:literal(item['literal']);return
        if platform=='android':
            from .platforms.android_api import JavaValue
            if set(item)=={'array','type'}:
                if not isinstance(item['array'],list) or not isinstance(item['type'],str):raise ValueError('Typed array requires array and type name')
                literal(item['array']);JavaValue.array(item['array'],item['type']);return
            if set(item)=={'class'}:JavaValue.class_literal(item['class']);return
            if set(item)=={'null'}:
                if not isinstance(item['null'],str):raise ValueError('Typed null requires type name')
                JavaValue.null(item['null']);return
        raise ValueError('Unknown native value form')
    for item in inputs:
        if not isinstance(item,dict) or set(item)-{'name','type','mutable'} or not {'name','type'}<=set(item):raise ValueError('Invalid sequence input')
        bind(item['name'])
    for step in steps:
        if not isinstance(step,dict):raise ValueError('Invalid native sequence step')
        if 'project' in step:
            if platform!='ios' or set(step)!={'project','bind'}:raise ValueError('Tuple projection requires iOS, project and bind')
            projection=step['project']
            if not isinstance(projection,dict) or set(projection)!={'ref','index'} or type(projection['index']) is not int or not 0<=projection['index']<=31:raise ValueError('Invalid tuple projection')
            reference({'ref':projection['ref']})
        elif 'unwrap' in step:
            if set(step)!={'unwrap','bind','message'} or not allow_throws:raise ValueError('Native unwrap requires bind, message and explicit throws context')
            reference(step['unwrap'])
            if not isinstance(step['message'],str) or len(step['message'])>4096:raise ValueError('Invalid unwrap message')
            literal(step['message'])
        else:
            if set(step)-{'id','scope','arguments','receiver','set','bind','typeArguments','constructedType','variant'} or not isinstance(step.get('id'),str) or not step['id']:raise ValueError('Invalid native sequence step')
            if 'scope' in step and (not isinstance(step['scope'],str) or not step['scope']):raise ValueError('Invalid native scope')
            if not isinstance(step.get('arguments',[]),list):raise ValueError('arguments must be an array')
            for argument in step.get('arguments',[]):value(argument)
            if 'receiver' in step:reference(step['receiver'])
            if 'set' in step:value(step['set'])
            if 'set' in step and ('bind' in step or step.get('arguments')):raise ValueError('Assignment cannot bind or accept arguments')
            if 'variant' in step:
                from .ios_native_variants import validate_identity
                if platform != 'ios': raise ValueError('Native Swift variant is supported only for iOS')
                validate_identity(step['variant'])
            if platform=='ios' and ('typeArguments' in step or 'constructedType' in step):raise ValueError('Explicit type arguments/constructedType require Android')
            if 'typeArguments' in step and (not isinstance(step['typeArguments'],list) or not 1<=len(step['typeArguments'])<=32 or any(not isinstance(t,str) or not t for t in step['typeArguments'])):raise ValueError('Invalid native type arguments')
            if 'typeArguments' in step or 'constructedType' in step:
                from .platforms.android_api import _type,_safe_type,_PRIMITIVES,_concrete_owner_type
                for argument in step.get('typeArguments',[]):
                    typ=_type(argument)
                    if not _safe_type(typ) or typ in _PRIMITIVES:raise ValueError('Type arguments must be reference types')
                if 'constructedType' in step:
                    raw=step['constructedType']
                    if not isinstance(raw,str):raise ValueError('Invalid constructed type')
                    typ=_type(raw)
                    if not _concrete_owner_type(typ):raise ValueError('Constructed type requires a concrete class type')
        if 'bind' in step:bind(step['bind'])
    return frozenset(names)


def emit_sequence(api, request):
    if not isinstance(request, dict) or set(request) - {'platform','inputs','steps','iosVersion','allowAsync','allowThrows','actorContext','executionContext','androidSdkSha256','androidMinSdk','androidCompileSdk'}:
        raise ValueError('Unknown native sequence fields')
    platform = request.get('platform')
    if platform not in ('ios','android'):
        raise ValueError('Native sequence requires ios or android')
    steps = request.get('steps')
    inputs = request.get('inputs', [])
    if not isinstance(steps,list) or not 1 <= len(steps) <= 1024:
        raise ValueError('Native sequence requires 1..1024 steps')
    if not isinstance(inputs,list) or len(inputs)>256:
        raise ValueError('Native sequence inputs must be an array of at most 256 bindings')
    options = {k:v for k,v in request.items() if k in ('iosVersion','allowAsync','allowThrows','actorContext')}
    allows_throws = request.get('allowThrows', False)
    if type(allows_throws) is not bool: raise ValueError('allowThrows must be boolean')
    if platform == 'android':
        from .android_deployment_validation import levels
        levels(request)
        options.pop('allowThrows', None)
        if options: raise ValueError('iOS options do not apply to Android')
        options.update({k:request[k] for k in ('androidMinSdk','androidCompileSdk') if k in request})
        if 'executionContext' in request: options['executionContext']=request['executionContext']
        if 'androidSdkSha256' in request: options['androidSdkSha256']=request['androidSdkSha256']
    elif 'executionContext' in request:
        raise ValueError('Use actorContext for iOS execution requirements')
    if platform=='ios' and set(request)&{'androidSdkSha256','androidMinSdk','androidCompileSdk'}:raise ValueError('Android SDK identity on iOS sequence')
    validate_sequence_structure(platform,inputs,steps,allows_throws)
    conditional_availability=[]
    version_availability=[]
    symbols = {}
    native_names = {}
    escaping_inputs = set()

    def binding(name, native_type, mutable=False):
        if not isinstance(native_type,str) or type(mutable) is not bool:
            raise ValueError('Native binding type must be a string and mutable must be boolean')
        if not isinstance(name,str) or name.startswith('dcfLocal'):
            raise ValueError('Invalid or reserved native local name')
        if platform=='android':
            from .platforms.android_api import JavaValue
            JavaValue.reference(name,native_type)
            if mutable: raise ValueError('Android inputs do not accept mutable metadata')
        else:
            from .platforms.ios_api import parse_cli_value
            parse_cli_value({'ref':name,'type':native_type,'mutable':mutable})
        if name in symbols: raise ValueError('Duplicate native binding: '+name)
        return NativeBinding(name,native_type,mutable)

    for item in inputs:
        if not isinstance(item,dict) or set(item)-{'name','type','mutable'} or not {'name','type'}<=set(item):
            raise ValueError('Native input requires name and type')
        b=binding(item['name'],item['type'],item.get('mutable',False))
        symbols[b.name]=b

    def resolve(value):
        if not isinstance(value,dict): raise ValueError('Expected a structured native value')
        if 'ref' not in value: return value
        if set(value)!={'ref'}: raise ValueError('Sequence references infer their type; supply only ref')
        name=value['ref']
        if not isinstance(name,str) or name not in symbols:
            raise ValueError('Unknown or forward native reference: '+str(name))
        b=symbols[name]
        result={'ref':native_names.get(b.name,b.name),'type':b.native_type}
        if platform=='ios': result['mutable']=b.mutable
        return result

    statements=[]; imports=set(); dependencies=[]
    for index,step in enumerate(steps):
        if isinstance(step, dict) and 'unwrap' in step:
            if set(step) != {'unwrap','bind','message'} or not allows_throws:
                raise ValueError('Native unwrap requires bind, message and explicit throws context')
            if not isinstance(step['unwrap'], dict) or set(step['unwrap']) != {'ref'}:
                raise ValueError('Optional unwrap requires a reference')
            message = step['message']
            if not isinstance(message, str) or len(message) > 4096:
                raise ValueError('Unwrap failure message must be a string of at most 4096 characters')
            if any(0xD800 <= ord(char) <= 0xDFFF for char in message):
                raise ValueError('Unwrap message requires valid Unicode')
            selected = resolve(step['unwrap'])
            if platform == 'ios':
                if any(item['name'] == 'Foundation' for item in inputs):
                    raise ValueError('Native input shadows Foundation required by unwrap failure')
                from .platforms.swift_types import parse_type, spelling, optional_inner, is_optional
                from .platforms.ios_api import _argument, Literal
                typ = parse_type(selected['type'])
                inner = optional_inner(typ)
                if inner is None: raise ValueError('Unwrap requires an optional native type')
                native_type = spelling(inner)
                b = binding(step['bind'], native_type, True)
                error_text = _argument(Literal(message), 'String')
                expression = f'guard var `dcfLocal{index}` = `{selected["ref"]}` else {{ throw Foundation.NSError(domain: "NativeValue", code: 1, userInfo: [Foundation.NSLocalizedDescriptionKey: {error_text}]) }}'
                imports.add('Foundation')
            else:
                from .platforms.android_api import JavaValue, _PRIMITIVES
                native_type = selected['type']
                if native_type in _PRIMITIVES: raise ValueError('Android unwrap requires a reference type')
                b = binding(step['bind'], native_type)
                error_text = JavaValue.literal(message).source()
                expression = f'final {native_type} dcfLocal{index} = {selected["ref"]};\nif (dcfLocal{index} == null) throw new java.lang.IllegalStateException({error_text});'
            statements.append(NativeStatement(None, expression, b))
            symbols[b.name] = b; native_names[b.name] = f'dcfLocal{index}'
            continue
        if isinstance(step, dict) and 'project' in step:
            if platform != 'ios' or set(step) != {'project','bind'}:
                raise ValueError('Tuple projection requires iOS, project and bind')
            project = step['project']
            if not isinstance(project, dict) or set(project) != {'ref','index'} or type(project['index']) is not int:
                raise ValueError('Tuple projection requires a reference and integer index')
            selected = resolve({'ref': project['ref']})
            from .platforms.swift_types import parse_type, spelling, optional_inner, is_optional
            typ = parse_type(selected['type'])
            position = project['index']
            if typ.name != '$tuple' or is_optional(typ) or not 0 <= position < len(typ.arguments):
                raise ValueError('Projection requires an in-range nonoptional tuple element')
            native_type = spelling(typ.arguments[position])
            b = binding(step['bind'], native_type, True)
            expression = f'var `dcfLocal{index}`: {native_type} = `{selected["ref"]}`.{position}'
            statements.append(NativeStatement(None, expression, b))
            symbols[b.name] = b; native_names[b.name] = f'dcfLocal{index}'
            continue
        if not isinstance(step,dict) or set(step)-{'id','scope','arguments','receiver','set','bind','typeArguments','constructedType','variant'} or 'id' not in step:
            raise ValueError('Invalid native sequence step')
        call={**options,'platform':platform,**{k:v for k,v in step.items() if k in ('id','scope','typeArguments','constructedType','variant')}}
        if 'arguments' in step:
            if not isinstance(step['arguments'],list): raise ValueError('arguments must be an array')
            call['arguments']=[resolve(v) for v in step['arguments']]
        for name in ('receiver','set'):
            if name in step: call[name]=resolve(step[name])
        # External input names exist in the native scope. Reject a collision
        # with a referenced type/module; generated local names are hygienic.
        from .catalog import Catalog
        with Catalog(api.catalog_path) as catalog:
            descriptor=catalog.get(platform,step['id'],step.get('scope'))['api']
        if platform == 'ios' and ('nativeVariants' in descriptor or 'variant' in step):
            from .platforms.ios_api import SDKCatalog
            from .ios_native_variants import validate_identity
            if 'variant' in step: validate_identity(step['variant'])
            descriptor=SDKCatalog.from_records([descriptor]).get(step['id'],step.get('variant')).to_dict()
        reserved={descriptor.get('owner','').split('.')[0],descriptor.get('module','').split('.')[0]}
        if any(item['name'] in reserved for item in inputs):
            raise ValueError('Native input shadows a referenced SDK type or module')
        emitted=api.emit(call)
        if 'versionAvailability' in emitted:version_availability.append(emitted['versionAvailability'])
        conditional=emitted.get('conditionalAvailability')
        if conditional is not None:
            if not allows_throws:raise ValueError('Conditional flagged API requires an authored throwing/failure contract')
            conditional_availability.append(conditional)
        if platform == 'ios' and 'set' not in step:
            # The block does not own its caller's parameter declarations. Expose
            # required retention annotations so a typed callback input can be
            # forwarded without silently losing its SDK contract.
            for argument,parameter in zip(step.get('arguments',[]),descriptor.get('parameters',[])):
                if parameter.get('escaping',False) and set(argument)=={'ref'}:
                    name=argument['ref']
                    if name not in native_names:
                        escaping_inputs.add(name)
        native_type=emitted['resultType']
        b=None
        if 'bind' in step:
            if native_type in ('void','Void','()') or 'set' in step:
                raise ValueError('Cannot bind a void call or assignment')
            b=binding(step['bind'],native_type,platform=='ios')
        expression=emitted['source']
        if platform=='android':
            if conditional is not None:
                declaration=f'{native_type} dcfLocal{index};\n' if b or native_type!='void' and 'set' not in step else ''
                assignment=f'dcfLocal{index} = ' if declaration else ''
                expression=declaration+'try { '+assignment+expression+'; } catch (java.lang.LinkageError dcfUnavailable'+str(index)+') { throw new java.lang.IllegalStateException("Conditional Android API unavailable", dcfUnavailable'+str(index)+'); }'
            elif b: expression=f'{native_type} dcfLocal{index} = {expression};'
            elif native_type not in ('void','Void','()') and 'set' not in step:
                # A field read is not a Java statement expression. Materialize
                # every unused result so evaluation happens exactly once.
                expression=f'{native_type} dcfLocal{index} = {expression};'
            else: expression+=';'
        else:
            if b: expression=f'var `dcfLocal{index}`: {native_type} = {expression}'
            elif native_type not in ('void','Void','()'): expression='_ = '+expression
        statements.append(NativeStatement(step['id'],expression,b,emitted.get('variant')))
        if b:
            symbols[b.name]=b
            native_names[b.name]=f'dcfLocal{index}'
        imports.update(emitted['imports'])
        dependency=emitted.get('runtimeDependency')
        if dependency is not None and dependency not in dependencies: dependencies.append(dependency)
    return {'platform':platform,'language':'java' if platform=='android' else 'swift',
            'source':'\n'.join(s.source for s in statements), 'imports':sorted(imports),
            'bindings':[{'name':s.binding.name,'type':s.binding.native_type,'nativeName':native_names[s.binding.name]} for s in statements if s.binding],
            'apiIds':[s.api_id for s in statements if s.api_id is not None],
            'apiCalls':[{'id':s.api_id,**({'variant':s.variant} if s.variant else {})} for s in statements if s.api_id is not None], 'nativeDependencies':dependencies,
            'compilerRuntimeDependency':None,
            'conditionalAvailability':conditional_availability,
            'versionAvailability':version_availability,
            'inputContracts':[{'name':item['name'],'type':item['type'],
                               **({'escaping':item['name'] in escaping_inputs} if platform=='ios' else {})}
                              for item in inputs],
            'scope':'Native block body; caller supplies declared inputs, native context, lifecycle and error handling. No execution or shared-flow integration implied.'}
