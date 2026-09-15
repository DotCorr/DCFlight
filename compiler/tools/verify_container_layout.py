"""Measure generated SwiftUI container defaults on a macOS native host.

This verifies native layout, not simulator screenshots or Android geometry.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.backends.ios_presentation import render
from dcflight.ir import Node, Style


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    if args.report.exists():
        parser.error('Choose a fresh report path')
    source = 'import SwiftUI\nimport AppKit\n'
    cases = []
    for kind in ('row', 'column', 'card'):
        for suffix, style in (('omitted', None), ('empty', Style())):
            name = kind + suffix
            node = Node(name, kind, (), (), style=style)
            body = render(node, '', children_source='Color.red.frame(width: 20, height: 20)\nColor.blue.frame(width: 40, height: 40)').body
            source += 'struct '+name+': View { var body: some View { '+body+' } }\n'
            width, height = (60, 40) if kind == 'row' else (40, 60)
            cases.append('("'+name+'", AnyView('+name+'()), '+str(width)+', '+str(height)+')')
    source += '''
@main struct Check {
 @MainActor static func main() {
  let cases: [(String, AnyView, CGFloat, CGFloat)] = [
'''+',\n'.join(cases)+''']
  for (name, view, width, height) in cases {
   let host = NSHostingView(rootView: view)
   let size = host.fittingSize
   precondition(abs(size.width-width)<0.01 && abs(size.height-height)<0.01, "Unexpected native spacing: " + name)
   print("PASS \\(name): \\(size.width) x \\(size.height)")
  }
 }
}
'''
    with tempfile.TemporaryDirectory(prefix='dcflight-container-layout-') as folder:
        path = Path(folder)/'Layout.swift'
        exe = Path(folder)/'Layout'
        path.write_text(source)
        compiled = subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(path), '-o', str(exe)], capture_output=True, text=True, timeout=120)
        if compiled.returncode:
            raise RuntimeError(compiled.stderr)
        run = subprocess.run([str(exe)], capture_output=True, text=True, timeout=30)
        if run.returncode or len(run.stdout.splitlines()) != 6:
            raise RuntimeError(run.stdout + run.stderr)
        report = {'passed': True, 'cases': 6, 'output': run.stdout, 'source': source,
                  'scope': 'Native macOS SwiftUI hosting measurements; not iOS simulator or Android visual acceptance.'}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n')
    print(run.stdout, end='')


if __name__ == '__main__':
    main()
