"""Rebuild the reviewed baseline mappings. Extend families, not backend switches."""
import json
from pathlib import Path


def prop(kind, **extra):
    return dict(type=kind, **extra)


def entry(name, properties, swift, java_class, java_update, children=False, action=False):
    return dict(id=name, properties=properties, children=children, action=action,
                targets={"ios": dict(expression=swift, symbol=swift.split('(')[0], source="https://developer.apple.com/documentation/swiftui"),
                         "android": dict(className=java_class, update=java_update, source="https://developer.android.com/reference/" + java_class.replace('.', '/'))})


entries = [
    entry("text", {"text": prop("string")}, "Text({text})", "android.widget.TextView", "{view}.setText({text});"),
    entry("counter", {"value": prop("int")}, "Text(String({value}))", "android.widget.TextView", "{view}.setText(String.valueOf({value}));"),
    entry("button", {"text": prop("string")}, "Button({text}, action: {action})", "android.widget.Button", "{view}.setText({text});", action=True),
    entry("column", {}, "VStack(alignment: .leading) {\n{children}\n}", "android.widget.LinearLayout", "{view}.setOrientation(android.widget.LinearLayout.VERTICAL);", children=True),
    entry("row", {}, "HStack {\n{children}\n}", "android.widget.LinearLayout", "{view}.setOrientation(android.widget.LinearLayout.HORIZONTAL);", children=True),
    entry("toggle", {"text": prop("string"), "value": prop("bool", binding=True)}, "Toggle({text}, isOn: {binding_value})", "android.widget.Switch", "{view}.setText({text});\n{view}.setChecked({value});"),
    entry("textField", {"value": prop("string", binding=True), "placeholder": prop("string", default="")}, "TextField({placeholder}, text: {binding_value})", "android.widget.EditText", "if (!{view}.getText().toString().equals({value})) {view}.setText({value});\n{view}.setHint({placeholder});"),
    entry("divider", {}, "Divider()", "android.view.View", "{view}.setBackgroundColor(android.graphics.Color.GRAY);"),
    entry("progress", {}, "ProgressView()", "android.widget.ProgressBar", "{view}.setIndeterminate(true);"),
    entry("native", {"symbol": prop("string", literal=True)}, "UserViews.{symbol}(model: model)", "android.view.View", "")
]
path = Path(__file__).resolve().parents[1] / "dcflight/data/capabilities.json"
path.write_text(json.dumps(dict(version=1, capabilities=entries), indent=2) + "\n")
