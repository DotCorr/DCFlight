# Released DC Dart: shared application logic capability audit

Snap now authors screens, state, requests, and navigation in the shared Dart application definition. DC Dart executes scalar decision functions; generated native adapters execute the shared flow effects. The integrated logic ABI now passes bounded borrowed UTF-8 inputs to those functions; Snap username validation uses real text. Records, collections, and string results still need integration. See [shared UTF-8 inputs](shared-utf8-input.md) for bounds and lifetime obligations. The release audit below distinguishes DC Dart language capabilities from integration work still required in dcflight.

## Evidence from DC Dart 0.1.1

Reviewed release commit `acd4519`, released `dcc --version` 0.1.1, its matching prelude, `core/dcc-lower/lib/lower.dart`, `core/backend/lib/c_header.dart`, and ADRs 0010/0011/0053/0060. The compiler dependency was not modified.

| Capability | Released implementation and limit |
|---|---|
| State records | `@packed class … extends Struct`, address constructor and typed getter/setter pairs lower to native memory loads/stores. Caller-owned records need no heap or VM. Exact field order/width is ABI. |
| Buffers/pointers | `Pointer<T>.fromAddress(u64)` and typed access exist. This is unsafe native memory, requiring generated bounds/lifetime rules; do not expose arbitrary addresses as developer JSON values. |
| Text | `Str` is borrowed UTF-8 `{pointer,length}`; length counts **bytes**. Prelude explicitly says owned `String`, growable `StrBuf`, rune count and UTF-16 length are not implemented. Existing literals/slices do not imply full Dart String support. Byte-buffer inputs can be inspected without a VM. |
| Control flow | Conditional branches, local variables, loops and calls lower to native code. Actual dispatch proof below exercises branches, state writes and buffer reads. |
| External native calls | `@extern external` declares direct C ABI calls. Every undefined symbol must match a declared, reviewed adapter. Do not blanket-allow libc or arbitrary platform symbols. |
| Function values | Named top-level/hoisted noncapturing function references and indirect calls exist (ADR0060). Ownership is part of their type; ordinary Dart function-type parameters are all-borrowed. This does not establish safe arbitrary capturing native callbacks or long-lived borrowed captures. |
| Async | Lowerer explicitly rejects non-sync functions: “DCDart has no async or generators.” Shared application async behavior must currently use explicit events/effects/completions, or require a deliberate compiler feature release. |
| Memory management | Native ARC/heap support exists elsewhere in the language. It is not a Dart VM. dcflight's present symbol audit deliberately supports a narrower no-helper subset; general ownership/allocator integration remains unaudited. Zero VM does not mathematically require zero allocation. |
| Headers | Compiler emits scalar, pointer, struct and function-pointer C declarations. The proof's exported address ABI does not cause internal `AppState` layout to appear in the header: dcflight must generate and verify that record layout separately, not assume the compiler exported it. |

## Executed proof

Task scratch `work/shared-flow-proof/` contains `flow.dart`, matching release `prelude.dart`, emitted `flow.h`, `check.c`, and native objects. The single DC Dart function mutates a caller-owned 12-byte state record (`phase`, `requestId`, `error`), inspects caller UTF-8 bytes, rejects send before login, validates empty login input, produces a login effect, accepts only the current request's completion, produces a message-send effect after authentication, resets state on logout, and ignores a late login completion after logout.

The C caller only allocates state and submits events; all those transition decisions are DC Dart. Eight host-native assertions passed. The host object had **no undefined symbols**. The identical source compiled with release 0.1.1 to host, iOS simulator ARM64 Mach-O and Android ARM64 ELF objects. This proof did not execute on either mobile device, perform HTTP, implement Unicode validation, or replace the shipped app's native business flow.

Reproduce using the released compiler and matching prelude:

```sh
DCDART_DART=/path/to/dart dcc build --mode bare --target host \
  --prelude "$PWD/prelude.dart" "$PWD/flow.dart" -o flow.o --emit-header flow.h
clang check.c flow.o -o check
./check
nm -u flow.o
# Repeat compilation with ios-simulator-arm64 and android-arm64.
```

