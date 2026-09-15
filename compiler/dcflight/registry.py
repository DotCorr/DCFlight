"""Reviewed mappings are separate from automatically imported API inventories."""
import json
from pathlib import Path


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
                raise ValueError("MVP mappings require both native targets: " + key)
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
        for key, entry in sorted(self.entries.items()):
            props = {}
            for name, spec in entry["properties"].items():
                shape = expression(spec["type"])
                if spec.get("binding"):
                    shape = shape["oneOf"][1]
                if spec.get("literal"):
                    shape = {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_]*$"}
                props[name] = shape
            shape = {"id": {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9_]*$"}, "type": {"const": key},
                     "props": {"type": "object", "properties": props, "required": [name for name, spec in entry["properties"].items() if "default" not in spec], "additionalProperties": False}}
            required = ["id", "type", "props"]
            if entry.get("children"):
                shape["children"] = {"type": "array", "items": {"$ref": "#/$defs/node"}}
            if entry.get("action"):
                shape["action"] = {"type": "string"}
                required.append("action")
            nodes.append({"type": "object", "properties": shape, "required": required, "additionalProperties": False})
        return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "https://dcflight.dev/schema/app-v1.json",
                "type": "object", "additionalProperties": False, "required": ["version", "id", "name", "root"],
                "properties": {"version": {"const": 1}, "id": {"type": "string"}, "name": {"type": "string"},
                    "state": {"type": "object", "additionalProperties": scalar},
                    "actions": {"type": "array", "items": {"oneOf": [
                        {"type": "object", "required": ["id", "op", "target", "value"], "additionalProperties": False, "properties": {"id": {"type": "string"}, "op": {"const": "set"}, "target": {"type": "string"}, "value": {"oneOf": [scalar, {"type": "object", "required": ["ref"], "properties": {"ref": {"type": "string"}}, "additionalProperties": False}]}}},
                        {"type": "object", "required": ["id", "op", "target"], "additionalProperties": False, "properties": {"id": {"type": "string"}, "op": {"enum": ["increment", "toggle"]}, "target": {"type": "string"}}},
                        {"type": "object", "required": ["id", "op"], "additionalProperties": False, "properties": {"id": {"type": "string"}, "op": {"const": "native"}}}
                    ]}}, "root": {"$ref": "#/$defs/node"}}, "$defs": {"node": {"oneOf": nodes}}}
