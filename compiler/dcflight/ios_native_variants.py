"""Development-time callable identities for multiple Swift forms of one SDK ID."""
from dataclasses import replace
import hashlib
import json
import re

PREFIX = 'swift-v1:'
MAX_VARIANTS = 32
MAX_RECORD_BYTES = 256 * 1024
REQUIRED = 'native variant selection required'

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True, allow_nan=False)

def unique_rows(rows):
    return tuple(json.loads(row) for row in sorted({canonical(row) for row in rows}))

def semantic_bridges(contracts):
    """Call identities retain bridge roles/relations, never capture byte identity."""
    projected = []
    for contract in contracts:
        item = {'module': contract['module']}
        for role in ('reference', 'value', 'alias', 'conformances', 'memberships'):
            rows = []
            for original in contract[role]:
                row = {k: v for k, v in original.items() if k not in ('sourceSHA256', 'symbolSHA256')}
                if 'availability' in row:
                    row['availability'] = list(unique_rows(row['availability']))
                rows.append(row)
            item[role] = list(unique_rows(rows))
        projected.append(item)
    return unique_rows(projected)


def merge_bridges(contracts):
    """Preserve every exact SDK proof row within bounded equal semantic contracts."""
    from .ios_bridge_types import validate_contracts
    groups = {}
    for contract in contracts:
        validate_contracts([contract], {contract['module']})
        key = canonical(semantic_bridges([contract])[0])
        merged = groups.setdefault(key, {'module': contract['module'], **{
            role: [] for role in ('reference', 'value', 'alias', 'conformances', 'memberships')}})
        for role in ('reference', 'value', 'alias', 'conformances', 'memberships'):
            merged[role] = list(unique_rows((*merged[role], *contract[role])))
            if len(merged[role]) > 256:
                raise ValueError('Merged bridge provenance exceeds row bound')
        if len(groups) > 64:
            raise ValueError('Too many bridge contracts for native variant')
        if len(canonical(list(groups.values())).encode()) > MAX_RECORD_BYTES:
            raise ValueError('Merged bridge provenance exceeds byte bound')
    return tuple(groups[key] for key in sorted(groups))


def normalized(api):
    return replace(api, availability=unique_rows(api.availability),
                   required_imports=tuple(sorted(set(api.required_imports))),
                   type_resolutions=unique_rows(api.type_resolutions),
                   bridge_resolutions=merge_bridges(api.bridge_resolutions))

def identity(api):
    record = api.to_dict()
    # These are compiler/proof conclusions or compile context, not the selected
    # SDK declaration. Export must independently replay the exact import context.
    for field in ('emittable', 'unsupportedReasons', 'requiredImports'):
        record.pop(field, None)
    # Source bytes are separately retained and replayed; they are not a call form.
    record['typeResolutions'] = list(unique_rows(
        {key: value for key, value in row.items() if key != 'sourceSHA256'}
        for row in record['typeResolutions']))
    record['availability'] = list(unique_rows(record['availability']))
    if 'bridgeResolutions' in record:
        record['bridgeResolutions'] = list(semantic_bridges(record['bridgeResolutions']))
    for parameter in record['parameters']:
        parameter.pop('name', None)  # Swift call sites use the external label.
    return PREFIX + hashlib.sha256(canonical(record).encode()).hexdigest()

def validate_identity(value):
    if not isinstance(value, str) or not re.fullmatch(r'swift-v1:[0-9a-f]{64}', value):
        raise ValueError('Invalid native variant identity')
    return value

def collect(apis):
    groups = {}
    for raw in apis:
        api = normalized(raw)
        key = identity(api)
        group = groups.setdefault(api.id, {})
        previous = group.get(key)
        if previous is not None:
            # Preserve every resolved source, even when two sources provide the
            # same nominal declaration. Keep a deterministic local parameter name.
            selected = min((previous, api), key=lambda a: canonical(a.to_dict()))
            api = replace(selected, type_resolutions=unique_rows(previous.type_resolutions + api.type_resolutions),
                          required_imports=tuple(sorted(set(previous.required_imports + api.required_imports))),
                          unsupported=tuple(sorted(set(previous.unsupported + api.unsupported))),
                          bridge_resolutions=merge_bridges((*previous.bridge_resolutions, *api.bridge_resolutions)))
        if len(api.type_resolutions)>256 or len(api.required_imports)>32:
            raise ValueError('Native variant provenance exceeds bounded source/import limits')
        group[key] = api
        if len(group) > MAX_VARIANTS:
            raise ValueError('Too many native variants for precise SDK identity')
    return {key: dict(sorted(group.items())) for key, group in groups.items()}

def envelope(precise_id, variants):
    children = [{**api.to_dict(), 'variant': key} for key, api in variants.items()]
    if len(children) == 1:
        return children[0] | {'variant': next(iter(variants))}
    first = children[0]
    record = {key: first[key] for key in ('id', 'name', 'owner', 'path', 'module', 'platform', 'kind')}
    record.update(emittable=False, unsupportedReasons=[REQUIRED], nativeVariants=children)
    if len(canonical(record).encode()) > MAX_RECORD_BYTES:
        raise ValueError('Native variant record exceeds byte bound')
    return record
