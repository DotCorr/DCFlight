# Suspending native operations

`NativeOperation(suspends: true, ...)` declares that completion may suspend.
It is independent of `execution`, which selects main, worker, or (for standalone
emission) caller context. Existing declarations default to `suspends: false`.
JSON uses the same boolean field; the typed canonical contract retains it.

The iOS implementation becomes a native Swift `async` function and the SDK
sequence can await supported native async calls. `throwsErrors` / JSON `throws`
remains a separate requirement. Main operations retain `@MainActor`; worker
operations run in detached native tasks. Swift compilation must still validate
actor isolation and Sendability across suspension points.

Android implementations remain synchronous Java native API sequences. The
generated effect defers a suspending main operation onto the native main event
queue or executes a worker operation on its bounded executor. It never blocks
the main thread waiting for a Future or latch. This does not make expensive
synchronous Java work safe for the main thread: select worker when appropriate.
Target emission metadata states each native invocation's `sync` or `async` shape.

Arguments snapshot before scheduling. Deferred operations share one latest-wins
channel per app model, including mixed main and worker calls. Explicit
cancellation and model disposal invalidate results. HTTP/media internal
cancellation remains independent. Completion publishes the validated scalar
result on the main thread and then runs the authored success action; native
failure invokes the failure action without replacing the result.

Native cancellation is cooperative. Work already executing may have effects
that cannot be undone. A synchronous main operation cannot be interrupted by a
new main event while it is running. Synchronous nonsuspending main operations
retain their existing immediate behavior.

This is a native SDK sequence capability, not general async Dart business-code
compilation. Arbitrary SDK callback implementations, callback-to-await adapters,
and cross-platform object capture/lifetime authoring are still unsupported.
Generated apps include ordinary native calls and scheduling code; no dcflight
interpreter, VM or operation registry executes in the app.
