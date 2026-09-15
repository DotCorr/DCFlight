# Device and simulator SDK evidence

`--sdk-environment iphonesimulator` remains the default. Explicit `iphoneos` selects the installed device SDK. The shared environment helper couples the SDKSettings canonical name, supported target, architecture and environment with the target triple: `arm64-apple-ios18.0-simulator` or `arm64-apple-ios18.0`. Mixed SDK/triple combinations reject before native compilation. New receipts include `sdkEnvironment` and the exact SDKSettings SHA256. Export checks actual settings again; missing environment on legacy evidence means simulator only, never inferred device support.

The option is supported by `tools/sweep_ios_sdk.py`, the packaged iOS verifier, `dcflight sdk verify-ios`, `dcflight sdk verify-ios-invocations`, and `tools/verify_ios_sdk.py`. Extraction's optional `--target` must agree with the SDK environment. Keep separate extraction/output directories; changed environment invalidates extraction/coordinator resume identity. The whole-SDK coordinator still requires a complete eligible extraction inventory. For a bounded device capture, invoke the direct per-module verifier instead.

Example signing-free device verification:

```sh
python tools/sweep_ios_sdk.py --sdk-environment iphoneos --modules DockKit MetalKit --output device-extraction
python tools/verify_ios_api_batch.py --sdk-environment iphoneos --module DockKit=device-extraction/DockKit/symbolgraphs --ios-version 18.0 --swift-version 6 --limit 0 --output dockkit-device.json
```

`verify_and_index(..., sdk_environment='iphoneos')` publishes into `Module@iphoneos`, while simulator keeps the legacy `Module` scope. SDK environment and settings identity remain in source/evidence metadata. Public native requests selecting device exports require `sdkEnvironment: "iphoneos"` and the device scope; defaults cannot consume device certificates. Identical IDs in both scopes require an explicit scope selection. Operation/context certificates recompile against their exact SDK environment and reject cross-environment requests.

Higher-level native sequence and application-operation authoring do not yet expose environment selection. They reject `sdkEnvironment` explicitly instead of dropping it or borrowing device certificates for their default simulator context. This change does not add device deployment, signing, installation or hardware capability validation.

Validation includes SDK/settings/target tampering, separate catalog scopes, old simulator mock fixtures upgraded to real minimal SDKSettings, exact operation certificate checks, and unchanged simulator invocation regressions. Real installed SDK extraction confirms MetalKit's iOS26-only currentMTL4RenderPassDescriptor is present in the device graph and absent from the simulator graph. Bounded native proofs check DockKit at device18, MetalKit at device18/device26.2, and MetalKit simulator18; the version26 member is skipped at18 and receives no18 compiled credit. Matching device invocation evidence is actually recompiled, while the simulator default rejects it. These are source typechecks, not calls executed on physical devices.
