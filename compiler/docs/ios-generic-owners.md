# Native iOS receiver specialization

Dart and JSON use the existing typed NativeValue input/reference forms. An instance receiver can name `NSDiffableDataSourceSnapshot<Int, String>`; the compiler checks owner generic requirements and substitutes parameter/result types before emitting ordinary Swift. No raw source or descriptor edit is needed.

Protocol static calls require an existential metatype receiver such as `any Protocol.Type`. This is a value representing a conforming native type, distinct from the protocol type itself. Ordinary concrete static calls retain their existing syntax.

Supported specialization includes top-level generic instance members and inherited nested owners with identical parameter identities, such as `NSDiffableDataSourceSnapshot<Int, Int>.ReorderingHandlers`. Owner Hashable/Sendable checks currently use compiler-owned Swift scalar conformance evidence. Arbitrary custom conformances, method generic parameters, generic constructors and ambiguous shadowed owners remain rejected. Dependent metatypes are structural; unresolved associated member types remain rejected.

Native verification records the receiver specialization used by each probe. One compiled specialization is evidence for that specialization, not every possible generic argument. Native rejection/skip metadata cannot be bypassed merely by supplying a typed receiver. Swift concurrency and deployment-target checks still apply.