## Application boundary to implement

1. **One shared state and event model.** Generate versioned packed records with explicit fixed-width fields plus typed buffer/handle fields. DC Dart owns application transitions, validation, pending-operation tracking, selected route, collections and operation decisions. UI nodes bind to the resulting state; native platforms must not separately decide those flows.
2. **One shared dispatcher.** A synchronous native export accepts state, an event and a bounded output region. It updates state and emits typed effects. Event tags and effect tags must be schema-generated named constants with exhaustive checks, never ad hoc numbers in each platform's handwritten implementation.
3. **Narrow native adapters.** Emitted Swift/Java/C code renders the shared state and executes specifically typed HTTP, secure storage, photo, permission, location, clock and navigation effects through normal OS APIs. Results become completion events. An HTTP adapter transports a shared request specification; it must not contain separately authored login/send/friendship decisions.
4. **Explicit lifecycle.** Serialize dispatch onto one owner thread. Borrow input UTF-8/bytes only for that dispatch. Copy values needed after return into app-owned storage, with checked length/capacity and explicit allocation failure. Never retain JNI local references, Swift temporary buffer pointers or sensitive strings by accident. Cancel/reject completions using request and session generations. Clear sensitive storage on logout/account deletion.
5. **No hidden scheduler/interpreter.** Effects are ordinary generated native calls, not a runtime registry or JSON interpreter. Async OS completion plumbing is generated application code. DC Dart's state machine is AOT machine code; its schema/compiler is absent from the installed app.

## Minimal dcflight changes versus compiler changes

The proof needs **no DC Dart compiler change**. dcflight currently limits its public ABI declarations to bool/int32/uint32. Add a distinct generated record/buffer interface supporting native address-width fields and checked unsigned lengths, layout assertions, Swift C interop and JNI marshaling. Keep raw addresses private to generated adapters. Generate typed event/effect structures, lifecycle functions and observable state bindings from the canonical model. Inspect emitted headers/symbols and compile real native consumers on both mobile targets. This is a substantial dcflight application compiler change, not just four more policy exports.

A bounded event/effect application can therefore run on 0.1.1 now. Ergonomic owned strings, growing collections, Unicode operations and general async functions may require upstream language/library work if dcflight promises those exact semantics. Do not silently lower them into a different native implementation per platform. Any needed DC Dart changes require intentional tests, version bump and a published release before becoming the distributed dependency. General heap-helper acceptance needs an explicit ownership/runtime audit; it should neither be described as a VM requirement nor enabled by widening an allowlist without evidence.

The correct completion criterion is the same authored DC Dart transition code driving both apps' account, network and feature flows, with platform implementations limited to typed OS adapters. The existing four-policy Snap build does not meet that criterion yet.

## Implemented adapter extension after this audit

`ABIType.UINT64` / authoring ABI name `uint64` is now accepted for native-export signatures. Swift sees `UInt64` through `uint64_t`. Java sees `long`; its signed interpretation is irrelevant for opaque address bits. The emitted JNI converts inputs to `uint64_t` modulo 2^64 and copies return bits into `jlong`, avoiding implementation-defined unsigned-to-signed overflow casts. Portable scalar CALL actions still reject uint64: a pointer or wide integer must not pass through Int32 application state. Native record/buffer adapters are a distinct boundary.

The actual `generate_logic` path compiled and audited the proof for both iOS targets and Android ARM64, including generated JNI and final Android library dependency inspection. Exact emitted JNI was also linked to the host-native proof object and loaded by the JVM. Six bit-pattern roundtrips passed: 0, 1, 2^32, Int64.max, 2^63 and UInt64.max. A Swift executable using the emitted bridging header passed the same six values. These are host execution plus mobile compilation/link evidence, not mobile UI execution.

