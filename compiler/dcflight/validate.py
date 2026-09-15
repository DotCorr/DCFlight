import re
from .ir import Application, Action, ActionOperation, Literal, Node, Reference, ScalarType, State
from .registry import STYLE_PROPERTIES


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


def lower(data, registry):
    keys(data, ("version", "id", "name", "state", "actions", "root"), ("version", "id", "name", "root"), "app")
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

    raw_actions = data.get("actions", [])
    check(isinstance(raw_actions, list), "actions: expected array")
    actions = []
    seen_actions = set()
    for raw in raw_actions:
        keys(raw, ("id", "op", "target", "value"), ("id", "op"), "action")
        aid = identifier(raw["id"], "action.id")
        check(aid not in seen_actions, "duplicate action: " + aid)
        seen_actions.add(aid)
        op = raw["op"]
        check(op in ("increment", "set", "toggle", "native"), "unsupported action operation")
        target = raw.get("target")
        value = None
        if op == "native":
            check(set(raw) == {"id", "op"}, aid + ": native actions have no interpreted body")
        else:
            identifier(target, aid + ".target")
            check(target in state_types, aid + ": unknown target state")
            if op == "set":
                check("value" in raw, aid + ": set requires value")
                value = expr(raw["value"], aid + ".value")
                check(value.type == state_types[target], aid + ": incompatible assignment")
            else:
                check("value" not in raw, aid + ": unexpected value")
                expected = ScalarType.INT if op == "increment" else ScalarType.BOOL
                check(state_types[target] == expected, aid + ": incompatible target type")
        actions.append(Action(aid, ActionOperation(op), target, value))
    seen = set()

    def style(raw_style, path):
        keys(raw_style, tuple(STYLE_PROPERTIES), (), path + ": style")
        values = []
        for name, spec in sorted(STYLE_PROPERTIES.items()):
            if name not in raw_style:
                continue
            value = raw_style[name]
            if spec.get("color"):
                check(isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{8}", value) is not None,
                      path + "." + name + ": expected #RRGGBBAA color")
                values.append((name, Literal(value.lower(), ScalarType.STRING)))
            elif spec.get("enum"):
                check(isinstance(value, str) and value in spec["enum"], path + "." + name + ": expected one of " + ", ".join(spec["enum"]))
                values.append((name, Literal(value, ScalarType.STRING)))
            elif spec["type"] == "int":
                check(type(value) is int and spec["minimum"] <= value <= spec["maximum"],
                      path + "." + name + ": expected int in [" + str(spec["minimum"]) + ", " + str(spec["maximum"]) + "]")
                values.append((name, Literal(value, ScalarType.INT)))
            else:
                check(type(value) is bool, path + "." + name + ": expected bool")
                values.append((name, Literal(value, ScalarType.BOOL)))
        return tuple(values)

    def node(raw, depth=0):
        check(depth <= 100, "UI nesting exceeds 100")
        keys(raw, ("id", "type", "props", "children", "action", "style"), ("id", "type", "props"), "node")
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
            props.append((name, val))
        node_style = style(raw["style"], nid) if "style" in raw else ()
        children = raw.get("children", [])
        check(isinstance(children, list), nid + ": children must be an array")
        check(entry.get("children") or "children" not in raw, nid + ": does not accept children")
        action = raw.get("action")
        if entry.get("action"):
            identifier(action, nid + ".action")
            check(action in seen_actions, nid + ": unknown action")
        else:
            check("action" not in raw, nid + ": does not accept action")
        return Node(nid, raw["type"], tuple(props), tuple(node(c, depth + 1) for c in children), action, node_style)

    return Application(data["id"], data["name"], states, tuple(sorted(actions, key=lambda a: a.id)), node(data["root"]))
