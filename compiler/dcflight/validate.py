import re
from .ir import Application, Action, ActionOperation, Literal, Node, Reference, ScalarType, State, ABIType, LogicFunction, LogicModule, Service, Theme, ModuleReference
from .presentation import lower_style, lower_motion, ICONS
from .native_configuration import lower_native_configuration


class Diagnostic(ValueError):
    pass


def check(condition, message):
    if not condition:
        raise Diagnostic(message)


def keys(value, allowed, required, path):
    check(isinstance(value, dict), path + ": expected object")
    check(not (set(value) - set(allowed)), path + ": unknown fields " + str(set(value) - set(allowed)))
    check(set(required) <= set(value), path + ": missing fields " + str(set(required) - set(value)))


def identifier(value, path):
    check(isinstance(value, str) and len(value) <= 80 and re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", value) is not None,
          path + ": expected stable ASCII identifier")
    return value


def literal(value, path):
    types = {str: ScalarType.STRING, int: ScalarType.INT, bool: ScalarType.BOOL}
    check(type(value) in types, path + ": expected string, int or bool")
    if type(value) is int:
        check(-2147483648 <= value <= 2147483647, path + ": integer outside portable Int32 range")
    if type(value) is str:
        check(not any(0xD800 <= ord(c) <= 0xDFFF for c in value), path + ": invalid Unicode surrogate")
    return Literal(value, types[type(value)])


def lower_predicate(value, scalar, path):
    """Closed, bounded presentation conditions; never writable scalar expressions."""
    from .ir import StringIsEmpty, BooleanNot, BooleanAll, BooleanAny
    remaining = 256
    def visit(raw, at, depth):
        nonlocal remaining
        remaining -= 1
        check(depth <= 16, at + ": predicate nesting exceeds 16")
        check(remaining >= 0, at + ": predicate exceeds 256 nodes")
        if isinstance(raw, dict) and set(raw).intersection(('isEmpty', 'not', 'all', 'any')):
            check(len(raw) == 1, at + ": predicate requires exactly one operator")
            op = next(iter(raw)); operand = raw[op]
            if op == 'isEmpty':
                result = scalar(operand, at + '.isEmpty')
                check(result.type == ScalarType.STRING, at + ": isEmpty requires a string operand")
                return StringIsEmpty(result)
            if op == 'not':
                return BooleanNot(visit(operand, at + '.not', depth + 1))
            check(isinstance(operand, list) and 1 <= len(operand) <= 32, at + ": " + op + " requires 1..32 boolean operands")
            values = tuple(visit(v, at + '.' + op + '[' + str(i) + ']', depth + 1) for i, v in enumerate(operand))
            return (BooleanAll if op == 'all' else BooleanAny)(values)
        result = scalar(raw, at)
        check(result.type == ScalarType.BOOL, at + ": condition must be boolean")
        return result
    return visit(value, path, 0)


