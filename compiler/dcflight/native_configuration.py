"""Typed, development-only native project configuration and XML/plist lowering."""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime
import base64
import binascii
import math
import re
from typing import Literal, Union
import xml.etree.ElementTree as ET


ANDROID_NAMESPACE = 'http://schemas.android.com/apk/res/android'
TOOLS_NAMESPACE = 'http://schemas.android.com/tools'
NAMESPACES = {'android': ANDROID_NAMESPACE, 'tools': TOOLS_NAMESPACE}
DEFAULT_NAMESPACES = tuple(sorted(NAMESPACES.items()))
MAX_DEPTH = 32
MAX_NODES = 10000
MAX_STRING_BYTES = 1048576
NAME = r'[A-Za-z_][A-Za-z0-9_.-]*'


@dataclass(frozen=True)
class PlistValue:
    type: Literal['string', 'integer', 'real', 'boolean', 'data', 'date', 'array', 'dictionary']
    value: Union[str, int, float, bool, tuple[PlistValue, ...], tuple[tuple[str, PlistValue], ...]]


@dataclass(frozen=True)
class ManifestElement:
    tag: str
    attributes: tuple[tuple[str, str], ...] = ()
    children: tuple[ManifestElement, ...] = ()


@dataclass(frozen=True)
class NativeConfiguration:
    ios_info_plist: tuple[tuple[str, PlistValue], ...] = ()
    ios_entitlements: tuple[tuple[str, PlistValue], ...] = ()
    android_manifest: ManifestElement | None = None
    android_source_sets: tuple[str, ...] = ('debug', 'release')
    android_namespaces: tuple[tuple[str, str], ...] = DEFAULT_NAMESPACES
    ios_deployment_target: tuple[int, int] = (17, 0)
    android_compile_sdk: int = 35
    android_min_sdk: int = 26
    android_target_sdk: int = 35
    android_validate_native_availability: bool = False


def _fail(message):
    from .validate import Diagnostic
    raise Diagnostic('nativeConfiguration: ' + message)


def _object(value, allowed=None, required=()):
    if not isinstance(value, dict) or any(not isinstance(k, str) for k in value):
        _fail('expected an object with string keys')
    if allowed is not None and set(value) - set(allowed):
        _fail('unknown fields: ' + ', '.join(sorted(set(value) - set(allowed))))
    if set(required) - set(value):
        _fail('missing fields: ' + ', '.join(sorted(set(required) - set(value))))


def _string(value):
    if not isinstance(value, str):
        _fail('expected string')
    try:
        size = len(value.encode('utf-8'))
    except UnicodeEncodeError:
        _fail('invalid Unicode string')
    if size > MAX_STRING_BYTES:
        _fail('string exceeds 1 MiB')
    if any(not (c in '\t\n\r' or '\x20' <= c <= '\ud7ff' or '\ue000' <= c <= '\ufffd' or '\U00010000' <= c <= '\U0010ffff') for c in value):
        _fail('string contains characters forbidden in XML')
    return value


class _Lower:
    def __init__(self):
        self.nodes = 0
        self.namespaces = dict(NAMESPACES)

    def xml_name(self, value):
        value = _string(value)
        if not re.fullmatch('(?:' + NAME + ':)?' + NAME, value) or value.lower().startswith('xml'):
            _fail('invalid manifest XML name')
        if ':' in value and value.split(':', 1)[0] not in self.namespaces:
            _fail('unbound manifest namespace prefix')
        return value

    def visit(self, depth):
        self.nodes += 1
        if depth > MAX_DEPTH:
            _fail('maximum nesting depth is 32')
        if self.nodes > MAX_NODES:
            _fail('maximum node count is 10000')

    def entries(self, raw, depth):
        _object(raw)
        return tuple((_string(key), self.plist(value, depth)) for key, value in sorted(raw.items()))

    def plist(self, raw, depth=1):
        self.visit(depth)
        _object(raw, ('type', 'value'), ('type', 'value'))
        kind, value = raw['type'], raw['value']
        if kind == 'string':
            value = _string(value)
        elif kind == 'integer':
            if type(value) is not int or not -(2**63) <= value < 2**63:
                _fail('plist integer must be signed 64-bit')
        elif kind == 'real':
            if type(value) not in (int, float):
                _fail('plist real must be finite')
            try:
                value = float(value)
            except OverflowError:
                _fail('plist real must be finite')
            if not math.isfinite(value):
                _fail('plist real must be finite')
        elif kind == 'boolean':
            if type(value) is not bool:
                _fail('plist boolean requires true or false')
        elif kind == 'data':
            value = _string(value)
            try:
                decoded = base64.b64decode(value, validate=True)
            except (ValueError, binascii.Error):
                _fail('plist data requires strict base64')
            if base64.b64encode(decoded).decode('ascii') != value:
                _fail('plist data requires canonical base64')
        elif kind == 'date':
            value = _string(value)
            if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', value):
                _fail('plist date requires UTC YYYY-MM-DDTHH:MM:SSZ')
            try:
                datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')
            except ValueError:
                _fail('invalid plist calendar date')
        elif kind == 'array':
            if not isinstance(value, list):
                _fail('plist array requires an array')
            value = tuple(self.plist(child, depth + 1) for child in value)
        elif kind == 'dictionary':
            value = self.entries(value, depth + 1)
        else:
            _fail('unknown plist type')
        return PlistValue(kind, value)

    def manifest(self, raw, depth=1):
        self.visit(depth)
        _object(raw, ('tag', 'attributes', 'children'), ('tag',))
        tag = self.xml_name(raw['tag'])
        attributes = raw.get('attributes', {})
        _object(attributes)
        pairs = []
        for key, value in sorted(attributes.items()):
            self.xml_name(key)
            pairs.append((key, _string(value)))
            self.visit(depth)
        children = raw.get('children', [])
        if not isinstance(children, list):
            _fail('manifest children requires an array')
        return ManifestElement(tag, tuple(pairs), tuple(self.manifest(child, depth + 1) for child in children))


