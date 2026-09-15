# Typed shared presentation conditions

Declare conditions once in Dart or JSON. Lowering produces immutable canonical StringIsEmpty, BooleanNot, BooleanAll and BooleanAny expressions. Swift, Java Views and Kotlin Compose output uses ordinary native string emptiness checks and boolean operators. No predicate evaluator, JSON registry, Dart VM or dcflight library is shipped.

```dart
Text.bind(const Ref<String>(name: 'message'), id: 'status',
  visibleWhen: const BooleanNot(
    StringIsEmpty(Ref<String>(name: 'message'))));
```

Equivalent JSON node condition:

```json
{"visibleWhen":{"not":{"isEmpty":{"ref":"message"}}}}
```

`BooleanAll([...])` / `{"all":[...]}` requires every operand; `BooleanAny([...])` / `{"any":[...]}` requires at least one. Native evaluation short-circuits in authored order. Operands are pure reads. A string is empty only when it has zero content; spaces, line breaks, combining marks and emoji are nonempty. No trimming, case folding or Unicode equality rule is implied.

Conditions are supported on `visibleWhen` and `enabledWhen`, including supported media/device nodes and repeated row children. Literal booleans and bool references remain valid. Inside a row, `FieldRef<String>` can be used in StringIsEmpty and bool fields can be composed directly. Field references keep their row scope and remain read-only. Android map annotation dependencies include state reads nested inside predicates.

The canonical validator checks operand types, unknown fields/references, nesting up to 16, at most 256 predicate nodes and 1..32 operands per all/any. The JSON Schema describes recursive shape and array bounds; lowering additionally enforces types, scope and resource limits. Dart authoring serializes predicates, without evaluating runtime state. The current node constructor accepts Object? conditions for compatibility; malformed operand types are rejected by compiler validation rather than being guaranteed by Dart's static type checker.

These expressions do not widen writable bindings, scalar node properties, action assignments or effect arguments. Unsupported use is rejected. String equality and comparisons need separately specified cross-platform semantics. Canonical predicate records carry an explicit operator discriminator so generation hashes distinguish all from any and isEmpty from not.

Verification covers both Dart frontends, schema, invalid input, row-scope restoration, direct native emission and compiled/executed Swift/Java/Kotlin truth tables. Snap uses this API for its shared status labels. These are presentation expressions, not a claim of arbitrary shared asynchronous Dart business logic support.
