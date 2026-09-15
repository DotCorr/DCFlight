# Verify with exact per-module type plans

The SDK coordinator accepts `--type-plans BATCH_DIRECTORY` instead of
`--dependencies`. It uses the original SDK capture as the primary graph input.
Validated derived nominal subsets are passed as automatic type-module inputs;
they are not added as explicit imports. The compiler chooses imports per call.
Select the desired deployment target with `--ios-version 26.2` and device SDK
with `--sdk-environment iphoneos`.

The validator independently scans original capture symbols, reconstructs exact
referenced nominal selection and compares derived JSON against original normalized
symbol hashes. Rehashing an edited subset or plan manifest cannot confer original
SDK provenance. Original retention, primary aliases, graph sets, SDK context and
capture statuses are checked. Batch producer fingerprints are recorded as provenance,
not treated as signed native certificates. Original extraction producer identity is
validated separately by the existing coordinator.

Rejected plans produce `dependency_plan_rejected` receipts and a nonzero overall
result. No fallback or omission turns those modules into passes. Failed original
extractions remain separately classified. Planning provides no native credit.

Resume identity includes batch and per-plan hashes, the batch producer fingerprint,
validator source hash, exact verifier wheel, original extraction producer and inputs,
selected SDK target and toolchain. Final validation also runs on entirely resumed
jobs. Native worker execution uses the selected wheel without compiler overlays.

Validation uses the existing bounded input readers, a one-million-symbol limit and
four-million-reference limit. It keeps compact nominal hashes rather than source
objects, but underlying JSON parsing and original SDK graphs can still use substantial
memory. Run under a supervisor for a hard process resource deadline. The batch tree
must stay immutable, and archives must preserve its private hardlinks.

Rejected-plan explanations are retained as caller-provided reasons, not certified
reproductions of the planner failure. They cannot grant native credit or success.
