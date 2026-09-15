"""Indexed SDK descriptions with explicit evidence levels and bounded AI queries."""
import json
from pathlib import Path
import sqlite3
from typing import Iterable


SCHEMA = '''
CREATE TABLE IF NOT EXISTS sources (
    platform TEXT NOT NULL,
    scope TEXT NOT NULL,
    sdk TEXT NOT NULL,
    provenance TEXT NOT NULL,
    PRIMARY KEY(platform, scope)
);
CREATE TABLE IF NOT EXISTS apis (
    platform TEXT NOT NULL,
    scope TEXT NOT NULL,
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    owner TEXT NOT NULL,
    kind TEXT NOT NULL,
    emittable INTEGER NOT NULL CHECK(emittable IN (0,1)),
    searchable TEXT NOT NULL,
    descriptor TEXT NOT NULL,
    PRIMARY KEY(platform, scope, id),
    FOREIGN KEY(platform,scope) REFERENCES sources(platform,scope) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS api_names ON apis(platform,name);
CREATE TABLE IF NOT EXISTS evidence (
    platform TEXT NOT NULL,
    scope TEXT NOT NULL,
    id TEXT NOT NULL,
    level TEXT NOT NULL CHECK(level IN ('compiled','executed')),
    evidence TEXT NOT NULL,
    PRIMARY KEY(platform,scope,id,level),
    FOREIGN KEY(platform,scope,id) REFERENCES apis(platform,scope,id) ON DELETE CASCADE
);
PRAGMA user_version=1;
'''


