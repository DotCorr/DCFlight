"""Bounded Swift value-type grammar for development-time SDK calls."""
from dataclasses import dataclass, replace
import re


@dataclass(frozen=True)
class SwiftType:
    name: str
    arguments: tuple = ()
    optional: bool = False
    labels: tuple = ()
    effects: tuple = ()
    attributes: tuple = ()


def is_optional(value):
    """Whether the outermost Swift value is optional, including nested Optional."""
    return value.optional or value.name == 'Optional'


def optional_inner(value):
    """Remove exactly one optional layer; return None for nonoptional values."""
    if value.optional:
        return replace(value, optional=False)
    if value.name == 'Optional' and len(value.arguments) == 1:
        return value.arguments[0]
    return None


def make_optional(value):
    """Add one layer without flattening nested Optional values."""
    if is_optional(value):
        return SwiftType('Optional', (value,))
    return replace(value, optional=True)


def parse_type(source):
    if not isinstance(source, str) or not source or len(source) > 4096:
        raise ValueError('Unsupported Swift type: ' + str(source))
    offset = 0

    def whitespace():
        nonlocal offset
        while offset < len(source) and source[offset] == ' ':
            offset += 1

    def take(token):
        nonlocal offset
        whitespace()
        if source.startswith(token, offset):
            offset += len(token)
            return True
        return False

    def required(token):
        if not take(token):
            raise ValueError('Unsupported Swift type: ' + source)

    def value(depth):
        nonlocal offset
        attributes=[]
        while take('@'):
            match=re.match(r'[A-Za-z_][A-Za-z_0-9]*',source[offset:])
            if not match or match.group() not in ('Sendable','MainActor','convention'):
                raise ValueError('Unsupported Swift function attribute')
            attribute=match.group();offset+=len(attribute)
            if attribute=='convention':
                required('(');required('c');required(')')
                attribute='convention(c)'
            if attribute in attributes:
                raise ValueError('Duplicate Swift function attribute')
            attributes.append(attribute)
        result=base_value(depth)
        if attributes:
            if result.name!='$function' or is_optional(result) or result.attributes:
                raise ValueError('Attributes require a nonoptional function type')
            if 'convention(c)' in attributes and (result.effects or 'MainActor' in attributes):
                raise ValueError('C function pointers cannot use Swift async, throws or actor isolation')
            result=replace(result,attributes=tuple(sorted(attributes)))
        return result

    def base_value(depth):
        nonlocal offset
        labels = (); grouped = None
        if depth > 16:
            raise ValueError('Swift type nesting exceeds 16')
        whitespace()
        if source.startswith('any ', offset):
            offset += 4
            protocol = base_value(depth + 1)
            if protocol.name.startswith('$') or is_optional(protocol):
                raise ValueError('Existential requires a nonoptional protocol type; use (any Protocol)? for optional values')
            return SwiftType('$existential', (protocol,))
        if take('('):
            items = []; names = []
            if not take(')'):
                while True:
                    whitespace()
                    label = re.match(r'([A-Za-z_][A-Za-z_0-9]*)\s*:', source[offset:])
                    names.append(label[1] if label else '')
                    if label: offset += len(label[0])
                    items.append(value(depth + 1))
                    if not take(','): break
                    if len(items) >= 32: raise ValueError('Too many Swift tuple elements')
                required(')')
            effects = []
            if take('async'): effects.append('async')
            if take('throws'): effects.append('throws')
            if take('->'):
                if any(label not in ('', '_') for label in names):
                    raise ValueError('Function type parameters cannot have labels')
                result = value(depth + 1)
                return SwiftType('$function', tuple(items) + (result,), False, (), tuple(effects))
            if effects: raise ValueError('Function effects require an arrow')
            if len(items) == 1:
                if (items[0].name not in ('$function', '$existential') and not source[offset:].lstrip().startswith('.')) or names[0]:
                    raise ValueError('Single-element tuples are unsupported')
                grouped = items[0]
            arguments = tuple(items); labels = tuple(names); name = '$tuple'
            named = [label for label in labels if label and label != '_']
            if len(set(named)) != len(named): raise ValueError('Duplicate Swift tuple labels')
        elif take('['):
            first = value(depth + 1)
            if take(':'):
                arguments = (first, value(depth + 1)); name = 'Dictionary'
            else:
                arguments = (first,); name = 'Array'
            required(']')
        else:
            whitespace()
            match = re.match(r'[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*', source[offset:])
            if not match:
                raise ValueError('Unsupported Swift type: ' + source)
            name = match.group(); offset += len(name)
            arguments = ()
            if take('<'):
                items = [value(depth + 1)]
                while take(','):
                    if len(items) >= 32:
                        raise ValueError('Too many Swift type arguments')
                    items.append(value(depth + 1))
                required('>'); arguments = tuple(items)
            if name in ('Swift.Array', 'Swift.Dictionary', 'Swift.Optional'):
                name = name.removeprefix('Swift.')
            if name in ('Array', 'Dictionary') and len(arguments) != (1 if name == 'Array' else 2):
                raise ValueError('Invalid Swift collection type arity')
        if grouped is not None:
            result = grouped
        elif name == 'Optional':
            if len(arguments) != 1:
                raise ValueError('Invalid Swift Optional type arity')
            result = make_optional(arguments[0])
        else:
            result = SwiftType(name, arguments, False, labels)
        while take('.'):
            member = re.match(r'[A-Za-z_][A-Za-z_0-9]*', source[offset:])
            if not member:
                raise ValueError('Invalid qualified Swift member type')
            member_name = member.group(); offset += len(member_name)
            if (result.name in ('$tuple','$function','$existential') or is_optional(result)) and member_name != 'Type':
                raise ValueError('Structured parent supports only a metatype member')
            member_arguments = ()
            if take('<'):
                items = [value(depth + 1)]
                while take(','):
                    if len(items) >= 32: raise ValueError('Too many Swift type arguments')
                    items.append(value(depth + 1))
                required('>'); member_arguments = tuple(items)
            result = SwiftType('$member', (result, SwiftType(member_name, member_arguments)))
        return optional_suffix(result, depth)

    def optional_suffix(result, depth):
        count = 0
        while take('?'):
            count += 1
            if depth + count > 16:
                raise ValueError('Swift type nesting exceeds 16')
            result = make_optional(result)
        return result

    result = value(0)
    whitespace()
    if offset != len(source):
        raise ValueError('Unsupported Swift type: ' + source)
    def check_depth(item, depth=0):
        if depth > 16:
            raise ValueError('Swift type nesting exceeds 16')
        for argument in item.arguments:
            check_depth(argument, depth + 1)
    check_depth(result)
    return result


