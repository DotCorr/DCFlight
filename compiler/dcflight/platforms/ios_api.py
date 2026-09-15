"""Development-time Swift calls from SDK symbol graphs; no executable SDK templates."""
from __future__ import annotations
from dataclasses import dataclass, replace
import hashlib
from pathlib import Path
import json
import math
import re
from ..symbolgraph import symbols
from .swift_imports import public_imports
from .swift_types import parse_type, supported_type, spelling, make_optional, optional_inner, is_optional

class TargetAvailabilityError(ValueError):
    """A structurally valid API lies outside an authored iOS version interval."""
    def __init__(self, constraint, target, boundary):
        self.classification={'kind':'iosTargetAvailability','constraint':constraint,'target':list(target),'boundary':list(boundary)}
        super().__init__('API outside target iOS availability')


_IDENT = re.compile(r'^[A-Za-z_][A-Za-z_0-9]*$')
_KINDS = {'swift.init': 'constructor', 'swift.method': 'method', 'swift.type.method': 'static_method', 'swift.func': 'function', 'swift.property': 'property', 'swift.type.property': 'static_property'}


def _identifier(value):
    if not isinstance(value, str) or not _IDENT.fullmatch(value):
        raise ValueError('Expected a Swift identifier')
    return '`' + value + '`'


def _typename(value):
    if not supported_type(value):
        raise ValueError('Unsupported Swift type: ' + str(value))
    return value


@dataclass(frozen=True)
class Parameter:
    label: str
    name: str
    type: str
    escaping: bool = False
    inout: bool = False
    autoclosure: bool = False


@dataclass(frozen=True)
class API:
    id: str
    module: str
    path: tuple
    kind: str
    parameters: tuple
    result: str
    availability: tuple
    unsupported: tuple
    async_: bool = False
    throws: bool = False
    writable: bool = False
    optional_call: bool = False
    mutating: bool = False
    owner_kind: str = "unknown"
    setter_mutating: bool | None = None
    actor_isolation: str = "unknown"
    required_imports: tuple = ()
    type_resolutions: tuple = ()
    owner_parameters: tuple = ()
    owner_constraints: tuple = ()
    specialized_owner: str = ""
    generic_owner: str = ""
    class_facts: tuple = ()
    bridge_resolutions: tuple = ()

    def to_dict(self):
        from dataclasses import asdict
        return {"id": self.id, "name": self.path[-1] if self.path else "", "kind": self.kind,
                "owner": self.owner, "path": list(self.path), "module": self.module, "platform": "ios",
                "parameters": [asdict(p) for p in self.parameters], "resultType": self.result,
                "emittable": not self.unsupported, "unsupportedReasons": list(self.unsupported),
                "availability": list(self.availability), "async": self.async_, "throws": self.throws, "writable": self.writable, "optionalCall": self.optional_call, "mutating": self.mutating, "ownerKind": self.owner_kind, "setterMutating": self.setter_mutating, "actorIsolation": self.actor_isolation, "requiredImports":list(self.required_imports), "typeResolutions": list(self.type_resolutions), "genericOwner":self.generic_owner, "ownerParameters":list(self.owner_parameters), "ownerConstraints":[list(c) for c in self.owner_constraints], **({"ownerClassFacts":list(self.class_facts)} if self.class_facts else {}), **({"bridgeResolutions":list(self.bridge_resolutions)} if self.bridge_resolutions else {})}

    @property
    def owner(self):
        return self.specialized_owner or '.'.join(self.path[:-1])


@dataclass(frozen=True)
class Reference:
    """A named, typed local binding, never a Swift expression string."""
    name: str
    type: str
    mutable: bool = False


@dataclass(frozen=True)
class Literal:
    value: object


@dataclass(frozen=True)
class Emission:
    expression: str
    result_type: str
    imports: tuple


def _text(fragments):
    return ''.join(f.get('spelling', '') for f in fragments)


def _actor_isolation(symbol, global_actors=None):
    fragments = symbol.get('declarationFragments', [])
    declaration = _text(fragments)
    if re.search(r'\bnonisolated\b', declaration):
        return 'nonisolated'
    if re.search(r'@(?:(?:_Concurrency|Swift)\.)?MainActor\b', declaration):
        return 'main'
    # Resolve attributes by Swift symbol identity, never by an attribute suffix.
    matches = {global_actors[fragment['preciseIdentifier']]
               for fragment in fragments if fragment.get('kind') == 'attribute'
               and fragment.get('preciseIdentifier') in (global_actors or {})}
    if len(matches) > 1:
        raise ValueError('Conflicting global actor attributes')
    return next(iter(matches), 'unknown')


def _valid_actor_context(value):
    return isinstance(value, str) and (value in ('unknown', 'main', 'nonisolated') or
        re.fullmatch(r'global:[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+', value) is not None)


def _call_effects(declaration, kind):
    if kind.endswith('property'):
        effects=declaration.partition('{')[2]
    else:
        start=re.search(r'\b(?:func|init)\b',declaration)
        opening=declaration.find('(',start.end()) if start else -1
        if opening<0: return False,False
        depth=0; closing=None
        for index in range(opening,len(declaration)):
            if declaration[index]=='(': depth+=1
            elif declaration[index]==')':
                depth-=1
                if depth==0: closing=index;break
        if closing is None: return False,False
        effects=declaration[closing+1:].split('->',1)[0]
    return bool(re.search(r'\basync\b',effects)),bool(re.search(r'\bthrows\b',effects))


