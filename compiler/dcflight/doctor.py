"""Detect required native toolchains and optionally install the missing ones.

`doctor` never modifies the system unless the caller explicitly passes
``install=True`` (or names tools). Detection is read-only. Version probes read
combined output because several tools (dart, java) banner to stderr.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

REQUIRED = ('dart', 'dcc', 'python')
NOTES = {
    'xcode': 'iOS builds and iOS SDK verification: install Xcode from the Mac App Store',
    'java': 'Android Gradle builds: install JDK 17 (temurin) or Android Studio',
    'adb': 'Android device installs: comes with Android Studio / platform-tools',
    'gradle': 'Android builds: per-project Gradle wrapper is also accepted',
}


def _which(name):
    return shutil.which(name)


def _run(command, timeout=60):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    banner = (result.stdout.strip() + '\n' + result.stderr.strip()).strip()
    return banner.splitlines()[0] if banner else None


def _machine():
    machine = getattr(os, 'uname', lambda: None)()
    machine = machine.machine if machine else ''
    if machine.startswith('arm') or machine == 'aarch64':
        return 'arm64'
    return 'x86_64'


def _windows():
    return sys.platform.startswith('win')


def _dcc_hint():
    for candidate in (
            Path.home() / '.dcflight' / 'toolchains' / 'dcc' / 'bin' / 'dcc',
            Path.home() / '.dcflight' / 'toolchains' / 'dcc' / 'bin' / 'dcc.exe'):
        if candidate.exists():
            return str(candidate)
    return None


def _detect():
    rows = []

    def add(name, path, version=None, note=None):
        rows.append({'name': name, 'present': bool(path), 'version': version,
                     'path': path, 'note': (note if not path else None)})

    dart = _which('dart')
    add('dart', dart, _run([dart, '--version']) if dart else None)

    dcc = _which('dcc') or _dcc_hint()
    add('dcc', dcc, _run([dcc, '--version']) if dcc else None,
        'dcdart native Dart compiler: install from https://github.com/dotcorr/dcdart/releases')

    add('python', sys.executable, '{}.{}.{}'.format(*sys.version_info[:3]))

    xcode = _which('xcodebuild')
    add('xcode', xcode, _run([xcode, '-version']) if xcode else None)

    add('xcrun', _which('xcrun'))

    java = _which('java')
    add('java', java, _run([java, '-version']) if java else None)

    add('adb', _which('adb'))

    gradle = _which('gradle')
    add('gradle', gradle, _run([gradle, '--version']) if gradle else None)

    add('git', _which('git'))
    return rows


def status():
    """Return {'items': [...], 'ready': bool, 'missing': [...]}."""
    items = _detect()
    missing = [row['name'] for row in items if not row['present'] and row['name'] in REQUIRED]
    return {'items': items, 'ready': not missing, 'missing': missing}


def install(missing=None, progress=None):
    """Opt-in installer for dev toolchains. Never touches the system silently."""
    report = status()
    names = report['missing'] if missing is None else list(missing)
    installed, failed = [], []
    say = progress or (lambda row: None)

    for name in names:
        if name == 'python':
            continue
        say({'tool': name, 'state': 'installing'})
        try:
            if name == 'dart':
                _install_dart(say)
            elif name == 'dcc':
                _install_dcc(say)
            elif name in ('java', 'gradle', 'adb'):
                _install_android_toolchain(say)
            else:
                failed.append({'tool': name, 'reason': NOTES.get(name, 'no automatic installer')})
                continue
            say({'tool': name, 'state': 'installed'})
            installed.append(name)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            failed.append({'tool': name, 'reason': str(error)})

    after = status()
    return {'requested': names, 'installed': installed, 'failed': failed,
            'ready': after['ready'], 'remaining': after['missing']}


def _url(name):
    override = os.environ.get('DCFLIGHT_' + name.upper() + '_URL')
    if override:
        return override
    machine = _machine()
    if name == 'dart':
        if _windows():
            return 'https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-windows-x64-release.zip'
        system = 'macos' if sys.platform == 'darwin' else 'linux'
        return ('https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/'
                'dartsdk-{}-{}-release.zip'.format(system, machine))
    if name == 'dcc':
        raise ValueError('dcc requires DCFLIGHT_DCC_URL set to a dcdart release archive '
                         '(https://github.com/dotcorr/dcdart/releases)')
    raise ValueError(name)


def _unzip(archive, target):
    if _windows():
        _run_unchecked(['powershell', '-NoProfile', '-Command',
                        'Expand-Archive -Force "{}" "{}"'.format(archive, target)])
    else:
        target = Path(target)
        target.mkdir(parents=True, exist_ok=True)
        _run_unchecked(['ditto' if sys.platform == 'darwin' else 'unzip',
                        '-x', '-k', archive, str(target)] if sys.platform == 'darwin'
                       else ['-o', archive, '-d', str(target)])


def _install_dart(say):
    if _which('dart'):
        return
    say({'tool': 'dart', 'state': 'downloading'})
    home = Path.home() / '.dcflight'
    archive = home / 'dart-sdk.zip'
    home.mkdir(parents=True, exist_ok=True)
    _download(_url('dart'), archive)
    _unzip(archive, home)
    archive.unlink(missing_ok=True)
    produced = home / 'dart-sdk' / 'bin' / ('dart.exe' if _windows() else 'dart')
    if not produced.exists():
        raise OSError('dart archive layout unexpected; add the Dart SDK bin directory to PATH')
    say({'tool': 'dart', 'state': 'path-hint', 'path': str(produced.parent)})


def _install_dcc(say):
    if _which('dcc') or _dcc_hint():
        return
    say({'tool': 'dcc', 'state': 'downloading'})
    target = Path.home() / '.dcflight' / 'toolchains'
    target.mkdir(parents=True, exist_ok=True)
    archive = target / 'dcc.zip'
    _download(_url('dcc'), archive)
    _unzip(archive, target)
    archive.unlink(missing_ok=True)
    if not _dcc_hint():
        raise OSError('dcc archive layout unexpected; see the note in doctor output for manual install')


def _install_android_toolchain(say):
    """JDK/Android Studio stay user-level installs; this only bootstraps the
    Android SDK commandline-tools when a JDK already exists."""
    home = Path.home() / '.dcflight' / 'android'
    if home.exists():
        return
    if _which('java') is None:
        raise OSError('Install a JDK 17 first (temurin or Android Studio), then rerun: dcflight doctor --install')
    if _windows():
        raise OSError('On Windows install Android Studio (https://developer.android.com/studio); '
                      'it provisions the SDK used by dcflight')
    say({'tool': 'android', 'state': 'downloading'})
    home.mkdir(parents=True, exist_ok=True)
    archive = '/tmp/dcf-cmdline-tools.zip'
    _run_unchecked(['curl', '-fsSL', '-o', archive,
                    'https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip'])
    _unzip(archive, home)
    sdkmanager = home / 'cmdline-tools' / 'bin' / 'sdkmanager'
    if not sdkmanager.exists():
        raise OSError('cmdline-tools layout unexpected; install Android Studio instead')
    env = {**os.environ, 'ANDROID_HOME': str(home)}
    subprocess.run([str(sdkmanager), '--sdk_root=' + str(home),
                    'platform-tools', 'platforms;android-35', 'build-tools;35.0.0'],
                   input='y\n', text=True, capture_output=True, timeout=1800, env=env)


def _download(url, target):
    if _windows():
        _run_unchecked(['powershell', '-NoProfile', '-Command',
                        'Invoke-WebRequest "{}" -OutFile "{}"'.format(url, target)])
    else:
        _run_unchecked(['curl', '-fsSL', '-o', str(target), url])


def _run_unchecked(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=1800)
    except FileNotFoundError as error:
        raise OSError('required helper missing: ' + str(error))
    if result.returncode != 0:
        raise OSError((result.stderr.strip() or result.stdout.strip())[:300]
                      or 'command failed: ' + ' '.join(command))
    return result
