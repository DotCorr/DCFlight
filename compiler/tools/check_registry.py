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
        if key in {'native','tabs','tab','camera','inbox','stories','friendMap','account'}:
            continue  # Native symbols require supplied user implementations, tested separately.
        props = {}
        for name, spec in entry['properties'].items():
            props[name] = spec['enum'][0] if 'enum' in spec else ('Fixture' if spec.get('literal') else {'ref': spec['type'] + 'Value'})
        node = dict(id='sample_' + key, type=key, props=props)
        if key == 'scroll': node['children'] = [dict(id='scrollText',type='text',props={'text':'Scrollable'})]
        if entry.get('action'):
            node['action'] = 'increment'
        nodes.append(node)
    return dict(version=1, id='com.dotcorr.catalog', name='Native Catalog', state=states,
                actions=[dict(id='increment', op='increment', target='intValue')],
                root=dict(id='catalog', type='column', props={}, children=nodes))


def social_fixture():
    features=[('camera','camera'),('inbox','chat'),('stories','story'),('friendMap','map'),('account','user')]
    return {'version':1,'id':'com.dotcorr.socialcatalog','name':'Social Catalog',
        'service':{'baseUrl':'https://example.com'},
        'logic':{'source':'logic.dart','prelude':'prelude.dart','functions':[
            {'name':name,'parameters':['uint32']*count,'returns':'uint32'} for name,count in
            [('canSendMessage',2),('canUploadPhoto',1),('remainingStorySeconds',1),('shouldPublishLocation',2)]]},
        'root':{'id':'tabs','type':'tabs','props':{},'children':[
            {'id':feature+'Tab','type':'tab','props':{'title':feature,'icon':icon},'children':[{'id':feature,'type':feature,'props':{}}]} for feature,icon in features]}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fixture-out')
    args = parser.parse_args()
    registry = Registry()
    for data in (fixture(), social_fixture()):
        app = lower(data, registry)
        for cls in BACKENDS.values():
            cls().generate(app, registry)
    expected = json.dumps(registry.schema(), indent=2) + '\n'
    schema_path = Path(__file__).resolve().parents[1] / 'registry/app.schema.json'
    if schema_path.read_text() != expected:
        raise SystemExit('Schema stale: python3 -m dcflight schema > registry/app.schema.json')
    if args.fixture_out:
        Path(args.fixture_out).write_text(json.dumps(fixture(), indent=2) + '\n')
    print(json.dumps({'reviewedMappings': len(registry.entries), 'targets': list(BACKENDS), 'schema': 'current', 'evidence': 'validated contexts and native source generation only; not compilation/execution'}))


if __name__ == '__main__':
    main()
