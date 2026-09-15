# Android native thread requirements

The SDK importer records `threadRequirement` as `main`, `worker`, `any`,
`unknown` or `conflicting`. Method annotations override class annotations.
`MainThread` and `UiThread` both mean main. Parameter/callback annotations and
field initializer text do not change the containing call's requirement.

Direct Android requests and native sequences accept `executionContext` with
`main`, `worker` or `unknown`. A declared context must satisfy an explicit SDK
thread requirement. Conflicting requirements reject. A direct expression-only
request may omit context, in which case the returned `threadRequirement`
remains an obligation of its native caller; emission is not thread certification.

Shared native operations always provide a context: `execution: main` supplies
main, `execution: worker` supplies worker, and `execution: caller` supplies unknown. A worker-only call is therefore
rejected inside a shared main operation, and an explicitly main-only call cannot
silently depend on an unspecified caller thread. Routed app operations require
explicit main or worker execution. Worker effects generate native background
execution and publish completion on the main thread; see
[worker operations](native-worker-operations.md). iOS continues to use its
separate actor-isolation checks.

An unannotated API remains unknown. This does not mean it is nonblocking,
thread-safe or safe on every executor. Context checking neither dispatches work
nor proves the actual caller's thread, and it adds no runtime dcflight layer.

Tests cover owner requirements, method overrides, parameter annotations,
conflicts, literals resembling annotations, invalid contexts and propagation
from shared operations. A source-level check against Android 35 verifies a real
`NotificationManager.matchesCallFilter(Uri)` requirement without accessing
notifications or executing that API.
