"""Exact SDK compile evidence for conditional use of flagged Android APIs."""
import copy
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from dataclasses import replace
from pathlib import Path
from types import MappingProxyType

FLAGGED = 'flagged API requires separate SDK support'


def _candidate_view(api, identities):
    """Compiler-verifier-only view: all candidates still require native proof."""
    ids = set(identities)
    if any(api.get(identity).unsupported_reasons != (FLAGGED,) for identity in ids):
        raise ValueError('Availability candidates must have only the flagged API blocker')
    result = copy.copy(api)
    members = {key: replace(member, unsupported_reasons=()) if key in ids else member
               for key, member in api.members.items()}
    result.members = MappingProxyType(members)
    peers = {}
    for member in members.values():
        peers.setdefault((member.owner, member.kind, '<init>' if member.kind == 'ctor' else member.name), []).append(member)
    result._overloads = MappingProxyType({key: tuple(values) for key, values in peers.items()})
    return result


def report_digest(report):
    return hashlib.sha256(json.dumps(report, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def report_member_ids(report):
    """Validate untrusted structural fields before cache/membership decisions."""
    if not isinstance(report,dict):raise ValueError('Malformed availability report')
    for key in ('sourceSha256','sdkSha256'):
        if not isinstance(report.get(key),str) or not re.fullmatch('[0-9a-f]{64}',report[key]):
            raise ValueError('Malformed availability digest')
    if type(report.get('apiLevel')) is not int or report['apiLevel']<1:
        raise ValueError('Malformed availability SDK level')
    rows=report.get('members')
    if not isinstance(rows,list) or not 1<=len(rows)<=50000:
        raise ValueError('Malformed availability members')
    if any(not isinstance(row,dict) or not isinstance(row.get('id'),str) or not row['id']
           or type(row.get('compiled')) is not bool for row in rows):
        raise ValueError('Malformed availability member entry')
    if len({row['id'] for row in rows})!=len(rows):raise ValueError('Duplicate availability identities')
    return frozenset(row['id'] for row in rows if row['compiled'])


def verify_report(report, api):
    from .ios_verification import compiler_sources
    if not isinstance(report, dict) or report.get('kind') != 'dcflight.android.flagged-availability.v1':
        raise ValueError('Expected generator-driven Android availability report')
    report_member_ids(report)
    if (report.get('sourceSha256') != api.source_sha256 or report.get('apiLevel') != api.api_level
            or report.get('compilerSources') != compiler_sources() or report.get('compilerUnchanged') is not True):
        raise ValueError('Availability evidence does not match current source, SDK level or compiler')
    if not isinstance(report.get('sdkSha256'), str) or not re.fullmatch('[0-9a-f]{64}', report['sdkSha256']):
        raise ValueError('Availability evidence requires exact SDK identity')
    if report.get('generator') != 'AndroidAPI.emit' or report.get('dependencyScanPassed') is not True:
        raise ValueError('Availability evidence requires generator and dependency verification')
    if (not isinstance(report.get('command'),list) or not report['command']
            or any(not isinstance(command,list) or not command or any(not isinstance(arg,str) for arg in command) for command in report['command'])
            or not isinstance(report.get('toolchain'),dict) or not report['toolchain'].get('javac') or not report['toolchain'].get('version')
            or report.get('runtimeSupported','missing') is not None or report.get('minimumApi','missing') is not None):
        raise ValueError('Availability evidence requires toolchain provenance and unknown runtime availability')
    rows = report.get('members')
    if not isinstance(rows, list) or not rows or len(rows) > 50000:
        raise ValueError('Expected bounded availability member evidence')
    identities = []
    for row in rows:
        if (not isinstance(row, dict) or not isinstance(row.get('id'), str)
                or type(row.get('compiled')) is not bool
                or not re.fullmatch('[0-9a-f]{64}', str(row.get('probeSha256', '')))):
            raise ValueError('Malformed per-member availability evidence')
        identities.append(row['id'])
    if len(set(identities)) != len(identities):
        raise ValueError('Duplicate availability identities')
    if (type(report.get('candidateCount')) is not int or type(report.get('compiledCount')) is not int
            or report['candidateCount'] != len(rows) or report['compiledCount'] != sum(r['compiled'] for r in rows)):
        raise ValueError('Availability evidence count mismatch')
    view = _candidate_view(api, identities)
    from .android_availability_probe import probe
    for row in rows:
        if row['probeSha256'] != hashlib.sha256(probe(view, view.get(row['id']), 0).encode()).hexdigest():
            raise ValueError('Availability evidence differs from generated call')
    return _candidate_view(api, [row['id'] for row in rows if row['compiled']])


def revalidate_report(report, api, sdk_bytes, *, javac=None):
    if hashlib.sha256(sdk_bytes).hexdigest() != report.get("sdkSha256"):
        raise ValueError("Availability SDK hash mismatch")
    view=verify_report(report,api)
    enabled=[row["id"] for row in report["members"] if row["compiled"]]
    # Recompile the exact enabled generator expressions against the supplied
    # SDK bytes before accepting a report. A flipped success bit is not proof.
    from .android_availability_probe import probe
    with tempfile.TemporaryDirectory(prefix='dcflight-availability-import-') as temporary:
        root=Path(temporary);sdk_copy=root/'android.jar';sdk_copy.write_bytes(sdk_bytes)
        compiler=str(javac or shutil.which('javac') or 'javac')
        for offset in range(0,len(enabled),256):
            java=root/'AvailabilityImport.java'
            java.write_text('public class AvailabilityImport {\n'+'\n'.join(
                probe(view,view.get(identity),index) for index,identity in enumerate(enabled[offset:offset+256]))+'\n}')
            result=subprocess.run([compiler,'-source','8','-target','8','-bootclasspath',str(sdk_copy),
                                   '-Xlint:unchecked','-Werror','-d',str(root),str(java)],capture_output=True,text=True,timeout=120)
            if result.returncode:raise ValueError('Availability enabled calls failed native revalidation: '+result.stderr[-4000:])
    verify_report(report,api)
    return view


def import_availability(database, report_path, sdk_path, *, javac=None):
    from .catalog import Catalog
    from .platforms.android_api import AndroidAPI
    report_path, sdk_path = Path(report_path), Path(sdk_path)
    report = json.loads(report_path.read_text())
    sdk_bytes=sdk_path.read_bytes()
    if hashlib.sha256(sdk_bytes).hexdigest() != report.get('sdkSha256'):
        raise ValueError('Availability SDK hash mismatch')
    database = Path(database).resolve()
    with Catalog(database) as catalog:
        source = catalog.source('android', 'framework')
        old_evidence = catalog.evidence_groups('android', 'framework')
    provenance = source['provenance']
    path = (database.parent / provenance['sourceRelativePath']).resolve()
    path.relative_to(database.parent)
    api = AndroidAPI.from_file(path, api_level=int(source['sdk']))
    if api.source_sha256 != provenance['sourceSha256']:
        raise ValueError('Indexed Android source changed')
    view = verify_report(report, api)
    enabled = [row['id'] for row in report['members'] if row['compiled']]
    view=revalidate_report(report,api,sdk_bytes,javac=javac)
    proof = {'report': report, 'sha256': report_digest(report)}
    records = view.records()
    enabled_set=set(enabled)
    for record in records:
        if record['id'] in enabled_set:
            record['availability'].update({'conditional': True, 'sdkSha256': report['sdkSha256'],
                                          'runtimeSupported': None, 'minimumApi': None})
    with Catalog(database, write=True) as catalog:
        preserved=[]
        for group in old_evidence:
            identities=[identity for identity in group['ids'] if view.get(identity).emittable and identity not in enabled_set]
            if identities:preserved.append({**group,'ids':identities})
        compiled={'ids':enabled,'evidence':{
                'command': report['command'], 'toolchain': report['toolchain'],
                'reportSha256': hashlib.sha256(report_path.read_bytes()).hexdigest(),
                'scope': 'Exact SDK source compilation only; conditional runtime availability and flag state remain unknown.'}}
        result = catalog.import_records('android', 'framework', source['sdk'], records,
                                        {**provenance, 'flaggedAvailability': proof},compiled=compiled,
                                        evidence_entries=preserved)
    return {**result, 'conditionalCompiled': len(enabled), 'unavailableOrUnverified': len(report['members'])-len(enabled)}
