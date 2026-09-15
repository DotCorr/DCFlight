#!/usr/bin/env python3
"""Verify delivered shared logic on Android with a separate native test APK.

No UI input is injected. Instrumentation invokes app model/JNI functions in the
installed app process. The application APK is not modified. This does not claim
UI or lifecycle coverage beyond instrumentation startup/completion.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import time
import zipfile

CHECK_PACKAGE = 'com.dotcorr.logicchecks'

JAVA = r'''package com.dotcorr.logicchecks;
import android.app.Instrumentation;
import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import org.json.JSONObject;
import org.json.JSONArray;
import __TARGET__.AppModel;
import __TARGET__.SharedLogic;

public final class DeviceChecks extends Instrumentation {
    private int checks;
    private boolean created;
    @Override public void onCreate(Bundle args) { super.onCreate(args); created = true; start(); }
    private void equal(int actual, int expected) { checks++; if(actual != expected) throw new AssertionError(actual + " != " + expected); }
    private void rejected(Runnable action) { checks++; try { action.run(); } catch(IllegalArgumentException expected) { return; } throw new AssertionError("Expected unsigned range rejection"); }
    @Override public void onStart() {
        JSONObject result = new JSONObject(); Bundle output = new Bundle();
        long start = android.os.SystemClock.elapsedRealtime(); boolean passed = false;
        try {
            result.put("pid", android.os.Process.myPid());
            result.put("package", getTargetContext().getPackageName());
            result.put("instrumentationCreated", created);
            result.put("sdk", android.os.Build.VERSION.SDK_INT);
            result.put("abis", new JSONArray(android.os.Build.SUPPORTED_ABIS));
            result.put("vm", System.getProperty("java.vm.name"));
            AppModel model = new AppModel();
            model.a_add(); model.a_add(); equal(model.s_count, 2);
            model.a_reset(); equal(model.s_count, 0);
            model.a_discount(); equal(model.s_total, 6000);
            model.a_gcd(); equal(model.s_gcd, 6);
            equal(SharedLogic.f_discountedTotal(2500, 3, 101), 0);
            equal(SharedLogic.f_discountedTotal(2500, 3, 100), 0);
            equal(SharedLogic.f_discountedTotal(2500, 3, 0), 7500);
            equal(SharedLogic.f_greatestCommonDivisor(0, 0), 0);
            equal(SharedLogic.f_greatestCommonDivisor(0, 18), 18);
            equal(SharedLogic.f_greatestCommonDivisor(2147483647, 1), 1);
            rejected(() -> SharedLogic.f_increment(-1));
            rejected(() -> SharedLogic.f_increment(Integer.MAX_VALUE));
            rejected(() -> SharedLogic.f_discountedTotal(-1, 1, 0));
            rejected(() -> SharedLogic.f_greatestCommonDivisor(1, -1));
            model.s_count = -1; rejected(model::a_add); equal(model.s_count, -1);
            JSONArray nativeMappings = new JSONArray();
            boolean artLoaded = false, logicLoaded = false;
            String apkPath = getTargetContext().getApplicationInfo().sourceDir;
            String mappingKind = "none";
            try(java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.FileReader("/proc/self/maps"))) {
                String line;
                while((line = reader.readLine()) != null) {
                    if(line.contains("libart.so")) artLoaded = true;
                    if(line.contains("libapplogic.so")) { logicLoaded = true; mappingKind = "named-library"; }
                    // Uncompressed APK native libraries are mmap-ed from base.apk.
                    boolean executableApk = line.contains(apkPath) && line.contains("r-xp");
                    if(executableApk) { logicLoaded = true; mappingKind = "executable-target-apk"; }
                    if(line.contains("libart.so") || line.contains("libapplogic.so") || executableApk) nativeMappings.put(line);
                }
            }
            result.put("artLoaded", artLoaded); result.put("appLogicLoaded", logicLoaded);
            result.put("nativeMappings", nativeMappings); result.put("appLogicMappingKind", mappingKind);
            if(!artLoaded || !logicLoaded) throw new AssertionError("Expected ART and application JNI library in process");
            if(checks != 16 || !created) throw new AssertionError("Incomplete instrumentation run");
            passed = true;
        } catch(Throwable failure) {
            try { result.put("failure", Log.getStackTraceString(failure)); } catch(Exception ignored) {}
            Log.e("NativeLogicChecks", "FAIL", failure);
        } finally {
            try {
                result.put("passed", passed); result.put("checks", checks);
                result.put("elapsedMs", android.os.SystemClock.elapsedRealtime() - start);
            } catch(Exception ignored) {}
            String report = result.toString(); Log.i("NativeLogicChecks", report);
            output.putString("resultJson", report);
            finish(passed ? Activity.RESULT_OK : Activity.RESULT_CANCELED, output);
        }
    }
}
'''


def run(command, env=None, timeout=300):
    result = subprocess.run([str(x) for x in command], env=env, text=True, capture_output=True, timeout=timeout)
    if result.returncode: raise ValueError('Command failed: ' + ' '.join(map(str, command)) + '\n' + result.stdout + result.stderr)
    return result.stdout


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dex_classes(data):
    """Read defined class descriptors, distinguishing references from bundled code."""
    if not data.startswith(b'dex\n'): raise ValueError('Unexpected DEX format')
    string_count, string_offset = struct.unpack_from('<II', data, 56)
    type_count, type_offset = struct.unpack_from('<II', data, 64)
    class_count, class_offset = struct.unpack_from('<II', data, 96)
    names = []
    for i in range(class_count):
        type_index = struct.unpack_from('<I', data, class_offset + i * 32)[0]
        if type_index >= type_count: raise ValueError('Invalid DEX type')
        string_index = struct.unpack_from('<I', data, type_offset + type_index * 4)[0]
        if string_index >= string_count: raise ValueError('Invalid DEX string')
        offset = struct.unpack_from('<I', data, string_offset + string_index * 4)[0]
        while data[offset] & 0x80: offset += 1
        offset += 1
        names.append(data[offset:data.index(b'\0', offset)].decode('utf8'))
    return names


def build(project, work, sdk, java_home, gradle):
    manifest = json.loads((project / 'app.json').read_text())
    package = manifest['id']
    if not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+', package): raise ValueError('Invalid app package')
    source = project / 'native/android/app/src/main/java' / package.replace('.', '/')
    required = [source / 'AppModel.java', source / 'SharedLogic.java']
    if not all(p.is_file() for p in required): raise ValueError('Generate the delivered shared-logic app first')
    work.mkdir(parents=True, exist_ok=True)
    classes = work / 'target-signatures'; classes.mkdir(exist_ok=True)
    run([java_home / 'bin/javac', '-d', classes, *required])
    jar = work / 'target-signatures.jar'
    run([java_home / 'bin/jar', 'cf', jar, '-C', classes, '.'])
    (work / 'settings.gradle').write_text("pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name='NativeDeviceChecks'\ninclude ':app'\n")
    (work / 'build.gradle').write_text("plugins { id 'com.android.application' version '8.9.2' apply false }\n")
    app = work / 'app'; (app / 'src/main/java/com/dotcorr/logicchecks').mkdir(parents=True, exist_ok=True)
    (app / 'build.gradle').write_text("plugins { id 'com.android.application' }\nandroid { namespace '" + CHECK_PACKAGE + "'; compileSdk 35; defaultConfig { applicationId '" + CHECK_PACKAGE + "'; minSdk 26; targetSdk 35; versionCode 1; versionName '1.0' }; compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 } }\ndependencies { compileOnly files('../target-signatures.jar') }\n")
    (app / 'src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Native Logic Tests"/><instrumentation android:name="' + CHECK_PACKAGE + '.DeviceChecks" android:targetPackage="' + package + '" android:functionalTest="true"/></manifest>\n')
    (app / 'src/main/java/com/dotcorr/logicchecks/DeviceChecks.java').write_text(JAVA.replace('__TARGET__', package))
    env = os.environ.copy(); env.update(ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk), JAVA_HOME=str(java_home))
    log = run([gradle, '-p', work, '--no-daemon', ':app:assembleDebug'], env=env, timeout=600)
    (work / 'build.log').write_text(log)
    apk = app / 'build/outputs/apk/debug/app-debug.apk'
    with zipfile.ZipFile(apk) as archive:
        if any(name.startswith('lib/') for name in archive.namelist()): raise ValueError('Test APK unexpectedly contains native libraries')
        defined = [name for member in archive.namelist() if member.endswith('.dex') for name in dex_classes(archive.read(member))]
        if any(name.startswith('L' + package.replace('.', '/') + '/') for name in defined): raise ValueError('Target application classes were copied into the test APK')
    return package, apk, defined


def verify(project, work, sdk, java_home, gradle, serial, build_only=False, target_apk=None):
    package, test_apk, defined = build(project, work, sdk, java_home, gradle)
    report = {'testApk': str(test_apk), 'testApkSha256': sha(test_apk), 'testDefinedClasses': defined, 'targetClassesBundled': False, 'androidDeviceExecuted': False}
    if build_only: return report
    if not serial: raise ValueError('Provide --serial for an authorized running Android device or emulator')
    adb = sdk / 'platform-tools/adb'
    command = [adb, '-s', serial]
    if run(command + ['get-state']).strip() != 'device': raise ValueError('Android device is unavailable')
    package_paths = run(command + ['shell', 'pm', 'path', package]).splitlines()
    if len(package_paths) != 1 or not package_paths[0].startswith('package:'): raise ValueError('Install the delivered standalone target APK before this test')
    installed = work / 'installed-target.apk'
    run(command + ['pull', package_paths[0][8:], installed])
    target = Path(target_apk).resolve() if target_apk else project / 'app-debug.apk'
    if sha(installed) != sha(target): raise ValueError('Installed app APK differs from delivered app-debug.apk')
    report.update(targetApkSha256=sha(target), serial=serial, fingerprint=run(command + ['shell', 'getprop', 'ro.build.fingerprint']).strip())
    run(command + ['install', '-r', test_apk])
    output = run(command + ['shell', 'am', 'instrument', '-w', '-r', CHECK_PACKAGE + '/' + CHECK_PACKAGE + '.DeviceChecks'])
    (work / 'instrumentation.txt').write_text(output)
    match = re.search(r'^INSTRUMENTATION_RESULT: resultJson=(.*)$', output, re.M)
    if not match: raise ValueError('Instrumentation did not return a result: ' + output)
    result = json.loads(match[1]); report['instrumentation'] = result
    pid = result.get('pid')
    if type(pid) is int:
        logs = run(command + ['logcat', '-d', '--pid=' + str(pid), '-v', 'threadtime'])
        (work / 'device-logcat.txt').write_text(logs)
        report['crashLogDetected'] = bool(re.search(r'FATAL EXCEPTION|Fatal signal', logs))
    report['androidDeviceExecuted'] = True
    report['passed'] = bool(result.get('passed') and result.get('checks') == 16 and result.get('artLoaded') and result.get('appLogicLoaded') and not report.get('crashLogDetected') and 'INSTRUMENTATION_CODE: -1' in output)
    report['scope'] = 'Actual Android ART process and app JNI/model execution; external test APK, no UI interaction or Android activity lifecycle assertions.'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--work-dir', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--java-home', type=Path, required=True)
    parser.add_argument('--gradle', type=Path, required=True)
    parser.add_argument('--serial')
    parser.add_argument('--target-apk', type=Path, help='Exact installed application APK; defaults to project/app-debug.apk')
    parser.add_argument('--build-only', action='store_true')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    try:
        report = verify(args.project.resolve(), args.work_dir.resolve(), args.sdk.resolve(), args.java_home.resolve(), args.gradle.resolve(), args.serial, args.build_only, args.target_apk)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        report = {'passed': False, 'androidDeviceExecuted': None, 'error': str(error), 'scope': 'Harness failed; no successful Android execution claim. Inspect build/instrumentation logs.'}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if (args.build_only and 'error' not in report) or report.get('passed') else 1


if __name__ == '__main__': raise SystemExit(main())
