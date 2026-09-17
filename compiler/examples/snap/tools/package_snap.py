#!/usr/bin/env python3
"""Package existing Snap projects without building or touching running processes."""
import argparse
import json
from pathlib import Path
import shutil
import shlex


def package(destination,config_path,python,ios_device,android_starter,*,allow_existing=False,backend_database=None):
    root=Path(destination).resolve();snap=Path(__file__).resolve().parents[1];compiler=snap.parents[1]
    if not (root/'app.dart').is_file() or not (root/'ios').is_dir() or not (root/'android').is_dir():
        raise ValueError('Destination must already contain the Snap authoring and generated native projects')
    config=json.loads(Path(config_path).read_text())
    config.update(compiler=str(compiler),python=str(Path(python).absolute()),iosDevice=ios_device,applicationId='com.dotcorr.snap',allowExistingBackend=allow_existing)
    if backend_database:config['backendDatabase']=str(Path(backend_database).resolve())
    shutil.copytree(snap/'server',root/'backend',dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','.pytest_cache','.venv','data','*.sqlite3','*.sqlite3-*'))
    shutil.copy2(Path(__file__).with_name('snap_launcher.py'),root/'launch.py')
    shutil.copy2(android_starter,root/'start_android.py')
    (root/'toolchain.json').write_text(json.dumps(config,indent=2)+'\n')
    for label,platform in [('iOS','ios'),('Android','android')]:
        command=root/('Run Snap '+label+'.command')
        command.write_text('#!/bin/zsh\ncd -- "${0:A:h}"\n'+shlex.quote(config['python'])+' launch.py '+platform+'\nsnap_launch_status=$?\nif (( snap_launch_status != 0 )); then read "?Press Return to close…"; fi\nexit $snap_launch_status\n')
        command.chmod(0o755)
    shutil.copy2(compiler/'docs/snap-product.md',root/'README.md')
    return {'destination':str(root),'packaged':True,'built':False,'started':False}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('destination');p.add_argument('--toolchain',required=True);p.add_argument('--python',required=True);p.add_argument('--ios-device',required=True);p.add_argument('--android-starter',required=True);p.add_argument('--allow-existing-backend',action='store_true');p.add_argument('--backend-database')
    a=p.parse_args();print(json.dumps(package(a.destination,a.toolchain,a.python,a.ios_device,a.android_starter,allow_existing=a.allow_existing_backend,backend_database=a.backend_database)))
