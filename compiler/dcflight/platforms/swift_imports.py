"""Reviewed SDK public entry points; source symbol/module identities remain intact."""
import re

# SDK 26.2 swiftinterface -public-module-name flags, corroborated by native
# diagnostics and public umbrella @_exported imports. This is compiler policy,
# never an instruction accepted from a symbol graph or generated application.
_PUBLIC_MODULES = {'SwiftUICore': 'SwiftUI', 'RealityFoundation': 'RealityKit'}

def public_imports(modules):
    result=set()
    for module in modules:
        if not isinstance(module,str) or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',module):
            raise ValueError('Invalid Swift import module')
        result.add(_PUBLIC_MODULES.get(module,module))
    return tuple(sorted(result))
