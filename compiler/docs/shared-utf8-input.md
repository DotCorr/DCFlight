# Shared DC Dart UTF-8 inputs

`LogicFunction(parameters: ['utf8'], returns: 'uint32')` accepts a string literal
or `Ref<String>` in both Dart and JSON authoring. The canonical ABI distinguishes
this borrowed UTF-8 input from integers and pointers. Results remain scalar;
returning a string, retaining an input address, or borrowing asynchronously is
not supported by this contract.

An input may contain at most 1 MiB of UTF-8 bytes; all string inputs together may
contain at most 4 MiB per call. Encoding preserves embedded NUL, emoji, combining
sequences, and non-Latin text. It does not normalize text. Java strings containing
unpaired UTF-16 surrogates are rejected. Empty strings use address 0 and length 0.

## Authoring and failure handling

```dart
logic: const Logic(
  source: 'logic.dart', prelude: 'prelude.dart',
  functions: [LogicFunction(name: 'hasText', parameters: ['utf8'], returns: 'uint32')],
),
flowActions: [
  FlowAction(id: 'check', function: 'hasText',
    arguments: [const Ref<String>(name: 'text')], failure: 'invalidText',
    cases: [
      FlowCase(code: 0, effects: [SetEffect(target: 'message', value: 'Enter text.')]),
      FlowCase(code: 1, effects: [SetEffect(target: 'message', value: 'Accepted.')]),
    ]),
  FlowAction(id: 'invalidText', cases: [
    FlowCase(code: 0, effects: [SetEffect(target: 'message', value: 'Text cannot be processed.')]),
  ]),
],
```

UTF-8 calls require an explicit `failure` action. Ordinary `Action.call` uses the
same input and failure contract; its failure target refers to an ordinary action.
Flow failure targets refer to flows. Unknown targets and synchronous cycles are
rejected before generation. No success-case effects or result assignment occur
when input conversion fails. A failure handler may intentionally update state.

## Native function ABI

One logical string expands into two native parameters: `uint64_t address` followed
by `uint32_t byteLength`. Other parameters retain their order. The compiler checks
the flattened declaration against the header emitted by released DC Dart 0.1.1.
For the example, the shared source is:

```dart
import 'prelude.dart';
@bare
u32 hasText(u64 address, u32 byteLength) {
  if (byteLength == u32(0)) return u32(0);
  return u32(1);
}
```

To inspect bytes, use `Pointer<u8>.fromAddress(address + offset).value`, with
`offset < byteLength`. App input never supplies an address. Generated native
adapters obtain addresses only while the associated buffers are alive. DC Dart
code must not mutate or retain those borrowed buffers; this low-level obligation
is not statically proven by dcflight.

Swift emits scoped buffer borrows. Android emits a strict String facade and a
private JNI byte-array entry point, with validation and release on every acquired
buffer path. JNI does not use modified UTF-8 conversion. These helpers are ordinary
app-owned native source. No registry, interpreter, Dart VM, or dcflight runtime is
linked into the app.

Unsigned input conversion and portable state-result overflow use the authored
failure path for UTF-8 calls. Existing scalar-only call behavior is unchanged.
Snap login and registration use this API to validate username contents in the
single shared DC Dart source, matching the backend's ASCII username character set.

Native proof covers iOS simulator and Android ART, including malformed Android
input, bounds, mixed arguments, repeated failures and recovery. It does not prove
arbitrary user logic memory safety or recovery from every allocation failure.
