"""Development-time DC Dart compilation; only audited native objects ship."""
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

TARGETS = {
    'host': 'host',
    'ios-arm64': 'arm64-apple-ios16.0',
    'ios-simulator-arm64': 'arm64-apple-ios16.0-simulator',
    'android-arm64': 'aarch64-linux-android26',
}
FORBIDDEN_SYMBOL = re.compile(r'(?:dartvm|dart_|dcflight|flutter|hermes|javascriptcore|dc_(?:alloc|retain|release|heap|orc))', re.I)


@dataclass(frozen=True)
class LogicArtifact:
    object: Path
    header: Path
    provenance: Path
    target: str


def _run(args, env=None):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, env=env)
    if result.returncode:
        raise ValueError(f'{args[0]} failed ({result.returncode}): {result.stderr or result.stdout}')
    return result.stdout.strip()


def _digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def audit_object(path, nm='llvm-nm', allowed_externals=()):
    """Inspect all symbols, not only imports, to catch embedded runtime code too."""
    symbols = _run([nm, '--format=posix', path])
    forbidden = [line for line in symbols.splitlines() if FORBIDDEN_SYMBOL.search(line.split()[0])]
    undefined = _run([nm, '--undefined-only', '--just-symbol-name', path]).splitlines()
    # Mach-O ABI adds a single leading underscore; ELF does not.
    macho = Path(path).read_bytes()[:4] in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf')
    normalized = [s[1:] if macho and s.startswith('_') else s for s in undefined]
    unexpected = sorted(set(normalized) - set(allowed_externals))
    if forbidden or unexpected:
        raise ValueError(f'Native logic runtime audit failed: prohibited={forbidden}, undeclared={unexpected}')
    return {'undefinedSymbols': normalized, 'allowedExternals': sorted(allowed_externals),
            'prohibitedSymbols': forbidden, 'passed': True}


def compile_logic(source, output, target='host', *, prelude, dcc='dcc', nm='llvm-nm',
                  allowed_externals=(), env=None):
    """Compile with released DCC >=0.1.1. Explicit C externs require an allowlist.

    The source must import the exact prelude path passed here. No rewriting of
    program semantics, retargeting a foreign object or hosted-mode fallback.
    """
    if target not in TARGETS:
        raise ValueError(f'Unsupported DC Dart target {target!r}; choose {list(TARGETS)}')
    source, output, prelude = Path(source).resolve(), Path(output).resolve(), Path(prelude).absolute()
    if not source.is_file() or not prelude.is_file():
        raise ValueError('DC Dart source and prelude must exist')
    command = [dcc] if isinstance(dcc, (str, Path)) else list(dcc)
    version = _run(command + ['--version'], env)
    match = re.fullmatch(r'dcc (\d+)\.(\d+)\.(\d+)', version)
    if not match or tuple(map(int, match.groups())) < (0, 1, 1):
        raise ValueError('DC Dart 0.1.1 or newer is required for mobile native targets')
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='logic-', dir=output) as staging:
        temp = Path(staging)
        obj, header = temp / 'logic.o', temp / 'logic.h'
        args = command + ['build', '--mode', 'bare', '--target', target, '--prelude', str(prelude),
                          str(source), '-o', str(obj), '--emit-header', str(header)]
        _run(args, env)
        if not obj.is_file() or not header.is_file() or not obj.stat().st_size:
            raise ValueError('DC Dart did not produce the promised object and ABI header')
        audit = audit_object(obj, nm, allowed_externals)
        tool_files = []
        for arg in command:
            located = shutil.which(str(arg), path=(env or os.environ).get('PATH')) or str(arg)
            if Path(located).is_file():
                tool_files.append({'path': str(Path(located).resolve()), 'sha256': _digest(located)})
        provenance = {'schemaVersion': 1, 'compilerVersion': version, 'compilerFiles': tool_files,
                      'source': str(source), 'sourceSha256': _digest(source),
                      'preludeSha256': _digest(prelude), 'target': target, 'triple': TARGETS[target],
                      'mode': 'bare', 'nativeCompiler': _run(['clang', '--version'], env),
                      'dartFrontend': (env or os.environ).get('DCDART_DART', shutil.which('dart')),
                      'objectSha256': _digest(obj), 'headerSha256': _digest(header),
                      'audit': audit}
        # Commit only a fully compiled and audited result; errors retain prior output.
        final_obj, final_header = output / 'logic.o', output / 'logic.h'
        os.replace(obj, final_obj)
        os.replace(header, final_header)
        final_provenance = output / 'logic.build.json'
        final_provenance.write_text(json.dumps(provenance, indent=2) + '\n')
    return LogicArtifact(final_obj, final_header, final_provenance, target)