Ergonomic authoring must not require application developers to write packed offsets or getter/setter boilerplate. The released compiler directly supports the annotated Struct/getter-pair form used by the proof; ordinary stored-field caller-owned records are not the same implemented surface (stored fields are used by heap classes). A dcflight declaration pass can generate the verified Struct layout and native C/Swift/JNI views from one typed record declaration while preserving user-authored DC Dart transition bodies. That is source/compiler input lowering, not a runtime schema interpreter. It still needs explicit field types, variable-length buffer ownership, capacities, alignment assertions, allocation failure, and destroy/reset semantics before application integration is complete.

## Caller-owned layout foundation

`dcflight/state_layout.py` now provides frozen canonical `RecordLayout`, `Field` and `FieldType` definitions, independent of authoring syntax. It generates DC Dart packed declarations and a C record/owner from the same field sequence. Types are uint32, uint64, canonical bool and fixed-capacity caller-owned UTF-8. Bool is explicitly represented as normalized `u8`; UTF-8 is flattened into address/length/capacity because release0.1.1 does not lower nested packed getters.

Generated C includes all offset/size assertions and a 64-bit-pointer target check. UTF-8 setters reject invalid encodings, overlong encodings, surrogate scalars, out-of-range scalars and over-capacity input without changing state; shorter replacements wipe the unused tail. Owner wipe uses volatile stores. Owners must stay at one address after initialization and must not be shallow-copied: embedded addresses point into their own buffers. One thread owns dispatch. The generated representation does not make arbitrary pointer operations in developer logic memory-safe, and no borrow may outlive its owner. Generated Swift/JNI allocation and deterministic disposal wrappers are now available as described below. Asynchronous application capture/integration remains separate work.

`tools/verify_state_layout.py` generates the layout and compiles a named-field shared function that uses `state.mode`, `state.requestId`, `state.usernameLength`, `state.usernameCapacity`, `state.usernameAddress` and `state.consentFlag`. A generated 29-byte packed state passed host execution including a request ID beyond2^32, alongside four-target compilation and an empty undefined-symbol audit. Unit tests compile/run generated C setters and wiping, and reject invalid/colliding canonical declarations. The user-authored transition contains no manual offsets. Exact nested `state.username.length` and direct bool property syntax remain unsupported without an additional explicit authoring-lowering pass or a compiler extension.

## Generated native owner wrappers

`RecordLayout.swift_adapter()`, `java_adapter(package)` and `jni_adapter(package)` emit ordinary app-owned source. Swift uses one stable native owner allocation, a recursive lock, scoped `withAddress` borrowing and deterministic `close` (plus deinit cleanup). Java implements `AutoCloseable`, private native allocation/deallocation/setter methods, synchronized scoped borrowing and explicit close. It intentionally does not pretend finalizers provide deterministic cleanup: owners must be closed, normally with try-with-resources.

Closing or externally mutating an owner during a borrow fails rather than freeing its memory. Closing twice is harmless; using a closed wrapper fails. UTF-8 text is copied into bounded owner buffers through the generated C validator, with preallocation bounds checks and strict Java encoder errors for malformed UTF-16. Owner memory is wiped using volatile stores before deallocation. Temporary arrays are cleared on completion; immutable source Swift/Java strings and copies outside these wrappers cannot be guaranteed erased.

`withAddress` is an unsafe native-adapter boundary: a callback must not retain the address, launch asynchronous access, or make the DC Dart implementation corrupt the owner representation. The APIs do not make arbitrary native pointers memory-safe. The callback holds the lock for its synchronous duration; async OS operations must copy effect payloads and submit later completion events through a fresh borrow. These helpers allocate native application data; they are not a dcflight VM, bytecode interpreter or registry dispatcher.

The updated `tools/verify_state_layout.py --java-home ...` compiles/runs generated Swift and exact generated JNI/Java wrappers against the same host DC Dart function. Checks cover UTF-8 copy/oversize rejection, malformed Java surrogates, shared function execution, close/mutation during borrow, idempotent close and use-after-close rejection. It also recompiles the shared logic for iOS device/simulator and Android ARM64. These tests are host lifecycle execution and mobile object compilation, not a claim that the lifecycle wrappers are integrated into Snap or that shared Snap orchestration is complete.
