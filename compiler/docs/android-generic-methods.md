# Explicit Android generic method calls

Static and instance generic methods can be specialized with explicit `typeArguments` in a
native invocation request or a native sequence step. This remains a platform
escape hatch, not shared Dart callback-body authoring.

```json
{
  "platform": "android",
  "scope": "core-bytecode",
  "id": "java.util.Collections#singletonList(T)",
  "typeArguments": ["java.lang.String"],
  "arguments": [{"literal": "hello"}]
}
```

The result type is `java.util.List<java.lang.String>` and the emitted expression
is `java.util.Collections.<java.lang.String>singletonList((java.lang.String) ("hello"))`.
Both the explicit Java type witness and selected-parameter casts remain in
ordinary native source. No runtime registry or specialization helper is emitted.

The evaluated Dart authoring form uses the same checked request:

```dart
NativeCall(
  'java.util.Collections#singletonList(T)',
  scope: 'core-bytecode',
  typeArguments: ['java.lang.String'],
  arguments: [NativeLiteral('hello')],
  bind: 'items',
)
```

For a native Class parameter use `NativeClass('android.net.Uri')` in the
arguments list. `NativeCall.typeArguments` and `NativeClass` serialize compiler
input only; they do not execute generic methods or load classes in Dart.
The operation schema accepts these forms and bounds type-argument lists to
1–32 entries. The platform emitter performs type, bound and availability checks.

The compiler substitutes method parameters into argument and result types and
checks each declared upper bound, including intersection bounds, using the
catalog's assignability evidence. Arguments must be reference types. Missing,
extra, primitive or incompatible type arguments reject. Substitution must leave
fully supported concrete types. Other unsupported reasons—such as a non-public
or flagged API—remain errors; type arguments do not override verification
failures recorded in a catalog.

An instance invocation also requires a typed receiver. The emitter checks its
declared owner relationship, retains the owner's wildcard view where generic,
and applies the method's explicit type arguments. For example, a `List<String>`
receiver can call `toArray(T[])` with `typeArguments: ["java.lang.String"]` and
an empty String array, yielding `java.lang.String[]`. An unrelated receiver or
an incompatible array argument rejects. The element compatibility of a native
collection conversion remains subject to the API's runtime behavior.

No type inference is attempted. Constructors declaring their own type parameters and iOS generic specialization remain unsupported by
this path. Concrete Android owner types are supported as described below. A catalog member that needs specialization remains marked unsupported
for unspecialized calls; this change does not relabel the inventory as compiled.

The emitter conservatively rejects competing generic varargs overloads when a
peer's type-variable array also accepts the selected concrete array after
specialization. Explicit Java type witnesses do not always disambiguate such
overloads; native Android animation declarations exposed this case.

`tools/verify_android_generics.py` sweeps a source snapshot using explicit
candidate types, supplied with repeated `--type` options. It requires
`--source`, `--android-jar`, `--javac` and a fresh `--report`. Each candidate is
repeated across a method's parameters, so this is sampled specialization
coverage, not every possible combination. It compiles batches against a copied
SDK jar with unchecked warnings treated as errors, isolates failing probes,
and records source/SDK/compiler hashes, exact probe methods, pre-compilation
rejections and native diagnostics. It does not execute calls or promote catalog
records to universally supported status.

Tests exercise bound rejection, concrete results, empty generic collections,
native sequence bindings, and Java compilation with unchecked warnings treated
as errors. The Android execution harness specializes a real catalogued
`Collections.singletonList(T)`, calls the generic instance `List.toArray(T[])`,
and passes results to native string-formatting APIs
on ART. These are specific native-call checks, not certification of every
generic method or of full application behavior.


## Concrete native receiver types

A typed receiver such as `java.util.List<java.lang.String>` supplies the owner
parameter `E` when compiling `List.get(int)` or `List.add(E)`. The result and
argument types remain `java.lang.String` in generated Java. A receiver declared
as a subclass can supply the same parameters through catalogued generic parent
relationships. Instance fields use the same substitution for reads and writes.
Explicit method parameters remain separate: method variables shadow owner
variables, and method bounds can refer to an owner's concrete arguments.

Native invocation requests already contain the receiver type; there is no new
runtime object or authoring interpreter. In native sequences, receiver types
are inferred from input or preceding result bindings. The compiler validates
arity, declared bounds, receiver assignability and supported resulting types.
Unresolved dependent types and incompatible arguments reject. Catalog restrictions
such as non-public members remain restrictions after specialization. Wildcard-dependent
owner operations and arbitrary native callback bodies are not provided by this addition.

