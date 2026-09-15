# Generic Android reference assignability

The direct Java emitter preserves concrete generic arguments through declared superclass and interface edges. It substitutes the owner's formal type parameters into each parent declaration, then applies ordinary invariance and wildcard containment checks. For example, ArrayList<String> can reach Collection<?> through its declared generic parents; List<String> does not become List<Object>.

Non-generic owners retain fixed parent arguments too: a class declared as StringList extends ArrayList<String> can be passed to List<String> or Collection<?> APIs, including through another non-generic subclass. It cannot be passed to List<Integer>. Omitting the arguments of a generic owner does not supply evidence for a concrete parameterized parent, and supplying arguments to a non-generic owner rejects.

Only catalogued class/interface declarations supply inheritance evidence. Unknown owners, incompatible element types and unresolved generic parameters reject. Raw parent declarations do not establish parameterized compatibility. Traversal is bounded to 32 steps; Java type strings are bounded to 4096 characters and 16 nested type levels. Cyclic or oversized input cannot cause unbounded recursion.

Native call arguments retain explicit casts to the selected SDK parameter type, preserving overload selection. A host Java test compiles with unchecked warnings treated as errors, and device verification executes the same Collections.frequency call through the real SDK catalog on Android ART. Neither test certifies arbitrary callbacks, all collection APIs or complete app behavior.
