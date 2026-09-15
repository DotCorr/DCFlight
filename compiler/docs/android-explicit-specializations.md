# Android explicit generic invocations

Generic SDK declarations often cannot be emitted until their owner and callable type parameters are chosen. An unbound declaration stays `emittable: false` and `nativeTested: false`; a successful concrete invocation does not change that declaration's catalog credit.

Newly indexed Android descriptors expose `invocationRequirements`. This contains owner and method/constructor parameter names, separate scopes, ordered bounds, required request fields, and unrelated restrictions. Existing catalogs need reindexing to include this discovery metadata; invocation itself continues to use the retained SDK source. MCP `sdk_android_invocation_schema` returns the typed Android request shape without executing code.

For example, the shared typed NativeAPI request for `Collections.singletonList` is:

```json
{
  "platform": "android",
  "scope": "sdk-bytecode:36",
  "id": "java.util.Collections#singletonList(T)",
  "typeArguments": ["java.lang.String"],
  "arguments": [{"literal": "hello"}]
}
```

`typeArguments` selects method or constructor parameters. An instance `receiver.type` or constructor `constructedType` selects owner parameters. These remain distinct when a method shadows an owner parameter. Dart authoring uses the existing typed NativeValue/NativeAPI fields and reaches the same resolver as JSON. No generic signatures are erased to Object.

The emitter now accepts concrete owner arguments containing nested unbounded wildcards, such as `ArrayList<Class<?>>`. An outer capture such as `List<?>` and bounded nested wildcards remain outside this change. The normal type checker continues to enforce inheritance, parameter/result relationships, generic arity, intersection bounds and constructor accessibility. Ordinary native sequences use the same constructor validation.

## Bounded planning and native verification

```sh
dcflight sdk plan-android-specializations --catalog private.sqlite \
  --scope sdk-bytecode:36 --max-trials 250000 --output plan.json

dcflight sdk verify-android-specializations plan.json --catalog private.sqlite \
  --sdk /path/to/platforms/android-36/android.jar --javac /path/to/jdk17/bin/javac \
  --api-level 36 --timeout 600 --min-free-mb 1024 --output fresh-proof
```

The planner searches declared public native types and their inherited generic arguments. It excludes inaccessible enclosing types, preserves every bound, and reports unplanned requests when its budget is exhausted. It does not grant native evidence or solve all possible generic instantiations. Planning is limited to 4,096 generic-only candidates, 16,384 witness types, a configured trial budget up to 1,000,000, and an 8 MiB request document. Abstract/inaccessible constructors remain separate restrictions.

The verifier emits each explicit request through the ordinary public NativeAPI path and compiles generated Java with the exact captured SDK jar, `-proc:none`, and unchecked warnings treated as errors. Failed batches are bisected, failed or rejected requests remain visible, and the command exits unsuccessfully if any request fails. Progress goes to stderr; the report is JSON. The request list is detached from caller-owned mutable data before any callbacks run.

Reports retain exact requests, selected descriptors, a deduplicated source provenance table, compiler source fingerprints, SDK and properties hashes, compiler identity, generated sources, commands and diagnostics. Original and captured SDK bytes, source metadata, selected catalog records and compiler inputs are revalidated before publishing the report. Catalogs are never mutated. The captured jar is a verification input, not an application dependency or bundled runtime.

Only integer base SDKs are supported here. Minor or preview SDK metadata is rejected, including contradictory base/minor properties. Compile evidence is for the named SDK and concrete calls; it is not minimum-OS availability, permission, nullability, threading, device execution or production readiness evidence. Use the separate application availability contract for minimum-version enforcement. No dcflight runtime, Dart VM or bridge is introduced.
