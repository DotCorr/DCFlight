"""Explicit generic invocation requirements and bounded native witness planning.

Witnesses are typed requests, not implementation substitutions or native evidence.
The normal Android emitter remains the authority for bounds and call legality.
"""
from __future__ import annotations
import re


def _formals(prefix):
    from .platforms.android_api import _split
    if not prefix.startswith('<'):return ()
    depth,end=1,1
    while end<len(prefix) and depth:
        depth+=(prefix[end]=='<')-(prefix[end]=='>');end+=1
    if depth:raise ValueError('Unbalanced generic parameter declaration')
    result=[]
    for value in _split(prefix[1:end-1]):
        match=re.fullmatch(r'([A-Za-z_$][\w$]*)(?:\s+extends\s+(.+))?',value)
        if not match or any(name==match[1] for name,_ in result):raise ValueError('Malformed generic parameter declaration')
        result.append((match[1],match[2] or 'java.lang.Object'))
    if not 1<=len(result)<=32:raise ValueError('Generic parameter count exceeds supported bound')
    return tuple(result)


def owner_formals(api,owner):
    from .platforms.android_api import _annotations
    declaration,_=_annotations(api.classes.get(owner,{}).get('declaration',''))
    match=re.search(r'\b(?:class|interface)\s+[\w.$]+',declaration)
    return _formals(declaration[match.end():].strip()) if match else ()


def _public_owner(api,name,depth=0):
    from .platforms.android_api import _annotations
    if depth>32:return False
    declaration,_=_annotations(api.classes.get(name,{}).get('declaration',''))
    match=re.search(r'\b(?:class|interface|enum)\s+([\w.$]+)',declaration)
    if not match or 'public' not in declaration.split():return False
    declared=match[1]
    if '.' not in declared:return True
    if not name.endswith('.'+declared):return False
    parent=name[:-len(declared)]+declared.rsplit('.',1)[0]
    return _public_owner(api,parent,depth+1)


def requirements(api,member):
    """Small source-derived discovery metadata; no change to emittable status."""
    try:
        owner=owner_formals(api,member.owner)
        callable_parameters=_formals(api._callable_type_prefix(member))
    except ValueError as error:
        return {'status':'unavailable','reason':str(error)}
    if not owner and not callable_parameters:return None
    def parameters(values,scope):
        return [{'name':name,'scope':scope,'bounds':[b.strip() for b in bound.split('&')]} for name,bound in values]
    fields={}
    if owner and (member.kind=='ctor' or not member.static):
        fields['constructedType' if member.kind=='ctor' else 'receiver.type']={
            'template':member.owner+'<'+', '.join(name for name,_ in owner)+'>',
            'parametersInOrder':[name for name,_ in owner]}
    if callable_parameters:
        fields['typeArguments']={'count':len(callable_parameters),'parametersInOrder':[name for name,_ in callable_parameters]}
    blockers=[r for r in member.unsupported_reasons if not r.startswith('generic or unsupported type: ') and r!='generic constructor type parameters are unsupported']
    return {'status':'explicit-substitutions','ownerParameters':parameters(owner,'owner'),
            'callableParameters':parameters(callable_parameters,'constructor' if member.kind=='ctor' else 'method'),
            'inputFields':fields,'otherRestrictions':blockers,'unboundEmittable':member.emittable,
            'nativeVerified':False,'scope':'Requirements only; each concrete invocation must pass ordinary type and native checks.'}


def _shape(text):
    from .platforms.android_api import _split
    text=text.strip();arrays=0
    while text.endswith('[]'):arrays+=1;text=text[:-2]
    base,separator,args=text.partition('<')
    return base,tuple(_shape(value) for value in _split(args[:-1])) if separator else (),arrays


def _unify(pattern,actual,names,bindings):
    if pattern[0] in names and not pattern[1] and pattern[2]==0:
        def spell(node):return node[0]+('<'+', '.join(spell(a) for a in node[1])+'>' if node[1] else '')+'[]'*node[2]
        value=spell(actual)
        if pattern[0] in bindings:return bindings[pattern[0]]==value
        bindings[pattern[0]]=value;return True
    return pattern[0]==actual[0] and pattern[2]==actual[2] and len(pattern[1])==len(actual[1]) and all(_unify(a,b,names,bindings) for a,b in zip(pattern[1],actual[1]))