def lower(data, registry):
    if isinstance(data,dict) and type(data.get('version')) is int and data.get('version')==2:
        from .navigation_ir import lower_routed
        return lower_routed(data,registry)
    keys(data, ("version", "id", "name", "state", "actions", "root", "logic", "service", "theme", "modules", "nativeConfiguration"), ("version", "id", "name", "root"), "app")
    check(type(data["version"]) is int and data["version"] == 1, "app.version: only version 1 is supported")
    check(isinstance(data["id"], str) and re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", data["id"]) is not None, "app.id: expected reverse-domain identifier")
    reserved = {"class", "int", "native", "package", "default", "public", "private", "void", "new", "return", "switch", "for", "if", "else", "true", "false", "null", "import", "static", "enum", "this", "super", "try", "catch", "throw", "throws", "final", "abstract", "interface", "extends", "implements", "assert", "break", "case", "continue", "do", "double", "float", "long", "short", "byte", "char", "boolean", "synchronized", "transient", "volatile", "while", "instanceof", "const", "goto", "protected", "strictfp"}
    check(not set(data["id"].split('.')) & reserved, "app.id: reserved Java package segment")
    check(isinstance(data["name"], str) and 0 < len(data["name"]) <= 100, "app.name: expected 1–100 characters")
    literal(data["name"], "app.name")
    check(all(ord(c) >= 32 for c in data["name"]) and not data["name"].startswith(("@", "?")), "app.name: control characters and Android resource-reference prefixes are unsupported")
    raw_states = data.get("state", {})
    check(isinstance(raw_states, dict), "state: expected object")
    states = tuple(State(identifier(k, "state"), literal(v, "state." + k)) for k, v in sorted(raw_states.items()))
    state_types = {s.name: s.initial.type for s in states}

    def expr(value, path):
        if isinstance(value, dict):
            keys(value, ("ref",), ("ref",), path)
            name = identifier(value["ref"], path)
            check(name in state_types, path + ": unknown state " + name)
            return Reference(name, state_types[name])
        return literal(value, path)

    logic = None
    functions = {}
    if "logic" in data:
        raw_logic = data["logic"]
        keys(raw_logic, ("source", "prelude", "functions"), ("source", "prelude", "functions"), "logic")
        for path in ("source", "prelude"):
            check(isinstance(raw_logic[path], str) and raw_logic[path] and "\0" not in raw_logic[path], "logic." + path + ": expected path")
        check(isinstance(raw_logic["functions"], list) and raw_logic["functions"], "logic.functions: expected nonempty list")
        for function in raw_logic["functions"]:
            keys(function, ("name", "parameters", "returns", "maxOutputBytes"), ("name", "parameters", "returns"), "logic.function")
            name = identifier(function["name"], "logic.function.name")
            check(name not in functions, "duplicate logic function " + name)
            check(isinstance(function["parameters"], list), "logic.function.parameters: expected list")
            check(all(t in tuple(x.value for x in ABIType) for t in function["parameters"] + [function["returns"]]), "unsupported logic ABI type")
            capacity = function.get("maxOutputBytes")
            if function["returns"] == ABIType.UTF8.value:
                check(type(capacity) is int and 1 <= capacity <= 1048576, "utf8 result requires maxOutputBytes in 1..1048576")
            else:
                check("maxOutputBytes" not in function, "maxOutputBytes requires utf8 result")
            functions[name] = LogicFunction(name, tuple(ABIType(t) for t in function["parameters"]), ABIType(function["returns"]), capacity)
        logic = LogicModule(raw_logic["source"], raw_logic["prelude"], tuple(functions.values()))

    raw_actions = data.get("actions", [])
    check(isinstance(raw_actions, list), "actions: expected array")
    actions = []
    seen_actions = set()
    for raw in raw_actions:
        keys(raw, ("id", "op", "target", "value", "function", "args", "failure"), ("id", "op"), "action")
        aid = identifier(raw["id"], "action.id")
        check(aid not in seen_actions, "duplicate action: " + aid)
        seen_actions.add(aid)
        op = raw["op"]
        check(op in ("increment", "set", "toggle", "native", "call"), "unsupported action operation")
        target = raw.get("target")
        value = None
        function = None
        arguments = ()
        failure = None
        check(op == "call" or not ({"function", "args", "failure"} & set(raw)), aid + ": function/args/failure require call")
        if op == "native":
            check(set(raw) == {"id", "op"}, aid + ": native actions have no interpreted body")
        else:
            identifier(target, aid + ".target")
            check(target in state_types, aid + ": unknown target state")
            if op == "call":
                keys(raw, ("id", "op", "target", "function", "args", "failure"), ("id", "op", "target", "function", "args"), aid)
                function = identifier(raw["function"], aid + ".function")
                check(function in functions, aid + ": unknown logic function")
                signature = functions[function]
                if ABIType.UTF8 in signature.parameters or signature.returns == ABIType.UTF8:
                    check('failure' in raw, aid + ": utf8 call requires failure action")
                    failure = identifier(raw['failure'], aid + '.failure')
                else:
                    check('failure' not in raw, aid + ": failure requires utf8 input")
                check(ABIType.UINT64 not in signature.parameters and signature.returns != ABIType.UINT64, aid + ": uint64 requires generated record/buffer adapters, not portable Int32 state actions")
                check(isinstance(raw["args"], list) and len(raw["args"]) == len(signature.parameters), aid + ": incorrect logic argument count")
                arguments = tuple(expr(v, aid + ".args") for v in raw["args"])
                for argument, abi in zip(arguments, signature.parameters):
                    expected_argument = ScalarType.STRING if abi == ABIType.UTF8 else ScalarType.BOOL if abi == ABIType.BOOL else ScalarType.INT
                    check(argument.type == expected_argument, aid + ": incompatible logic argument")
                    if abi == ABIType.UINT32 and isinstance(argument, Literal):
                        check(argument.value >= 0, aid + ": unsigned argument cannot be negative")
                check(state_types[target] == (ScalarType.STRING if signature.returns == ABIType.UTF8 else ScalarType.BOOL if signature.returns == ABIType.BOOL else ScalarType.INT), aid + ": incompatible logic result")
            elif op == "set":
                check("value" in raw, aid + ": set requires value")
                value = expr(raw["value"], aid + ".value")
                check(value.type == state_types[target], aid + ": incompatible assignment")
            else:
                check("value" not in raw, aid + ": unexpected value")
                expected = ScalarType.INT if op == "increment" else ScalarType.BOOL
                check(state_types[target] == expected, aid + ": incompatible target type")
        actions.append(Action(aid, ActionOperation(op), target, value, function, arguments, failure))
    action_by_id = {action.id: action for action in actions}
    for action in actions:
        check(action.failure is None or action.failure in action_by_id, action.id + ': unknown failure action')
    done = set()
    for action in actions:
        active = set()
        current = action
        while current is not None and current.id not in done:
            check(current.id not in active, 'Synchronous action failure cycle: ' + current.id)
            active.add(current.id)
            current = action_by_id[current.failure] if current.failure is not None else None
        done.update(active)
    seen = set()

    def node(raw, depth=0):
        check(depth <= 100, "UI nesting exceeds 100")
        keys(raw, ("id", "type", "props", "children", "action", "style", "motion", "visibleWhen", "enabledWhen"), ("id", "type", "props"), "node")
        nid = identifier(raw["id"], "node.id")
        check(nid.casefold() not in seen, "duplicate node (case-insensitive): " + nid)
        seen.add(nid.casefold())
        check(isinstance(raw["type"], str), nid + ": expected capability string")
        entry = registry.get(raw["type"])
        keys(raw["props"], entry["properties"], (), nid + ".props")
        props = []
        for name, spec in sorted(entry["properties"].items()):
            check(name in raw["props"] or "default" in spec, nid + ": missing property " + name)
            val = expr(raw["props"].get(name, spec.get("default")), nid + "." + name)
            check(val.type.value == spec["type"], nid + ": wrong type for " + name)
            if spec.get("binding"):
                check(isinstance(val, Reference), nid + ": " + name + " requires a writable state reference")
            if spec.get("literal"):
                check(isinstance(val, Literal), nid + ": " + name + " requires a literal")
                identifier(val.value, nid + "." + name)
            if isinstance(val, Literal):
                if 'enum' in spec:
                    check(val.value in spec['enum'], nid + ': unsupported ' + name)
                if 'minimum' in spec:
                    check(spec['minimum'] <= val.value <= spec['maximum'], nid + ': out of range ' + name)
            props.append((name, val))
        children = raw.get("children", [])
        check(isinstance(children, list), nid + ": children must be an array")
        check(entry.get("children") or "children" not in raw, nid + ": does not accept children")
        if raw['type'] == 'scroll':
            check(len(children) == 1, nid + ': scroll requires exactly one child')
        if raw['type'] == 'tab':
            check(len(children) == 1, nid + ': tab requires exactly one child')
        if raw['type'] == 'tabs':
            check(1 <= len(children) <= 5 and all(c.get('type')=='tab' for c in children if isinstance(c,dict)), nid + ': tabs requires one to five tab children')
        action = raw.get("action")
        if entry.get("action"):
            identifier(action, nid + ".action")
            check(action in seen_actions, nid + ": unknown action")
        else:
            check("action" not in raw, nid + ": does not accept action")
        style = lower_style(raw['style'], check, nid + '.style') if 'style' in raw else None
        if style is not None:
            check(style.gap is None or raw['type'] in ('row','column','card'), nid+': gap only applies to row/column/card')
            check((style.font_size is None and style.font_weight is None) or raw['type'] in ('text','button','counter','textField','secureField','toggle'), nid+': font styling requires a text control')
            check(style.color is None or raw['type'] in ('text','button','counter','textField','secureField','toggle','icon','progress','progressBar'), nid+': foreground color is unsupported for this capability')
        motion = lower_motion(raw['motion'], check, nid + '.motion') if 'motion' in raw else None
        visible = lower_predicate(raw['visibleWhen'], expr, nid + '.visibleWhen') if 'visibleWhen' in raw else None
        check(visible is None or visible.type == ScalarType.BOOL, nid + ': visibleWhen must be boolean')
        enabled = lower_predicate(raw['enabledWhen'], expr, nid + '.enabledWhen') if 'enabledWhen' in raw else None
        check(enabled is None or enabled.type == ScalarType.BOOL, nid + ': enabledWhen must be boolean')
        return Node(nid, raw["type"], tuple(props), tuple(node(c, depth + 1) for c in children), action, style, motion, visible, enabled)

    service = None
    if 'service' in data:
        from urllib.parse import urlsplit
        raw = data['service']
        keys(raw, ('baseUrl','protocol','development'), ('baseUrl',), 'service')
        check(type(raw.get('development',False)) is bool, 'service.development: expected bool')
        check(raw.get('protocol','snap.v1') == 'snap.v1', 'unsupported service protocol')
        check(isinstance(raw['baseUrl'],str) and len(raw['baseUrl'])<=2048, 'service.baseUrl: expected URL')
        url = urlsplit(raw['baseUrl'])
        check(url.hostname is not None and not url.username and not url.password and not url.query and not url.fragment, 'service: invalid base URL')
        check(url.scheme == 'https' or (raw.get('development',False) and url.scheme=='http' and url.hostname in ('localhost','127.0.0.1')), 'service: HTTPS required outside explicit loopback development')
        check(not any(ord(c)<33 for c in raw['baseUrl']), 'service: invalid URL characters')
        service = Service(raw['baseUrl'].rstrip('/'),raw.get('protocol','snap.v1'),raw.get('development',False))
    theme = None
    if 'theme' in data:
        raw = data['theme']
        colors=('accent','background','surface','text','muted','danger')
        keys(raw, (*colors,'radius','padding'), (), 'theme')
        for key,value in raw.items():
            if key in colors:
                check(isinstance(value,str) and re.fullmatch(r'#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?',value) is not None, 'theme.'+key+': invalid RGBA color')
            else:
                check(type(value) is int and 0<=value<=128, 'theme.'+key+': invalid logical dimension')
        theme=Theme(**raw)
    modules=[]
    check(isinstance(data.get('modules',[]),list), 'modules: expected array')
    for item in data.get('modules',[]):
        keys(item,('id','platform','lock'),('id','platform','lock'),'module')
        check(isinstance(item['id'],str) and re.fullmatch(r'[A-Za-z][A-Za-z0-9_.-]{0,99}',item['id']), 'module: invalid id')
        check(item['platform'] in ('ios','android'), 'module: unsupported platform')
        check(isinstance(item['lock'],str) and 0<len(item['lock'])<=2048 and not any(ord(c)<32 for c in item['lock']), 'module: invalid lock path')
        check((item['id'],item['platform']) not in {(m.id,m.platform) for m in modules}, 'duplicate native module')
        modules.append(ModuleReference(**item))
    native_configuration = lower_native_configuration(data['nativeConfiguration']) if 'nativeConfiguration' in data else None
    app = Application(data["id"], data["name"], states, tuple(sorted(actions, key=lambda a: a.id)), node(data["root"]), logic=logic, service=service, theme=theme, modules=tuple(modules), native_configuration=native_configuration)
    features={'camera','inbox','stories','friendMap','account'}
    if any(n.capability in features for n in app.nodes()):
        check(service is not None, 'social capabilities require a declared service')
        check(not states and not actions, 'social state/actions binding is not implemented; shared policy functions are supported')
        for social_node in app.nodes():
            check(social_node.style is None and social_node.motion is None and social_node.visible_when is None, social_node.id+': social node presentation/visibility customization is not implemented; use application theme')
            if social_node.capability == 'tab':
                check(all(isinstance(value,Literal) for _,value in social_node.properties), social_node.id+': social tab properties require literals')
        required_policies={'canSendMessage':2,'canUploadPhoto':1,'remainingStorySeconds':1,'shouldPublishLocation':2}
        check(logic is not None, 'social capabilities require shared DC Dart policy functions')
        functions={f.name:f for f in logic.functions}
        for name,count in required_policies.items():
            check(name in functions and functions[name].returns==ABIType.UINT32 and functions[name].parameters==(ABIType.UINT32,)*count,
                  'social policy '+name+': expected '+str(count)+' uint32 parameters returning uint32')
        check(app.root.capability=='tabs', 'social features require a tabs root')
        kinds=[]
        for tab in app.root.children:
            check(tab.capability=='tab' and len(tab.children)==1 and tab.children[0].capability in features, 'social tabs require one feature per tab')
            kinds.append(tab.children[0].capability)
        check(len(kinds)==len(set(kinds)), 'duplicate social feature tab')
        check('account' in kinds, 'social app requires account controls for logout/privacy/deletion')
    elif any(n.capability in ('tabs','tab') for n in app.nodes()):
        check(False, 'generic tabs require a routing backend; currently use declared social features')
    elif service is not None:
        check(False, 'service requires social capabilities; generic service binding is not yet implemented')
    check(theme is None or service is not None, 'theme requires social service capabilities; use per-node style for generic apps')
    return app
