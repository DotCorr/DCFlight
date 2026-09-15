"""Shared authoring shape for compile-time typed UI conditions.

State types and collection scope are checked by lowering, not JSON Schema.
These definitions deliberately do not widen scalar properties or action values.
"""

CONDITION_REF = {'$ref': '#/$defs/condition'}


def definitions(*, fields=False):
    identifier = {'type': 'string', 'pattern': '^[A-Za-z][A-Za-z0-9_]*$'}

    def obj(name, value):
        return {'type': 'object', 'properties': {name: value},
                'required': [name], 'additionalProperties': False}

    references = [obj('ref', identifier)]
    if fields:
        references.append(obj('field', {
            'type': 'object', 'properties': {'collection': identifier, 'name': identifier},
            'required': ['collection', 'name'], 'additionalProperties': False}))
    conditions = [{'type': 'boolean'}, *references,
                  obj('isEmpty', {'$ref': '#/$defs/conditionString'}),
                  obj('not', CONDITION_REF)]
    for name in ('all', 'any'):
        conditions.append(obj(name, {'type': 'array', 'minItems': 1,
                                    'maxItems': 32, 'items': CONDITION_REF}))
    return {'condition': {'oneOf': conditions},
            'conditionString': {'oneOf': [{'type': 'string'}, *references]}}
