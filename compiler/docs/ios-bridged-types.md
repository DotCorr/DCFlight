# Exact SDK bridged value spellings

An SDK member fragment can expose a Swift value type while retaining the precise ID of its Objective-C reference class. The compiler preserves that member spelling only when retained SDK graphs prove an exact `ReferenceConvertible` conformance, a `ReferenceType` alias with a direct precise reference-class ID, and the alias's exact `memberOf` relationship to the value nominal. These are separate identities; the compiler does not declare them equivalent or invent conversion code.

Records retain raw graph and symbol hashes, the exact conformance and membership relationships, and availability for the reference class, value and alias. Missing or conditional relationships do not establish a bridge. Contradictory alias ownership, duplicate conflicting pairs and ambiguous values reject. Ordinary renamed/nested type resolution continues unchanged.

Both the single and batch exact-type planners enrich selected nominal subsets with the value, alias and original relationships. Coordinator replay recomputes these facts from retained input bytes, compares every symbol and relationship, and rejects stale or forged subsets. Bridge-aware plans must be regenerated when an older subset omitted required bridge metadata. No planning result grants native credit. Normal native verification and standalone exporter replay remain required.

The batch planner scans its nominal index once and separately scans dependency relationship graphs lazily, at most once per encountered dependency. `symbolScans` counts the original indexing passes; `bridgeGraphScans` explicitly counts the additional relationship passes. Inputs, entries, nominal rows, relationships and output bytes remain bounded. Resource checks are cooperative, not an OS isolation boundary.

This stage depends on the separately reviewed batch planner and planned coordinator stages. It changes no runtime, app, DC Dart compiler, current catalog, or live verification plan. Native tests cover an AVRouting bridge and prior UIKit renamed/generic-owner cases; they do not prove every SDK bridge, deployment environment, device behavior or runtime path.
