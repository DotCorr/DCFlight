"""A backend consumes only validated IR + reviewed mappings and returns an artifact plan."""
from dataclasses import dataclass
from typing import Protocol, Dict
from ..ir import Application
from ..registry import Registry


@dataclass(frozen=True)
class Artifact:
    content: str
    ownership: str = "generated"


class Backend(Protocol):
    target: str

    def generate(self, app: Application, registry: Registry) -> Dict[str, Artifact]:
        ...


HEADER = '''/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */
'''
