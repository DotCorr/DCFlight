import json
from pathlib import Path
from .backends.ios import IOS
from .backends.android import Android
from .backends import Artifact
from .frontends import load
from .registry import Registry
from .sync import synchronize
from .validate import lower, Diagnostic

BACKENDS = {'ios': IOS, 'android': Android}


def compile_app(source, output, targets=('ios', 'android'), dry_run=False, registry=None):
    registry = registry or Registry()
    app = lower(load(source), registry)
    if not targets or len(set(targets)) != len(targets):
        raise Diagnostic('Choose one or more distinct targets')
    artifacts = {}
    for target in targets:
        if target not in BACKENDS:
            raise Diagnostic('Unsupported target: ' + target)
        artifacts.update(BACKENDS[target]().generate(app, registry))
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
                          'android': 'android/app/src/main/java/' + app.id.replace('.', '/') + '/AppScreen.java#n_' + node.id}
                for node in app.nodes()}
    artifacts['.dcflight/nodes.json'] = Artifact(json.dumps(node_map, indent=2, sort_keys=True) + '\n')
    return synchronize(output, artifacts, app.id, dry_run, tuple(t + '/' for t in targets) + ('.dcflight/',))
