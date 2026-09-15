"""Install only the standard Gradle wrapper, checking upstream SHA256 checksums."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request

VERSION = '8.11.1'
BASE = 'https://services.gradle.org/distributions/gradle-' + VERSION


def checksum(url):
    value = urllib.request.urlopen(url, timeout=30).read().decode().strip()
    if len(value) != 64 or any(c not in '0123456789abcdef' for c in value):
        raise ValueError('Invalid upstream checksum')
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('android_project')
    parser.add_argument('--gradle', default='gradle')
    args = parser.parse_args()
    root = Path(args.android_project).resolve()
    if not (root / 'settings.gradle').is_file():
        parser.error('Expected a generated Android project')
    distribution_hash = checksum(BASE + '-bin.zip.sha256')
    wrapper_hash = checksum(BASE + '-wrapper.jar.sha256')
    paths = ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar', 'gradle/wrapper/gradle-wrapper.properties']
    with tempfile.TemporaryDirectory() as folder:
        temporary = Path(folder)
        (temporary / 'settings.gradle').write_text("rootProject.name = 'wrapper'\n")
        subprocess.run([args.gradle, '--no-daemon', 'wrapper', '--gradle-version', VERSION,
                        '--distribution-type', 'bin', '--gradle-distribution-sha256-sum', distribution_hash], cwd=temporary, check=True)
        jar = temporary / 'gradle/wrapper/gradle-wrapper.jar'
        if hashlib.sha256(jar.read_bytes()).hexdigest() != wrapper_hash:
            raise ValueError('Wrapper jar checksum differs from official distribution')
        for relative in paths:
            destination = root / relative
            if destination.is_symlink() or any(p.is_symlink() for p in destination.parents if p != root):
                raise ValueError('Symlink in wrapper destination: ' + str(destination))
            if destination.exists() and destination.read_bytes() != (temporary / relative).read_bytes():
                raise ValueError('Existing wrapper differs; refusing overwrite: ' + str(destination))
        for relative in paths:
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(temporary / relative, destination)
    print('Installed verified standard Gradle ' + VERSION + ' wrapper')


if __name__ == '__main__':
    main()
