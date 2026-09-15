"""Replayable base-version requirements for development-time Android calls."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import stat

_FIELDS=('androidMinSdk','androidCompileSdk')

def levels(request):
    present=set(_FIELDS)&set(request)
    if not present:return None
    if present!=set(_FIELDS):raise ValueError('Android availability requires both androidMinSdk and androidCompileSdk')
    minimum,compile_sdk=(request[k] for k in _FIELDS)
    if any(type(v) is not int or not 1<=v<=999 for v in (minimum,compile_sdk)) or minimum>compile_sdk:
        raise ValueError('Android API levels require positive base integers with minimum <= compile')
    return {'minimum':minimum,'compile':compile_sdk,'requireKnown':True}

def select_context(request,app):
    explicit=levels(request)
    if app is not None:
        if not isinstance(app,dict) or set(app)!={'minimum','compile','requireKnown'} or type(app['requireKnown']) is not bool:
            raise ValueError('Malformed Android application availability context')
        levels({'androidMinSdk':app['minimum'],'androidCompileSdk':app['compile']})
        if explicit and (explicit['minimum']>app['minimum'] or explicit['compile']!=app['compile']):
            raise ValueError('Explicit Android availability context conflicts with application deployment')
    return explicit or app

def app_context(app):
    config=app.native_configuration
    return {'minimum':config.android_min_sdk if config else 26,
            'compile':config.android_compile_sdk if config else 35,
            'requireKnown':config.android_validate_native_availability if config else False}

def operation_for_app(definition,context):
    # Explicit higher floors cannot hide an unguarded call from older app devices.
    impl=definition.get('implementations',{}).get('android',{})
    explicit=levels(impl)
    if explicit:
        if explicit['minimum']>context['minimum']:raise ValueError('Android implementation minimum exceeds application minimum; an authored runtime guard is required')
        if explicit['compile']!=context['compile']:raise ValueError('Android implementation compile SDK differs from application compile SDK')
    return definition

def _snapshot(root,metadata,maximum):
    if not isinstance(metadata,dict):raise ValueError('Malformed Android availability snapshot')
    relative=metadata.get('sourceRelativePath');expected=metadata.get('sourceSha256')
    if not isinstance(relative,str) or not relative or not isinstance(expected,str):raise ValueError('Missing retained Android availability snapshot')
    rel=Path(relative)
    if rel.is_absolute() or any(p in ('..','.') for p in rel.parts):raise ValueError('Android availability snapshot escapes catalog')
    path=root
    for part in rel.parts:
        path=path/part
        if path.is_symlink():raise ValueError('Android availability snapshot symlink is forbidden')
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size>maximum:raise ValueError('Android availability snapshot is not a bounded regular file')
        with os.fdopen(fd,'rb') as stream:
            fd=None;raw=stream.read(maximum+1)
        if len(raw)>maximum or hashlib.sha256(raw).hexdigest()!=expected:raise ValueError('Android availability snapshot hash mismatch')
        return raw
    finally:
        if fd is not None:os.close(fd)

def check(catalog_path,source,descriptor,member,context,cache):
    """Recompute facts from retained native declarations and XML, never annotations alone."""
    if context is None:return None
    unknown={'status':'unknown','minimumApi':None,'runtimeSupported':None}
    def unavailable(reason):
        if context['requireKnown']:raise ValueError('Unknown Android availability: '+reason)
        return dict(unknown,reason=reason)
    provenance=source['provenance']
    if 'availabilityXml' not in provenance or 'availabilityJvmSignatures' not in provenance:
        return unavailable('exact retained XML and JVM declarations are required')
    root=Path(catalog_path).resolve().parent
    xml=_snapshot(root,provenance['availabilityXml'],32*1024*1024)
    signatures=_snapshot(root,provenance['availabilityJvmSignatures'],128*1024*1024)
    key=(hashlib.sha256(xml).hexdigest(),hashlib.sha256(signatures).hexdigest())
    if key not in cache:
        from .android_api_versions import APIVersions,declaration_descriptors
        from .modules.export import _convert
        text=signatures.decode('utf-8')
        descriptors=declaration_descriptors(text)
        filtered='\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('descriptor:'))
        bindings={}
        _convert(filtered,jvm_descriptors=descriptors,declaration_bindings=bindings)
        cache[key]=(APIVersions(xml),bindings)
    table,bindings=cache[key]
    matches=bindings.get((member.id,member.declaration),set())
    if len(matches)!=1:return unavailable('missing or ambiguous exact JVM declaration binding')
    owner,kind,name,descriptor_type=next(iter(matches))
    facts=table.lookup(owner,kind,name,descriptor_type)
    if facts is None:return unavailable('exact JVM identity has no XML entry')
    stored=descriptor.get('availability',{})
    # A mutated annotation must never silently become trusted evidence.
    actual={k:stored.get(k) for k in facts}
    if json.dumps(actual,sort_keys=True)!=json.dumps(facts,sort_keys=True):raise ValueError('Stored Android availability differs from replayed exact JVM/XML facts')
    if facts['removedApi'] is not None:raise ValueError('Removed Android API requires an upper-runtime guard; targetSdk is not a runtime ceiling')
    if facts['minimumApi'] is None:return unavailable('unknown base minimum')
    if context['minimum']<facts['minimumApi']:raise ValueError('Android API introduced after application minimum')
    from .android_api_versions import base_requirement
    base_minimum=base_requirement(facts)
    if base_minimum is None:return unavailable('extension-only requirements have no supported base SDK branch')
    if context['minimum']<base_minimum:raise ValueError('Android API introduced after application minimum')
    if str(context['compile'])!=str(source['sdk']):raise ValueError('Android compile SDK must match the exact captured SDK snapshot')
    sdk_hash=provenance.get('sdkArchiveSha256')
    import re
    if not isinstance(sdk_hash,str) or not re.fullmatch('[0-9a-f]{64}',sdk_hash):return unavailable('missing exact SDK archive identity')
    return {'status':'base-version-checked','minimumApi':base_minimum,'applicationMinimum':context['minimum'],
            'apiLevel':context['compile'],'sdkSha256':sdk_hash,'xmlSha256':key[0],'jvmSignaturesSha256':key[1],
            'jvmIdentity':facts['jvmIdentity'],'runtimeSupported':None,'extensionsEvaluated':False,
            'permissions':None,'flags':None}
