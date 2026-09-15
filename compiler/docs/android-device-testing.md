# Executing shared logic on Android

`tools/verify_android_device.py` builds a separate, dependency-free native Android instrumentation APK. It invokes the delivered application's generated `AppModel` and `SharedLogic` inside the installed application's Android process. The application's APK remains unchanged.

The verifier checks sixteen arithmetic, branch, loop and unsigned ABI cases. It confirms ART and the native application library are mapped into the process, records the Android build fingerprint and PID, and saves PID-filtered logs. It checks the installed application's APK hash against the delivered file before testing. The test APK contains only test classes: the target model and native wrappers are compile-only references, and no application classes or native libraries are bundled into it.

```sh
python3 tools/verify_android_device.py \
  --project /path/to/dcflight-shared-logic \
  --work-dir /path/to/external-build-directory \
  --sdk /path/to/android-sdk \
  --java-home /path/to/jdk17 \
  --gradle /path/to/gradle-8.11.1/bin/gradle \
  --serial emulator-5580 \
  --report /path/to/device-verification.json
```

Install the delivered `app-debug.apk` on the selected device or emulator first. If testing a freshly rebuilt APK, pass its exact path with `--target-apk`; the verifier compares its hash with the installed package. The application and instrumentation APK must use the same debug signing key. `--build-only` builds and audits the test APK without contacting a device; its report explicitly states that Android execution has not occurred.

This test uses Android's platform `Instrumentation` API and `adb am instrument`, without AndroidX or a test framework runtime. It sends no UI input and does not launch or manipulate an activity. Instrumentation may finish the target process when testing completes, so reopen the app afterward for manual UI testing.

Passing this test establishes actual Android ART/JNI/model execution for the delivered example. It does not establish complete UI behavior, activity lifecycle coverage, device API coverage or execution of every indexed platform API. A separate host-JVM test exists in `tools/verify_host_jni.py`; host results must not be described as Android execution.
