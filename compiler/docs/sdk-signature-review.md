# Reviewing incomplete SDK signatures

SDK symbol graphs can omit contract information present in the installed Swift interface. AVFoundation SDK 26.2's video-composition filtering initializer, for example, exports its async callback without the Sendable attribute present in the Swift interface.

Do not infer a replacement type solely from a native compiler diagnostic. Locate the matching owner, overload, parameter labels and complete signature in the installed SDK interface. Record the interface hash, path and line, plus the original descriptor. Keep original inventory evidence intact.

Use SDKCatalog.from_records with the reviewed typed descriptor. Verify both the original failing call and corrected passing call under the same SDK, target and Swift language mode. Preserve escaping, async, throwing and actor contracts; a change that compiles in one context does not establish universal caller safety.

Import reviewed records into a separate explicit catalog scope. Catalog.import_records can atomically attach compiled evidence with exact command, toolchain and generated-source hash. NativeAPI requests select that scope explicitly. Do not relabel compilation evidence as runtime execution, and do not automatically promote all related signatures.

This manual review path already works through the installed compiler's typed descriptor API. Bulk Swift-interface enrichment and shared Dart callback-body authoring are separate unfinished capabilities.

## Autoclosure parameters

The iOS descriptor Parameter.autoclosure flag distinguishes lazy native arguments from ordinary callbacks. Import preserves the flag from function-signature or full-declaration fragments. Callers supply a typed zero-argument callback reference; emission places a callback invocation inside Swift's native autoclosure argument, preserving lazy evaluation. Escaping remains independent metadata, so generated wrapper inputs retain escaping requirements.

Current support covers synchronous, nonthrowing, nonoptional, unannotated zero-argument callback types. Other autoclosure shapes are rejected during signature validation; no eager evaluation fallback is used. Native regression execution verifies that a skipped callback is not invoked and an evaluated callback runs once. This does not supply shared Dart callback-body authoring.

## Actor-owned members

Swift symbol graphs can classify actor declarations as swift.class. The owner pass also checks the declaration's actor keyword and preserves ownerKind=actor. Instance methods and properties inherit actorIsolation=instance unless an explicit nonisolated/global-actor declaration supplies a different contract. Static members and constructors do not automatically inherit instance isolation.

Calls to isolated instance members require allowAsync and emit native await. Nonisolated methods remain ordinary calls. Direct isolated property assignment is rejected; callers must use an actor method. This models external actor access, not actor-local isolation proofs. Native compilation must still verify Sendable arguments/results, actor reentrancy assumptions and SDK availability for the actual caller context. Shared synchronous Dart operations do not become async merely because native escape-hatch emission supports actor calls.

## Explicit protocol values

The Swift type grammar preserves any Protocol as an existential node, distinct from the protocol's nominal spelling. Optional syntax is (any Protocol)?; nested collections and callback signatures retain that distinction. Typed references match structurally, and optional nil literals are emitted using the native optional existential type. No implicit concrete-to-protocol erasure or conformance proof is supplied. Protocol compositions, opaque some types and generic Self requirements remain rejected.

## Mutating getters

Swift property access is not always a read-only operation. An accessor declared mutating get preserves the descriptor's mutating flag, requires a mutable receiver binding and reads directly from that binding. The verification wrapper creates a mutable local receiver for this case. This is distinct from setterMutating, which describes property assignment. Native span/lifetime restrictions still come from Swift's typechecker; a successful discarded getter probe does not prove that its returned borrow can escape.

## C callback calling convention

The typed Swift grammar supports @convention(c) function types and optional/collection forms. C pointers are distinct from ordinary Swift closure values and must match the declared reference type. Swift async, throwing and MainActor C callback types reject. Native compilation still establishes C representability for the parameter and return types.

Some imported C function-pointer parameters lose their convention in Swift symbol graphs. Review the installed C header's typedef and function declaration rather than inferring the convention solely from an error. Keep the header hash, declaration locations, original failing signature and corrected passing fixture. A reviewed signature can live in a separate catalog scope. The native ABI test links generated Swift with a Clang-compiled callback-invoking function; it does not add a dcflight runtime adapter.
