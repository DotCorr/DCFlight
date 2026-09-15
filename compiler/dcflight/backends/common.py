import json
from ..ir import Reference, ScalarType


def symbol(name):
    # Preserve case and never hash/truncate: explicit IDs remain collision-free.
    return 'n_' + name


def expression(expr, target):
    if isinstance(expr, Reference):
        return 'model.s_' + expr.name
    if expr.type == ScalarType.BOOL:
        return 'true' if expr.value else 'false'
    if expr.type == ScalarType.INT:
        return str(expr.value)
    if target == 'ios':
        escapes = {'"': '\\"', '\\': '\\\\', '\n': '\\n', '\r': '\\r', '\t': '\\t'}
        encoded = ''.join(escapes.get(c, ('\\u{' + format(ord(c), 'x') + '}') if ord(c) < 32 else c) for c in expr.value)
        return '"' + encoded + '"'
    return json.dumps(expr.value, ensure_ascii=False)



def color_rgba(hex_color):
    """#RRGGBBAA -> (r, g, b, a) floats for SwiftUI."""
    return tuple(int(hex_color[i:i + 2], 16) / 255.0 for i in (1, 3, 5, 7))


def color_int(hex_color):
    """#RRGGBBAA -> RRGGBBAA integer for the generated Swift hex initializer."""
    return int(hex_color[1:], 16)


def color_java(hex_color):
    """#RRGGBBAA -> #AARRGGBB accepted by android.graphics.Color.parseColor."""
    return '#' + hex_color[7:] + hex_color[1:7]


def expand(template, values):
    # Only substitute named placeholders; braces belonging to source survive.
    import re
    def replace(match):
        key = match.group(1)
        if key not in values:
            raise ValueError('Unknown mapping placeholder: ' + key)
        return values[key]
    return re.sub(r'\{([A-Za-z_][A-Za-z0-9_]*)\}', replace, template)