def _descriptor(symbol, module, owner_kinds=None, owner_actors=None, global_actors=None):
    kind = _KINDS.get(symbol.get('kind', {}).get('identifier'), 'unsupported')
    path = tuple(symbol.get('pathComponents', []))
    decl = _text(symbol.get('declarationFragments', []))
    sig = symbol.get('functionSignature', {})
    reasons = []
    params = []
    title = path[-1] if path else ''
    labels = title.partition('(')[2].rstrip(')').split(':')[:-1] if '(' in title else []
    raw_params = sig.get('parameters', [])
    # Swift symbol graphs can omit @escaping from functionSignature while
    # retaining it in the full declaration (notably Objective-C block aliases).
    fragments = symbol.get('declarationFragments', [])
    starts = [i for i,f in enumerate(fragments) if f.get('kind') == 'externalParam']
    parameter_declarations = []
    if len(starts) == len(raw_params):
        parameter_declarations = [_text(fragments[start:end]) for start,end in
                                  zip(starts, starts[1:] + [len(fragments)])]
    for index, param in enumerate(raw_params):
        typ = _text(param.get('declarationFragments', [])).partition(':')[2].strip()
        inout = typ.startswith('inout ')
        if inout: typ = typ[len('inout '):].strip()
        escaping = False
        autoclosure = False
        while re.match(r'^@(escaping|autoclosure)\b', typ):
            attribute, typ = typ.split(None, 1)
            escaping = escaping or attribute == '@escaping'
            autoclosure = autoclosure or attribute == '@autoclosure'
            typ = typ.strip()
        if parameter_declarations:
            escaping = escaping or bool(re.search(r'@escaping\b', parameter_declarations[index]))
            autoclosure = autoclosure or bool(re.search(r'@autoclosure\b', parameter_declarations[index]))
            inout = inout or bool(re.search(r':\s*inout\b', parameter_declarations[index]))
        label = labels[index] if index < len(labels) else param.get('name', '')
        params.append(Parameter(label, param.get('name', ''), typ, escaping, inout, autoclosure))
        if not supported_type(typ):
            reasons.append('parameter type requires structured lowering: ' + typ)
        if label != '_' and not _IDENT.fullmatch(label):
            reasons.append('invalid parameter label')
    result = _text(sig.get('returns', [])).strip() or 'Void'
    if kind == 'constructor':
        result = '.'.join(path[:-1])
        if 'init?' in decl or 'init!' in decl:
            result += '?'
    if kind.endswith('property'):
        result = decl.partition(':')[2].partition('{')[0].strip()
    if not supported_type(result):
        reasons.append('result type requires structured lowering: ' + result)
    for entry in symbol.get('availability', []):
        if entry.get('isUnconditionallyUnavailable') and entry.get('domain') in ('iOS', 'Swift', '*'):
            reasons.append('unavailable API')
        if entry.get('domain') == 'Swift' and entry.get('obsoleted', {}).get('major', 999) <= 6:
            reasons.append('obsolete Swift spelling: ' + entry.get('renamed', 'unavailable'))
    if kind == 'static_property' and re.search(r'\boptional\b', decl):
        reasons.append('optional Objective-C static property requires concrete owner lowering')
    if kind == 'unsupported':
        reasons.append('symbol is not an invocable member')
    if symbol.get('swiftGenerics') or symbol.get('swiftExtension', {}).get('constraints'):
        reasons.append('generic constraints require specialization')
    if re.search(r'\b(Self|some|rethrows)\b', decl):
        reasons.append('polymorphic or ownership signature requires lowering')
    if re.search(r'\binout\b',decl) and not any(p.inout for p in params):
        reasons.append('inout parameter contract could not be resolved')
    if len(labels) != len(raw_params):
        reasons.append('parameter labels do not match signature')
    if not path or any(not _IDENT.fullmatch(p) for p in path[:-1]):
        reasons.append('unsupported owner path')
    name = title.partition('(')[0]
    if not _IDENT.fullmatch(name):
        reasons.append('unsupported callable name')
    if kind != 'function' and len(path) < 2:
        reasons.append('missing receiver type')
    actor = _actor_isolation(symbol, global_actors)
    if actor == 'unknown':
        actor = (owner_actors or {}).get(tuple(path[:-1]), 'unknown')
    owner_kind = (owner_kinds or {}).get(tuple(path[:-1]), 'unknown')
    if kind == 'constructor' and owner_kind == 'protocol':
        reasons.append('protocol construction requires a concrete conforming type')
    if actor == 'unknown' and owner_kind == 'actor' and kind in ('method','property'):
        actor = 'instance'
    setter_mutating = None
    if kind == 'static_property' or owner_kind == 'class' or re.search(r'\bnonmutating\s+set\b', decl):
        setter_mutating = False
    elif owner_kind in ('struct', 'enum') or re.search(r'(?<!non)\bmutating\s+set\b', decl):
        setter_mutating = True
    async_,throws=_call_effects(decl,kind)
    return API(symbol['identifier']['precise'], module, path, kind, tuple(params), result,
               tuple(symbol.get('availability', [])), tuple(dict.fromkeys(reasons)),
               async_,throws,
               bool(re.search(r'\{\s*get\s+(?:(?:nonmutating|mutating)\s+)?set\s*\}', decl)),
               bool(re.search(r'\boptional\s+func\b', decl)) or (kind == 'property' and bool(re.search(r'\boptional\b', decl))), ((kind == 'method' and bool(re.search(r'\bmutating\b', decl))) or (kind == 'property' and bool(re.search(r'\bmutating\s+get\b', decl)))), owner_kind, setter_mutating, actor)


def _concrete_self_type(source, owner):
    """Resolve value-type Self leaves; dependent members remain unsupported."""
    if not re.search(r'\bSelf\b', source): return source
    replacement=parse_type(owner)
    def walk(node):
        if node.name.startswith('Self.'):
            raise ValueError('Dependent Self member requires indexed type identity')
        if node.name=='Self':
            if node.arguments or node.labels or node.effects or node.attributes:
                raise ValueError('Invalid Self type structure')
            return make_optional(replacement) if node.optional else replacement
        return replace(node,arguments=tuple(walk(child) for child in node.arguments))
    return spelling(walk(parse_type(source)))


def _validate_signature(api):
    if api.kind == 'constructor' and api.owner_kind == 'protocol':
        raise ValueError('Protocol construction requires a concrete conforming type')
    if any(re.search(r'\bSelf\b',typ) for typ in [api.result]+[parameter.type for parameter in api.parameters]):
        raise ValueError('Self requires concrete nominal owner resolution')
    _identifier(api.module); _typename(api.result)
    if not isinstance(api.required_imports,tuple) or len(api.required_imports)>32:
        raise ValueError('Required imports must contain at most 32 module names')
    for module in api.required_imports: _identifier(module)
    if api.actor_isolation != 'instance' and not _valid_actor_context(api.actor_isolation):
        raise ValueError('Invalid actor isolation')
    if api.owner_kind not in ('unknown', 'class', 'struct', 'enum', 'protocol', 'actor'):
        raise ValueError('Invalid owner kind')
    if api.setter_mutating is not None and type(api.setter_mutating) is not bool:
        raise ValueError('Invalid setter mutability')
    if api.actor_isolation == 'instance' and (api.owner_kind != 'actor' or api.kind not in ('method','property')):
        raise ValueError('Instance isolation requires an actor instance member')
    if api.owner_kind == 'class' and api.setter_mutating is True:
        raise ValueError('Class setter cannot mutate its receiver binding')
    if api.kind not in _KINDS.values() or not api.path:
        raise ValueError('Unsupported member kind or missing path')
    for part in api.path[:-1]: _identifier(part)
    title = api.path[-1]
    name = title.partition('(')[0]; _identifier(name)
    if api.kind != 'function' and len(api.path) < 2:
        raise ValueError('Missing receiver type')
    if api.kind == 'constructor' and name != 'init':
        raise ValueError('Constructor must identify init')
    for param in api.parameters:
        if type(param.inout) is not bool or (param.inout and param.escaping):
            raise ValueError('Invalid inout parameter contract')
        if type(param.escaping) is not bool:
            raise ValueError('Parameter escaping flag must be boolean')
        if type(param.autoclosure) is not bool:
            raise ValueError('Parameter autoclosure flag must be boolean')
        if param.autoclosure:
            callback = parse_type(param.type)
            if param.inout or callback.name != '$function' or callback.optional or len(callback.arguments) != 1 or callback.effects or callback.attributes:
                raise ValueError('Autoclosure requires a synchronous nonthrowing zero-argument callback')
        _typename(param.type); _identifier(param.name)
        if param.label != '_': _identifier(param.label)
    if api.kind.endswith('property'):
        if api.parameters or title != name or (api.optional_call and api.kind != 'property'):
            raise ValueError('Invalid property signature')
    elif title != name + '(' + ''.join(p.label + ':' for p in api.parameters) + ')':
        raise ValueError('Callable title and parameter labels disagree')
    for flag in (api.async_, api.throws, api.writable, api.optional_call, api.mutating):
        if type(flag) is not bool: raise ValueError('Invalid SDK boolean flag')
    for entry in api.availability:
        if not isinstance(entry, dict) or not isinstance(entry.get('domain'), str):
            raise ValueError('Invalid availability descriptor')
        for key in ('introduced', 'obsoleted', 'deprecated'):
            if key in entry:
                version = entry[key]
                if not isinstance(version, dict) or 'major' not in version or set(version) - {'major', 'minor', 'patch'} or any(type(x) is not int or x < 0 for x in version.values()):
                    raise ValueError('Invalid availability version')
        for key in ('isUnconditionallyUnavailable', 'isUnconditionallyDeprecated'):
            if key in entry and type(entry[key]) is not bool:
                raise ValueError('Invalid availability flag')


