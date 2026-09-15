"""Language-independent canonical types; no source syntax or native objects."""
from dataclasses import dataclass, field, replace
from enum import Enum
from typing import Tuple, Union, Optional
from .native_configuration import NativeConfiguration
from .navigation_appearance import NavigationAppearance, TabAppearance


class ScalarType(str, Enum):
    STRING = "string"
    INT = "int"
    BOOL = "bool"


class ActionOperation(str, Enum):
    SET = "set"
    INCREMENT = "increment"
    TOGGLE = "toggle"
    NATIVE = "native"
    CALL = "call"


Scalar = Union[str, int, bool]


@dataclass(frozen=True)
class Literal:
    value: Scalar
    type: ScalarType


@dataclass(frozen=True)
class Reference:
    name: str
    type: ScalarType


@dataclass(frozen=True)
class FieldReference:
    collection: str
    field: str
    type: ScalarType


@dataclass(frozen=True)
class MediaRef:
    name: str


@dataclass(frozen=True)
class StringIsEmpty:
    value: "Expression"
    operator: str = field(default="isEmpty", init=False)

    def __post_init__(self):
        if not isinstance(self.value, (Literal, Reference, FieldReference)) or self.value.type != ScalarType.STRING:
            raise ValueError("isEmpty requires a scalar string operand")

    @property
    def type(self): return ScalarType.BOOL


@dataclass(frozen=True)
class BooleanNot:
    value: "Expression"
    operator: str = field(default="not", init=False)

    def __post_init__(self):
        if getattr(self.value, "type", None) != ScalarType.BOOL:
            raise ValueError("not requires a boolean operand")

    @property
    def type(self): return ScalarType.BOOL


@dataclass(frozen=True)
class BooleanAll:
    values: Tuple["Expression", ...]
    operator: str = field(default="all", init=False)

    def __post_init__(self):
        if not isinstance(self.values, tuple) or not 1 <= len(self.values) <= 32 or any(getattr(v, "type", None) != ScalarType.BOOL for v in self.values):
            raise ValueError("all requires 1..32 boolean operands")

    @property
    def type(self): return ScalarType.BOOL


@dataclass(frozen=True)
class BooleanAny:
    values: Tuple["Expression", ...]
    operator: str = field(default="any", init=False)

    def __post_init__(self):
        if not isinstance(self.values, tuple) or not 1 <= len(self.values) <= 32 or any(getattr(v, "type", None) != ScalarType.BOOL for v in self.values):
            raise ValueError("any requires 1..32 boolean operands")

    @property
    def type(self): return ScalarType.BOOL


Expression = Union[Literal, Reference, FieldReference, MediaRef, StringIsEmpty, BooleanNot, BooleanAll, BooleanAny]


def walk_expression(expr):
    """Visit a canonical expression tree, including its root."""
    yield expr
    if isinstance(expr, (StringIsEmpty, BooleanNot)):
        yield from walk_expression(expr.value)
    elif isinstance(expr, (BooleanAll, BooleanAny)):
        for value in expr.values:
            yield from walk_expression(value)


def map_expression(expr, transform):
    """Map leaves and parents bottom-up, preserving immutable typed operands."""
    if isinstance(expr, (StringIsEmpty, BooleanNot)):
        expr = replace(expr, value=map_expression(expr.value, transform))
    elif isinstance(expr, (BooleanAll, BooleanAny)):
        expr = replace(expr, values=tuple(map_expression(v, transform) for v in expr.values))
    return transform(expr)


@dataclass(frozen=True)
class State:
    name: str
    initial: Literal


@dataclass(frozen=True)
class Action:
    id: str
    operation: ActionOperation
    target: Optional[str] = None
    value: Optional[Expression] = None
    function: Optional[str] = None
    arguments: Tuple[Expression, ...] = ()
    failure: Optional[str] = None


@dataclass(frozen=True)
class Style:
    """Portable logical units. None preserves an unspecified author intent."""
    padding: Optional[int] = None
    gap: Optional[int] = None
    width: Optional[int] = None
    height: Optional[int] = None
    max_width: Optional[int] = None
    fill: Optional[bool] = None
    color: Optional[str] = None
    background: Optional[str] = None
    border_color: Optional[str] = None
    border_width: Optional[int] = None
    radius: Optional[int] = None
    font_size: Optional[int] = None
    font_weight: Optional[str] = None
    align: Optional[str] = None
    opacity: Optional[int] = None


@dataclass(frozen=True)
class Motion:
    kind: str
    duration_ms: int


@dataclass(frozen=True)
class Node:
    id: str
    capability: str
    properties: Tuple[Tuple[str, Expression], ...]
    children: Tuple["Node", ...]
    action: Optional[str] = None
    style: Optional[Style] = None
    motion: Optional[Motion] = None
    visible_when: Optional[Expression] = None
    enabled_when: Optional[Expression] = None
    navigation_appearance: Optional[Union[NavigationAppearance,TabAppearance]] = None

    def props(self):
        return dict(self.properties)


class ABIType(str, Enum):
    INT32 = "int32"
    UINT32 = "uint32"
    UINT64 = "uint64"
    BOOL = "bool"
    UTF8 = "utf8"


@dataclass(frozen=True)
class LogicFunction:
    name: str
    parameters: Tuple[ABIType, ...]
    returns: ABIType
    max_output_bytes: Optional[int] = None


@dataclass(frozen=True)
class LogicModule:
    source: str
    prelude: str
    functions: Tuple[LogicFunction, ...]


@dataclass(frozen=True)
class Service:
    base_url: str
    protocol: str = 'snap.v1'
    development: bool = False


@dataclass(frozen=True)
class Theme:
    accent: str = '#FFDD33'
    background: str = '#F7F7F2'
    surface: str = '#FFFFFF'
    text: str = '#18191C'
    muted: str = '#72757E'
    danger: str = '#B42318'
    radius: int = 24
    padding: int = 20


@dataclass(frozen=True)
class ModuleReference:
    id: str
    platform: str
    lock: str


@dataclass(frozen=True)
class Application:
    id: str
    name: str
    states: Tuple[State, ...]
    actions: Tuple[Action, ...]
    root: Node
    version: int = 1
    logic: Optional[LogicModule] = None
    service: Optional[Service] = None
    theme: Optional[Theme] = None
    modules: Tuple[ModuleReference, ...] = ()
    native_configuration: Optional[NativeConfiguration] = None

    def nodes(self):
        def walk(node):
            yield node
            for child in node.children:
                yield from walk(child)
        return tuple(walk(self.root))
