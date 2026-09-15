# Android native value conversions

The typed Java emitter accepts native invocation conversions: primitive widening,
boxing to the corresponding Java wrapper followed by reference widening, and
unboxing followed by primitive widening. Reference inheritance uses catalogued
declarations. For example, `int` can reach `Integer` and `Object`, while
`Integer` can reach `long`. A wrapper's additional superclass or interface
relationships require catalog evidence.

It does not combine primitive widening with boxing (`int` to `Long`), narrow
unboxed values (`Long` to `int`), convert between unrelated wrappers, or box
array elements. Explicitly authored null values cannot be unboxed. A reference
that evaluates to null at runtime retains Java's native unboxing exception;
the compiler does not insert a fallback value or claim null-flow analysis.

Calls still cast arguments to the selected member's exact parameter types.
This preserves the selected overload even when another overload could accept
the original primitive or wrapper directly. Field assignments use the same
conversion checks. These are source-level Java conversions; no dcflight
conversion library ships with the app.

The rules follow [Java invocation contexts](https://docs.oracle.com/javase/specs/jls/se17/html/jls-5.html#jls-5.3).
Native Java tests exercise competing overloads and field assignment. The
Android execution harness includes boxing through `Objects.toString(Object)`
and unboxing/widening through `Integer.valueOf(int)` followed by
`Long.toString(long)`, emitted from the real SDK catalog and executed on ART.
These checks do not establish full SDK, application lifecycle or UI coverage.

## Class literals

Native requests and sequence arguments accept `{"class":"android.net.Uri"}`.
This emits `android.net.Uri.class` with type `java.lang.Class<android.net.Uri>`.
It can be passed to a specialized generic method such as
`Bundle.getParcelable(String, Class<T>)` with `typeArguments: ["android.net.Uri"]`.

Class literals also support arrays and primitive type names. `int.class` has
type `Class<Integer>`; `int[].class` has type `Class<int[]>`; `void.class` has
type `Class<Void>`. Parameterized literals such as `List<String>.class`, free
type variables and raw expression strings reject. These are normal native
class tokens, not a dcflight runtime type registry. Referenced native classes
still have to exist in the app's SDK or declared dependencies.