def supported_type(source):
    try:
        parse_type(source)
        return True
    except ValueError:
        return False


def spelling(value):
    if value.name == '$member':
        parent, member = value.arguments
        body = spelling(parent)
        if parent.name in ('$function','$existential') or is_optional(parent): body = '(' + body + ')'
        return body + '.' + spelling(member) + ('?' if value.optional else '')
    if value.name == 'Optional':
        return spelling(value.arguments[0]) + '?' + ('?' if value.optional else '')
    if value.name == '$existential':
        body = 'any ' + spelling(value.arguments[0])
        return '(' + body + ')?' if value.optional else body
    if value.name == '$function':
        body = '(' + ', '.join(spelling(item) for item in value.arguments[:-1]) + ')'
        if value.effects: body += ' ' + ' '.join(value.effects)
        body += ' -> ' + spelling(value.arguments[-1])
        if value.attributes: body=' '.join('@'+a for a in value.attributes)+' '+body
        return '(' + body + ')?' if value.optional else body
    if value.name == '$tuple':
        return '(' + ', '.join((label + ': ' if label else '') + spelling(item)
                               for label, item in zip(value.labels, value.arguments)) + ')' + ('?' if value.optional else '')
    arguments = '<' + ', '.join(spelling(item) for item in value.arguments) + '>' if value.arguments else ''
    return value.name + arguments + ('?' if value.optional else '')
