"""Reviewed mappings are separate from automatically imported API inventories."""
import json
from pathlib import Path
from .presentation import style_schema, MOTION_SCHEMA
from .predicate_schema import CONDITION_REF, definitions as predicate_definitions
from .native_configuration import schema as native_configuration_schema


# Reviewed development-time style vocabulary shared by every capability.
# Values are compile-time literals; nothing is interpreted at runtime.
STYLE_PROPERTIES = {
    "color": {"type": "string", "color": True},
    "fontSize": {"type": "int", "minimum": 1, "maximum": 96},
    "fontWeight": {"type": "string", "enum": ("regular", "medium", "semibold", "bold")},
    "backgroundColor": {"type": "string", "color": True},
    "padding": {"type": "int", "minimum": 0, "maximum": 64},
    "cornerRadius": {"type": "int", "minimum": 0, "maximum": 64},
    "spacing": {"type": "int", "minimum": 0, "maximum": 64},
    "alignment": {"type": "string", "enum": ("start", "center", "end")},
    "fillWidth": {"type": "bool"},
}


class Registry:
    def __init__(self, path=None):
        root = Path(path) if path else Path(__file__).parent / "data" / "capabilities.json"
        data = json.loads(root.read_text())
        if data.get("version") != 1:
            raise ValueError("Unsupported registry version")
        self.entries = {}
        for entry in data["capabilities"]:
            key = entry["id"]
            if key in self.entries:
                raise ValueError("Duplicate capability: " + key)
            if not {"ios", "android"} <= set(entry["targets"]):
                raise ValueError("Shared mappings require both native targets: " + key)
            self.entries[key] = entry

    def get(self, key):
        if key not in self.entries:
            raise ValueError("Unsupported capability: " + key)
        return self.entries[key]

    def search(self, query=""):
        return [entry for key, entry in sorted(self.entries.items())
                if query.lower() in json.dumps(entry).lower()]

    def schema(self):
        scalar = {"oneOf": [{"type": "string"}, {"type": "integer", "minimum": -2147483648, "maximum": 2147483647}, {"type": "boolean"}]}
        def expression(kind):
            native = {"string": "string", "int": "integer", "bool": "boolean"}[kind]
            literal = {"type": native}
            if kind == "int":
                literal.update(minimum=-2147483648, maximum=2147483647)
            return {"oneOf": [literal, {"type": "object", "properties": {"ref": {"type": "string"}}, "required": ["ref"], "additionalProperties": False}]}
        nodes = []
        style_props = {}
        for name, spec in STYLE_PROPERTIES.items():
            if spec.get("enum"):
                shape = {"enum": list(spec["enum"])}
            elif spec.get("color"):
                shape = {"type": "string", "pattern": "^#[0-9a-fA-F]{8}$"}
            elif spec["type"] == "int":
                shape = {"type": "integer", "minimum": spec["minimum"], "maximum": spec["maximum"]}
            else:
                shape = {"type": "boolean"}
            style_props[name] = shape
        style_shape = {"type": "object", "properties": style_props, "additionalProperties": False}
        for key, entry in sorted(self.entries.items()):
            props = {}
            for name, spec in entry["properties"].items():
                shape = expression(spec["type"])
                if spec.get("binding"):
                    shape = shape["oneOf"][1]
                if spec.get("literal"):
                    shape = {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_]*$"}
                if 'enum' in spec:
                    shape = {'enum': spec['enum']}
                if 'minimum' in spec and 'oneOf' in shape:
                    shape['oneOf'][0].update(minimum=spec['minimum'], maximum=spec['maximum'])
                props[name] = shape
            shape = {"id": {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_]*$"}, "type": {"const": key},
                     "props": {"type": "object", "properties": props, "required": [name for name, spec in entry["properties"].items() if "default" not in spec], "additionalProperties": False}, "style": style_shape}
            required = ["id", "type", "props"]
            if key not in ('tabs','tab','camera','inbox','stories','friendMap','account'):
                portable_style = style_schema()
                properties = portable_style['properties']
                if key not in ('row','column','card'): properties.pop('gap')
                if key not in ('text','button','counter','textField','secureField','toggle'):
                    properties.pop('fontSize'); properties.pop('fontWeight')
                if key not in ('text','button','counter','textField','secureField','toggle','icon','progressBar'): properties.pop('color')
                shape['style'] = portable_style
                shape['motion'] = MOTION_SCHEMA
                shape['visibleWhen'] = CONDITION_REF
                shape['enabledWhen'] = CONDITION_REF
            if key == 'tab': props['title'] = {'type':'string'}
            if entry.get("children"):
                shape["children"] = {"type": "array", "items": {"$ref": "#/$defs/node"}}
                if key in ('scroll','tab'):
                    shape['children'].update(minItems=1, maxItems=1)
                    required.append('children')
                if key == 'tabs':
                    shape['children'].update(minItems=1,maxItems=5)
                    required.append('children')
            if entry.get("action"):
                shape["action"] = {"type": "string"}
                required.append("action")
            nodes.append({"type": "object", "properties": shape, "required": required, "additionalProperties": False})
        schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "https://dcflight.dev/schema/app-v1.json",
                "type": "object", "additionalProperties": False, "required": ["version", "id", "name", "root"],
                "properties": {"version": {"const": 1}, "id": {"type": "string"}, "name": {"type": "string"},
                    "state": {"type": "object", "additionalProperties": scalar},
                    "actions": {"type": "array", "items": {"oneOf": [
                        {"type": "object", "required": ["id", "op", "target", "value"], "additionalProperties": False, "properties": {"id": {"type": "string"}, "op": {"const": "set"}, "target": {"type": "string"}, "value": {"oneOf": [scalar, {"type": "object", "required": ["ref"], "properties": {"ref": {"type": "string"}}, "additionalProperties": False}]}}},
                        {"type": "object", "required": ["id", "op", "target"], "additionalProperties": False, "properties": {"id": {"type": "string"}, "op": {"enum": ["increment", "toggle"]}, "target": {"type": "string"}}},
                        {"type": "object", "required": ["id", "op"], "additionalProperties": False, "properties": {"id": {"type": "string"}, "op": {"const": "native"}}}
                    ]}}, "root": {"$ref": "#/$defs/node"}}, "$defs": {"node": {"oneOf": nodes}, **predicate_definitions()}}

        abi = {"enum": ["int32", "uint32", "uint64", "bool"]}
        schema["properties"]["logic"] = {"type": "object", "additionalProperties": False, "required": ["source", "prelude", "functions"], "properties": {
            "source": {"type": "string", "minLength": 1}, "prelude": {"type": "string", "minLength": 1},
            "functions": {"type": "array", "minItems": 1, "items": {"type": "object", "additionalProperties": False, "required": ["name", "parameters", "returns"], "properties": {
                "name": {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_]*$"}, "parameters": {"type": "array", "items": {"enum": [*abi["enum"], "utf8"]}}, "returns": {"enum": [*abi["enum"], "utf8"]}, "maxOutputBytes": {"type":"integer","minimum":1,"maximum":1048576}}}}}}
        schema["properties"]["logic"]["properties"]["functions"]["items"].update({
            "if": {"properties": {"returns": {"const": "utf8"}}},
            "then": {"required": ["maxOutputBytes"]},
            "else": {"not": {"required": ["maxOutputBytes"]}}})
        schema["properties"]["actions"]["items"]["oneOf"].append({"type": "object", "additionalProperties": False, "required": ["id", "op", "target", "function", "args"], "properties": {
            "id": {"type": "string"}, "op": {"const": "call"}, "target": {"type": "string"}, "function": {"type": "string"}, "failure": {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_]*$"}, "args": {"type": "array", "items": {"oneOf": [scalar, {"type": "object", "required": ["ref"], "additionalProperties": False, "properties": {"ref": {"type": "string"}}}]}}}})
        schema['properties']['service'] = {'type':'object','additionalProperties':False,'required':['baseUrl'],
            'properties':{'baseUrl':{'type':'string','maxLength':2048},'protocol':{'const':'snap.v1'},'development':{'type':'boolean'}}}
        schema['properties']['modules'] = {'type':'array','items':{'type':'object','additionalProperties':False,
            'required':['id','platform','lock'],'properties':{'id':{'type':'string','pattern':'^[A-Za-z][A-Za-z0-9_.-]{0,99}$'},
            'platform':{'enum':['ios','android']},'lock':{'type':'string','minLength':1,'maxLength':2048}}}}
        schema['properties']['theme'] = {'type':'object','additionalProperties':False,'properties':{
            **{key:{'type':'string','pattern':'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$'} for key in ('accent','background','surface','text','muted','danger')},
            **{key:{'type':'integer','minimum':0,'maximum':128} for key in ('radius','padding')}}}
        schema['dependentRequired'] = {'theme':['service']}
        schema['allOf'] = [{'if':{'required':['service']},'then':{'properties':{'state':{'maxProperties':0},'actions':{'maxItems':0}}}}]
        configuration = native_configuration_schema()
        definitions = configuration.pop('$defs', {})
        if set(definitions).intersection(schema['$defs']):
            raise ValueError('Native configuration schema definition collision')
        schema['$defs'].update(definitions)
        schema['properties']['nativeConfiguration'] = configuration
        return schema