def _validate_owner_contract(api):
    if not isinstance(api.owner_parameters,tuple) or len(api.owner_parameters)>32 or len(set(api.owner_parameters))!=len(api.owner_parameters):
        raise ValueError('Invalid generic owner parameters')
    for name in api.owner_parameters: _identifier(name)
    if not isinstance(api.owner_constraints,tuple) or len(api.owner_constraints)>128:
        raise ValueError('Invalid generic owner constraints')
    for constraint in api.owner_constraints:
        if len(constraint)!=3 or any(not isinstance(value,str) for value in constraint):
            raise ValueError('Invalid generic owner constraint')
        kind,lhs,rhs=constraint
        if kind not in ('conformance','sameType','superclass') or not lhs or not rhs or len(lhs)>1024 or len(rhs)>1024:
            raise ValueError('Invalid generic owner constraint')
    _class_fact_validation(api.class_facts)
    if any(f['module']!=api.module for f in api.class_facts):raise ValueError('Class facts must belong to the descriptor source module')
    if api.class_facts and not any(k=='conformance' and rhs in ('AnyObject','Swift.AnyObject') for k,lhs,rhs in api.owner_constraints):raise ValueError('Class facts require a class-bound owner')
    if api.generic_owner:
        _identifier(api.generic_owner)
        if api.path[0]!=api.generic_owner:
            raise ValueError('Generic owner path mismatch')
    if api.owner_parameters and len(api.path)!=2 and not api.generic_owner:
        raise ValueError('Nested generic owner specialization is unsupported')


def _owner_declaration_constraints(declaration,parameters,structured):
    """Retain declaration-only requirements; unknown syntax cannot weaken a contract."""
    clauses=[]
    def split(text):
        result=[];start=0;depth=0
        for i,char in enumerate(text):
            if char in '<([':depth+=1
            elif char in '>)]':
                depth-=1
                if depth<0:raise ValueError('Unbalanced generic requirement')
            elif char==',' and depth==0:result.append(text[start:i].strip());start=i+1
        if depth:raise ValueError('Unbalanced generic requirement')
        result.append(text[start:].strip())
        if any(not part for part in result):raise ValueError('Empty generic requirement')
        return result
    where=re.search(r'\bwhere\b',declaration)
    head=declaration[:where.start()] if where else declaration
    if where:clauses+=split(declaration[where.end():].strip())
    start=head.find('<')
    if start>=0:
        depth=0;end=None
        for i in range(start,len(head)):
            if head[i]=='<':depth+=1
            elif head[i]=='>':
                depth-=1
                if depth==0:end=i;break
        if end is None:raise ValueError('Unbalanced generic parameter list')
        for param in split(head[start+1:end]):
            if ':' in param:clauses.append(param)
            elif param not in parameters and not any(re.fullmatch(r'each\s+'+re.escape(name),param) for name in parameters):raise ValueError('Unresolved generic parameter syntax')
    constraints=list(structured)
    compact=lambda value:re.sub(r'\s+','',value)
    for clause in clauses:
        match=re.fullmatch(r'([A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*)\s*(:|==)\s*(.+)',clause)
        if not match:raise ValueError('Unresolved declaration generic requirement')
        lhs,operation,rhs=match.groups();rhs=rhs.strip()
        if lhs.split('.')[0] not in parameters:raise ValueError('Unknown requirement parameter')
        if any(l==lhs and compact(r)==compact(rhs) and (k=='sameType')==(operation=='==') for k,l,r in structured):continue
        if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*',rhs):
            raise ValueError('Unresolved declaration generic requirement type')
        constraints.append(('sameType' if operation=='==' else 'conformance',lhs,rhs))
    return tuple(dict.fromkeys(constraints))


def _class_fact_validation(facts):
    if not isinstance(facts,tuple) or len(facts)>128:raise ValueError('Class facts exceed bounded source index')
    seen=set()
    for fact in facts:
        if not isinstance(fact,dict) or set(fact)!={'id','module','spelling','kind','availability','sourceSHA256'}:raise ValueError('Invalid SDK class fact')
        if fact['kind']!='class' or not isinstance(fact['id'],str) or not fact['id']:raise ValueError('Expected exact SDK class identity')
        _identifier(fact['module']);_identifier(fact['spelling'])
        if not isinstance(fact['sourceSHA256'],str) or not re.fullmatch('[0-9a-f]{64}',fact['sourceSHA256']):raise ValueError('Invalid SDK class source digest')
        key=(fact['module'],fact['spelling'],fact['id'],fact['sourceSHA256'])
        if key in seen:raise ValueError('Duplicate SDK class fact')
        seen.add(key)
        if not isinstance(fact['availability'],(list,tuple)):raise ValueError('Invalid SDK class availability')
        # Reuse the signature validator's complete availability checks.
        probe=API('class-fact',fact['module'],('probe()',),'function',(),'Void',tuple(fact['availability']),())
        _validate_signature(probe)


def _available_class(fact,version):
    for entry in fact['availability']:
        if entry.get('domain') not in ('iOS','*','Swift'):continue
        if entry.get('isUnconditionallyUnavailable'):return False
        if entry.get('domain')=='Swift' and entry.get('obsoleted',{}).get('major',999)<=6:return False
        if entry.get('domain')=='iOS':
            for key,reject in [('introduced',lambda v:tuple(version)<v),('obsoleted',lambda v:tuple(version)>=v)]:
                if key in entry:
                    v=entry[key]
                    if reject((v.get('major',0),v.get('minor',0))):return False
    return True


