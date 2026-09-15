# Native generation target boundaries

`compile_app(..., targets=("android",))` emits and verifies Android NativeOperation implementations only. The iOS-only path works symmetrically. Standalone operation emission defaults to both targets; explicit unsupported, empty or duplicate targets are rejected.

The canonical operation still requires both implementations. Both graphs receive SDK-free grammar and local-dataflow validation, including reference-only receivers, declaration-before-use, unique nonreserved bindings, valid nested projection/unwrap forms, explicit throws for unwrap, and bounded literals (depth16,4096 nodes per literal). Android explicit types use the existing concrete Java type grammar. SDK-specific result types, overloads and availability are validated when that platform is selected. Skipping a platform does not certify its implementation.

Both platforms' exact referenced catalog descriptors and provenance remain shared input evidence. Reading that metadata never invokes foreign SDK tools. Native invocation certificates and Android conditional availability are revalidated only for selected implementations. Separate per-platform emission hashes are retained in the source receipt; shared-input comparison ignores those intentionally different hashes. Unrelated catalog entries do not invalidate the app's shared-input identity. App deployment-target validation applies when generating iOS, without raising the minimum automatically.

The SDK extraction harness also accepts only the root-owned standard macOS `/var` and `/tmp` aliases as ancestors. Arbitrary output symlinks remain rejected. This corrects the failed dev19 temporary-directory regression; it does not change the frozen dev19 result or claim full SDK coverage.

No runtime dispatcher, renderer, Dart VM or JS engine is introduced by these development-time checks. DC Dart remains released0.1.1 and unchanged.
