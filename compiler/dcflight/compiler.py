import json
from pathlib import Path
from .backends.ios import IOS
from .backends.android import Android
from .backends import Artifact
from .frontends import load
from .registry import Registry
from .sync import synchronize
from .validate import lower, Diagnostic
from .shared_logic import generate_logic

BACKENDS = {'ios': IOS, 'android': Android}


def compile_app(source, output, targets=('ios', 'android'), dry_run=False, registry=None,
                *, evaluate_dart=False, dart='dart', document=None):
    registry = registry or Registry()
    if document is None:
        if evaluate_dart:
            from .evaluated_frontend import load_evaluated
            document = load_evaluated(source, dart)
        else:
            document = load(source)
    app = lower(document, registry)
    if not targets or len(set(targets)) != len(targets):
        raise Diagnostic('Choose one or more distinct targets')
    artifacts = {}
    from .navigation_ir import RoutedApplication
    backends = BACKENDS
    if isinstance(app, RoutedApplication):
        from .backends.ios_routed import IOS as RoutedIOS
        from .backends.android_routed import AndroidRouted
        backends = {'ios': RoutedIOS, 'android': AndroidRouted}
    for target in targets:
        if target not in BACKENDS:
            raise Diagnostic('Unsupported target: ' + target)
        artifacts.update(backends[target]().generate(app, registry))
    operation_evidence=[]
    if getattr(app,'native_operations',()):
        from .native_api import NativeAPI
        from .native_operation import emit_operation
        from .catalog import Catalog
        catalog_path=Path(document['sdkCatalog'])
        if not catalog_path.is_absolute():catalog_path=Path(source).resolve().parent/catalog_path
        operation_inputs=[]
        from .android_deployment_validation import app_context, operation_for_app as android_operation_for_app
        android_context=app_context(app)
        api=NativeAPI(catalog_path,android_deployment=android_context)
        for definition in document['nativeOperations']:
            from .ios_deployment import deployment_target, operation_for_app
            effective_definition=operation_for_app(definition,deployment_target(app)) if 'ios' in targets else definition
            if 'android' in targets:effective_definition=android_operation_for_app(effective_definition,android_context)
            emitted=emit_operation(api,effective_definition,targets=targets)
            selected=[]
            with Catalog(catalog_path) as catalog:
                for platform in ('ios','android'):
                    for step in definition['implementations'][platform]['steps']:
                        if 'project' in step or 'unwrap' in step: continue
                        record=catalog.get(platform,step['id'],step.get('scope'))
                        selected.append({'api':record,'source':catalog.source(platform,record['scope'])})
            operation_inputs.append({'definition':definition,'selected':selected})
            operation_evidence.append({'emitted':emitted,'selected':selected})
            for target in targets:
                result=emitted['targets'][target]
                content=result['source']
                if target=='ios':relative='ios/App/Generated/Operations/'+result['fileName']
                else:
                    relative='android/app/src/main/java/'+app.id.replace('.','/')+'/'+result['fileName']
                    content='package '+app.id+';\n'+content
                artifacts[relative]=Artifact(content)
    if 'android' in targets:
        requirements=[item for evidence in operation_evidence
                      for item in evidence['emitted']['targets']['android'].get('conditionalAvailability',[])]
        requirements.extend(item for evidence in operation_evidence
                            for item in evidence['emitted']['targets']['android'].get('versionAvailability',[])
                            if item.get('status')=='base-version-checked')
        from .android_sdk_guard import gradle_guard, active_guard_hook
        directive="apply from: 'verified-android-sdk.gradle'"
        existing=Path(output)/'android/app/build.gradle'
        if requirements and existing.is_file() and not active_guard_hook(existing.read_text()):
            raise Diagnostic('Conditional Android API requires '+directive+' in user-owned android/app/build.gradle')
        artifacts['android/app/verified-android-sdk.gradle']=Artifact(gradle_guard(requirements))
        build=artifacts['android/app/build.gradle']
        artifacts['android/app/build.gradle']=Artifact(build.content+'\n'+directive+'\n',build.ownership)
    from .modules.generate import generate_modules
    generate_modules(app, source, targets, artifacts)
    modules=json.loads(artifacts['.dcflight/modules.json'].content).get('modules',[]) if '.dcflight/modules.json' in artifacts else []
    for evidence in operation_evidence:
        for target in targets:
            for dependency in evidence['emitted']['targets'][target]['nativeDependencies']:
                if not any(m['module']==dependency for m in modules):
                    raise Diagnostic('Native operation requires an exactly matching declared module lock')
    if set(targets) != set(BACKENDS):
        from .sync import safe_path
        prior_path = safe_path(Path(output).absolute(), '.dcflight/modules.json')
        if prior_path.is_file():
            prior = json.loads(prior_path.read_text())
            current = json.loads(artifacts['.dcflight/modules.json'].content) if '.dcflight/modules.json' in artifacts else {'modules': [], 'nativeLibraries': {}}
            current['modules'].extend(m for m in prior['modules'] if m['module']['platform'] not in targets)
            if 'android' not in targets:
                current['nativeLibraries'].update(prior['nativeLibraries'])
            if current['modules']:
                artifacts['.dcflight/modules.json'] = Artifact(json.dumps(current, indent=2, sort_keys=True) + '\n')
    artifacts.update(generate_logic(app, source, targets))
    # A one-platform rebuild retains evidence for the untouched native project.
    if set(targets) != set(BACKENDS):
        from .sync import safe_path
        prior_path = safe_path(Path(output).absolute(), '.dcflight/logic.json')
        if prior_path.is_file():
            prior = json.loads(prior_path.read_text())
            current = json.loads(artifacts['.dcflight/logic.json'].content) if '.dcflight/logic.json' in artifacts else {'builds': [], 'libraries': {}}
            current['builds'].extend(b for b in prior['builds'] if b['target'].split('-')[0] not in targets)
            current['libraries'].update({p: v for p, v in prior['libraries'].items() if p.split('/')[0] not in targets})
            current['builds'].sort(key=lambda b: b['target'])
            if current['builds'] or current['libraries']:
                artifacts['.dcflight/logic.json'] = Artifact(json.dumps(current, indent=2) + '\n')
    if app.logic and 'ios' in targets:
        existing = Path(output) / 'ios/App.xcodeproj/project.pbxproj'
        if existing.is_file() and 'Native/Logic.xcconfig' not in existing.read_text():
            raise Diagnostic('Existing user-owned Xcode project predates native logic configuration. Use a new output directory or add Native/Logic.xcconfig as the target base configuration.')
    from .native_metadata import finalize_metadata
    finalize_metadata(app,targets,artifacts,output)
    if 'ios' in targets:
        from .ios_deployment import finish as finish_ios_deployment
        finish_ios_deployment(app,artifacts,Path(output).absolute())
    # Escape hatches refer to user-owned native implementations, never injected snippets.
    requirements = []
    for target in targets:
        base = 'ios/App/User/' if target == 'ios' else 'android/app/src/main/java/' + app.id.replace('.', '/') + '/'
        extension = '.swift' if target == 'ios' else '.java'
        if any(a.operation == 'native' for a in app.actions):
            requirements.append(base + 'UserActions' + extension)
        if any(n.capability == 'native' for n in app.nodes()):
            requirements.append(base + 'UserViews' + extension)
    for relative in requirements:
        from .sync import safe_path
        if not safe_path(Path(output).absolute(), relative).is_file():
            raise Diagnostic('Native escape hatch requires user-owned source: ' + relative)
    node_map = {node.id: {'capability': node.capability, 'ios': 'ios/App/Generated/Nodes/n_' + node.id + '.swift',
                          'android': 'android/app/src/main/java/' + app.id.replace('.', '/') + ('/AuthoredApplication.kt#' + node.id if isinstance(app, RoutedApplication) else '/AppScreen.java#n_' + node.id)}
                for node in app.nodes()}
    artifacts['.dcflight/nodes.json'] = Artifact(json.dumps(node_map, indent=2, sort_keys=True) + '\n')
    # Development-side evidence identifies the input used for this generation.
    # Store only hashes: documents may contain private app defaults.
    import hashlib
    from dataclasses import asdict
    from enum import Enum
    def canonical(value):
        return json.dumps(value, sort_keys=True, separators=(',', ':'),
                          default=lambda item: item.value if isinstance(item, Enum) else str(item)).encode('utf-8')
    from .generation_identity import generation_identity
    receipt = {'appId': app.id, 'authoringVersion': document.get('version', 1),
               'generator': generation_identity(registry),
               'documentSha256': hashlib.sha256(canonical(document)).hexdigest(),
               'irSha256': hashlib.sha256(canonical(asdict(app))).hexdigest(),
               'targetsGeneratedThisRun': list(targets), 'nodeCount': len(app.nodes())}
    # Retain each platform's input evidence. A single-target regeneration must
    # not make an older project appear to have been regenerated from new input.
    from .sync import safe_path
    prior_source = safe_path(Path(output).absolute(), '.dcflight/source.json')
    per_target = {}
    operation_emissions = {}
    if prior_source.is_file():
        previous = json.loads(prior_source.read_text())
        if previous.get('appId') == app.id:
            per_target = previous.get('targets', {})
            operation_emissions = previous.get('nativeOperationEmissions', {})
    logic_builds = json.loads(artifacts['.dcflight/logic.json'].content).get('builds', []) if '.dcflight/logic.json' in artifacts else []
    for target in targets:
        inputs = sorted({(build.get('authorSourceSha256', build.get('sourceSha256')), build.get('preludeSha256'))
                         for build in logic_builds if build['target'].split('-')[0] == target}, key=str)
        per_target[target] = {key: receipt[key] for key in ('documentSha256', 'irSha256', 'nodeCount', 'generator')}
        per_target[target]['logicInputs'] = [list(item) for item in inputs]
        if operation_evidence:
            per_target[target]['nativeOperationInputs']=hashlib.sha256(canonical(operation_inputs)).hexdigest()
            operation_emissions[target]=hashlib.sha256(canonical([e['emitted']['targets'][target] for e in operation_evidence])).hexdigest()
        else:operation_emissions.pop(target,None)
    receipt['targets'] = per_target
    if operation_emissions:receipt['nativeOperationEmissions']=operation_emissions
    artifacts['.dcflight/source.json'] = Artifact(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    if 'android' in targets:
        from .android_deployment import finish as finish_android_deployment
        finish_android_deployment(app,artifacts,Path(output).absolute())
    return synchronize(output, artifacts, app.id, dry_run, tuple(t + '/' for t in targets) + ('.dcflight/',))
