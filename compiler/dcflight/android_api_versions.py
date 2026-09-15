"""Exact JVM-keyed Android schema3 availability facts; no runtime certification."""
from __future__ import annotations
from dataclasses import dataclass
import hashlib,os,re,stat,xml.etree.ElementTree as ET
MAX_BYTES=32*1024*1024
MAX_NODES=250000
_NAME=re.compile(r'[A-Za-z_$][A-Za-z0-9_$]*')
_BINARY=re.compile(r'[A-Za-z_$][A-Za-z0-9_$]*(?:/[A-Za-z_$][A-Za-z0-9_$]*)*')

def read_api_versions(path):
    fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK|os.O_NOFOLLOW)
    try:
        info=os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size>MAX_BYTES:
            raise ValueError('API versions input must be a bounded regular file')
        with os.fdopen(fd,'rb') as stream:
            fd=None;raw=stream.read(MAX_BYTES+1)
        if len(raw)>MAX_BYTES:raise ValueError('API versions XML exceeds byte bound')
        return raw
    finally:
        if fd is not None:os.close(fd)


def _level(value):
    if value is None:return None
    if not isinstance(value,str) or not re.fullmatch(r'[1-9][0-9]{0,6}',value):raise ValueError('Only exact positive integer API levels are supported')
    return int(value)

def _descriptor(value,method):
    if not isinstance(value,str) or not 1<=len(value)<=65536:raise ValueError('Invalid JVM descriptor')
    def one(pos,void=False):
        start=pos
        while pos<len(value) and value[pos]=='[':pos+=1
        if pos-start>255 or pos>=len(value):raise ValueError('Invalid JVM descriptor')
        if value[pos] in 'BCDFIJSZ':return pos+1
        if void and pos==start and value[pos]=='V':return pos+1
        if value[pos]=='L':
            end=value.find(';',pos)
            if end<0 or not _BINARY.fullmatch(value[pos+1:end]):raise ValueError('Invalid JVM reference descriptor')
            return end+1
        raise ValueError('Invalid JVM descriptor')
    if method:
        if not value.startswith('('):raise ValueError('Invalid JVM method descriptor')
        pos=1
        while pos<len(value) and value[pos]!=')':pos=one(pos)
        if pos>=len(value):raise ValueError('Invalid JVM method descriptor')
        pos=one(pos+1,True)
    else:pos=one(0)
    if pos!=len(value):raise ValueError('Trailing JVM descriptor data')
    return value

@dataclass(frozen=True)
class VersionFacts:
    since:int|None
    deprecated:int|None
    removed:int|None
    sdks:tuple[tuple[int,int],...]|None
    module:str|None

def _facts(attrs):
    sdks=None
    if 'sdks' in attrs:
        if len(attrs['sdks'])>1024:raise ValueError('SDK requirements exceed attribute bound')
        pairs=[]
        for value in attrs['sdks'].split(','):
            parts=value.split(':')
            if len(parts)!=2:raise ValueError('Invalid extension SDK requirements')
            # SDK0 is the platform namespace; extension levels themselves are positive.
            if not re.fullmatch(r'0|[1-9][0-9]{0,6}',parts[0]):raise ValueError('Invalid SDK namespace')
            pairs.append((int(parts[0]),_level(parts[1])))
        if len(pairs)>64 or len({p[0] for p in pairs})!=len(pairs):raise ValueError('Duplicate or excessive SDK requirements')
        sdks=tuple(sorted(pairs))
    module=attrs.get('module')
    if module is not None and not re.fullmatch(r'[A-Za-z0-9_.-]{1,256}',module):raise ValueError('Invalid SDK module name')
    return VersionFacts(*(_level(attrs.get(k)) for k in ('since','deprecated','removed')),sdks,module)


def base_requirement(facts):
    """Known base floor only; extension-only availability has no base proof."""
    minimum=facts['minimumApi']
    if minimum is None:return None
    for row in (facts['classFacts'],facts['memberFacts']):
        branches=row['sdks']
        if branches is not None:
            branch=dict(branches).get(0)
            if branch is None:return None
            minimum=max(minimum,branch)
    return minimum

