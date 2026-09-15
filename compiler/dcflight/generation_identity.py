"""Development-side compiler/mapping identity; never included in native apps."""
import hashlib
import json
from pathlib import Path
from . import __version__


def generation_identity(registry, package_root=None):
    root = Path(package_root) if package_root is not None else Path(__file__).parent
    files = set(root.rglob('*.py'))
    files.update((root / 'data').glob('*.json'))
    for directory in (root/'backends/templates', root/'reload/native'):
        if directory.is_dir():
            files.update(path for path in directory.rglob('*') if path.is_file())
    entries = []
    for path in sorted(files):
        relative = path.relative_to(root)
        if '__pycache__' in relative.parts or any(part.startswith('.') for part in relative.parts):
            continue
        entries.append([relative.as_posix(), hashlib.sha256(path.read_bytes()).hexdigest()])
    def digest(value):
        return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'version': __version__, 'compilerSha256': digest(entries),
            'registrySha256': digest(registry.entries)}