def _known_conformance(typ,protocol):
    # Compiler-owned evidence for Swift standard-library scalar conformances.
    # Arbitrary SDK/user conformances require a future indexed proof contract.
    primitives={'Bool','String','Character','Int','Int8','Int16','Int32','Int64','UInt','UInt8','UInt16','UInt32','UInt64','Float','Double'}
    return protocol in ('Hashable','Sendable','Swift.Hashable','Swift.Sendable') and not typ.arguments and not typ.optional and typ.name.removeprefix('Swift.') in primitives


class SDKCatalog:
    def __init__(self, apis):
        from ..ios_native_variants import collect, REQUIRED
        self.variants = collect(apis)
        self.apis = {identity: (next(iter(group.values())) if len(group) == 1 else
                     replace(next(iter(group.values())), unsupported=(REQUIRED,)))
                     for identity, group in self.variants.items()}

    @classmethod
    def from_symbolgraphs(cls, paths, module, *, type_graphs=None):
        _identifier(module)
        paths = tuple(Path(path) for path in paths)
        imported_types = {}; bridges = {}
        from ..ios_bridge_types import bridge_contracts, validate_contracts
        for dependency, dependency_paths in sorted((type_graphs or {}).items()):
            _identifier(dependency)
            dependency_paths=tuple(dependency_paths)
            for key,contract in bridge_contracts(dependency_paths,dependency).items():
                if key in bridges and bridges[key]!=contract:raise ValueError('Conflicting imported bridge pair')
                bridges[key]=contract
            for dependency_path in dependency_paths:
                dependency_path = Path(dependency_path)
                digest = hashlib.sha256(dependency_path.read_bytes()).hexdigest()
                for nominal in symbols(dependency_path):
                    if nominal.get('kind', {}).get('identifier') not in ('swift.class', 'swift.struct', 'swift.enum', 'swift.protocol', 'swift.actor', 'swift.typealias'):
                        continue
                    name = nominal.get('pathComponents', [])
                    if not name or any(not _IDENT.fullmatch(part) for part in name): continue
                    precise = nominal['identifier']['precise']
                    record = {'id': precise, 'module': dependency, 'spelling': '.'.join(name), 'sourceSHA256': digest}
                    prior = imported_types.get(precise)
                    if prior and (prior[0][0]['module'], prior[0][0]['spelling']) != (dependency, record['spelling']):
                        raise ValueError('Conflicting imported type identity: ' + precise)
                    # Overlay graphs may add constraints to the same nominal.
                    # Retain every contributing source and intersect availability.
                    records = {item['sourceSHA256']: item for item in prior[0]} if prior else {}
                    records[digest] = record
                    availability = (prior[1] if prior else ()) + tuple(nominal.get('availability', []))
                    imported_types[precise] = (tuple(records[key] for key in sorted(records)), availability)
        # Two streaming passes: collect nominal owners without retaining SDK members.
        owners = {}; actors = {}; global_actors = {}; nominal_symbols = []; generic_owners = set(); generic_contracts = {}; generic_identities = {}; generic_issues = {}; class_facts = []
        type_availability = {}; owner_availability = {}; graph_imports = {}; extension_imports = {}
        for path in paths:
            source_hash=hashlib.sha256(path.read_bytes()).hexdigest()
            metadata={}
            for symbol in symbols(path,metadata=metadata):
                extension = symbol.get('swiftExtension', {})
                if not isinstance(extension, dict):
                    raise ValueError('Malformed Swift extension metadata')
                if 'extendedModule' in extension:
                    imported = extension['extendedModule']; _identifier(imported)
                    precise = symbol['identifier']['precise']
                    if precise in extension_imports and extension_imports[precise] != imported:
                        raise ValueError('Conflicting extension module for precise SDK identity')
                    extension_imports[precise] = imported
                kind = symbol.get('kind', {}).get('identifier', '').removeprefix('swift.')
                if kind in ('class', 'struct', 'enum', 'protocol', 'actor', 'typealias'):
                    availability = tuple(symbol.get('availability', []))
                    precise = symbol['identifier']['precise']
                    type_availability[precise] = type_availability.get(precise, ()) + availability
                    path_key = tuple(symbol.get('pathComponents', []))
                    owner_availability[path_key] = owner_availability.get(path_key, ()) + availability
                if kind in ('class', 'struct', 'enum', 'protocol', 'actor'):
                    nominal_symbols.append({key: symbol.get(key, []) for key in ('pathComponents', 'declarationFragments')})
                    owner = tuple(symbol.get('pathComponents', []))
                    if re.search(r'\bactor\s+[A-Za-z_]', _text(symbol.get('declarationFragments', []))):
                        kind = 'actor'
                    owners[owner] = kind if owner not in owners or owners[owner] == kind else 'unknown'
                    nominal_declaration=_text(symbol.get('declarationFragments',[]))
                    if owner and re.search(r'\b(?:class|struct|enum|actor)\s+'+re.escape(owner[-1])+r'\s*<',nominal_declaration) and not symbol.get('swiftGenerics',{}).get('parameters'):
                        generic_owners.add(owner);generic_issues[owner]='Generic declaration requires precise parameter identity metadata'
                    if kind != 'protocol' and symbol.get('swiftGenerics', {}).get('parameters'):
                        generic_owners.add(owner)
                        contract=symbol['swiftGenerics']
                        identities=tuple((p['depth'],p['index'],p['name']) for p in sorted(contract['parameters'],key=lambda p:(p['depth'],p['index'])))
                        if owner in generic_identities and generic_identities[owner]!=identities:
                            raise ValueError('Conflicting generic owner parameter identities')
                        generic_identities[owner]=identities
                        parameters=tuple(p['name'] for p in sorted(contract['parameters'],key=lambda p:(p['depth'],p['index'])))
                        constraints=tuple((c['kind'],c['lhs'],c['rhs']) for c in contract.get('constraints',[]))
                        try:constraints=_owner_declaration_constraints(_text(symbol.get('declarationFragments',[])),parameters,constraints)
                        except ValueError as error:generic_issues[owner]='Generic declaration requires structural lowering: '+str(error)
                        previous=generic_contracts.get(owner)
                        if previous and previous[0]!=parameters:
                            raise ValueError('Conflicting generic owner parameters')
                        generic_contracts[owner]=(parameters,tuple(dict.fromkeys((previous[1] if previous else ())+constraints)))
                    if kind=='class' and len(owner)==1 and owner[0] and _IDENT.fullmatch(owner[0]) and not symbol.get('swiftGenerics',{}).get('parameters'):
                        class_facts.append({'id':symbol['identifier']['precise'],'module':module,'spelling':owner[0],'kind':'class','availability':list(symbol.get('availability',[])),'sourceSHA256':source_hash})
                    declaration=_text(symbol.get('declarationFragments',[]))
                    if re.search(r'@globalActor\b', declaration) and owner and all(_IDENT.fullmatch(p) for p in owner):
                        global_actors[symbol['identifier']['precise']] = 'global:' + module + '.' + '.'.join(owner)
            graph_module=metadata.get('module',{})
            if not isinstance(graph_module,dict): raise ValueError('Malformed symbol graph module metadata')
            bystanders=graph_module.get('bystanders',[])
            if not isinstance(bystanders,list) or len(bystanders)>32:
                raise ValueError('Graph bystanders must be a bounded module list')
            for imported in bystanders:
                if not isinstance(imported,str): raise ValueError('Graph bystander must be a module name')
                _identifier(imported)
            graph_imports[path]=tuple(sorted(set(bystanders)-{module}))
        class_facts=tuple(sorted((f for f in class_facts if owners.get((f['spelling'],))=='class' and (f['spelling'],) not in generic_owners),key=lambda f:(f['module'],f['spelling'],f['id'],f['sourceSHA256'])))
        for symbol in nominal_symbols:
            isolation = _actor_isolation(symbol, global_actors)
            if isolation != 'unknown':
                actors[tuple(symbol.get('pathComponents', []))] = isolation
        def with_signature_availability(symbol):
            # Symbol graphs can date a member earlier than its receiver or a
            # referenced signature type. All those availability constraints must
            # hold before the generated Swift declaration can be typechecked.
            availability = list(symbol.get('availability', []))
            owner = tuple(symbol.get('pathComponents', []))[:-1]
            for length in range(1, len(owner) + 1):
                availability.extend(owner_availability.get(owner[:length], ()))
            def fragments(value):
                if isinstance(value, dict):
                    if value.get('kind') == 'typeIdentifier':
                        availability.extend(type_availability.get(value.get('preciseIdentifier'), ()))
                    for child in value.values(): fragments(child)
                elif isinstance(value, list):
                    for child in value: fragments(child)
            fragments(symbol.get('declarationFragments', []))
            fragments(symbol.get('functionSignature', {}))
            unique = {json.dumps(entry, sort_keys=True): entry for entry in availability}
            return {**symbol, 'availability': list(unique.values())}
        def descriptor(symbol, bystanders):
            resolved = {}; additional_availability = []; bridge_evidence = {}
            def rewrite(value):
                if isinstance(value, dict):
                    imported = imported_types.get(value.get('preciseIdentifier')) if value.get('kind') == 'typeIdentifier' else None
                    if imported:
                        provenance, availability = imported
                        record = provenance[0]
                        spelling = value.get('spelling', '')
                        bridge=bridges.get((value.get('preciseIdentifier'),spelling))
                        if bridge and spelling not in (record['spelling'],record['spelling'].split('.')[-1]):
                            bridge_evidence[(value['preciseIdentifier'],spelling)]=bridge
                            for role in ('reference','value','alias'):
                                for item in bridge[role]:
                                    source={k:item[k] for k in ('id','module','spelling','sourceSHA256')}
                                    resolved[(source['id'],source['sourceSHA256'])]=source
                                    additional_availability.extend(item['availability'])
                            # Preserve the member's exposed Swift value spelling;
                            # Objective-C and Swift nominal identities stay distinct.
                            return dict(value)
                        additional_availability.extend(availability)
                        for source in provenance:
                            resolved[(source['id'], source['sourceSHA256'])] = source
                        # Already canonical nested fragments retain their owner
                        # tokens. Only an exact, standalone obsolete token moves.
                        if spelling not in (record['spelling'], record['spelling'].split('.')[-1]) and _IDENT.fullmatch(spelling):
                            return {**value, 'spelling': record['spelling']}
                    return {key: rewrite(child) for key, child in value.items()}
                if isinstance(value, list): return [rewrite(child) for child in value]
                return value
            normalized = dict(symbol)
            for key in ('declarationFragments', 'functionSignature'):
                if key in symbol: normalized[key] = rewrite(symbol[key])
            normalized = with_signature_availability(normalized)
            normalized['availability'].extend(additional_availability)
            api = _descriptor(normalized, module, owners, actors, global_actors)
            owner = tuple(symbol.get('pathComponents', []))[:-1]
            declaration=_text(normalized.get('declarationFragments',[]))
            signature_types=[api.result]+[parameter.type for parameter in api.parameters]
            if (api.unsupported==('polymorphic or ownership signature requires lowering',)
                    and api.owner_kind in ('struct','enum')
                    and not any(owner[:length] in generic_owners for length in range(1,len(owner)+1))
                    and not re.search(r'\b(some|rethrows)\b|\bSelf\s*\.',declaration)
                    and any(re.search(r'\bSelf\b',typ) for typ in signature_types)
                    and not any(re.search(r'\bSelf\s*\.',typ) for typ in signature_types)):
                api=replace(api,parameters=tuple(replace(parameter,type=_concrete_self_type(parameter.type,api.owner)) for parameter in api.parameters),
                            result=_concrete_self_type(api.result,api.owner),unsupported=())

            if any(owner[:length] in generic_owners for length in range(1, len(owner) + 1)):
                api = replace(api, unsupported=tuple(dict.fromkeys((*api.unsupported, 'generic owner requires explicit specialization'))))
                if len(owner)==1 and owner in generic_contracts:
                    api=replace(api,owner_parameters=generic_contracts[owner][0],owner_constraints=generic_contracts[owner][1])
                elif owner[:1] in generic_contracts and owner in generic_contracts:
                    parent=generic_contracts[owner[:1]]; child=generic_contracts[owner]
                    if parent[0]==child[0] and len(set(child[0]))==len(child[0]) and generic_identities[owner[:1]]==generic_identities[owner]:
                        api=replace(api,owner_parameters=child[0],owner_constraints=tuple(dict.fromkeys(parent[1]+child[1])),generic_owner=owner[0])
            issues=[reason for path,reason in generic_issues.items() if owner[:len(path)]==path]
            if issues:api=replace(api,unsupported=tuple(dict.fromkeys(api.unsupported+tuple(issues))))
            if any(k=='conformance' and rhs in ('AnyObject','Swift.AnyObject') for k,lhs,rhs in api.owner_constraints):
                if len(class_facts)>128:api=replace(api,unsupported=api.unsupported+('Class-bound owner needs a bounded source class index (maximum128facts)',))
                else:api=replace(api,class_facts=class_facts)
            records = tuple(resolved[key] for key in sorted(resolved))
            required = {record['module'] for record in records} | set(bystanders)
            if api.id in extension_imports: required.add(extension_imports[api.id])
            contracts=tuple(bridge_evidence[k] for k in sorted(bridge_evidence))
            validate_contracts(contracts,required)
            return replace(api, required_imports=tuple(sorted(required - {module})), type_resolutions=records,bridge_resolutions=contracts)
        return cls(descriptor(symbol,graph_imports[path]) for path in paths for symbol in symbols(path))

    @classmethod
    def from_records(cls, records):
        from ..ios_native_variants import validate_identity, identity, canonical, MAX_RECORD_BYTES, MAX_VARIANTS, REQUIRED
        apis = []
        expanded = []
        legacy_contracts = {}
        for record in records:
            if isinstance(record, dict) and 'nativeVariants' in record:
                children = record['nativeVariants']
                if (record.get('emittable') is not False or record.get('unsupportedReasons') != [REQUIRED]
                        or not isinstance(children, list) or not 2 <= len(children) <= MAX_VARIANTS
                        or len(canonical(record).encode()) > MAX_RECORD_BYTES
                        or 'nativeConformance' in record or 'nativeTested' in record):
                    raise ValueError('Invalid native variant parent')
                seen = set()
                for child in children:
                    if (not isinstance(child, dict) or 'nativeVariants' in child
                            or child.get('id') != record.get('id') or child.get('module') != record.get('module')
                            or child.get('platform') != 'ios' or 'variant' not in child):
                        raise ValueError('Native variant child identity mismatch')
                    selected = validate_identity(child['variant'])
                    if selected in seen: raise ValueError('Duplicate native variant identity')
                    seen.add(selected)
                    expanded.append(child)
            else:
                expanded.append(record)
        for r in expanded:
            if not isinstance(r, dict):
                raise ValueError('SDK descriptor must be an object')
            for flag in ('emittable', 'async', 'throws', 'writable', 'optionalCall', 'mutating'):
                if flag in r and type(r[flag]) is not bool:
                    raise ValueError('SDK flag must be boolean: ' + flag)
            if r.get('platform', 'ios') != 'ios':
                raise ValueError('Expected an iOS SDK descriptor')
            try:
                imports=r.get('requiredImports',[])
                if not isinstance(imports,(list,tuple)) or len(imports)>32:
                    raise ValueError('Invalid required imports')
                for module in imports: _identifier(module)
                resolutions = r.get('typeResolutions', [])
                if not isinstance(resolutions, (list, tuple)) or len(resolutions) > 256:
                    raise ValueError('Invalid type resolution provenance')
                for resolution in resolutions:
                    if not isinstance(resolution, dict) or set(resolution) != {'id', 'module', 'spelling', 'sourceSHA256'}:
                        raise ValueError('Invalid type resolution provenance')
                    if not isinstance(resolution['id'], str) or not resolution['id']:
                        raise ValueError('Invalid resolved type identity')
                    _identifier(resolution['module'])
                    if resolution['module'] not in imports or not isinstance(resolution['spelling'], str) or not all(_IDENT.fullmatch(part) for part in resolution['spelling'].split('.')):
                        raise ValueError('Invalid resolved type spelling/import')
                    if not isinstance(resolution['sourceSHA256'], str) or not re.fullmatch('[0-9a-f]{64}', resolution['sourceSHA256']):
                        raise ValueError('Invalid resolved type source digest')
                from ..ios_bridge_types import validate_contracts
                bridge_evidence=validate_contracts(r.get('bridgeResolutions',()),imports)
                path = r.get('path', ([x for x in r['owner'].split('.') if x] + [r['name']]))
                if not isinstance(path, (list, tuple)) or any(not isinstance(x, str) for x in path):
                    raise ValueError('Invalid SDK path')
                reasons = r['unsupportedReasons']
                if not isinstance(reasons, (list, tuple)) or any(not isinstance(x, str) for x in reasons):
                    raise ValueError('Invalid unsupported reasons')
                reasons = list(reasons)
                if r.get('emittable') is False and not reasons:
                    reasons.append('Descriptor explicitly disables emission')
                certification = r.get('nativeConformance', {})
                if certification.get('status') in ('rejected', 'skipped') and (not reasons or reasons == ['generic owner requires explicit specialization']):
                    reasons.append('Native conformance rejected this descriptor')
                if not isinstance(r.get('ownerParameters',()),(list,tuple)) or not isinstance(r.get('ownerConstraints',()),(list,tuple)):
                    raise ValueError('Invalid generic owner metadata')
                api = API(r['id'], r['module'], tuple(path), r['kind'],
                          tuple(Parameter(**p) for p in r['parameters']), r['resultType'],
                          tuple(r['availability']), tuple(reasons), r.get('async', False),
                          r.get('throws', False), r.get('writable', False),
                          r.get('optionalCall', False), r.get('mutating', False),
                          r.get('ownerKind', 'unknown'), r.get('setterMutating'), r.get('actorIsolation','unknown'),tuple(imports),tuple(resolutions),tuple(r.get('ownerParameters',())),tuple(tuple(c) for c in r.get('ownerConstraints',())), '', r.get('genericOwner',''),tuple(r.get('ownerClassFacts',())),bridge_evidence)
                _validate_owner_contract(api)
            except (KeyError, TypeError, AttributeError) as error:
                raise ValueError('Malformed SDK descriptor') from error
            if not isinstance(api.id, str) or not api.id:
                raise ValueError('Missing precise SDK identity')
            if not api.unsupported:
                _validate_signature(api)
                if r.get('owner', api.owner) != api.owner or r.get('name', api.path[-1]) != api.path[-1]:
                    raise ValueError('Descriptor path disagrees with owner/name')
            if 'variant' in r and 'nativeConformance' in r:
                if not isinstance(r['nativeConformance'],dict) or r['nativeConformance'].get('variant') != r['variant']:
                    raise ValueError('Native evidence differs from selected variant')
            if 'variant' in r and validate_identity(r['variant']) != identity(api):
                raise ValueError('Native variant differs from descriptor contract')
            if 'variant' not in r:
                previous = legacy_contracts.get(api.id)
                if previous is not None and previous != api:
                    raise ValueError('Conflicting descriptors for precise SDK identity')
                legacy_contracts[api.id] = api
            apis.append(api)
        return cls(apis)

    def search(self, query, *, emittable_only=False):
        return [api for api in self.apis.values() if query.casefold() in '.'.join(api.path).casefold()
                and (not emittable_only or not api.unsupported)]

    def records(self):
        from ..ios_native_variants import envelope
        return (envelope(identity, group) if len(group) > 1 else next(iter(group.values())).to_dict()
                for identity in self.apis for group in (self.variants[identity],))

    def get(self, precise_id, variant=None):
        from ..ios_native_variants import validate_identity, REQUIRED
        group = self.variants[precise_id]
        if variant is not None:
            validate_identity(variant)
            if variant not in group: raise ValueError('Unknown native variant for precise SDK identity')
            return group[variant]
        if len(group) != 1: raise ValueError(REQUIRED)
        return next(iter(group.values()))

    def select(self, precise_id, variant=None):
        """An explicit singleton view; does not rewrite the selected call contract."""
        return SDKCatalog([self.get(precise_id, variant)])

    def variant_records(self, precise_id):
        return [{**api.to_dict(), 'variant': key} for key, api in self.variants[precise_id].items()]

    def coverage(self):
        return {'indexed': len(self.apis), 'emittable_signatures': sum(not api.unsupported for api in self.apis.values()),
                'native_tested': None, 'variants_indexed':sum(len(self.variants[key]) for key in self.apis),
                'ambiguous_parent_ids':sum(len(self.variants[key])>1 for key in self.apis),
                'variant_emittable_signatures':sum(not api.unsupported for key in self.apis for api in self.variants[key].values())}

    def specialize(self, precise_id, receiver=None):
        api=self.get(precise_id)
        if not api.owner_parameters: return api
        _validate_owner_contract(api)
        if api.unsupported != ('generic owner requires explicit specialization',):
            raise ValueError('; '.join(api.unsupported) or 'Missing generic owner specialization contract')
        if api.kind not in ('method','property') or not isinstance(receiver,Reference):
            raise ValueError('Generic owner requires an explicitly typed instance receiver')
        typ=parse_type(receiver.type)
        if api.generic_owner:
            members=[]
            while typ.name=='$member' and not typ.optional:
                parent,member=typ.arguments
                if member.arguments or member.optional:
                    raise ValueError('Nested generic parameter scope requires precise identity lowering')
                members.insert(0,member.name);typ=parent
            if '.'.join([typ.name]+members)!=api.owner:
                raise ValueError('Receiver nested generic owner mismatch')
        if typ.name!=(api.generic_owner or api.owner) or typ.optional or len(typ.arguments)!=len(api.owner_parameters):
            raise ValueError('Receiver generic owner or argument arity mismatch')
        bindings=dict(zip(api.owner_parameters,typ.arguments))
        selected_facts=[]
        for kind,lhs,rhs in api.owner_constraints:
            if kind=='conformance' and lhs in bindings and rhs in ('AnyObject','Swift.AnyObject'):
                typ=bindings[lhs]
                matches=[f for f in api.class_facts if typ.name in (f['spelling'],f['module']+'.'+f['spelling'])]
                if typ.arguments or typ.optional or typ.attributes or typ.effects or not matches or len({f['id'] for f in matches})!=1:
                    raise ValueError('Class constraint requires an indexed nongeneric SDK class: '+lhs)
                selected_facts.extend(matches);continue
            if kind!='conformance' or lhs not in bindings or not _known_conformance(bindings[lhs],rhs):
                raise ValueError('Generic constraint requires indexed native conformance proof: '+lhs+' '+kind+' '+rhs)
        def substitute(value):
            typ=parse_type(value)
            def walk(node):
                head, separator, suffix=node.name.partition('.')
                if separator and head in bindings:
                    if suffix!='Type' or node.arguments or node.labels or node.effects or node.attributes:
                        raise ValueError('Dependent generic member requires indexed type identity: '+node.name)
                    result=replace(node,name='$member',arguments=(bindings[head],replace(node,name='Type',optional=False)),optional=False)
                    return make_optional(result) if node.optional else result
                if node.name in bindings:
                    if node.arguments or node.labels or node.effects or node.attributes:
                        raise ValueError('Unsupported generic type substitution')
                    result=bindings[node.name]
                    return make_optional(result) if node.optional else result
                return replace(node,arguments=tuple(walk(child) for child in node.arguments))
            return spelling(walk(typ))
        return replace(api,parameters=tuple(replace(p,type=substitute(p.type)) for p in api.parameters),result=substitute(api.result),unsupported=(),specialized_owner=receiver.type,availability=api.availability+tuple(entry for fact in selected_facts for entry in fact['availability']))

    def probe_receiver(self,precise_id,ios_version=(18,0)):
        api=self.get(precise_id);_validate_owner_contract(api);arguments=[]
        for parameter in api.owner_parameters:
            class_bound=any(k=='conformance' and lhs==parameter and rhs in ('AnyObject','Swift.AnyObject') for k,lhs,rhs in api.owner_constraints)
            if class_bound:
                names=sorted({f['module']+'.'+f['spelling'] for f in api.class_facts})
                available=[name for name in names if all(_available_class(f,ios_version) for f in api.class_facts if f['module']+'.'+f['spelling']==name)]
                if not available:raise ValueError('No indexed class witness available at requested iOS target')
                arguments.append(available[0])
            else:arguments.append('Int')
        name=(api.generic_owner or api.owner)+'<'+', '.join(arguments)+'>'+('.'+'.'.join(api.path[1:-1]) if api.generic_owner else '')
        return Reference('receiver',name,mutable=api.mutating)

    def emit_call(self, precise_id, arguments=(), *, receiver=None, ios_version=(18, 0), allow_async=False, allow_throws=False, actor_context=None):
        return self._emit_member(precise_id, arguments, receiver=receiver, ios_version=ios_version, allow_async=allow_async, allow_throws=allow_throws, actor_context=actor_context)

    def _emit_member(self, precise_id, arguments=(), *, receiver=None, ios_version=(18, 0), allow_async=False, allow_throws=False, actor_context=None, assignment=False):
        api = self.specialize(precise_id,receiver)
        if api.unsupported:
            raise ValueError('; '.join(api.unsupported))
        _validate_signature(api)
        if not isinstance(ios_version, (tuple, list)) or len(ios_version) != 2 or any(type(x) is not int or x < 0 for x in ios_version):
            raise ValueError('iOS version must contain two nonnegative integers')
        ios_version = tuple(ios_version)
        if type(allow_async) is not bool or type(allow_throws) is not bool:
            raise ValueError('Async and throws context flags must be boolean')
        for entry in api.availability:
            if entry.get('domain') not in ('iOS', '*', 'Swift'):
                continue
            if entry.get('isUnconditionallyUnavailable'):
                raise ValueError('API unavailable on iOS')
            if entry.get('domain') == 'Swift' and entry.get('obsoleted', {}).get('major', 999) <= 6:
                raise ValueError('Obsolete Swift API spelling')
            if entry.get('domain') == 'iOS':
                for key, reject in [('introduced', lambda version: ios_version < version), ('obsoleted', lambda version: ios_version >= version)]:
                    if key in entry:
                        version = entry[key]; version = (version.get('major', 0), version.get('minor', 0))
                        if reject(version):
                            raise TargetAvailabilityError(key,ios_version,version)
        requires_await = not assignment and (api.async_ or api.actor_isolation == 'instance')
        if not assignment and (requires_await and not allow_async or api.throws and not allow_throws):
            raise ValueError('Caller must explicitly support async/throws')
        if len(arguments) != len(api.parameters):
            raise ValueError('Pass every parameter explicitly, including SDK defaults')
        if actor_context is not None and (not _valid_actor_context(actor_context) or actor_context == 'unknown'):
            raise ValueError('Invalid actor context')
        if api.actor_isolation=='main' and actor_context!='main':
            raise ValueError('MainActor API requires an explicit main actor context')
        if api.actor_isolation.startswith('global:') and actor_context != api.actor_isolation:
            raise ValueError('Global actor API requires matching actor context: ' + api.actor_isolation)
        instance = api.kind in ('method', 'property')
        protocol_static = api.owner_kind == 'protocol' and api.kind in ('static_method', 'static_property')
        if protocol_static:
            expected = 'any ' + api.owner + '.Type'
            if not isinstance(receiver, Reference) or receiver.type != expected:
                raise ValueError('Protocol static member requires a metatype binding of type ' + expected)
            if type(receiver.mutable) is not bool:
                raise ValueError('Receiver mutability must be boolean')
            target = _identifier(receiver.name) + '.'
        elif instance:
            if not isinstance(receiver, Reference) or receiver.type != api.owner:
                raise ValueError('Expected receiver binding of type ' + api.owner)
            if type(receiver.mutable) is not bool:
                raise ValueError('Receiver mutability must be boolean')
            if not assignment and api.mutating and not receiver.mutable:
                raise ValueError('Mutating API requires a mutable receiver binding')
            target = _identifier(receiver.name) + '.'
        elif receiver is not None:
            raise ValueError('Static calls and constructors do not take receivers')
        else:
            target = '.'.join(_identifier(p) for p in api.path[:-1])
            target = target + '.' if target else ''
        name = api.path[-1].partition('(')[0]
        if api.kind == 'constructor':
            expression = target.rstrip('.')
        else:
            expression = target + _identifier(name)
        if not api.kind.endswith('property'):
            args = []
            borrowed = set()
            for param, value in zip(api.parameters, arguments):
                rendered = _argument(value, param.type)
                if param.inout:
                    if not isinstance(value,Reference) or value.mutable is not True:
                        raise ValueError('Inout parameter requires a mutable reference')
                    if value.name in borrowed or (api.mutating and receiver and value.name==receiver.name):
                        raise ValueError('Overlapping inout access')
                    borrowed.add(value.name)
                    rendered = '&' + rendered
                elif param.autoclosure:
                    if not isinstance(value, Reference):
                        raise ValueError('Autoclosure requires a typed callback reference')
                    rendered += '()'
                elif isinstance(value, Literal):
                    rendered = '(' + rendered + ' as ' + param.type + ')'
                args.append(rendered if param.label == '_' else _identifier(param.label) + ': ' + rendered)
            expression += ('?' if api.optional_call else '') + '(' + ', '.join(args) + ')' 
        if api.optional_call:
            result = parse_type(api.result)
            if api.kind == 'property' or not is_optional(result):
                result = make_optional(result)
            result_type = spelling(result)
        else:
            result_type = api.result
        expression = ('try ' if api.throws and not assignment else '') + ('await ' if requires_await else '') + expression
        if not api.kind.endswith('property'):
            expression = '(' + expression + ' as ' + result_type + ')'
        return Emission(expression, result_type, public_imports({api.module,*api.required_imports}))

    def emit_set(self, precise_id, value, *, receiver=None, ios_version=(18, 0), actor_context=None):
        api = self.specialize(precise_id,receiver)
        if api.optional_call:
            raise ValueError('Optional Objective-C property assignment is unsupported')
        if api.actor_isolation == 'instance':
            raise ValueError('Actor-isolated properties must be mutated through actor methods')
        if not api.kind.endswith('property') or not api.writable:
            raise ValueError('SDK property does not expose a public setter')
        target = self._emit_member(precise_id, receiver=receiver, ios_version=ios_version,actor_context=actor_context,assignment=True)
        if api.kind == 'property':
            # Old normalized records have no owner evidence. Requiring a mutable
            # binding is conservative for both reference and value types.
            needs_mutable = api.setter_mutating is not False and api.owner_kind != 'class'
            if needs_mutable and not receiver.mutable:
                raise ValueError('Setter requires a mutable receiver binding (value type or unknown owner)')
        return Emission(target.expression + ' = ' + _argument(value, api.result), 'Void', target.imports)