def lower_native_configuration(raw):
    _object(raw, ('ios', 'android'))
    lower = _Lower()
    ios, android = raw.get('ios', {}), raw.get('android', {})
    _object(ios, ('infoPlist', 'entitlements', 'deploymentTarget'))
    _object(android, ('manifest', 'sourceSets', 'namespaces', 'compileSdk', 'minSdk', 'targetSdk', 'validateNativeAvailability'))
    levels = tuple(android.get(k, default) for k, default in [('compileSdk',35),('minSdk',26),('targetSdk',35)])
    if any(type(v) is not int or not 1 <= v <= 999 for v in levels):
        _fail('Android SDK versions require integer base levels 1..999; preview/minor versions are unsupported')
    if levels[1] < 26:
        _fail('Generated Android applications currently require minSdk >= 26')
    if not levels[1] <= levels[2] <= levels[0]:
        _fail('Android SDK versions require minSdk <= targetSdk <= compileSdk')
    strict = android.get('validateNativeAvailability', False)
    if type(strict) is not bool:
        _fail('android.validateNativeAvailability requires boolean')
    namespaces = android.get('namespaces', {})
    _object(namespaces)
    for prefix, uri in sorted(namespaces.items()):
        _string(prefix)
        if not re.fullmatch(NAME, prefix) or prefix.lower().startswith('xml') or re.fullmatch(r'ns\d+', prefix):
            _fail('invalid or reserved XML namespace prefix')
        _string(uri)
        if not re.match(r'[A-Za-z][A-Za-z0-9+.-]*:', uri) or any(c.isspace() for c in uri):
            _fail('namespace requires a nonempty absolute URI without whitespace')
        if uri in ('http://www.w3.org/XML/1998/namespace', 'http://www.w3.org/2000/xmlns/'):
            _fail('reserved XML namespace URI')
        if prefix in NAMESPACES and uri != NAMESPACES[prefix]:
            _fail('cannot change standard Android/tools namespace')
        if any(existing != prefix and value == uri for existing, value in lower.namespaces.items()):
            _fail('namespace URI aliases are unsupported')
        lower.namespaces[prefix] = uri
        lower.visit(1)
    source_sets = android.get('sourceSets', ['debug', 'release'])
    if not isinstance(source_sets, list) or not 1 <= len(source_sets) <= 64:
        _fail('android.sourceSets requires 1..64 source-set names')
    if any(not isinstance(name, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', name)
           or name in ('main', 'androidTest', 'test') for name in source_sets):
        _fail('invalid or reserved Android source-set name')
    if len(set(source_sets)) != len(source_sets):
        _fail('Android source-set names must be unique')
    deployment = ios.get('deploymentTarget', [17, 0])
    if (not isinstance(deployment, list) or len(deployment) != 2 or any(type(v) is not int for v in deployment)
            or not 17 <= deployment[0] <= 99 or not 0 <= deployment[1] <= 99):
        _fail('ios.deploymentTarget requires [major, minor], major 17..99 and minor 0..99')
    info = lower.entries(ios.get('infoPlist', {}), 1)
    entitlements = lower.entries(ios.get('entitlements', {}), 1)
    manifest = lower.manifest(android['manifest']) if 'manifest' in android else None
    if manifest is not None and manifest.tag != 'manifest':
        _fail('Android root tag must be manifest')
    return NativeConfiguration(info, entitlements, manifest, tuple(source_sets), tuple(sorted(lower.namespaces.items())), tuple(deployment), *levels, strict)


def _plist(value):
    if value.type == 'array':
        return [_plist(child) for child in value.value]
    if value.type == 'dictionary':
        return plist_dict(value.value)
    if value.type == 'date':
        # plistlib before Python 3.13 expects naive UTC datetimes.
        return datetime.strptime(value.value, '%Y-%m-%dT%H:%M:%SZ')
    if value.type == 'data':
        return base64.b64decode(value.value, validate=True)
    return value.value


def plist_dict(entries):
    return {key: _plist(value) for key, value in entries}


def manifest_xml(element, namespaces=DEFAULT_NAMESPACES):
    namespaces = dict(namespaces)
    for prefix, namespace in namespaces.items():
        ET.register_namespace(prefix, namespace)
    def expanded(name):
        if ':' not in name:
            return name
        prefix, local = name.split(':', 1)
        return '{' + namespaces[prefix] + '}' + local
    result = ET.Element(expanded(element.tag), {expanded(key): value for key, value in element.attributes})
    result.extend(manifest_xml(child, namespaces) for child in element.children)
    return result


def schema():
    """Complete config schema; runtime lowering additionally enforces aggregate limits."""
    def obj(properties, required=()):
        return {'type': 'object', 'properties': properties, 'required': list(required), 'additionalProperties': False}
    text = {'type': 'string', 'maxLength': MAX_STRING_BYTES}
    plist_ref = {'$ref': '#/$defs/nativePlistValue'}
    entries = {'type': 'object', 'propertyNames': text, 'maxProperties': MAX_NODES, 'additionalProperties': plist_ref}
    types = {
        'string': text,
        'integer': {'type': 'integer', 'minimum': -(2**63), 'maximum': 2**63-1},
        'real': {'type': 'number'},
        'boolean': {'type': 'boolean'},
        'data': {**text, 'pattern': r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$'},
        'date': {**text, 'pattern': r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'},
        'array': {'type': 'array', 'maxItems': MAX_NODES, 'items': plist_ref},
        'dictionary': entries,
    }
    xml_name = '^(?![xX][mM][lL])(?:' + NAME + ':)?' + NAME + '$'
    manifest = obj({'tag': {'type': 'string', 'pattern': xml_name},
                    'attributes': {'type': 'object', 'maxProperties': MAX_NODES,
                                   'propertyNames': {'pattern': xml_name},
                                   'additionalProperties': text},
                    'children': {'type': 'array', 'maxItems': MAX_NODES,
                                 'items': {'$ref': '#/$defs/nativeManifestElement'}}}, ('tag',))
    root = obj({'ios': obj({'infoPlist': entries, 'entitlements': entries,
                           'deploymentTarget': {'type': 'array', 'minItems': 2, 'maxItems': 2,
                                                'prefixItems': [{'type': 'integer', 'minimum': 17, 'maximum': 99}, {'type': 'integer', 'minimum': 0, 'maximum': 99}], 'items': False}}),
                'android': obj({'compileSdk': {'type':'integer','minimum':1,'maximum':999},
                                'minSdk': {'type':'integer','minimum':26,'maximum':999},
                                'targetSdk': {'type':'integer','minimum':1,'maximum':999},
                                'validateNativeAvailability': {'type':'boolean'},
                                'namespaces': {'type': 'object', 'maxProperties': MAX_NODES,
                                               'propertyNames': {'pattern': '^(?![xX][mM][lL])(?!ns[0-9]+$)' + NAME + '$'},
                                               'additionalProperties': {**text, 'minLength': 1, 'pattern': r'^[A-Za-z][A-Za-z0-9+.-]*:\S*$'}},
                                'sourceSets': {'type': 'array', 'minItems': 1, 'maxItems': 64, 'uniqueItems': True,
                                               'items': {'type': 'string', 'pattern': '^(?!(?:main|androidTest|test)$)[A-Za-z][A-Za-z0-9_]*$'}},
                                'manifest': {'allOf': [{'$ref': '#/$defs/nativeManifestElement'},
                                                       {'properties': {'tag': {'const': 'manifest'}}}]}})})
    root['$defs'] = {'nativePlistValue': {'oneOf': [obj({'type': {'const': kind}, 'value': value}, ('type', 'value')) for kind, value in types.items()]},
                     'nativeManifestElement': manifest}
    return root
