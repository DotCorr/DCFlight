#!/usr/bin/env python3
"""Report indexed, emittable and compiled-native SDK coverage.

The report deliberately keeps these states separate. An indexed declaration is
catalog data; an emittable declaration has a reviewed generator path; compiled
evidence means the generated call was checked against a real SDK/toolchain.
None of these claims that every platform API has a shared semantic wrapper.
"""
import argparse
import json
import sqlite3
from contextlib import closing
from pathlib import Path


def report(database):
    database = Path(database).resolve(strict=True)
    with closing(sqlite3.connect(database.as_uri() + '?mode=ro', uri=True)) as connection:
        connection.execute('BEGIN')
        rows = connection.execute(
        """select platform, scope, count(*) as indexed,
                  sum(case when emittable=1 then 1 else 0 end) as emittable
             from apis group by platform, scope order by platform, scope"""
    ).fetchall()
        evidence_rows = connection.execute('''
            select a.platform,a.scope,e.level,count(distinct a.id)
            from apis a join evidence e
              on a.platform=e.platform and a.scope=e.scope and a.id=e.id
            where e.level in ('compiled','executed')
            group by a.platform,a.scope,e.level
        ''').fetchall()
        compiled = {(p,s): n for p,s,level,n in evidence_rows if level=='compiled'}
        executed = {(p,s): n for p,s,level,n in evidence_rows if level=='executed'}
        compiled_emittable = {(p,s): n for p,s,n in connection.execute('''
            select a.platform,a.scope,count(distinct a.id)
            from apis a join evidence e
              on a.platform=e.platform and a.scope=e.scope and a.id=e.id
            where e.level='compiled' and a.emittable=1
            group by a.platform,a.scope
        ''')}
    scopes = []
    for platform, scope, indexed, emittable in rows:
        compiled_count = compiled.get((platform, scope), 0)
        scopes.append({
            'platform': platform,
            'scope': scope,
            'indexed': indexed,
            'emittable': emittable,
            'compiled': compiled_count,
            'recordedExecuted': executed.get((platform, scope), 0),
            'compiledAndEmittable': compiled_emittable.get((platform, scope), 0),
            'emittablePercent': round(100 * emittable / indexed, 2) if indexed else 0,
            'compiledPercentOfIndexed': round(100 * compiled_count / indexed, 2) if indexed else 0,
            'compiledPercentOfEmittable': round(100 * compiled_emittable.get((platform, scope), 0) / emittable, 2) if emittable else 0,
        })
    totals = {}
    for platform in sorted({row['platform'] for row in scopes}):
        selected = [row for row in scopes if row['platform'] == platform]
        indexed = sum(row['indexed'] for row in selected)
        emittable = sum(row['emittable'] for row in selected)
        compiled_count = sum(row['compiled'] for row in selected)
        totals[platform] = {
            'indexed': indexed,
            'emittable': emittable,
            'compiled': compiled_count,
            'recordedExecuted': sum(row['recordedExecuted'] for row in selected),
            'compiledAndEmittable': sum(row['compiledAndEmittable'] for row in selected),
            'emittablePercent': round(100 * emittable / indexed, 2) if indexed else 0,
            'compiledPercentOfIndexed': round(100 * compiled_count / indexed, 2) if indexed else 0,
            'compiledPercentOfEmittable': round(100 * sum(row['compiledAndEmittable'] for row in selected) / emittable, 2) if emittable else 0,
        }
    return {
        'database': str(Path(database).resolve()),
        'completePlatformCoverage': False,
        'scopeLimitations': [
            'One catalog snapshot only; separate catalogs and newer reports are not merged.',
            'No complete platform denominator: indexed declarations include non-callable types and synthesized members.',
            'Counts are per platform/scope/id; overlapping scopes may describe the same declaration.',
            'Evidence rows are counted, not revalidated against the current compiler or SDK.',
            'Zero recorded execution evidence does not imply no execution tests exist elsewhere.',
            'Platform-wide runtime and shared-language capability coverage remain unknown.'
        ],
        'definitions': {
            'indexed': 'Declaration discovered in the SDK catalog.',
            'emittable': 'Catalog flag says the emitter accepts the signature shape; not a per-API review or current compilation guarantee.',
            'compiled': 'Distinct catalog declarations with a recorded compiled evidence row; freshness is not revalidated.',
            'recordedExecuted': 'Distinct catalog declarations with a recorded executed evidence row; no inferred runtime coverage.',
            'semanticCoverage': 'Not represented by these counts; shared capability wrappers and runtime journeys are a separate surface.',
        },
        'totals': totals,
        'scopes': scopes,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('database', type=Path)
    parser.add_argument('--json', type=Path)
    args = parser.parse_args()
    result = report(args.database)
    encoded = json.dumps(result, indent=2) + '\n'
    if args.json:
        args.json.write_text(encoded)
    print(encoded, end='')


if __name__ == '__main__':
    main()
