# dcflight 0.4.0.dev19

This development release keeps dcflight entirely at development time. DC Dart remains released0.1.1; no language dependency was changed.

## One authored iOS minimum

Use `IOSConfiguration(deploymentTarget: [18, 0])` in Dart or `nativeConfiguration.ios.deploymentTarget: [18, 0]` in JSON. The default remains17.0. Application NativeOperations inherit it; an explicit operation target above the app minimum is rejected before synchronization. An error flow alone does not provide an availability fallback. See [deployment details](../ios-deployment-target.md).

The minimum is emitted into the generated target xcconfig. Regeneration preserves user-owned projects and checks actual parsed target configuration bindings. Missing or redirected hooks and target-level deployment overrides must be repaired explicitly. External command-line build overrides are outside the authored contract.

## Replayable iOS SDK extraction

`tools/sweep_ios_sdk.py` retains deterministic gzip graph inputs by default. Resume validates graph and descriptor hashes and extraction provenance; missing, corrupt or mismatched artifacts trigger extraction again. `--keep-graphs` retains uncompressed inputs. Explicit `--discard-graphs` produces output that cannot be reused as native proof or resumed as verified success. This makes verification reproducible; it does not itself certify every extracted API.

## Reusable Android native flow verification

Run the repository helper with an explicit toolchain description and isolated output:

```sh
python tools/verify_snap_shared_android.py --toolchain /path/to/toolchain.json --out /path/to/fresh-verification --serial emulator-5580
python tools/verify_snap_shared_android.py --toolchain /path/to/toolchain.json --out /path/to/existing-verification --audit-only
```

The helper builds the generated Snap native test fixture, executes its assertions on the selected Android device/emulator, and audits the exact APK artifacts. Audit-only mode checks existing artifacts; it does not execute device tests. These targeted shared-flow assertions and artifact audits are separate from full UI, hardware and production acceptance.

Final release validation must use this version's installed/extracted package and fresh reports. Historical dev18 evidence is not relabeled as dev19 evidence.