class Catalog:
    def __init__(self, path, write=False):
        self.path = Path(path).resolve()
        if write:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.connection = sqlite3.connect(str(self.path))
            version = self.connection.execute('PRAGMA user_version').fetchone()[0]
            if version not in (0, 1):
                self.connection.close()
                raise ValueError('Unsupported SDK catalog schema')
            self.connection.executescript(SCHEMA)
        else:
            if not self.path.is_file():
                raise ValueError('No SDK catalog found: ' + str(self.path))
            self.connection = sqlite3.connect(self.path.as_uri() + '?mode=ro', uri=True)
            if self.connection.execute('PRAGMA user_version').fetchone()[0] != 1:
                self.connection.close()
                raise ValueError('Unsupported SDK catalog schema')
        self.connection.execute('PRAGMA foreign_keys=ON')
        self.connection.row_factory = sqlite3.Row

    def close(self):
        self.connection.close()

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()

    def import_records(self, platform, scope, sdk, records: Iterable[dict], provenance):
        if platform not in ('ios', 'android', 'web', 'windows', 'linux'):
            raise ValueError('Unknown platform')
        if not scope or not sdk:
            raise ValueError('SDK and source scope are required')
        count = 0
        with self.connection:
            # Deleting a source intentionally invalidates evidence for changed SDK records.
            self.connection.execute('DELETE FROM sources WHERE platform=? AND scope=?', (platform, scope))
            self.connection.execute('INSERT INTO sources VALUES (?,?,?,?)',
                (platform, scope, sdk, json.dumps(provenance, sort_keys=True)))
            for record in records:
                identity = record.get('id')
                if not isinstance(identity, str) or not identity:
                    raise ValueError('Every SDK descriptor needs a stable nonempty id')
                emittable = record.get('emittable', record.get('supported', False))
                if type(emittable) is not bool:
                    raise ValueError('SDK descriptor emittable flag must be boolean')
                name = str(record.get('name', identity))
                owner = str(record.get('owner') or '')
                kind = str(record.get('kind') or '')
                serialized = json.dumps(record, sort_keys=True)
                searchable = ' '.join((name, owner, kind, str(record.get('signature', '')))).lower()
                self.connection.execute('INSERT INTO apis VALUES (?,?,?,?,?,?,?,?,?)',
                    (platform, scope, identity, name, owner, kind, int(emittable), searchable, serialized))
                count += 1
        return {'platform': platform, 'scope': scope, 'sdk': sdk, 'indexed': count}

    def record_evidence(self, platform, scope, identities, level, evidence):
        if level not in ('compiled', 'executed'):
            raise ValueError('Evidence level must be compiled or executed')
        if not isinstance(evidence, dict) or not evidence.get('command') or not evidence.get('toolchain'):
            raise ValueError('Evidence must identify the command and toolchain')
        with self.connection:
            for identity in identities:
                row = self.connection.execute('SELECT emittable FROM apis WHERE platform=? AND scope=? AND id=?',
                    (platform, scope, identity)).fetchone()
                if row is None or not row['emittable']:
                    raise ValueError('Cannot mark unknown or unsupported API as verified: ' + identity)
                self.connection.execute('INSERT OR REPLACE INTO evidence VALUES (?,?,?,?,?)',
                    (platform, scope, identity, level, json.dumps(evidence, sort_keys=True)))

    def search(self, query='', platform=None, scope=None, emittable_only=False, limit=20, offset=0):
        if type(limit) is not int or not 1 <= limit <= 100 or type(offset) is not int or offset < 0:
            raise ValueError('Search requires limit 1..100 and nonnegative offset')
        if not isinstance(query, str) or len(query) > 500:
            raise ValueError('Search query must contain at most 500 characters')
        clauses, params = [], []
        for column, value in (('platform', platform), ('scope', scope)):
            if value is not None:
                clauses.append(column + '=?')
                params.append(value)
        for word in query.lower().split():
            clauses.append('instr(searchable, ?) > 0')
            params.append(word)
        if emittable_only:
            clauses.append('emittable=1')
        where = ' WHERE ' + ' AND '.join(clauses) if clauses else ''
        total = self.connection.execute('SELECT count(*) FROM apis' + where, params).fetchone()[0]
        rows = self.connection.execute('SELECT platform,scope,id,name,owner,kind,emittable FROM apis' + where +
            ' ORDER BY platform,scope,name,id LIMIT ? OFFSET ?', [*params, limit, offset]).fetchall()
        return {'total': total, 'offset': offset, 'limit': limit, 'results': [dict(row) for row in rows],
                'nextOffset': offset + len(rows) if offset + len(rows) < total else None}

    def get(self, platform, identity, scope=None):
        query = 'SELECT scope,descriptor FROM apis WHERE platform=? AND id=?'
        args = [platform, identity]
        if scope is not None:
            query += ' AND scope=?'
            args.append(scope)
        rows = self.connection.execute(query, args).fetchall()
        if not rows:
            raise ValueError('Unknown native API: ' + identity)
        if len(rows) != 1:
            raise ValueError('API occurs in multiple scopes; select scope: ' + ', '.join(row['scope'] for row in rows))
        row = rows[0]
        result = json.loads(row['descriptor'])
        evidence = self.connection.execute('SELECT level,evidence FROM evidence WHERE platform=? AND scope=? AND id=?',
            (platform, row['scope'], identity)).fetchall()
        return {'platform': platform, 'scope': row['scope'], 'api': result,
                'evidence': [{'level': e['level'], **json.loads(e['evidence'])} for e in evidence]}

    def coverage(self):
        result = []
        for source in self.connection.execute('SELECT * FROM sources ORDER BY platform,scope'):
            args = (source['platform'], source['scope'])
            counts = self.connection.execute('SELECT count(*),coalesce(sum(emittable),0) FROM apis WHERE platform=? AND scope=?',args).fetchone()
            levels = dict(self.connection.execute('SELECT level,count(DISTINCT id) FROM evidence WHERE platform=? AND scope=? GROUP BY level', args))
            result.append({'platform': source['platform'], 'scope': source['scope'], 'sdk': source['sdk'],
                'indexed': counts[0], 'emittable': counts[1], 'compiled': levels.get('compiled', 0), 'executed': levels.get('executed', 0),
                'provenance': json.loads(source['provenance'])})
        return {'sources': result, 'completePlatformCoverage': False,
                'definitions': {'indexed': 'SDK descriptor imported', 'emittable': 'Supported structured native source emission',
                    'compiled': 'This exact symbol occurs in a successful native compilation fixture',
                    'executed': 'This exact symbol occurs in a successful native execution fixture'}}