class WitnessPlanner:
    """Find bounded example substitutions from the exact indexed type hierarchy.

    Unconstrained slots use String, not erasure to Object. Constraint witnesses
    come from declared public native types; missing witnesses are not negatives.
    """
    def __init__(self,api,*,max_trials=250000,max_types=16384):
        if type(max_trials) is not int or not 1<=max_trials<=1000000 or type(max_types) is not int or not 1<=max_types<=16384:raise ValueError('Invalid witness planner bounds')
        self.api=api;self.remaining=max_trials;self.cache={};self.pool=['java.lang.String'];self.views={}
        for name,data in sorted(api.classes.items()):
            if not _public_owner(api,name):continue
            fs=owner_formals(api,name)
            candidates=[name] if not fs else [name+'<'+', '.join([value]*len(fs))+'>' for value in ('java.lang.String','?')]
            for candidate in candidates:
                try:
                    if fs:api._owner_view(name,candidate)
                except ValueError:continue
                if candidate not in self.pool:self.pool.append(candidate)
                if len(self.pool)>max_types:raise ValueError('Witness type pool exceeds configured bound')

    def _trial(self):
        self.remaining-=1
        if self.remaining<0:raise ValueError('Witness search budget exhausted')

    def _valid(self,fs,values):
        from .platforms.android_api import _safe_type
        return all(all(_safe_type(resolved) and self.api.is_assignable(values[name],resolved)
                       for resolved in (self.api._substitute(c.strip(),values) for c in bound.split('&')))
                   for name,bound in fs)

    def _parents(self,value):
        if value in self.views:return self.views[value]
        pending=[(value,0)];seen=set()
        while pending:
            item,depth=pending.pop()
            if item in seen:continue
            if len(seen)>=256 or depth>32:raise ValueError('Witness hierarchy exceeds bound')
            seen.add(item);pending.extend((p,depth+1) for p in self.api._generic_parents(item))
        self.views[value]=tuple(sorted(seen));return self.views[value]

    def solve(self,fs):
        if fs in self.cache:return self.cache[fs]
        values={};pending=dict(fs)
        while pending:
            progress=False
            for name,bound in tuple(pending.items()):
                referenced=set(re.findall(r'(?<![\w.$])[A-Za-z_$][\w$]*(?![\w.$])',bound))&set(pending)-{name}
                if referenced:continue
                for value in ['java.lang.String'] if bound=='java.lang.Object' else self.pool:
                    self._trial();trial={**values,name:value}
                    if self._valid(((name,bound),),trial):values[name]=value;del pending[name];progress=True;break
            if not progress:break
        if pending:
            # A concrete inherited self-bound can constrain earlier free slots:
            # OfInt -> OfPrimitive<Integer,IntConsumer,OfInt>. No name mapping.
            names={name for name,_ in fs};found=None
            for name,bound in fs:
                for constraint in bound.split('&'):
                    pattern=_shape(constraint.strip())
                    if not pattern[1]:continue
                    for candidate in self.pool:
                        for view in self._parents(candidate):
                            self._trial();trial={name:candidate}
                            if not _unify(pattern,_shape(view),names,trial):continue
                            trial={n:trial.get(n,'java.lang.String') for n,_ in fs}
                            if self._valid(fs,trial):found=trial;break
                        if found:break
                    if found:break
                if found:break
            if found is None:self.cache[fs]=None;return None
            values=found
        result=tuple(values[name] for name,_ in fs)
        self.cache[fs]=result;return result

    def request(self,member_id,scope):
        from .platforms.android_api import _safe_type
        member=self.api.get(member_id);info=requirements(self.api,member)
        if not info or info.get('otherRestrictions') or info.get('status')!='explicit-substitutions':raise ValueError('No eligible generic-only invocation')
        request={'platform':'android','scope':scope,'id':member_id};arguments={}
        if member.kind=='ctor' or not member.static:
            fs=owner_formals(self.api,member.owner);values=self.solve(fs)
            if values is None:raise ValueError('No bounded owner witness found')
            owner=member.owner+('<'+', '.join(values)+'>' if fs else '')
            if member.kind=='ctor':request['constructedType']=owner;arguments['constructed_type']=owner
            else:request['receiver']={'ref':'receiver','type':owner};arguments['receiver_type']=owner
        resolved=self.api.resolve_member(member_id,**arguments)
        fs=_formals(self.api._callable_type_prefix(resolved));values=self.solve(fs)
        if values is None:raise ValueError('No bounded callable witness found')
        if fs:request['typeArguments']=list(values);arguments['type_arguments']=values
        resolved=self.api.resolve_member(member_id,**arguments)
        if not resolved.emittable:raise ValueError('Witness leaves unsupported native requirements')
        request['arguments']=[{'ref':'p'+str(i),'type':p.java_type} for i,p in enumerate(resolved.parameters)]
        return request


