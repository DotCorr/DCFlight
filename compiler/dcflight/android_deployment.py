"""Canonical base SDK versions and development-time native Gradle binding."""
from .backends import Artifact
from .native_configuration import NativeConfiguration
from .android_sdk_guard import active_guard_hook
from .validate import Diagnostic

DIRECTIVE = "apply from: 'native-versions.gradle'"


def configuration(app):
    return getattr(app, 'native_configuration', None) or NativeConfiguration()


def gradle_configuration(config):
    compile_sdk, minimum, target = config.android_compile_sdk, config.android_min_sdk, config.android_target_sdk
    if any(type(n) is not int or not 1 <= n <= 999 for n in (compile_sdk, minimum, target)) or not 26 <= minimum <= target <= compile_sdk:
        raise Diagnostic('Invalid canonical Android SDK versions')
    return '''// Generated development-time SDK configuration. Not packaged in the app.
android {
    compileSdk %d
    defaultConfig { minSdk %d; targetSdk %d }
}
def authoredVersions = [compileSdk: %d, minSdk: %d, targetSdk: %d]
def configuredAndroid = android
def variantVersions = []
androidComponents.onVariants(androidComponents.selector().all()) { variant ->
    variantVersions.add([name: variant.name, minSdk: variant.minSdk.apiLevel,
                         targetSdk: variant.targetSdk.apiLevel,
                         minCodename: variant.minSdk.codename, targetCodename: variant.targetSdk.codename])
}
def verifyAuthoredVersions = tasks.register('verifyAuthoredAndroidVersions') {
    doLast {
        if (configuredAndroid.compileSdkVersion != 'android-' + authoredVersions.compileSdk)
            throw new GradleException('compileSdk differs from authored nativeConfiguration.android.compileSdk')
        if (configuredAndroid.defaultConfig.minSdkVersion?.apiLevel != authoredVersions.minSdk ||
            configuredAndroid.defaultConfig.targetSdkVersion?.apiLevel != authoredVersions.targetSdk)
            throw new GradleException('Default Android SDK versions differ from authored nativeConfiguration')
        if (variantVersions.isEmpty()) throw new GradleException('No Android application variants to verify')
        variantVersions.each { variant ->
            if (variant.minCodename != null || variant.targetCodename != null ||
                variant.minSdk != authoredVersions.minSdk || variant.targetSdk != authoredVersions.targetSdk)
                throw new GradleException('Android variant ' + variant.name + ' changes authored SDK versions; author the version contract explicitly')
        }
    }
}
tasks.matching { it.name == 'preBuild' }.configureEach { dependsOn(verifyAuthoredVersions) }
''' % (compile_sdk, minimum, target, compile_sdk, minimum, target)


def finish(app, artifacts, output):
    from .sync import safe_path
    relative = 'android/app/build.gradle'
    planned = artifacts[relative]
    path = safe_path(output, relative)
    source = path.read_text() if path.is_file() else planned.content
    if not active_guard_hook(source, filename='native-versions.gradle'):
        raise Diagnostic("Android SDK configuration requires a top-level " + DIRECTIVE + " in user-owned app/build.gradle. No project files were changed.")
    artifacts['android/app/native-versions.gradle'] = Artifact(gradle_configuration(configuration(app)))
