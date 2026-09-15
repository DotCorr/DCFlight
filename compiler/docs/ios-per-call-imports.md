# Per-call automatic iOS imports

Automatic type-module inputs provide exact nominal identity metadata, not a module list to import into every call. Each generated probe uses the emitter's required imports plus explicitly authored `--import` values. An unrelated dependency can no longer introduce ambiguous extensions into another candidate's scope.

A member declared as a Swift extension also needs its receiver's module. The importer reads that member's `swiftExtension.extendedModule` from the original SDK symbol, validates it as one module identifier and retains it in `requiredImports`. Conflicting values for the same precise member identity reject. The value is not inferred from mangled names, text spelling, filenames or guessed framework lists. Original graph bytes and their hashes remain bound by the existing verifier input contract and exact descriptor replay. Public module aliases are normalized only at emission.

Native reports declare `automaticTypeImports: referenced`. Export rejects a missing or changed mode, replays the same per-call candidate contract and reconstructs successful public descriptors with no hidden helper imports. Failed/skipped/untested records retain only their original exact type/extension imports and explicitly authored additional imports. Typed deployment skips gain no compiled credit and remain guarded at authoring time.

Partial dependency graphs with no matching precise nominal do not imply imports. Supply `--import Foundation`, for example, when that extra context is intentional. Explicit imports continue to apply to every candidate and may themselves introduce ambiguities; the compiler does not silently remove them.

The original broad-import experiments remain separate evidence: Charts lost `Never.body` because unrelated SwiftUI imports introduced ambiguity; dropping every helper import then lost receiver types such as Decimal and Circle. Exact extension metadata plus existing exact signature-type imports restores these receivers while keeping unrelated extensions out. This is development-time source generation only; no runtime dependency or framework layer is added.
