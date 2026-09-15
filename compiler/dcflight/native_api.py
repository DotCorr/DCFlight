"""One development-time interface for typed platform calls from the SDK catalog."""
import hashlib
import json
import os
from pathlib import Path
from .catalog import Catalog


class NativeAPI:
    def __init__(self, catalog, *, android_sdk=None, javac=None, android_deployment=None):
        self.catalog_path = Path(catalog)
        self.android_cache = {}
        self.ios_invocation_cache = set()
        self.android_sdk = android_sdk
        self.javac = javac
        self.android_deployment = android_deployment
        self.android_version_cache = {}

    def emit(self, request):
        if not isinstance(request, dict):
            raise ValueError('Native invocation must be an object')
        allowed = {'platform','scope','id','arguments','receiver','iosVersion','sdkEnvironment','allowAsync','allowThrows','set','actorContext','typeArguments','constructedType','executionContext','androidSdkSha256','androidMinSdk','androidCompileSdk','variant'}
        if set(request) - allowed or not {'platform','id'} <= set(request):
            raise ValueError('Unknown or missing native invocation fields')
        platform = request['platform']
        if 'variant' in request:
            if platform != 'ios':
                raise ValueError('Native Swift variant is supported only for iOS')
            from .ios_native_variants import validate_identity
            validate_identity(request['variant'])
        with Catalog(self.catalog_path) as catalog:
            found = catalog.get(platform, request['id'], request.get('scope'))
        descriptor = found['api']
        selected_variant = None
        if platform == 'ios' and ('nativeVariants' in descriptor or 'variant' in request):
            from .platforms.ios_api import SDKCatalog
            from .ios_native_variants import identity
            variants = SDKCatalog.from_records([descriptor])
            selected = variants.get(request['id'], request.get('variant'))
            selected_variant = identity(selected)
            if 'nativeVariants' in descriptor:
                descriptor = next(child for child in descriptor['nativeVariants'] if child['variant'] == selected_variant)
        elif platform != 'ios' and 'variant' in request:
            raise ValueError('Native Swift variant is supported only for iOS')
        if platform == 'ios' and 'nativeInvocationEvidence' in descriptor:
            from .ios_invocation_evidence import select_invocation
            descriptor = select_invocation(descriptor, request, self.ios_invocation_cache)
        reasons = descriptor.get('unsupportedReasons', [])
        can_specialize = (platform == 'android' and ('typeArguments' in request or 'receiver' in request or 'constructedType' in request) and reasons
                          and all(isinstance(r, str) and (r.startswith('generic or unsupported type: ')
                              or (r == 'generic constructor type parameters are unsupported' and 'typeArguments' in request)) for r in reasons))
        can_specialize = can_specialize or (platform == 'ios' and 'receiver' in request and reasons == ['generic owner requires explicit specialization'] and bool(descriptor.get('ownerParameters')) and descriptor.get('nativeConformance',{}).get('status') not in ('rejected','skipped'))
        if not descriptor.get('emittable', False) and not can_specialize:
            raise ValueError('Unsupported API: ' + '; '.join(descriptor.get('unsupportedReasons', [])))
        args = request.get('arguments', [])
        if not isinstance(args, list):
            raise ValueError('arguments must be an array')
        if platform == 'ios':
            if set(request) & {'androidSdkSha256','androidMinSdk','androidCompileSdk'}: raise ValueError('Android SDK identity on iOS invocation')
            if 'executionContext' in request: raise ValueError('Use actorContext for iOS execution requirements')
            if 'typeArguments' in request: raise ValueError('Explicit type arguments are not supported for iOS')
            if 'constructedType' in request: raise ValueError('constructedType is supported only for Android constructors')
            from .platforms.ios_api import SDKCatalog, parse_cli_value
            api = SDKCatalog.from_records([descriptor])
            receiver = parse_cli_value(request['receiver']) if 'receiver' in request else None
            from .ios_sdk_environment import environment
            sdk_environment=environment(request.get('sdkEnvironment','iphonesimulator'))
            native_environment=descriptor.get('nativeConformance',{}).get('sdkEnvironment','iphonesimulator') if 'nativeConformance' in descriptor else None
            if native_environment is not None and native_environment!=sdk_environment:raise ValueError('SDK descriptor environment differs from request')
            version = request.get('iosVersion', [18, 0])
            if not isinstance(version,list) or len(version) != 2 or any(type(v) is not int or v < 0 for v in version):
                raise ValueError('iosVersion requires [major, minor]')
            for name in ('allowAsync','allowThrows'):
                if name in request and type(request[name]) is not bool:
                    raise ValueError(name + ' must be boolean')
            if 'set' in request:
                if args:
                    raise ValueError('Property assignment does not accept arguments')
                emitted = api.emit_set(request['id'], parse_cli_value(request['set']), receiver=receiver, ios_version=tuple(version),actor_context=request.get('actorContext'))
            else:
                emitted = api.emit_call(request['id'], [parse_cli_value(a) for a in args], receiver=receiver,
                    ios_version=tuple(version), allow_async=request.get('allowAsync',False), allow_throws=request.get('allowThrows',False),actor_context=request.get('actorContext'))
            return {'platform':platform,'id':request['id'],'language':'swift','source':emitted.expression,
                    'resultType':emitted.result_type,'imports':list(emitted.imports),'runtimeDependency':None,'actorIsolation':descriptor.get('actorIsolation','unknown'),**({'variant':selected_variant} if selected_variant else {})}
        if platform == 'android':
            if 'executionContext' in request and request['executionContext'] not in ('unknown','main','worker'):
                raise ValueError('Execution context requires unknown, main or worker')
            if set(request) & {'iosVersion','sdkEnvironment','allowAsync','allowThrows','actorContext'}:
                raise ValueError('Unsupported Android invocation fields')
            from .platforms.android_api import AndroidAPI, JavaValue
            from .android_deployment_validation import select_context, check
            version_context=select_context(request,self.android_deployment)
            with Catalog(self.catalog_path) as catalog:
                source = catalog.source(platform, found['scope'])
            provenance = source['provenance']
            if 'sourceRelativePath' in provenance:
                root = self.catalog_path.resolve().parent
                path = (root / provenance['sourceRelativePath']).resolve()
                try:
                    path.relative_to(root)
                except ValueError:
                    raise ValueError('SDK snapshot escapes catalog directory')
            else:
                path = Path(provenance['sourcePath'])
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != provenance['sourceSha256']:
                raise ValueError('Android SDK source changed; reindex it before emitting calls')
            certificate = provenance.get('flaggedAvailability')
            certificate_hash = None
            if certificate is not None:
                from .android_availability import report_digest,report_member_ids
                if (not isinstance(certificate,dict) or set(certificate)!={'report','sha256'}
                        or report_digest(certificate['report']) != certificate['sha256']):
                    raise ValueError('Android availability certificate changed')
                available_ids=report_member_ids(certificate['report'])
                certificate_hash = certificate['sha256']
                from .ios_verification import compiler_sources
                if certificate['report'].get('compilerSources') != compiler_sources():
                    raise ValueError('Android availability certificate requires current compiler evidence')
            conditional = certificate is not None and request['id'] in available_ids
            if conditional and request.get('androidSdkSha256') != certificate['report']['sdkSha256']:
                raise ValueError('Conditional flagged API requires its exact verified Android SDK identity')
            sdk_bytes=None
            compiler=self.javac or (str(Path(os.environ['JAVA_HOME'])/'bin/javac') if os.environ.get('JAVA_HOME') else None)
            if conditional:
                location=self.android_sdk or os.environ.get('DCFLIGHT_ANDROID_SDK_JAR') or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
                if not location:raise ValueError('Conditional APIs require a configured Android SDK for native revalidation')
                sdk=Path(location)
                if sdk.is_dir():sdk=sdk/'platforms'/('android-'+source['sdk'])/'android.jar'
                sdk_bytes=sdk.read_bytes()
                if hashlib.sha256(sdk_bytes).hexdigest()!=certificate['report']['sdkSha256']:
                    raise ValueError('Availability SDK hash mismatch')
            key = (str(path),digest,certificate_hash if conditional else None)
            if key not in self.android_cache:
                parsed = AndroidAPI.from_file(path, api_level=int(source['sdk']))
                if conditional:
                    from .android_availability import revalidate_report
                    parsed = revalidate_report(certificate['report'],parsed,sdk_bytes,javac=compiler)
                self.android_cache[key] = parsed
            conditional = certificate is not None and request['id'] in {r['id'] for r in certificate['report']['members'] if r['compiled']}
            if conditional:
                if (certificate is None or request.get('androidSdkSha256') != certificate['report']['sdkSha256']
                        or request['id'] not in available_ids):
                    raise ValueError('Conditional flagged API requires its exact verified Android SDK identity')
            elif 'androidSdkSha256' in request:
                import re
                if not isinstance(request['androidSdkSha256'],str) or not re.fullmatch('[0-9a-f]{64}',request['androidSdkSha256']):
                    raise ValueError('Invalid Android SDK identity')
            def value(data, expected=None):
                if not isinstance(data,dict):
                    raise ValueError('Expected typed native value')
                if set(data)=={'array','type'}:
                    return JavaValue.array(data['array'],data['type'])
                if set(data)=={'class'}:
                    return JavaValue.class_literal(data['class'])
                if set(data)=={'literal'}:
                    if type(data['literal']) is list:
                        if expected is None: raise ValueError('Array literal needs a declared SDK parameter type')
                        return JavaValue.array(data['literal'],expected)
                    if expected in ('boolean','byte','short','int','long','float','double','char'):
                        return JavaValue.typed_literal(data['literal'], expected)
                    return JavaValue.literal(data['literal'])
                if set(data)=={'ref','type'}:
                    return JavaValue.reference(data['ref'],data['type'])
                if set(data)=={'null'}:
                    return JavaValue.null(data['null'])
                raise ValueError('Use a literal, class literal, typed reference or typed null; raw source is not accepted')
            receiver = value(request['receiver']) if 'receiver' in request else None
            if 'typeArguments' in request and not isinstance(request['typeArguments'], list):
                raise ValueError('Type arguments must be an array')
            if 'typeArguments' in request and 'set' in request:
                raise ValueError('Field assignment does not accept type arguments')
            if 'constructedType' in request:
                if not isinstance(request['constructedType'], str):
                    raise ValueError('constructedType must be a native type string')
                if 'set' in request or receiver is not None:
                    raise ValueError('constructedType does not accept a receiver or field assignment')
            member = self.android_cache[key].resolve_member(
                request['id'], receiver_type=receiver.java_type if receiver else None,
                type_arguments=request.get('typeArguments'), constructed_type=request.get('constructedType'))
            version_evidence=check(self.catalog_path,source,descriptor,self.android_cache[key].members[request['id']],version_context,self.android_version_cache)
            if version_evidence and version_evidence.get('sdkSha256') and request.get('androidSdkSha256',version_evidence['sdkSha256'])!=version_evidence['sdkSha256']:
                raise ValueError('Conflicting Android SDK identities')
            self.android_cache[key].check_thread(member, request.get('executionContext'))
            if 'set' in request:
                if args:
                    raise ValueError('Field assignment does not accept arguments')
                emitted = self.android_cache[key].emit_set(request['id'], value(request['set'],member.java_type), receiver,execution_context=request.get('executionContext'))
            else:
                if len(args) != len(member.parameters): raise ValueError('Argument count mismatch')
                emitted = self.android_cache[key].emit(request['id'],[value(a,p.java_type) for a,p in zip(args,member.parameters)],receiver,type_arguments=request.get('typeArguments'),constructed_type=request.get('constructedType'),execution_context=request.get('executionContext'))
            return {'platform':platform,'id':request['id'],'language':'java','source':emitted.source,
                    'resultType':emitted.java_type,'imports':[],'runtimeDependency':provenance.get('nativeModule'),
                    **({'versionAvailability':version_evidence} if version_evidence is not None else {}),
                    'compilerRuntimeDependency':None,'threadRequirement':self.android_cache[key].thread_requirement(member),
                    **({'conditionalAvailability':{'sdkSha256':certificate['report']['sdkSha256'],
                         'apiLevel':int(source['sdk']),'runtimeSupported':None,'minimumApi':None,
                         'failure':'LinkageError must reach authored failure handling'}} if conditional else {})}
        raise ValueError('Native call emission not implemented for ' + str(platform))


