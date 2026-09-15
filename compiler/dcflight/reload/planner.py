"""Conservative reload classification; eligibility is not platform support."""
from dataclasses import asdict, dataclass
import hashlib
import json


def abi_digest(functions):
    signatures=sorted((f.name, tuple(p.value for p in f.parameters), f.returns.value) for f in functions)
    return hashlib.sha256(json.dumps(signatures,separators=(',',':')).encode()).hexdigest()


@dataclass(frozen=True)
class ReloadPlan:
    action: str
    reason: str
    preserve_memory: bool = False


def plan(previous, current, *, logic_changed=False, native_changed=False, live_logic=False):
    if previous is None:return ReloadPlan('restart','Initial native build')
    if previous.id!=current.id:return ReloadPlan('blocked','Application identity changed; choose a separate session')
    # Any layout/state/ABI/module configuration change needs native regeneration.
    before=asdict(previous);after=asdict(current)
    if before!=after:return ReloadPlan('restart','Application structure, state, ABI or configuration changed')
    if native_changed:return ReloadPlan('restart','Native source/resources changed')
    if logic_changed:
        if current.logic is None:return ReloadPlan('restart','No declared native logic ABI')
        if live_logic:return ReloadPlan('native-swap','Unchanged ABI; requires a verified development loader',True)
        return ReloadPlan('restart','Native logic changed; this target has no verified app reload adapter')
    return ReloadPlan('none','No semantic or native input change',True)
