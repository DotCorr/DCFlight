"""Operator-invoked retention cleanup; prints only row counts."""
import json
import os
import time
from .database import Database


def clean(database, now=None):
    now = int(time.time()) if now is None else now
    with database.connect() as db:
        db.execute('BEGIN IMMEDIATE')
        counts = {}
        for table, column, cutoff in [('sessions','expires_at',now), ('stories','expires_at',now), ('locations','updated_at',now-3600), ('rate_limits','bucket',now-86400)]:
            counts[table] = db.execute(f'DELETE FROM {table} WHERE {column}<=?', (cutoff,)).rowcount
        counts['orphan_media'] = db.execute('DELETE FROM media WHERE created_at<? AND NOT EXISTS(SELECT 1 FROM messages WHERE media_id=media.id) AND NOT EXISTS(SELECT 1 FROM stories WHERE media_id=media.id)', (now-7*86400,)).rowcount
        return counts


if __name__ == '__main__':
    print(json.dumps(clean(Database(os.environ.get('SNAP_DATABASE', './data/snap.sqlite3'))), sort_keys=True))
