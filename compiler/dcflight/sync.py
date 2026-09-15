"""Conflict-safe file synchronization; generated text is editable, never silently lost."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile


class Conflict(ValueError):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(root, relative):
    part = PurePosixPath(relative)
    if part.is_absolute() or '..' in part.parts or not part.parts:
        raise Conflict('Unsafe output path: ' + relative)
    path = root
    for segment in part.parts:
        path = path / segment
        if path.is_symlink():
            raise Conflict('Symlink in output path: ' + str(path))
    if path.exists() and not path.is_file():
        raise Conflict('Expected a file: ' + str(path))
    return path


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.sync-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def synchronize(output, artifacts, app_id, dry_run=False, managed_prefixes=None):
    root = Path(output).absolute()
    # Resolve OS aliases such as macOS /var, but reject a symlink output root.
    if root.is_symlink():
        raise Conflict('Symlink output root: ' + str(root))
    root = root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    manifest = safe_path(root, '.dcflight/state.json')
    lock = safe_path(root, '.dcflight/write.lock')
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise Conflict('Output is locked; if its writer crashed, remove ' + str(lock))
    os.close(fd)
    try:
        previous = json.loads(manifest.read_text()) if manifest.exists() else {'version': 1, 'app': app_id, 'files': {}}
        if previous.get('version') != 1 or previous.get('app') != app_id:
            raise Conflict('Manifest version or app identity differs; use a new output directory')
        old = previous['files']
        changes = {}
        result = {}
        errors = []
        for relative, artifact in sorted(artifacts.items()):
            path = safe_path(root, relative)
            data = artifact.content.encode('utf-8')
            current = path.read_bytes() if path.exists() else None
            owned = artifact.ownership
            if owned not in ('generated', 'user'):
                raise Conflict('Invalid ownership: ' + owned)
            prior = old.get(relative)
            if prior and prior['ownership'] != owned:
                errors.append(relative + ': ownership change requires explicit migration')
            if owned == 'user' and current is not None:
                data = current
            elif current is not None and current != data and (not prior or digest(current) != prior['sha256']):
                errors.append(relative + ': modified generated source; move custom code to user files or reconcile manually')
            if current != data:
                changes[relative] = data
            result[relative] = {'sha256': digest(data), 'ownership': owned}
        for relative, prior in old.items():
            if relative in artifacts:
                continue
            if managed_prefixes and not any(relative.startswith(prefix) for prefix in managed_prefixes):
                result[relative] = prior
                continue
            path = safe_path(root, relative)
            if prior['ownership'] == 'user':
                # User files stay user-owned even if a later plan omits them.
                result[relative] = prior
            elif path.exists():
                if digest(path.read_bytes()) != prior['sha256']:
                    errors.append(relative + ': modified stale generated source; refusing deletion')
                else:
                    changes[relative] = None
        if errors:
            raise Conflict('\n'.join(errors))
        metadata = (json.dumps({'version': 1, 'app': app_id, 'files': result}, sort_keys=True, indent=2) + '\n').encode()
        report = {'write': [p for p, data in changes.items() if data is not None], 'delete': [p for p, data in changes.items() if data is None]}
        if dry_run:
            return report
        if not manifest.exists() or manifest.read_bytes() != metadata:
            changes['.dcflight/state.json'] = metadata
        backups = {}
        try:
            for relative, data in changes.items():
                path = safe_path(root, relative)
                backups[relative] = path.read_bytes() if path.exists() else None
                if data is None:
                    path.unlink()
                else:
                    atomic_write(path, data)
        except BaseException:
            for relative, data in reversed(list(backups.items())):
                path = safe_path(root, relative)
                if data is None:
                    if path.exists():
                        path.unlink()
                else:
                    atomic_write(path, data)
            raise
        return report
    finally:
        lock.unlink()
