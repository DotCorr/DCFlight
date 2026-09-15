#!/usr/bin/env python3
"""Compile one DC Dart program across native targets and execute host behavior."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.dcdart import TARGETS, compile_logic


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dcc', default='dcc')
    parser.add_argument('--prelude', required=True)
    parser.add_argument('--nm', default='llvm-nm')
    parser.add_argument('--output', default='build/shared-logic')
    parser.add_argument('--targets', nargs='+', choices=list(TARGETS), default=list(TARGETS))
    args = parser.parse_args()
    root = Path(args.output).resolve()
    root.mkdir(parents=True, exist_ok=True)
    examples = Path(__file__).resolve().parents[1] / 'examples/shared_logic'
    shutil.copyfile(examples / 'logic.dart', root / 'logic.dart')
    shutil.copyfile(args.prelude, root / 'prelude.dart')
    results = []
    for target in args.targets:
        artifact = compile_logic(root / 'logic.dart', root / target, target,
                                 prelude=root / 'prelude.dart', dcc=args.dcc, nm=args.nm)
        result = json.loads(artifact.provenance.read_text())
        if target == 'host':
            executable = root / target / 'verify'
            subprocess.run(['clang', '-I', str(artifact.header.parent), str(examples / 'main.c'),
                            str(artifact.object), '-o', str(executable)], check=True)
            result['execution'] = subprocess.check_output([str(executable)], text=True).strip()
        results.append(result)
    report = root / 'verification.json'
    report.write_text(json.dumps(results, indent=2) + '\n')
    print(report)


if __name__ == '__main__':
    main()
