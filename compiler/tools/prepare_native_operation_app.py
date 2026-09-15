#!/usr/bin/env python3
"""Prepare a shared Dart operation app using real supplied SDK declarations.

Generation only. Native builds and device execution are separate evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.catalog import Catalog
from dcflight.compiler import compile_app
from dcflight.modules.export import _convert
from dcflight.native_api import index_android


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--ios-catalog',type=Path,required=True)
    p.add_argument('--android-jar',type=Path,required=True)
    p.add_argument('--javap',required=True)
    p.add_argument('--dart',required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();root=a.out.resolve()
    if root.exists():raise ValueError('Use a new evidence directory; existing files are preserved')
    # Read the exact class bytes, not the JDK boot-classpath UUID declaration.
    with zipfile.ZipFile(a.android_jar) as jar:binary=jar.read('java/util/UUID.class')
    with tempfile.TemporaryDirectory() as tmp:
        path=Path(tmp)/'UUID.class';path.write_bytes(binary)
        result=subprocess.run([a.javap,'-public',str(path)],capture_output=True,text=True,check=True)
    converted,unsupported=_convert(result.stdout)
    with Catalog(a.ios_catalog) as c:
        records=[c.get('ios',identity,'Foundation')['api'] for identity in ('s:10Foundation4UUIDVACycfc','s:10Foundation4UUIDV10uuidStringSSvp')]
        provenance=c.source('ios','Foundation')
    root.mkdir(parents=True)
    (root/'android-core.txt').write_text(converted)
    index_android(root/'sdk.sqlite',root/'android-core.txt')
    with Catalog(root/'sdk.sqlite',write=True) as c:
        c.import_records('ios','Foundation',provenance['sdk'],records,provenance['provenance'])
    shutil.copyfile(Path(__file__).resolve().parents[1]/'examples/native-operation/app.dart',root/'app.dart')
    compile_app(root/'app.dart',root/'native',evaluate_dart=True,dart=a.dart)
    report={'generated':True,'compiled':False,'executed':False,'sourceSha256':hashlib.sha256((root/'app.dart').read_bytes()).hexdigest(),'androidUUIDClassSha256':hashlib.sha256(binary).hexdigest(),'unsupportedJVMDeclarations':unsupported,'scope':'Actual selected SDK signatures; generation only.'}
    (root/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))

if __name__=='__main__':main()
