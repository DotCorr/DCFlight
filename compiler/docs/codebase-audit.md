# Audit and cleanup record — 2026-09-13

Scope: the development-time compiler under `compiler/`. The parent repository contains unrelated legacy runtime work and uncommitted changes; these were not reverted or swept into this implementation.

## Findings and completed changes

- Presentation constraints were duplicated between validation and authoring schema. One reviewed style/motion definition now supplies both, including integer dimensions, RGBA colors, border pairs and conflicting width rules.
- Ordinary Dart authoring was limited to a const parser. An explicitly opted-in evaluator now executes trusted developer `buildApp()` composition at development time, then lowers its output to the same canonical IR. MCP and ordinary JSON validation do not execute Dart.
- New capabilities could previously reach generic generators with empty mappings. Unsupported social composition, generic routing, style properties and state/action bindings now fail before emitting broken or misleading source.
- Android inherited extra root padding, causing mismatch with explicitly styled layouts. Both generators now use declared layout; Android preserves platform system insets.
- A package resolver initially selected source variants. It now requests runtime-library variants and rejects documentation artifacts. Maven artifacts and transitive dependencies are content-locked, copied into ordinary native projects and integrity checked.
- One-platform regeneration could discard untouched-platform dependency evidence. The compiler now preserves that metadata across incremental platform builds.
- The source audit scanned build-tool intermediate files and mistook absolute workspace paths for runtime dependencies. Known native build-output folders are excluded; source scanning and final APK/library inspection remain separate checks.
- Unsigned iOS simulator builds compiled but could not use Keychain. Run tooling now requests native ad-hoc simulator signing. No insecure token-storage fallback was introduced.
- Independent backend review found validation errors could echo rejected passwords. Responses now expose only approved field/error metadata; a regression verifies secrets are absent.

## Source ownership

The old Snap feature templates embed application copy, layouts and flow separately per platform. This is an architectural defect, even though their emitted files are conflict protected and have no dcflight runtime. They are retained temporarily as tested OS/service adapter references, not accepted as the shared application source. New routed generation emits shared primitive trees and explicit navigation actions. Application entry points and native project configuration remain user-owned. No application-side template evaluator, registry, compiler, Dart SDK or dcflight library is emitted.

## Safety harness

Compiler tests cover schema/IR validation, deterministic generation, ownership conflicts, evaluated Dart equivalence, native API typed emission, module integrity and export, and platform-specific source contracts. Native builds, binary dependency/symbol checks, backend integration/TCP tests and interactive application checks provide separate evidence. Reports distinguish generated, compiled and executed behavior; API catalog totals are not feature-completeness or device-test claims.

## Remaining work

Snap migration to shared routed UI and shared event/effect orchestration is unfinished. The routed Dart fixture builds on both platforms from identical source. DC Dart has verified uint64 native calls and generated caller-owned packed records/UTF8 buffers; complete record/collection/async business orchestration remains unfinished. SPM transitive locking/project integration is not complete. Public deployment, account recovery, abuse reporting/moderation, push notifications, video features and physical-device certification are not represented as finished production functionality.