class APIVersions:
    def __init__(self,raw):
        if not isinstance(raw,bytes) or len(raw)>MAX_BYTES:raise ValueError('API versions XML exceeds byte bound')
        if b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():raise ValueError('XML declarations/entities are unsupported')
        parser=ET.XMLPullParser(events=('start','end'));root=None;nodes=0;depth=0
        text=raw.decode('utf-8')
        # Bound parser construction while feeding, not after building a full tree.
        # One feed can allocate at most4096 characters of additional XML nodes.
        for offset in range(0,len(text),4096):
            parser.feed(text[offset:offset+4096])
            for event,element in parser.read_events():
                if event=='start':
                    nodes+=1;depth+=1
                    if nodes>MAX_NODES:raise ValueError('API versions XML exceeds node bound')
                    if depth>3:raise ValueError('API versions XML exceeds depth bound')
                    if root is None:root=element
                else:depth-=1
        parser.close()
        if root is None or root.tag!='api' or root.attrib!={'version':'3'}:raise ValueError('Only api-versions.xml schema3 is supported; minor schemas require typed support')
        self.sha256=hashlib.sha256(raw).hexdigest();self.classes={};self.members={}
        for c in root:
            if c.tag=='sdk':
                if list(c) or set(c.attrib)-{'id','shortname','name','reference'}:raise ValueError('Malformed SDK declaration')
                
                if _level(c.attrib.get('id')) is None:raise ValueError('Missing SDK id')
                continue
            if c.tag!='class' or set(c.attrib)-{'name','since','deprecated','removed','sdks','module'}:raise ValueError('Unknown class metadata')
            owner=c.attrib.get('name','')
            if not _BINARY.fullmatch(owner) or owner in self.classes:raise ValueError('Invalid or duplicate JVM class')
            self.classes[owner]=_facts(c.attrib)
            for row in c:
                if list(row) or set(row.attrib)-{'name','since','deprecated','removed','sdks'}:raise ValueError('Malformed member metadata')
                name=row.attrib.get('name','')
                facts=_facts(row.attrib)
                if row.tag in ('extends','implements'):
                    if not _BINARY.fullmatch(name):raise ValueError('Invalid inheritance identity')
                    continue # Inheritance resolution deliberately not inferred.
                if row.tag=='field':
                    if not _NAME.fullmatch(name):raise ValueError('Invalid JVM field name')
                elif row.tag=='method':
                    split=name.find('(');simple=name[:split]
                    if split<1 or not (_NAME.fullmatch(simple) or simple=='<init>'):raise ValueError('Invalid JVM method name')
                    _descriptor(name[split:],True)
                    if simple=='<init>' and not name.endswith(')V'):raise ValueError('Invalid constructor result')
                else:raise ValueError('Unknown API member kind')
                key=(owner,row.tag,name)
                if key in self.members:raise ValueError('Duplicate JVM member availability')
                self.members[key]=facts

    def lookup(self,owner,kind,name,descriptor):
        """Caller supplies exact class-file identity, never a source-type guess."""
        if not isinstance(owner,str) or not _BINARY.fullmatch(owner):raise ValueError('Invalid JVM owner')
        if kind not in ('field','method'):raise ValueError('Invalid JVM member kind')
        if not isinstance(name,str) or not (_NAME.fullmatch(name) or (kind=='method' and name=='<init>')):raise ValueError('Invalid JVM member name')
        _descriptor(descriptor,kind=='method')
        key=(owner,kind,name+descriptor if kind=='method' else name)
        facts=self.members.get(key);owner_facts=self.classes.get(owner)
        if facts is None:return None
        def value(f):return {'since':f.since,'deprecated':f.deprecated,'removed':f.removed,'sdks':f.sdks,'module':f.module}
        since=[n for n in (owner_facts.since,facts.since) if n is not None]
        removed=[n for n in (owner_facts.removed,facts.removed) if n is not None]
        return {'xmlSHA256':self.sha256,'jvmIdentity':{'owner':owner,'kind':kind,'name':name,'descriptor':descriptor},'classFacts':value(owner_facts),'memberFacts':value(facts),'minimumApi':max(since) if since else None,'removedApi':min(removed) if removed else None,'permissions':None,'flags':None,'threadRequirement':None,'nullability':None,'runtimeSupported':None}

    def check_base_level(self,identity,level):
        if type(level) is not int or level<1:raise ValueError('Explicit positive integer base level required')
        facts=self.lookup(**identity)
        if facts is None:raise ValueError('Unknown exact JVM availability')
        minimum=base_requirement(facts)
        if minimum is None:raise ValueError('Unknown minimum API or extension-only availability')
        if level<minimum:raise ValueError('API introduced after selected base level')
        if facts['removedApi'] is not None and level>=facts['removedApi']:raise ValueError('API removed at selected base level')
        return facts # Requirement facts only; this is never runtime certification.

def declaration_descriptors(verbose):
    """Bind javap's adjacent native declaration and class-file descriptor."""
    owner=None;declaration=None;result={}
    for line in verbose.splitlines():
        if line.startswith('Classfile '):owner=None;declaration=None
        match=re.match(r'^.*?\b(?:class|interface|enum)\s+([\w.$]+)',line) if line and not line[0].isspace() else None
        if match:owner=match[1]
        if line.startswith('  ') and not line.startswith('    ') and line.rstrip().endswith(';'):
            declaration=line.strip()
        elif line.startswith('    descriptor:'):
            if owner is None or declaration is None:raise ValueError('Unbound javap descriptor')
            desc=line.partition(':')[2].strip();_descriptor(desc,'(' in declaration)
            key=(owner,declaration)
            if key in result:raise ValueError('Ambiguous javap descriptor declaration')
            result[key]=desc;declaration=None
    return result
