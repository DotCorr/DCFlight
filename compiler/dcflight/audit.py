"""Defense-in-depth audit. Native build/link verification supplies stronger evidence."""
import re
from pathlib import Path

FORBIDDEN = re.compile(r'\b(dcflight|flutter|flutter_zero|dart:ffi|libdart|DartVM|JavaScriptCore|WKWebView|android\.webkit|ReactNative|libhermes|yoga)\b', re.I)
SOURCE_SUFFIXES = {'.swift', '.java', '.kt', '.gradle', '.kts', '.xml', '.json', '.plist', '.pbxproj', '.xcconfig', '.properties'}


def audit(output):
    root = Path(output)
    findings = []
    checked = 0
    for target in ('ios', 'android'):
        folder = root / target
        if not folder.exists():
            continue
        for path in folder.rglob('*'):
            if path.is_symlink():
                findings.append(str(path.relative_to(root)) + ': symlink not auditable')
            elif path.is_file() and path.suffix in SOURCE_SUFFIXES:
                checked += 1
                text = path.read_text()
                if FORBIDDEN.search(text):
                    findings.append(str(path.relative_to(root)) + ': prohibited runtime reference')
    if checked == 0:
        raise ValueError('No native source/project files found')
    return {'checkedFiles': checked, 'findings': findings, 'passed': not findings,
            'scope': 'Source/project scan; use native builds and dependency inspection to verify linked artifacts.'}
