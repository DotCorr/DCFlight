"""Check mapping templates, regenerate schemas, and construct an all-mappings native fixture."""
import argparse
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.registry import Registry
from dcflight.validate import lower
from dcflight.compiler import BACKENDS


def fixture():
    registry = Registry()
    states = {'stringValue': 'Editable', 'intValue': 5, 'boolValue': True}
    nodes = []
    for key, entry in sorted(registry.entries.items()):
        if key == 'native':
            continue  # Native symbols require supplied user implementations, tested separately.
        props = {}
        for name, spec in entry['properties'].items():
            props[name] = {'ref': spec['type'] + 'Value'}
        node = dict(id='sample_' + key, type=key, props=props)
        if entry.get('action'):
            node['action'] = 'increment'
        nodes.append(node)
    return dict(version=1, id='com.dotcorr.catalog', name='Native Catalog', state=states,
                actions=[dict(id='increment', op='increment', target='intValue')],
                root=dict(id='catalog', type='column', props={}, children=nodes))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fixture-out')
    args = parser.parse_args()
    registry = Registry()
    app = lower(fixture(), registry)
    for cls in BACKENDS.values():
        cls().generate(app, registry)
    expected = json.dumps(registry.schema(), indent=2) + '\n'
    schema_path = Path(__file__).resolve().parents[1] / 'registry/app.schema.json'
    if schema_path.read_text() != expected:
        raise SystemExit('Schema stale: python3 -m dcflight schema > registry/app.schema.json')
    if args.fixture_out:
        Path(args.fixture_out).write_text(json.dumps(fixture(), indent=2) + '\n')
    print(json.dumps({'reviewedMappings': len(registry.entries), 'targets': list(BACKENDS), 'schema': 'current'}))


if __name__ == '__main__':
    main()