def request_schema():
    """Android expression request schema; emitter additionally checks SDK semantics."""
    def obj(properties,required=()):return {'type':'object','properties':properties,'required':list(required),'additionalProperties':False}
    typ={'type':'string','minLength':1,'maxLength':4096}
    value={'oneOf':[obj({'ref':{'type':'string'},'type':typ},('ref','type')),obj({'class':typ},('class',)),obj({'literal':{}},('literal',)),obj({'null':typ},('null',)),obj({'array':{'type':'array'},'type':typ},('array','type'))]}
    schema=obj({'platform':{'const':'android'},'scope':{'type':'string'},'id':{'type':'string'},'receiver':value,'arguments':{'type':'array','maxItems':256,'items':value},'set':value,'typeArguments':{'type':'array','minItems':1,'maxItems':32,'items':typ},'constructedType':typ,'executionContext':{'enum':['unknown','main','worker']},'androidSdkSha256':{'type':'string','pattern':'^[0-9a-f]{64}$'},'androidMinSdk':{'type':'integer','minimum':1,'maximum':999},'androidCompileSdk':{'type':'integer','minimum':1,'maximum':999}},('platform','id'))
    schema['dependentRequired']={'androidMinSdk':['androidCompileSdk'],'androidCompileSdk':['androidMinSdk']}
    schema['description']='Inspect descriptor invocationRequirements for formal parameter order and bounds. typeArguments selects callable parameters; receiver.type or constructedType selects owner parameters. No raw source.'
    return schema


def plan_catalog(catalog,scope,*,max_trials=250000):
    from pathlib import Path
    import hashlib,json
    from .catalog import Catalog
    from .android_deployment_validation import _snapshot
    from .platforms.android_api import AndroidAPI
    with Catalog(catalog) as c:source=c.source('android',scope)
    raw=_snapshot(Path(catalog).resolve().parent,source['provenance'],128*1024*1024)
    api=AndroidAPI(raw.decode('utf-8'),api_level=int(source['sdk']));planner=WitnessPlanner(api,max_trials=max_trials);requests=[];unplanned=[];eligible=0
    for member in api.members.values():
        if member.emittable or not all(r.startswith('generic or unsupported type: ') or r=='generic constructor type parameters are unsupported' for r in member.unsupported_reasons):continue
        eligible+=1
        if eligible>4096:raise ValueError('Generic planning candidate count exceeds4096')
        try:requests.append(planner.request(member.id,scope))
        except ValueError as error:unplanned.append({'id':member.id,'reason':str(error)})
    result={'kind':'dcflight.android.specialization-plan.v1','scope':scope,'sourceSHA256':hashlib.sha256(raw).hexdigest(),'candidateCount':eligible,'requests':requests,'unplanned':unplanned,'trialsRemaining':max(planner.remaining,0),'nativeVerified':False}
    if len(json.dumps(result).encode())>8*1024*1024:raise ValueError('Specialization plan exceeds8MiB')
    return result
