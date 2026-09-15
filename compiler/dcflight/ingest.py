"""Streaming Android API text and Apple symbol graph inventory adapters.

Inventories deliberately cannot become executable registry mappings without review.
"""
import hashlib
import json
import re
from pathlib import Path
from .symbolgraph import symbols


def ingest(source, kind, sdk):
    path = Path(source)
    hasher = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    records = {}
    def add(symbol, name, category, signature, availability=()):
        identity = kind + ':' + symbol
        records[identity] = {'id': identity, 'name': name, 'kind': category, 'signature': signature,
                             'sdk': sdk, 'sourceSha256': digest, 'status': 'unmapped', 'availability': list(availability)}
    if kind == 'apple-symbolgraph':
        for symbol in symbols(path):
            add(symbol['identifier']['precise'], '.'.join(symbol['pathComponents']), symbol['kind']['identifier'],
                ''.join(part['spelling'] for part in symbol.get('declarationFragments', [])), symbol.get('availability', []))
    elif kind == 'android-api':
        package, owner = None, None
        with path.open() as stream:
            for line in stream:
                line = line.strip()
                package_match = re.match(r'package ([\w.]+) \{', line)
                class_match = re.search(r'\b(class|interface|enum|@interface) ([\w.]+)', line)
                if package_match:
                    package = package_match.group(1)
                elif class_match and package:
                    owner = package + '.' + class_match.group(2)
                    add(owner, owner, class_match.group(1), line.rstrip(' {'))
                elif line.startswith(('method ', 'ctor ', 'field ', 'enum_constant ')) and owner:
                    category, signature = line.split(' ', 1)
                    add(owner + '#' + signature, owner, category, signature)
                elif line == '}':
                    if owner:
                        owner = None
                    else:
                        package = None
    else:
        raise ValueError('Unsupported inventory format: ' + kind)
    if not records:
        raise ValueError('No API symbols found; check format')
    return {'version': 1, 'format': kind, 'sdk': sdk, 'source': path.name, 'sourceSha256': digest,
            'symbols': [records[key] for key in sorted(records)]}
