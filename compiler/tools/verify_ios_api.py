#!/usr/bin/env python3
"""Compile representative SDK-derived calls with Apple's actual iOS Swift compiler."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.platforms.ios_api import SDKCatalog, Literal, Reference


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--symbolgraphs',type=Path,required=True,help='Foundation symbolgraph directory')
    parser.add_argument('--output',type=Path)
    parser.add_argument('--uikit-symbolgraphs',type=Path)
    args=parser.parse_args()
    catalog=SDKCatalog.from_symbolgraphs(sorted(args.symbolgraphs.glob('*.symbols.json')), 'Foundation')
    cases=[
        ('uuid',('UUID','init()'),[],None),
        ('uuidText',('UUID','uuidString'),[],Reference('uuid','UUID')),
        ('date',('Date','init(timeIntervalSince1970:)'),[Literal(0.0)],None),
        ('seconds',('Date','timeIntervalSince1970'),[],Reference('date','Date')),
        ('shifted',('Date','addingTimeInterval(_:)'),[Literal(60.0)],Reference('date','Date')),
        ('url',('URL','init(string:)'),[Literal('https://example.com')],None),
    ]
    emitted=[]; tested=[]
    for binding,path,values,receiver in cases:
        matches=[a for a in catalog.apis.values() if a.path==path and not a.unsupported]
        if len(matches)!=1:
            raise RuntimeError('Expected one precise API for '+str(path)+': '+str(len(matches)))
        api=matches[0]; output=catalog.emit_call(api.id,values,receiver=receiver)
        emitted.append('  let '+binding+' = '+output.expression)
        emitted.append('  _ = '+binding)
        tested.append(api.id)
    source='import Foundation\nfunc verifySDKCalls() {\n'+'\n'.join(emitted)+'\n}\n'
    if args.uikit_symbolgraphs:
        uikit=SDKCatalog.from_symbolgraphs(sorted(args.uikit_symbolgraphs.glob('*.symbols.json')), 'UIKit')
        ui_cases=[
            (('UIActivityIndicatorView','init(style:)'),[Reference('style','UIActivityIndicatorView.Style')],None,'let indicator = '),
            (('UIActivityIndicatorView','startAnimating()'),[],Reference('indicator','UIActivityIndicatorView'),''),
            (('UIColor','red'),[],None,'let color = '),
        ]
        ui_lines=[]
        for path,values,receiver,prefix in ui_cases:
            api=next(a for a in uikit.apis.values() if a.path==path and not a.unsupported)
            ui_lines.append('  '+prefix+uikit.emit_call(api.id,values,receiver=receiver).expression)
            tested.append(api.id)
        for path,value,receiver in [
            (('UILabel','text'),Literal('Hello from native Swift'),Reference('label','UILabel')),
            (('UIView','alpha'),Literal(0.5),Reference('view','UIView')),
        ]:
            api=next(a for a in uikit.apis.values() if a.path==path and not a.unsupported)
            ui_lines.append('  '+uikit.emit_set(api.id,value,receiver=receiver).expression)
            tested.append(api.id)
        source+='import UIKit\n@MainActor func verifyUIKit(label: UILabel, view: UIView, style: UIActivityIndicatorView.Style) {\n'+'\n'.join(ui_lines)+'\n  _ = color\n}\n'

    with tempfile.TemporaryDirectory() as directory:
        path=Path(directory)/'Verify.swift'; path.write_text(source)
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        subprocess.run(['xcrun','swiftc','-typecheck','-target','arm64-apple-ios18.0-simulator','-sdk',sdk,str(path)],check=True)
    report={**catalog.coverage(),'native_tested':len(tested),'native_tested_ids':tested,'target':'arm64-apple-ios18.0-simulator','uikit_coverage':uikit.coverage() if args.uikit_symbolgraphs else None,'source':source}
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__': main()