The native sweep harness also accepts repeated `--receiver` options instead of
`--type`. For example `--receiver 'android.util.SparseArray<java.lang.String>'`
checks reachable catalogued instance methods and fields with that receiver type.
Each report records emitted probes, native compiler failures and emission
rejections separately. It uses the same bounded batch compilation and SDK hashes
as the generic-method sweep. These are compile checks, not execution of all SDK
methods or universal certification of a parameterized type.


## Typed native construction

`NativeCall.constructedType` specifies the concrete Android class to construct.
It is separate from `typeArguments`, which specializes a method or constructor's own parameters.
For example:

```dart
NativeCall(
  'java.util.ArrayList#<init>()',
  constructedType: 'java.util.ArrayList<java.lang.String>',
  bind: 'items',
)
```

The JSON field is also `constructedType`. The compiler emits an ordinary
`new java.util.ArrayList<java.lang.String>()` expression and retains that exact
type on the sequence binding, so later `add(E)` and `get(int)` calls use String.
Parameters of constructors on generic classes use the same substitution,
including declared wildcard parameters such as `Collection<? extends E>`.

The constructed type must name the exact class owning the selected constructor,
with valid concrete arguments satisfying the declared bounds. It cannot be used
on methods, fields, iOS calls or with a receiver. Raw generic constructed types,
wildcard arguments, invalid arity, inaccessible or abstract owners, unsupported
inner constructors and indistinguishable overloads reject. Calls omitting
`constructedType` retain existing raw constructor behavior for ordinary constructors.

Generic constructor declarations require explicit `typeArguments`, including when
their type variables do not appear in the argument list. For a catalogued native
declaration `Box<C>` with `public <T extends CharSequence> Box(T value)`:

```dart
NativeCall(
  'sample.Box#<init>(T)',
  constructedType: 'sample.Box<java.lang.Integer>',
  typeArguments: ['java.lang.String'],
  arguments: [NativeLiteral('native value')],
  bind: 'box',
)
```

This emits `new <java.lang.String> sample.Box<java.lang.Integer>(...)` directly.
The class in this example must exist in the native project's SDK or dependency;
dcflight does not supply a `Box` runtime. Constructor variables shadow same-named
owner variables. Bounds may refer to other constructor variables or unshadowed
owner variables. A generic owner requires `constructedType`; no constructor type
inference or raw generic owner is accepted for this path. Missing arguments,
invalid bounds and ambiguous supported overloads reject before emission.

The syntax follows [Java class instance creation expressions](https://docs.oracle.com/javase/specs/jls/se17/html/jls-15.html#jls-15.9).
These are ordinary erased Java generics, with no dcflight runtime dependency.

The sweep tool accepts repeated `--construct` options, mutually exclusive with
`--receiver` and `--type`, to generate constructor probes from the SDK catalog.
Add repeated `--constructor-type` candidates alongside `--construct` to probe
constructor-owned generics. Each candidate is repeated across the constructor's
formal parameters; these are sampled combinations, not exhaustive assignments.
Ordinary constructors are checked once. Reports preserve both the constructed
owner type and constructor arguments for successful and rejected probes.
The checks compile native code without executing SDK constructors. Native host
execution tests separately exercise construction, writes, copy construction and
reads, including a complete operation authored through the Dart DSL.


## Android runtime verification

The packaged `dcflight sdk test-android-values` command also executes reviewed
typed-construction sequences on an explicitly selected Android device. Its cases
include Pair field reads, SparseArray clone independence, ArrayMap copy
independence and LruCache eviction and retained values. Deferred camera output
configuration cases use explicit constructor arguments for SurfaceTexture and
SurfaceHolder and check the default surface group without starting a camera.
All calls pass through
the catalog and typed sequence compiler. Java compilation treats unchecked
warnings as errors before D8 converts the fixture for ART.

The harness uses a unique temporary command-line fixture, checks a run-specific
completion marker and removes the fixture afterwards. It records the emitted
source, compiler-source hashes, SDK and DEX hashes, device build fingerprint,
expected results and exact cases. It does not install or drive the product app.
These checks establish those SDK behaviors on the selected device; they do not
certify UI behavior, application lifecycle, every API or production readiness.
