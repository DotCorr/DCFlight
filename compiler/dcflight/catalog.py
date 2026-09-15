"""Indexed SDK descriptions with explicit evidence levels and bounded AI queries."""
from functools import lru_cache
import hashlib
import json
import re
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
CREATE TABLE IF NOT EXISTS evidence_payloads (
    payload_id INTEGER PRIMARY KEY,
    sha256 TEXT NOT NULL UNIQUE,
    evidence TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS evidence_links (
    platform TEXT NOT NULL,
    scope TEXT NOT NULL,
    id TEXT NOT NULL,
    level TEXT NOT NULL CHECK(level IN ('compiled','executed')),
    payload_id INTEGER NOT NULL,
    PRIMARY KEY(platform,scope,id,level),
    FOREIGN KEY(platform,scope,id) REFERENCES apis(platform,scope,id) ON DELETE CASCADE,
    FOREIGN KEY(payload_id) REFERENCES evidence_payloads(payload_id)
);
CREATE INDEX IF NOT EXISTS evidence_payload_links ON evidence_links(payload_id);
CREATE VIEW IF NOT EXISTS evidence AS
    SELECT l.platform,l.scope,l.id,l.level,p.evidence
    FROM evidence_links AS l JOIN evidence_payloads AS p USING(payload_id);
PRAGMA user_version=2;
'''


TRIGGERS = (
    """CREATE TRIGGER evidence_payload_delete AFTER DELETE ON evidence_links BEGIN
        DELETE FROM evidence_payloads WHERE payload_id=OLD.payload_id
          AND NOT EXISTS (SELECT 1 FROM evidence_links WHERE payload_id=OLD.payload_id);
        END""",
    """CREATE TRIGGER evidence_payload_replace AFTER UPDATE OF payload_id ON evidence_links
        WHEN OLD.payload_id != NEW.payload_id BEGIN
        DELETE FROM evidence_payloads WHERE payload_id=OLD.payload_id
          AND NOT EXISTS (SELECT 1 FROM evidence_links WHERE payload_id=OLD.payload_id);
        END""",
)


def _normalized_sql(source):
    # Preserve whitespace inside SQL string/identifier literals while ignoring
    # formatting outside them. Removing literal whitespace changes semantics.
    return re.sub(r"'(?:''|[^'])*'|\"(?:\"\"|[^\"])*\"|\s+",
                  lambda match: '' if match.group().isspace() else match.group(), source)


def _schema_shape(connection):
    tables = ('sources', 'apis', 'evidence_payloads', 'evidence_links')
    shape = {}
    for name in tables:
        obj = connection.execute("SELECT type,sql FROM sqlite_master WHERE name=?", (name,)).fetchone()
        if obj is None or obj[0] != 'table':
            raise ValueError('Missing schema-v2 table: ' + name)
        shape[name] = {
            'columns': [tuple(row) for row in connection.execute('PRAGMA table_xinfo(' + name + ')')],
            'foreignKeys': [tuple(row) for row in connection.execute('PRAGMA foreign_key_list(' + name + ')')],
            'uniqueIndexes': sorted(tuple(row[2] for row in connection.execute('PRAGMA index_info("' + index[1].replace('"', '""') + '")'))
                                    for index in connection.execute('PRAGMA index_list(' + name + ')') if index[2]),
        }
    # Newly introduced tables, critical view, indexes and GC trigger bodies have
    # one compiler-owned definition. Compare definitions, not merely names: a
    # no-op trigger or filtered evidence view must not pass shape validation.
    for name in ('evidence_payloads','evidence_links','evidence','api_names','evidence_payload_links',
                 'evidence_payload_delete','evidence_payload_replace'):
        obj = connection.execute("SELECT type,sql FROM sqlite_master WHERE name=?", (name,)).fetchone()
        if obj is None or obj[1] is None:
            raise ValueError('Missing schema-v2 object: ' + name)
        shape['object:' + name] = (obj[0], _normalized_sql(obj[1]))
    # Legacy v1 source/API tables survive migration, so permit formatting of
    # their original SQL while still requiring the supported-symbol constraint.
    api_sql = connection.execute("SELECT sql FROM sqlite_master WHERE name='apis'").fetchone()[0]
    if 'CHECK(emittableIN(0,1))'.lower() not in ''.join(api_sql.split()).lower():
        raise ValueError('Missing schema-v2 API evidence constraint')
    return shape


@lru_cache(maxsize=1)
def _expected_schema_shape():
    reference = sqlite3.connect(':memory:')
    try:
        reference.executescript(SCHEMA)
        for trigger in TRIGGERS: reference.execute(trigger)
        return _schema_shape(reference)
    finally:
        reference.close()


class Catalog:
    def __init__(self, path, write=False):
        self.path = Path(path).resolve()
        if write:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.connection = sqlite3.connect(str(self.path))
        else:
            if not self.path.is_file():
                raise ValueError('No SDK catalog found: ' + str(self.path))
            self.connection = sqlite3.connect(self.path.as_uri() + '?mode=ro', uri=True)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute('PRAGMA foreign_keys=ON')
        try:
            version = self.connection.execute('PRAGMA user_version').fetchone()[0]
            if version not in ((0, 1, 2) if write else (1, 2)):
                raise ValueError('Unsupported SDK catalog schema')
            if write and version != 2:
                self._upgrade(version)
            if write or version == 2:
                self._validate_v2()
        except BaseException:
            self.connection.close()
            raise

    def _validate_v2(self):
        try:
            if _schema_shape(self.connection) != _expected_schema_shape():
                raise ValueError('Malformed SDK catalog schema v2')
        except sqlite3.DatabaseError as error:
            raise ValueError('Malformed SDK catalog schema v2') from error

    def _payload(self, serialized):
        digest = hashlib.sha256(serialized.encode('utf-8')).hexdigest()
        self.connection.execute('INSERT OR IGNORE INTO evidence_payloads(sha256,evidence) VALUES (?,?)',
                                (digest, serialized))
        row = self.connection.execute('SELECT payload_id,evidence FROM evidence_payloads WHERE sha256=?', (digest,)).fetchone()
        if row['evidence'] != serialized:
            raise ValueError('Evidence payload hash collision')
        return row['payload_id']

    def _upgrade(self, version):
        # No executescript: it commits an existing transaction implicitly.
        # Schema, links, payloads and user_version change in one transaction.
        self.connection.execute('BEGIN IMMEDIATE')
        try:
            # A concurrent writable opener may have upgraded while we waited.
            current = self.connection.execute('PRAGMA user_version').fetchone()[0]
            if current == 2:
                self._validate_v2()
                self.connection.commit()
                return
            if current != version:
                raise ValueError('Catalog schema changed during migration')
            if version == 1:
                self.connection.execute('ALTER TABLE evidence RENAME TO evidence_v1')
            elif self.connection.execute("SELECT 1 FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' LIMIT 1").fetchone():
                raise ValueError('Unversioned nonempty SDK catalog')
            for statement in SCHEMA.split(';'):
                if statement.strip(): self.connection.execute(statement)
            if version == 1:
                for row in self.connection.execute('SELECT e.*,a.emittable FROM evidence_v1 e LEFT JOIN apis a ON a.platform=e.platform AND a.scope=e.scope AND a.id=e.id'):
                    value = json.loads(row['evidence'])
                    if (row['level'] not in ('compiled','executed') or not isinstance(value,dict)
                            or not value.get('command') or not value.get('toolchain') or row['emittable'] != 1):
                        raise ValueError('Invalid legacy evidence; migration rolled back')
                    payload = self._payload(row['evidence'])
                    self.connection.execute('INSERT INTO evidence_links VALUES (?,?,?,?,?)',
                        (row['platform'],row['scope'],row['id'],row['level'],payload))
                self.connection.execute('DROP TABLE evidence_v1')
            for trigger in TRIGGERS: self.connection.execute(trigger)
            self._validate_v2()
            if self.connection.execute('PRAGMA foreign_key_check').fetchone():
                raise ValueError('Invalid catalog foreign keys; migration rolled back')
            self.connection.commit()
        except BaseException:
            self.connection.rollback()
            raise

    def close(self):
        self.connection.close()

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()

    def import_records(self, platform, scope, sdk, records: Iterable[dict], provenance, *, compiled=None, evidence_entries=()):
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
            if compiled is not None:
                self._record_evidence(platform, scope, compiled['ids'], 'compiled', compiled['evidence'])
            for entry in evidence_entries:
                self._record_evidence(platform, scope, entry['ids'], entry['level'], entry['evidence'])
        return {'platform': platform, 'scope': scope, 'sdk': sdk, 'indexed': count}

    def record_evidence(self, platform, scope, identities, level, evidence):
        with self.connection:
            self._record_evidence(platform, scope, identities, level, evidence)

    def _record_evidence(self, platform, scope, identities, level, evidence):
        if level not in ('compiled', 'executed'):
            raise ValueError('Evidence level must be compiled or executed')
        if not isinstance(evidence, dict) or not evidence.get('command') or not evidence.get('toolchain'):
            raise ValueError('Evidence must identify the command and toolchain')
        serialized = json.dumps(evidence, sort_keys=True)
        payload = None
        for identity in identities:
            row = self.connection.execute('SELECT emittable FROM apis WHERE platform=? AND scope=? AND id=?',
                (platform, scope, identity)).fetchone()
            if row is None or not row['emittable']:
                raise ValueError('Cannot mark unknown or unsupported API as verified: ' + identity)
            if payload is None: payload = self._payload(serialized)
            self.connection.execute('INSERT INTO evidence_links VALUES (?,?,?,?,?) '
                'ON CONFLICT(platform,scope,id,level) DO UPDATE SET payload_id=excluded.payload_id',
                (platform, scope, identity, level, payload))

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

    def source(self, platform, scope):
        row = self.connection.execute('SELECT * FROM sources WHERE platform=? AND scope=?', (platform,scope)).fetchone()
        if row is None:
            raise ValueError('Unknown SDK source')
        return {**dict(row), 'provenance': json.loads(row['provenance'])}

    def evidence_groups(self, platform, scope):
        """Preserve scope evidence without expanding shared payloads per symbol.

        This development-time bulk API is used during scope replacement. The
        legacy v1 fallback streams rows and retains each distinct JSON once.
        """
        if self.connection.execute('PRAGMA user_version').fetchone()[0] == 1:
            grouped = {}
            for row in self.connection.execute('SELECT id,level,evidence FROM evidence WHERE platform=? AND scope=?', (platform,scope)):
                key = (row['level'], row['evidence'])
                grouped.setdefault(key, []).append(row['id'])
            return [{'ids': ids, 'level': level, 'evidence': json.loads(payload)}
                    for (level,payload),ids in grouped.items()]
        groups = []
        for row in self.connection.execute('SELECT DISTINCT level,payload_id FROM evidence_links WHERE platform=? AND scope=?', (platform,scope)):
            payload = self.connection.execute('SELECT evidence FROM evidence_payloads WHERE payload_id=?', (row['payload_id'],)).fetchone()[0]
            ids = [item[0] for item in self.connection.execute('SELECT id FROM evidence_links WHERE platform=? AND scope=? AND level=? AND payload_id=?', (platform,scope,row['level'],row['payload_id']))]
            groups.append({'ids': ids, 'level': row['level'], 'evidence': json.loads(payload)})
        return groups

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
