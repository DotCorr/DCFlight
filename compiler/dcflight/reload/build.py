"""Build a content-addressed, stateless DC Dart native reload generation."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from ..dcdart import compile_logic
from ..shared_logic import rewrite_imports, C_TYPES
from .planner import abi_digest


def build_generation(app, source, output, *, target='host', clang='clang', dcc='dcc', nm='llvm-nm'):
    if app.logic is None:raise ValueError('A declared DC Dart logic ABI is required')
    if target not in ('host','android-arm64','ios-simulator-arm64'):raise ValueError('Physical iOS app loading is not verified; use restart')
    root=Path(source).resolve().parent;logic=(root/app.logic.source).resolve();prelude=(root/app.logic.prelude).absolute()
    destination=Path(output).resolve();destination.mkdir(parents=True,exist_ok=True)
    abi=abi_digest(app.logic.functions)
    with tempfile.TemporaryDirectory(prefix='reload-generation-') as temporary:
        work=Path(temporary);staged=work/'logic.dart'
        staged.write_text(rewrite_imports(logic.read_text(),logic,prelude))
        result=compile_logic(staged,work/'object',target,prelude=prelude,dcc=dcc,nm=nm)
        header=result.header.read_text()
        for f in app.logic.functions:
            declaration=C_TYPES[f.returns]+' '+f.name+'('+(', '.join(C_TYPES[t]+' a'+str(i) for i,t in enumerate(f.parameters)) or 'void')+');'
            if declaration not in header:raise ValueError('Compiled function ABI differs: '+f.name)
        symbols=subprocess.check_output([str(nm),'--format=posix',str(result.object)],text=True)
        # Mutable globals, TLS and unknown symbol classes make unloading unsafe.
        for line in symbols.splitlines():
            parts=line.split()
            if len(parts)>1 and parts[1] not in ('T','t','R','r','N','n','-'):
                raise ValueError('Reload supports stateless logic only; unsupported object symbol: '+line)
        metadata=work/'abi.c'
        metadata.write_text('#if !defined(DCFLIGHT_DEVELOPMENT_RELOAD) || DCFLIGHT_DEVELOPMENT_RELOAD != 1\n#error "Development reload metadata cannot ship"\n#endif\nconst char dcflight_reload_abi[] = "'+abi+'";\n')
        suffix='.so' if target=='android-arm64' or os.sys.platform!='darwin' else '.dylib'
        library=work/('generation'+suffix)
        linkflag='-dynamiclib' if suffix=='.dylib' else '-shared'
        flags=[]
        if target=='ios-simulator-arm64':
            sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
            flags=['-target','arm64-apple-ios16.0-simulator','-isysroot',sdk]
        subprocess.run([str(clang),*flags,linkflag,'-fPIC','-DDCFLIGHT_DEVELOPMENT_RELOAD=1',str(result.object),str(metadata),'-o',str(library)],check=True,capture_output=True)
        content=library.read_bytes();digest=hashlib.sha256(content).hexdigest();path=destination/(digest+suffix)
        if path.is_symlink():raise ValueError('Generation path must not be a symlink')
        if path.exists():
            if path.read_bytes()!=content:raise ValueError('Generation content integrity conflict')
        else:
            with path.open('xb') as stream:stream.write(content)
        record={'path':str(path),'sha256':digest,'abi':abi,'target':target,'developmentOnly':True,
                'sourceSha256':hashlib.sha256(logic.read_bytes()).hexdigest(),'stateContract':'scalar calls only; no globals, retained callbacks, pointers, tasks or reentry'}
        (destination/(digest+'.json')).write_text(json.dumps(record,indent=2)+'\n')
        return record
