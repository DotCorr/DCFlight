#!/usr/bin/env python3
"""Export compact catalog coverage and SDK discovery gaps, without repeating symbol evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.catalog import Catalog


def digest(path):
    value=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''): value.update(block)
    return value.hexdigest()


def export(database, output_prefix, ios_sweep=None, ios_analysis=None):
    database=Path(database);prefix=Path(output_prefix);prefix.parent.mkdir(parents=True,exist_ok=True)
    with Catalog(database) as catalog: coverage=catalog.coverage()
    platforms=[]
    for platform in ('ios','android','web','windows','linux'):
        sources=[source for source in coverage['sources'] if source['platform']==platform]
        platforms.append({'platform':platform,'sources':len(sources),
                          **{key:sum(source[key] for source in sources) for key in ('indexed','emittable','compiled','executed')}})
    result={'schemaVersion':1,'database':str(database.resolve()),'databaseSha256':digest(database),
            'completePlatformCoverage':False,'definitions':coverage['definitions'],
            'platforms':platforms,'sources':coverage['sources'],
            'gaps':[
                'Indexed entries are SDK descriptions, not implemented shared components.',
                'Emittable entries have supported source shapes; only compiled/executed columns carry exact native evidence.',
                'Compilation validates a particular native target and calling context; it does not establish runtime behavior, permissions or entitlements.',
                'Generics, callback/closure lowering, inherited receiver coercion and many complex Swift types remain unsupported.',
                'C++ SDK modules require a separate ingestion and typed emission adapter.',
                'Web, Windows and Linux have no catalog coverage unless explicitly listed with imported sources.',
            ]}
    if ios_sweep:
        root=Path(ios_sweep);receipt=json.loads((root/'coverage.json').read_text())
        inventory={x['module']:x for x in json.loads((root/'inventory.json').read_text())}
        result['iosDiscovery']={'receipt':str((root/'coverage.json').resolve()),'receiptSha256':digest(root/'coverage.json'),
                               'provenance':receipt['provenance'],'moduleCounts':receipt['moduleCounts'],
                               'failedOrExcluded':[dict(item,sources=inventory.get(item['module'],{}).get('sources',[]))
                                                   for item in receipt['modules'] if item['status'] in ('failed','excluded','pending')]}
        if ios_analysis:
            analysis_path=Path(ios_analysis);analysis=json.loads(analysis_path.read_text())
            result['iosDiscovery']['analysis']={'receipt':str(analysis_path.resolve()),'receiptSha256':digest(analysis_path),
                'groups':analysis['groups'],'remainingNonCxxFailures':analysis['remainingFailures'],
                'explanation':'The original failed count includes C++ candidates attempted by the Swift extractor. Classified groups preserve this evidence and distinguish public framework coverage.'}
    lines=['# SDK coverage','', 'This report separates discovered APIs, supported source generation and exact native verification. Full platform coverage is not complete.','',
           '| Platform | Sources | Indexed | Emittable | Native compiled | Native executed |',
           '|---|---:|---:|---:|---:|---:|']
    for item in platforms:
        lines.append('| '+item['platform']+' | '+' | '.join(format(item[key],',') for key in ('sources','indexed','emittable','compiled','executed'))+' |')
    lines+=['','Compilation counts refer to specific native fixtures and targets. They are not counts of complete app features.','']
    discovery=result.get('iosDiscovery')
    if discovery:
        lines+=['## iOS discovery','', 'Original sweep: '+', '.join(str(value)+' '+key for key,value in discovery['moduleCounts'].items())+'.','']
        analysis=discovery.get('analysis')
        if analysis:
            lines+=['| Candidate category | Successful | Failed | Excluded |','|---|---:|---:|---:|']
            for kind,counts in analysis['groups'].items():
                lines.append('| '+kind+' | '+' | '.join(str(counts.get(key,0)) for key in ('success','failed','excluded'))+' |')
            lines+=['','C++ candidates require their own adapter. Their failed Swift extraction attempts remain in the JSON receipt; they do not represent missing Swift framework bindings.','',
                    'Other extraction failures: '+', '.join('`'+item['module']+'`' for item in analysis['remainingNonCxxFailures'])+'.','']
    lines+=['## Remaining gaps','']+['- '+gap for gap in result['gaps']]
    lines+=['','The JSON companion includes source SDK provenance and individual failed/excluded discovery records. It intentionally omits per-symbol evidence payloads.','']
    json_path=prefix.with_suffix('.json');markdown_path=prefix.with_suffix('.md')
    json_path.write_text(json.dumps(result,indent=2)+'\n');markdown_path.write_text('\n'.join(lines))
    return {'json':str(json_path.resolve()),'markdown':str(markdown_path.resolve()),'platforms':platforms}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--database',type=Path,required=True)
    parser.add_argument('--output-prefix',type=Path,required=True)
    parser.add_argument('--ios-sweep',type=Path)
    parser.add_argument('--ios-analysis',type=Path)
    args=parser.parse_args()
    print(json.dumps(export(args.database,args.output_prefix,args.ios_sweep,args.ios_analysis),indent=2))

if __name__=='__main__':main()
