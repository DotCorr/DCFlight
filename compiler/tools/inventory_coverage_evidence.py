#!/usr/bin/env python3
"""Inventory local SDK catalogs without merging incompatible evidence snapshots."""
import argparse
from contextlib import closing
import json
from pathlib import Path
import sqlite3


def inventory(roots):
    catalogs, errors = [], []
    paths = sorted({p.resolve() for root in roots for suffix in ('*.sqlite', '*.sqlite3', '*.db')
                    for p in Path(root).rglob(suffix) if p.is_file() and not p.is_symlink()})
    for path in paths:
        try:
            with closing(sqlite3.connect(path.as_uri()+'?mode=ro', uri=True)) as db:
                tables = {r[0] for r in db.execute("select name from sqlite_master where type='table'")}
                if not {'sources', 'apis', 'evidence'} <= tables:
                    continue
                db.execute('BEGIN')
                sources=[]
                for platform, scope, sdk, provenance in db.execute('select platform,scope,sdk,provenance from sources order by platform,scope'):
                    if platform not in ('ios','android'):
                        continue
                    indexed, emittable=db.execute('select count(*),coalesce(sum(emittable),0) from apis where platform=? and scope=?',(platform,scope)).fetchone()
                    levels=dict(db.execute('select level,count(distinct id) from evidence where platform=? and scope=? group by level',(platform,scope)))
                    sources.append(dict(platform=platform,scope=scope,sdk=sdk,indexed=indexed,emittable=emittable,
                                        recordedEvidence=levels,provenance=json.loads(provenance)))
                if sources:
                    catalogs.append(dict(path=str(path),sources=sources))
        except (sqlite3.Error, ValueError, OSError) as error:
            errors.append(dict(path=str(path),error=str(error)))
    return dict(completePlatformCoverage=False,scanRoots=[str(Path(r).resolve()) for r in roots],
                scope='Local catalogs only; overlapping identities, fixtures and historical SDK/compiler snapshots are not summed. Evidence freshness is not certified.',
                catalogs=catalogs,errors=errors)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('roots',nargs='+',type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    result=inventory(args.roots)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'catalogs':len(result['catalogs']),'errors':len(result['errors']),'report':str(args.out)}))
