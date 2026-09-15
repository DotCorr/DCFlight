# Native worker operations

Author a `NativeOperation` with `execution: NativeExecution.worker` and invoke
it through `NativeOperationEffect`. The same typed operation contract produces
an ordinary Swift or Java implementation and native scheduling in
the generated app. The authoring input and registry are absent at runtime.

Scalar arguments are validated and copied on the main thread before dispatch.
The operation executes off the main thread. Its bounded result is committed to
shared state on the main thread before the success action runs. A recoverable
operation failure dispatches the failure action without replacing the target.
Failures in completion actions are not reclassified as native operation errors.

Only the latest worker invocation for a model may publish a result. A newer
worker invocation, explicit `CancelEffect` (`cancelRequests` in JSON), or model
disposal invalidates outstanding work. HTTP and media requests do not implicitly
invalidate workers. Explicit cancellation cancels both channels. Cancellation
is cooperative: an uninterruptible native call can continue executing, but its
stale result cannot update the app.

iOS uses native Swift concurrency with scalar captures and main-actor
publication. Android uses a bounded single-worker executor with one queued
replacement and a separate main-thread completion handler. This bounds queued
Android work; a blocking old operation may delay the latest operation.

Direct standalone operation emission provides a native function (Swift async
when `suspends` is declared). Its caller must supply the declared execution context. Routed effects
supply that scheduling. Thread metadata cannot certify an unannotated SDK API
as thread-safe. iOS actor checks and Android explicit thread requirements still
reject incompatible calls.

Worker operations can declare `suspends: true` separately from execution; see
[suspending operations](native-suspending-operations.md). General shared SDK
callback bodies, arbitrary captured objects, and DC Dart async/await authoring
remain unfinished. No DC Dart language change is required.