def _argument(value, expected, _budget=None):
    expected_type = parse_type(expected)
    if _budget is None:
        _budget = [4096]
    _budget[0] -= 1
    if _budget[0] < 0:
        raise ValueError('Native literal exceeds 4096 values')
    if isinstance(value, Reference):
        _typename(value.type)
        if parse_type(value.type) != expected_type:
            raise ValueError('Argument type mismatch: expected ' + expected)
        return _identifier(value.name)
    if not isinstance(value, Literal):
        raise ValueError('Arguments must be Literal or Reference nodes')
    raw = value.value
    if raw is None and is_optional(expected_type):
        return 'nil'
    while is_optional(expected_type):
        expected_type = optional_inner(expected_type)
    expected = spelling(expected_type)
    if expected_type.name == 'Array' and type(raw) is list:
        element = spelling(expected_type.arguments[0])
        return '[' + ', '.join(_argument(Literal(item), element, _budget) for item in raw) + ']'
    if expected_type.name == 'Dictionary' and type(raw) is dict:
        key_type, value_type = map(spelling, expected_type.arguments)
        entries = [_argument(Literal(key), key_type, _budget) + ': ' +
                   _argument(Literal(item), value_type, _budget) for key, item in raw.items()]
        return '[' + (', '.join(entries) if entries else ':') + ']'
    expected = expected.removesuffix('?')
    if type(raw) is bool and expected == 'Bool':
        return 'true' if raw else 'false'
    if type(raw) is str and expected == 'String':
        if any(0xD800 <= ord(c) <= 0xDFFF for c in raw):
            raise ValueError('Swift strings require valid Unicode scalar values')
        # JSON Unicode escapes are not Swift escapes; keep Unicode literal and escape control characters explicitly.
        return '"' + ''.join('\\"' if c == '"' else '\\\\' if c == '\\' else '\\u{' + format(ord(c), 'x') + '}' if ord(c) < 32 or ord(c) in (127, 0x2028, 0x2029) else c for c in raw) + '"'
    if type(raw) is int and expected in ('Int', 'Int8', 'Int16', 'Int32', 'Int64', 'UInt', 'UInt8', 'UInt16', 'UInt32', 'UInt64'):
        unsigned = expected.startswith('U'); bits = int(re.sub('[^0-9]', '', expected) or '64')
        if not (0 if unsigned else -(2 ** (bits - 1))) <= raw < 2 ** (bits if unsigned else bits - 1):
            raise ValueError('Integer literal out of range')
        return str(raw)
    if type(raw) in (float, int) and expected in ('Double', 'Float', 'CGFloat', 'TimeInterval'):
        try:
            number = float(raw)
        except (OverflowError, ValueError) as error:
            raise ValueError('Floating literal out of range') from error
        if not math.isfinite(number) or expected == 'Float' and abs(number) > 3.4028234663852886e38:
            raise ValueError('Floating literal out of range')
        return str(number)
    raise ValueError('Literal is incompatible with ' + expected)


def parse_cli_value(value):
    """Decode a closed JSON value schema. Raw Swift expressions are never accepted."""
    if not isinstance(value, dict):
        raise ValueError("Expected a typed value object")
    if set(value) == {"literal"}:
        return Literal(value["literal"])
    if set(value) in ({"ref", "type"}, {"ref", "type", "mutable"}):
        _identifier(value["ref"]); _typename(value["type"])
        if type(value.get("mutable", False)) is not bool:
            raise ValueError("mutable must be boolean")
        return Reference(value["ref"], value["type"], value.get("mutable", False))
    raise ValueError("Expected {literal: value} or {ref: name, type: type}")
