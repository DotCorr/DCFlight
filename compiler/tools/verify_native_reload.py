#!/usr/bin/env python3
"""Real same-process DC Dart native swap proof. Does not touch any app or preview."""
import argparse
from dataclasses import replace
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.reload.build import build_generation
from dcflight.reload.planner import abi_digest

DRIVER=r'''
#include "loader.h"
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <stdatomic.h>
static uint32_t call(dcflight_reload *r,uint32_t state) {
    pthread_mutex_lock(&r->mutex);
    uint32_t (*function)(uint32_t)=(uint32_t(*)(uint32_t))r->functions[0];
    uint32_t result=function(state);
    pthread_mutex_unlock(&r->mutex);
    return result;
}
static atomic_int go=0, errors=0, calls=0;
static void *worker(void *context) {
    dcflight_reload *r=(dcflight_reload *)context;
    while(!atomic_load(&go)) {}
    for(int i=0;i<25000;i++) {
        uint32_t result=call(r,0);
        if(result!=1 && result!=10)atomic_fetch_add(&errors,1);
        atomic_fetch_add(&calls,1);
    }
    return NULL;
}
int main(int argc,char **argv) {
    if(argc!=4)return 10;
    const char *names[]={"increment"};
    dcflight_reload loader;
    if(dcflight_reload_init(&loader,"ABI_DIGEST",names,1))return 11;
    if(dcflight_reload_swap(&loader,argv[1]))return 12;
    uint32_t state=10;
    state=call(&loader,state);if(state!=11)return 13;
    if(dcflight_reload_swap(&loader,argv[2]))return 14;
    state=call(&loader,state);if(state!=21)return 15;
    if(dcflight_reload_swap(&loader,argv[3])!=3)return 16;
    state=call(&loader,state);if(state!=31||loader.generation!=2)return 17;
    if(dcflight_reload_swap(&loader,"/nonexistent/reload-library")!=2)return 18;
    state=call(&loader,state);if(state!=41)return 19;
    pthread_t workers[4];
    for(int i=0;i<4;i++)if(pthread_create(&workers[i],NULL,worker,&loader))return 20;
    atomic_store(&go,1);
    for(int i=0;i<100;i++)if(dcflight_reload_swap(&loader,argv[1+(i%2)]))return 21;
    for(int i=0;i<4;i++)pthread_join(workers[i],NULL);
    if(atomic_load(&errors) || atomic_load(&calls)!=100000)return 22;
    printf("{\"passed\":true,\"pid\":%d,\"generations\":%u,\"state\":%u,\"abiMismatchRejected\":true,\"missingLibraryRejected\":true}\n",getpid(),loader.generation,state);
    dcflight_reload_destroy(&loader);
    return 0;
}
'''


def main():
    p=argparse.ArgumentParser();p.add_argument('--dcc',required=True);p.add_argument('--dart',required=True);p.add_argument('--prelude',required=True)
    p.add_argument('--clang',default='clang');p.add_argument('--nm',default='llvm-nm');p.add_argument('--target',choices=('host','android-arm64','ios-simulator-arm64'),default='host')
    p.add_argument('--adb');p.add_argument('--device');p.add_argument('--out',required=True)
    args=p.parse_args();os.environ['DCDART_DART']=args.dart
    repo=Path(__file__).resolve().parents[1];out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='native-reload-proof-') as temporary:
        work=Path(temporary);source=work/'app.json';logic=work/'logic.dart'
        prelude=Path(args.prelude).absolute()
        doc={'version':1,'id':'com.example.reloadproof','name':'Reload proof','root':{'id':'label','type':'text','props':{'text':'Native'}},
             'logic':{'source':'logic.dart','prelude':str(prelude),'functions':[{'name':'increment','parameters':['uint32'],'returns':'uint32'}]}}
        source.write_text(json.dumps(doc));app=lower(doc,Registry());generations=[]
        for amount in (1,10):
            logic.write_text("import '"+str(prelude)+"';\n@bare\nu32 increment(u32 value) => value + u32("+str(amount)+");\n")
            generations.append(build_generation(app,source,out/'generations',target=args.target,clang=args.clang,dcc=args.dcc,nm=args.nm))
        logic.write_text("import '"+str(prelude)+"';\n@bare\nu32 increment(u32 value, u32 extra) => value + extra;\n")
        doc['logic']['functions'][0]['parameters'].append('uint32')
        generations.append(build_generation(lower(doc,Registry()),source,out/'generations',target=args.target,clang=args.clang,dcc=args.dcc,nm=args.nm))
        native=repo/'dcflight/reload/native';driver=work/'driver.c';driver.write_text(DRIVER.replace('ABI_DIGEST',abi_digest(app.logic.functions)))
        executable=out/'native-reload-proof'
        flags=['-ldl'] if args.target=='android-arm64' or sys.platform!='darwin' else []
        target_flags=[]
        if args.target=='ios-simulator-arm64':
            sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
            target_flags=['-target','arm64-apple-ios16.0-simulator','-isysroot',sdk]
        subprocess.run([args.clang,*target_flags,'-DDCFLIGHT_DEVELOPMENT_RELOAD=1','-I'+str(native),str(driver),str(native/'loader.c'),'-pthread',*flags,'-o',str(executable)],check=True,capture_output=True)
        # The exact same source must fail to compile without the development gate.
        forbidden=subprocess.run([args.clang,'-I'+str(native),'-c',str(native/'loader.c'),'-o',str(work/'forbidden.o')],capture_output=True)
        if forbidden.returncode==0:raise RuntimeError('Development loader compiled without its required build gate')
        if args.target=='host':
            raw=subprocess.check_output([str(executable),*[g['path'] for g in generations]],text=True)
        elif args.target=='ios-simulator-arm64':
            if not args.device:raise ValueError('Simulator proof requires an explicit booted --device')
            raw=subprocess.check_output(['xcrun','simctl','spawn',args.device,str(executable),*[g['path'] for g in generations]],text=True)
        else:
            if not args.adb or not args.device:raise ValueError('Android proof requires explicit --adb and --device')
            remote='/data/local/tmp/dcflight-reload-proof-'+os.urandom(8).hex()
            adb=[args.adb,'-s',args.device]
            subprocess.run(adb+['shell','mkdir',remote],check=True,capture_output=True)
            try:
                files=[str(executable)]+[g['path'] for g in generations]
                subprocess.run(adb+['push',*files,remote+'/'],check=True,capture_output=True)
                paths=[remote+'/'+Path(f).name for f in files]
                subprocess.run(adb+['shell','chmod','700',paths[0]],check=True,capture_output=True)
                raw=subprocess.check_output(adb+['shell',*paths],text=True)
            finally:subprocess.run(adb+['shell','rm','-rf',remote],check=True,capture_output=True)
        report=json.loads(raw);report['generationCount']=report.pop('generations');report['concurrentCalls']=100000;report.update(target=args.target,releaseBuildGate=True,scope='Native command-line process; not an iOS/Android app reload integration',generations=generations)
        (out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({k:v for k,v in report.items() if k!='generations'},indent=2))

if __name__=='__main__':main()
