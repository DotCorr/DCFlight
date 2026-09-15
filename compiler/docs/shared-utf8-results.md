# Shared UTF-8 results

DC Dart remains an ahead-of-time input. The native compiler emits plain C-ABI
object files; generated Swift and JNI application glue owns temporary buffers.
No DC Dart VM, registry, interpreter, allocator protocol or dcflight library is
packaged with the app. This change does not modify DC Dart 0.1.1.

A logical function can return `utf8` when it declares `maxOutputBytes` in
1..1048576. Other return types must omit that field. Input UTF-8 retains the
existing per-string/aggregate limits and synchronous borrowing contract.

```dart
LogicFunction(name:'canonicalHandle',parameters:['utf8'],returns:'utf8',
  maxOutputBytes:24)
```

Its actual DC Dart definition uses the existing pointer/integer primitives:

```dart
@bare
u32 canonicalHandle(u64 input, u32 inputLength,
                    u64 output, u32 outputCapacity) { /* write bytes */ }
```

The last output address/capacity pair is generated and hidden from app actions.
Return the written byte length, including zero for an empty string. Return
`u32(4294967295)` for failure. Any result larger than capacity is rejected before
reading output. No NUL terminator is required; embedded NUL is preserved.

The native caller allocates a zero-initialized bounded output buffer and invokes
the function exactly once. It validates the length and strict UTF-8, copies the
result into a native string, and releases output storage on every path. JNI
clears temporary output bytes before freeing and clears its returned byte array
after constructing the String. Swift clears its borrowed output buffer before
release. These are application-owned allocations with no cross-call ownership
or retained pointers. DC Dart code must respect input/output bounds and must not
retain pointers. This is native code, not a memory-safety sandbox.

## Typed terminal flow effect

```dart
LogicCallEffect(function:'canonicalHandle',
  arguments:[Ref<String>(name:'username')],target:'canonical',
  success:'accepted',failure:'rejected')
```

JSON uses `{op:'logicCall',function,arguments,target,success,failure}`. The same
canonical validation handles both frontends. For this bounded release,
`LogicCallEffect` requires a UTF-8 result; its arguments can be portable scalar
or UTF-8 inputs. Native-address arguments/results stay rejected. The effect must
be last, its target must be string state, and both continuations must be declared
flow IDs. Synchronous continuation cycles are rejected. Timer flows do not yet
accept this effect. Existing scalar actions/selectors retain their behavior.
Legacy scalar `Action(op:'call')` also permits assigning a UTF-8 result to string
state when a declared failure action is supplied.

A failure leaves the target unchanged and dispatches only the failure flow. A
successful call assigns the validated string before dispatching success. Neither
continuation runs inside the native call's catch boundary.

`examples/utf8-result` demonstrates Snap's existing ASCII handle policy: preserve
digits/underscores and lowercase A–Z. It does not modify Snap's authoritative app,
password handling or backend. Invalid handles reach the failure flow.

## Native verification

`python tools/verify_utf8_results.py --toolchain /path/toolchain.json --output
/path/fresh-output` uses the released compiler to generate iOS-device,
iOS-simulator and Android-arm64 objects/libraries with existing dependency
checks. It executes those generated Swift/JNI facades against a real host object,
covering empty/NUL/multibyte strings, exact capacity, oversized lengths, explicit
failure, malformed output, retained results and 2,000 concurrent calls per
facade. Host JNI execution is not an Android ART execution claim. The report
records exact compiler/object identities and the narrower verification scope.
