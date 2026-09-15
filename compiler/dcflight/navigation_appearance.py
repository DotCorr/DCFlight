"""Per-host native navigation colors, independent of either UI toolkit."""
from dataclasses import dataclass
from typing import Optional
import re


def _validate(instance):
    for value in vars(instance).values():
        if value is not None and (not isinstance(value,str) or not re.fullmatch(r'#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?',value)):
            raise ValueError('Native navigation appearance requires literal #RRGGBB or #RRGGBBAA colors')


@dataclass(frozen=True)
class NavigationAppearance:
    accent: Optional[str] = None
    surface: Optional[str] = None
    def __post_init__(self):_validate(self)


@dataclass(frozen=True)
class TabAppearance:
    selected_foreground: Optional[str] = None
    unselected_foreground: Optional[str] = None
    surface: Optional[str] = None
    def __post_init__(self):_validate(self)


def schema(kind):
    names=('accent','surface') if kind=='navigationStack' else ('selectedForeground','unselectedForeground','surface')
    return {'type':'object','additionalProperties':False,'properties':{key:{'type':'string','pattern':'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$'} for key in names}}


def lower(raw,kind):
    if kind not in ('navigationStack','tabs'):raise ValueError('Appearance requires a native navigation host')
    if not isinstance(raw,dict) or set(raw)-set(schema(kind)['properties']):raise ValueError('Unsupported native navigation appearance fields')
    if any(not isinstance(value,str) for value in raw.values()):raise ValueError('Appearance colors must be literal strings')
    if kind=='navigationStack':return NavigationAppearance(**raw)
    return TabAppearance(raw.get('selectedForeground'),raw.get('unselectedForeground'),raw.get('surface'))


def validate_node(node):
    appearance=node.navigation_appearance
    if appearance is None:return
    expected={'navigationStack':NavigationAppearance,'tabs':TabAppearance}.get(node.capability)
    if expected is None or not isinstance(appearance,expected):raise ValueError('Appearance type does not match native navigation host')