def index_android(database, source, sdk=35):
    from .platforms.android_api import AndroidAPI
    source = Path(source).resolve()
    api = AndroidAPI.from_file(source, api_level=sdk)
    snapshot = snapshot_android_source(database, source)
    with Catalog(database,write=True) as catalog:
        result = catalog.import_records('android','framework',str(sdk),api.records(),
            {**snapshot,'parser':'metalava','statistics':api.stats()})
    return result


def index_ios_sweep(database, sweep):
    root = Path(sweep).resolve()
    provenance = json.loads((root/'provenance.json').read_text())
    results = []
    with Catalog(database,write=True) as catalog:
        for path in sorted(root.glob('*/status.json')):
            status = json.loads(path.read_text())
            if status['status'] != 'success':
                continue
            records = path.parent/'records.jsonl'
            source = {**provenance,'module':status['module'],'recordsSha256':hashlib.sha256(records.read_bytes()).hexdigest(),
                      'recordsPath':str(records),'extraction':status['extraction']}
            with records.open() as stream:
                results.append(catalog.import_records('ios',status['module'],provenance['sdkVersion'],
                    (json.loads(line) for line in stream if line.strip()), source))
    return {'indexedModules':len(results),'modules':results}


def snapshot_android_source(database, source):
    """Store an immutable content-addressed SDK input alongside its portable catalog."""
    source = Path(source).resolve()
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    database = Path(database).resolve()
    folder = database.parent / (database.name + '.sources')
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / ('android-' + digest + '.txt')
    if path.is_symlink():
        raise ValueError('SDK snapshot must not be a symlink')
    try:
        with path.open('xb') as stream:
            stream.write(data)
    except FileExistsError:
        if path.read_bytes() != data:
            raise ValueError('Existing SDK snapshot hash mismatch')
    return {'sourcePath': str(source), 'sourceRelativePath': str(path.relative_to(database.parent)), 'sourceSha256': digest}
