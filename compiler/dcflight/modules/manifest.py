"""Strict native module declarations. Manifests contain data, never build scripts."""
from dataclasses import dataclass
from pathlib import Path
import hashlib
import re
from ..frontends import read_json


@dataclass(frozen=True)
class NativeModule:
    id: str
    version: str
    platform: str
    package: str
    revision: str
    permissions: tuple
    products: tuple = ()


def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
    return h.hexdigest()


def read_manifest(path):
    d=read_json(Path(path).read_text())
    required={'schemaVersion','id','version','platform','package','revision'}
    allowed=required|{'permissions','products'}
    if not isinstance(d,dict) or not required<=set(d) or set(d)-allowed or type(d['schemaVersion']) is not int or d['schemaVersion']!=1:raise ValueError('Invalid native module manifest')
    for key in ('id','version'):
        if not isinstance(d[key],str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,99}',d[key]):raise ValueError('Invalid module '+key)
    platform=d['platform'];package=d['package'];revision=d['revision']
    if platform=='android':
        if not isinstance(package,str) or not re.fullmatch(r'[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+',package):raise ValueError('Expected Maven group:artifact')
        if not isinstance(revision,str) or not re.fullmatch(r'[0-9][A-Za-z0-9_.-]*',revision) or 'SNAPSHOT' in revision.upper():raise ValueError('Maven version must be exact and non-snapshot')
    elif platform=='ios':
        from urllib.parse import urlsplit
        if not isinstance(package,str) or any(ord(c)<33 for c in package):raise ValueError('Invalid SPM repository URL')
        u=urlsplit(package)
        if u.scheme!='https' or not u.hostname or u.username or u.password or u.query or u.fragment:raise ValueError('SPM source must be a credential-free HTTPS repository URL')
        if not isinstance(revision,str) or not re.fullmatch(r'[0-9a-f]{40}',revision):raise ValueError('SPM revision must be a full immutable Git commit')
    else:raise ValueError('Native module platform must be ios or android')
    permissions=d.get('permissions',[]);products=d.get('products',[])
    if not isinstance(permissions,list) or any(not isinstance(x,str) or not re.fullmatch(r'android\.permission\.[A-Z_]+',x) for x in permissions):raise ValueError('Invalid declared Android permissions')
    if platform=='ios' and permissions:raise ValueError('iOS permissions require usage descriptions, not Android permission names')
    if not isinstance(products,list) or any(not isinstance(x,str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*',x) for x in products):raise ValueError('Invalid SPM product names')
    if platform=='ios' and not products:raise ValueError('Declare the SPM library products to link')
    return NativeModule(d['id'],d['version'],platform,package,revision,tuple(sorted(set(permissions))),tuple(sorted(set(products))))
