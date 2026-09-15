"""Explicit, trusted Dart authoring execution. Never used by load() or MCP."""
import json
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urljoin
from .frontends import read_json
from .validate import Diagnostic


def _package_config(source, authoring):
    packages = []
    for folder in (source.parent, *source.parent.parents):
        config = folder / '.dart_tool/package_config.json'
        if config.is_file():
            data = read_json(config.read_text())
            if data.get('configVersion') != 2:
                raise Diagnostic('Evaluated Dart authoring requires package config version 2')
            for package in data.get('packages', []):
                if package.get('name') == 'dcflight_authoring':
                    continue
                item = dict(package)
                item['rootUri'] = urljoin(config.as_uri(), package['rootUri'])
                packages.append(item)
            break
        if (folder / 'pubspec.yaml').exists():
            # No implicit package downloads or pubspec execution.
            break
    packages.append({'name': 'dcflight_authoring', 'rootUri': authoring.as_uri() + '/',
                     'packageUri': 'lib/', 'languageVersion': '3.0'})
    return {'configVersion': 2, 'packages': packages}


def load_evaluated(path, dart='dart', *, timeout=30, authoring=None):
    return _load_evaluated(path,dart,timeout=timeout,authoring=authoring,kind='app')


def load_evaluated_operation(path, dart='dart', *, timeout=30, authoring=None):
    return _load_evaluated(path,dart,timeout=timeout,authoring=authoring,kind='operation')


def _load_evaluated(path, dart='dart', *, timeout=30, authoring=None, kind='app'):
    """Run a fixed trusted authoring entry point and return its input document.

    This is code execution with the current user's privileges, not a sandbox.
    Only explicit local authoring commands may call it. Network/package setup is
    never performed implicitly. Canonical validation remains the caller's next
    step; a successful authoring execution does not certify an application.
    """
    result_type, entrypoint = {'app':('App','buildApp'), 'operation':('NativeOperation','buildOperation')}[kind]
    source = Path(path).resolve()
    if not source.is_file() or source.suffix != '.dart':
        raise Diagnostic('Evaluated authoring requires an existing .dart source file')
    if authoring is not None:
        authoring = Path(authoring).resolve()
    else:
        authoring = Path(__file__).resolve().parents[1] / 'authoring'
        if not (authoring / 'lib/dcflight.dart').is_file():
            authoring = Path(__file__).resolve().parent / 'data/authoring'
    if not (authoring / 'lib/dcflight.dart').is_file():
        raise Diagnostic('Dart authoring package not found: ' + str(authoring))
    with tempfile.TemporaryDirectory(prefix='dcflight-authoring-') as temporary:
        root = Path(temporary)
        output = root / 'app.json'
        config = root / 'package_config.json'
        config.write_text(json.dumps(_package_config(source, authoring)))
        runner = root / 'evaluate.dart'
        # JSON quoting is valid Dart string syntax; file URIs encode apostrophes
        # and dollar signs before interpolation can occur.
        runner.write_text("import 'dart:convert';\nimport 'dart:io';\n"
                          "import 'package:dcflight_authoring/dcflight.dart';\n"
                          'import ' + json.dumps(source.as_uri()) + " as author;\n"
                          'void main() {\n  final ' + result_type + ' app = author.' + entrypoint + '();\n'
                          '  File.fromUri(Uri.parse(' + json.dumps(output.as_uri()) + ')).writeAsStringSync(jsonEncode(app.toJson()));\n}\n')
        try:
            process = subprocess.run([str(dart), '--packages=' + str(config), str(runner)],
                                     cwd=source.parent, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired as error:
            raise Diagnostic('Dart authoring exceeded ' + str(timeout) + ' seconds') from error
        except OSError as error:
            raise Diagnostic('Could not start Dart authoring SDK: ' + str(error)) from error
        if process.returncode:
            raise Diagnostic('Dart authoring failed:\n' + (process.stderr + '\n' + process.stdout)[-12000:])
        if not output.is_file():
            raise Diagnostic('Dart authoring did not produce an application document')
        if output.stat().st_size > 8 * 1024 * 1024:
            raise Diagnostic('Dart authoring document exceeds 8 MiB')
        try:
            data = read_json(output.read_text())
        except (ValueError, RecursionError) as error:
            raise Diagnostic('Dart authoring returned invalid JSON: ' + str(error)) from error
        if not isinstance(data, dict):
            raise Diagnostic('Dart authoring must return a ' + result_type + ' object')
        return data
