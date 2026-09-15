"""Language-independent canonical types; no source syntax or native objects."""
from dataclasses import dataclass
from enum import Enum
from typing import Tuple, Union, Optional


class ScalarType(str, Enum):
    STRING = "string"
    INT = "int"
    BOOL = "bool"


class ActionOperation(str, Enum):
    SET = "set"
    INCREMENT = "increment"
    TOGGLE = "toggle"
    NATIVE = "native"


Scalar = Union[str, int, bool]


@dataclass(frozen=True)
class Literal:
    value: Scalar
    type: ScalarType


@dataclass(frozen=True)
class Reference:
    name: str
    type: ScalarType


Expression = Union[Literal, Reference]


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


@dataclass(frozen=True)
class Node:
    id: str
    capability: str
    properties: Tuple[Tuple[str, Expression], ...]
    children: Tuple["Node", ...]
    action: Optional[str] = None
    style: Tuple[Tuple[str, Literal], ...] = ()

    def props(self):
        return dict(self.properties)


@dataclass(frozen=True)
class Application:
    id: str
    name: str
    states: Tuple[State, ...]
    actions: Tuple[Action, ...]
    root: Node
    version: int = 1

    def nodes(self):
        def walk(node):
            yield node
            for child in node.children:
                yield from walk(child)
        return tuple(walk(self.root))
