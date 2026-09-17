"""Native execution proof for shared Snap account decisions; no server fixtures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    p=argparse.ArgumentParser();p.add_argument('--dcc',required=True);p.add_argument('--dart',required=True);p.add_argument('--out',required=True)
    args=p.parse_args();out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True)
    source=Path(__file__).resolve().parents[1]/'shared/logic.dart';prelude=source.with_name('prelude.dart')
    env={**os.environ,'DCDART_DART':str(Path(args.dart).absolute())}
    for target in ('host','ios-arm64','ios-simulator-arm64','android-arm64'):
        subprocess.run([args.dcc,'build','--mode','bare','--target',target,'--prelude',prelude,source,'-o',out/(target+'.o'),'--emit-header',out/(target+'.h')],env=env,check=True)
    code='''#include "host.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(){
const char *username="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
uint64_t address=(uint64_t)(uintptr_t)username;
assert(decideLogin(address,2,12)==0);assert(decideLogin(address,25,12)==0);assert(decideLogin(address,3,11)==1);assert(decideLogin(address,3,129)==1);
assert(decideLogin(address,3,12)==3);assert(decideLogin(address,24,128)==3);
assert(decideRegister(address,3,12,0)==2);assert(decideRegister(address,3,12,61)==2);assert(decideRegister(address,3,12,1)==3);assert(decideRegister(address,24,128,60)==3);
assert(decideRegister(address,2,12,10)==0);assert(decideRegister(address,3,11,10)==1);
assert(decideLogin((uint64_t)(uintptr_t)"a_b12",5,12)==3);
assert(decideLogin((uint64_t)(uintptr_t)"a.b",3,12)==0);
assert(decideLogin((uint64_t)(uintptr_t)"a b",3,12)==0);
const unsigned char nonascii[]={97,195,169};
assert(decideLogin((uint64_t)(uintptr_t)nonascii,3,12)==0);
const unsigned char embeddedNul[]={97,0,98};
assert(decideLogin((uint64_t)(uintptr_t)embeddedNul,3,12)==0);
assert(decideLogin(0,0,12)==0);
unsigned char canonical[24]={0};uint64_t output=(uint64_t)(uintptr_t)canonical;
assert(canonicalHandle((uint64_t)(uintptr_t)"QA_Name",7,output,24)==7);
assert(memcmp(canonical,"qa_name",7)==0);
assert(canonicalHandle(address,24,output,24)==24);
assert(memcmp(canonical,"abcdefghijklmnopqrstuvwx",24)==0);
assert(canonicalHandle((uint64_t)(uintptr_t)"a_b12",5,output,24)==5);
assert(memcmp(canonical,"a_b12",5)==0);
assert(canonicalHandle((uint64_t)(uintptr_t)"a.b",3,output,24)==UINT32_MAX);
assert(canonicalHandle((uint64_t)(uintptr_t)nonascii,3,output,24)==UINT32_MAX);
assert(canonicalHandle((uint64_t)(uintptr_t)embeddedNul,3,output,24)==UINT32_MAX);
assert(canonicalHandle(0,0,output,24)==UINT32_MAX);
assert(canonicalHandle(address,25,output,24)==UINT32_MAX);
assert(canonicalHandle(address,3,output,2)==UINT32_MAX);

assert(decideProfile(0)==2);assert(decideProfile(61)==2);assert(decideProfile(1)==3);assert(decideProfile(60)==3);
assert(classifyFailure(0)==0);assert(classifyFailure(401)==1);assert(classifyFailure(409)==2);assert(classifyFailure(422)==3);assert(classifyFailure(429)==4);assert(classifyFailure(500)==5);
assert(decideRestore(0)==0);assert(decideRestore(43)==1);
assert(decideSearch(0)==0);assert(decideSearch(1)==0);assert(decideSearch(2)==1);assert(decideSearch(24)==1);assert(decideSearch(25)==0);
assert(decideMessage(0)==0);assert(decideMessage(1)==1);assert(decideMessage(2000)==1);assert(decideMessage(2001)==0);
assert(decidePhoto(1,0,0)==3);assert(decidePhoto(0,0,0)==0);assert(decidePhoto(8388609,0,0)==1);assert(decidePhoto(8388608,2000,0)==3);assert(decidePhoto(10,2001,0)==2);assert(decidePhoto(10,241,1)==2);assert(decidePhoto(10,240,1)==3);assert(decidePhoto(10,0,2)==4);
assert(decidePhotoDestination(0)==0);assert(decidePhotoDestination(1)==1);assert(decidePhotoDestination(2)==2);
assert(decideStoryExpiry(0,200,100)==0);assert(decideStoryExpiry(1,99,100)==0);assert(decideStoryExpiry(1,100,100)==1);assert(decideStoryExpiry(1,101,100)==1);
assert(decideCapture(0,1)==0);assert(decideCapture(1,0)==0);assert(decideCapture(1,1)==1);assert(decideCapture(2,1)==0);
assert(decideLocation(0,5)==0);assert(decideLocation(1,2001)==1);assert(decideLocation(1,2000)==2);assert(decideLocation(1,0)==2);
assert(decideMapExpiry(100,0)==0);assert(decideMapExpiry(99,100)==0);assert(decideMapExpiry(100,100)==1);assert(decideMapExpiry(101,100)==1);
puts("Shared account/social/media/device and UTF8 decision assertions passed");}
'''
    (out/'check.c').write_text(code)
    subprocess.run(['clang',out/'check.c',out/'host.o','-o',out/'check'],check=True);subprocess.run([out/'check'],check=True)
    undefined=subprocess.check_output(['nm','-u',out/'host.o'],text=True).strip()
    if undefined:raise RuntimeError('Unexpected native logic symbols: '+undefined)
    report={'assertions':code.count('assert('),'nativeHostExecution':True,'mobileObjectCompilation':['ios-arm64','ios-simulator-arm64','android-arm64'],'mobileExecution':False,'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'undefinedSymbols':[],'scope':'Shared account/social/media decisions; HTTP and UI integration must be verified separately'}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

if __name__=='__main__':main()
