# Native Swift callable variants

One precise SDK identifier can expose callback and synthesized async Swift call forms. The compiler retains both. Multiple forms require an explicit `variant` selector; singleton calls remain compatible. No form is chosen according to SDK graph order, and an async failure is never replaced by callback success.

The selector is `swift-v1:<sha256>` of a canonical SDK declaration contract. It includes labels, parameter/result types (including callback attributes), availability, effects, isolation, mutability and generic constraints. Local parameter names, native verification conclusions, unsupported-reason diagnostics, import context and source-file hashes are excluded. Exact import/source context is independently replayed by verification/export. Duplicate declarations retain the union of import dependencies, conservative rejection reasons and every resolved nominal source hash.

`SDKCatalog.variant_records(id)` exposes forms. `catalog.select(id, variant).emit_call(...)` selects one typed contract. JSON `NativeAPI.emit` accepts an iOS-only `variant` field and echoes it. Present malformed selectors, including null, are rejected. Dart `NativeCall(..., variant: ...)`, native sequences and native operations carry the same selector. Sequence/operation `apiCalls` retain it, and selected callback escaping requirements propagate to input declarations.

Multi-form records use `nativeVariants` children. The parent is not emittable and receives no blanket native proof. Children preserve the SDK parent ID and add their selector. Parent IDs and concrete variants are separate denominators (`indexed` versus `variants_indexed`). Verifier `nativeTested` and export `native_tested` count successful concrete candidates, not globally supported parent APIs.

The native verifier includes the selector in generated function identity, invocation members, source replay and child evidence. Export preserves selectors when attaching native conclusions and import context; child nativeConformance is bound to the same selector. Callback and async results remain separate. Context-specific certificates accept `variant_selections={id: selector}`; the CLI spelling is `--variant SDK_ID=SELECTOR`. Certificates retain operation, actor context and variant, and are revalidated before use.

Existing singleton catalogs remain callable as their recorded contracts, but cannot prove whether their original import discarded another form. No historical evidence is upgraded. Regenerated multi-form catalogs require explicit selection. SDK recovery tools that request an ambiguous ID without selecting a form fail closed; they do not receive a hidden default.

This change is still a private reviewed-stage candidate, not an integrated release. Native tests typecheck selected calls; they do not prove runtime behavior, entitlement approval, or universal application coverage.
