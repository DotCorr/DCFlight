#!/usr/bin/env python3
"""Execute reviewed SDK value and field-sequence cases on an explicitly selected Android device.

No app/UI is modified. Uses a temporary ART command-line fixture, removed afterwards.
This is runtime API evidence, not an app lifecycle or visual acceptance test.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
import zipfile

from .native_api import NativeAPI
from .platforms.android_api import JavaValue
from .native_sequence import emit_sequence


def cases():
    values = [
        ('boolean', [True, False], '[true, false]'),
        ('byte', [-128, 0, 127], '[-128, 0, 127]'),
        ('short', [-32768, 32767], '[-32768, 32767]'),
        ('int', [-2147483648, 2147483647], '[-2147483648, 2147483647]'),
        ('long', [-9223372036854775808, 9223372036854775807], '[-9223372036854775808, 9223372036854775807]'),
        ('float', [1e-50, 3.5], '[0.0, 3.5]'),
        ('double', [0.0, 3.5], '[0.0, 3.5]'),
        ('char', ['a', '\n'], '[a, \n]'),
        ('int', [], '[]'),
    ]
    result = [{'request': {'platform':'android', 'scope':'core-bytecode',
                         'id':'java.util.Arrays#toString(' + kind + '[])',
                         'arguments':[{'literal':value}]}, 'expected':expected}
            for kind, value, expected in values]
    scalars = [
        ('Boolean','boolean',True,'true'),
        ('Byte','byte',-128,'-128'), ('Byte','byte',127,'127'),
        ('Short','short',-32768,'-32768'),
        ('Integer','int',-2147483648,'-2147483648'),
        ('Long','long',-9223372036854775808,'-9223372036854775808'),
        ('Long','long',9223372036854775807,'9223372036854775807'),
        ('Float','float',1e-50,'0.0'), ('Double','double',1.25,'1.25'),
        ('Character','char','\n','\n'), ('Character','char','a','a'),
    ]
    result.extend({'request': {'platform':'android','scope':'core-bytecode',
                              'id':'java.lang.' + owner + '#toString(' + kind + ')',
                              'arguments':[{'literal':value}]}, 'expected':expected}
                  for owner,kind,value,expected in scalars)
    result.extend({'request':{'platform':'android','scope':'core-bytecode',
                             'id':'java.util.Arrays#deepToString(java.lang.Object[])',
                             'arguments':[{'array':value,'type':kind}]},'expected':expected}
                  for kind,value,expected in [
                      ('int[][]',[[1,2],[],None],'[[1, 2], [], null]'),
                      ('java.lang.String[][]',[['native','世界'],[None]],'[[native, 世界], [null]]')])
    for index,(actual,value,owner,expected,text) in enumerate([
            ('int',-2147483648,'Long','long','-2147483648'),
            ('char','A','Integer','int','65'),
            ('float',0.5,'Double','double','0.5')]):
        name='widening'+str(index)
        result.append({'inputs':[{'name':name,'type':actual,'value':value}],
                       'request':{'platform':'android','scope':'core-bytecode',
                                  'id':'java.lang.'+owner+'#toString('+expected+')',
                                  'arguments':[{'ref':name,'type':actual}]},'expected':text})
    result.append({'inputs':[{'name':'coordinate','type':'int','value':16777217}],
                   'sequence':{'platform':'android','steps':[
                       {'scope':'framework','id':'android.graphics.RectF#<init>()','bind':'rectangle'},
                       {'scope':'framework','id':'android.graphics.RectF#left','receiver':{'ref':'rectangle'},'set':{'ref':'coordinate'}},
                       {'scope':'framework','id':'android.graphics.RectF#left','receiver':{'ref':'rectangle'},'bind':'left'},
                       {'scope':'core-bytecode','id':'java.lang.Float#toString(float)','arguments':[{'ref':'left'}],'bind':'display'}]},
                   'result':'display','expected':'1.6777216E7'})
    result.append({'request':{'platform':'android','scope':'core-bytecode',
                              'id':'java.util.Objects#toString(java.lang.Object)',
                              'arguments':[{'literal':42}]},'expected':'42'})
    result.append({'sequence':{'platform':'android','steps':[
                       {'scope':'core-bytecode','id':'java.lang.Integer#valueOf(int)',
                        'arguments':[{'literal':-2147483648}],'bind':'boxed'},
                       {'scope':'core-bytecode','id':'java.lang.Long#toString(long)',
                        'arguments':[{'ref':'boxed'}],'bind':'display'}]},
                   'result':'display','expected':'-2147483648'})
    result.append({'sequence':{'platform':'android','steps':[
                       {'scope':'core-bytecode','id':'java.util.Collections#singletonList(T)',
                        'typeArguments':['java.lang.String'],'arguments':[{'literal':'native generic'}],'bind':'items'},
                       {'scope':'core-bytecode','id':'java.util.Objects#toString(java.lang.Object)',
                        'arguments':[{'ref':'items'}],'bind':'display'}]},
                   'result':'display','expected':'[native generic]'})
    result.append({'sequence':{'platform':'android','steps':[
                       {'scope':'core-bytecode','id':'java.util.Collections#singletonList(T)',
                        'typeArguments':['java.lang.String'],'arguments':[{'literal':'typed array'}],'bind':'items'},
                       {'scope':'core-bytecode','id':'java.util.List#toArray(T[])',
                        'typeArguments':['java.lang.String'],'receiver':{'ref':'items'},
                        'arguments':[{'literal':[]}],'bind':'array'},
                       {'scope':'core-bytecode','id':'java.util.Arrays#toString(java.lang.Object[])',
                        'arguments':[{'ref':'array'}],'bind':'display'}]},
                   'result':'display','expected':'[typed array]'})
    result.append({'sequence':{'platform':'android','steps':[
                       {'scope':'framework','id':'android.os.Bundle#<init>()','bind':'bundle'},
                       {'scope':'framework','id':'android.net.Uri#parse(java.lang.String)',
                        'arguments':[{'literal':'https://example.com/native'}],'bind':'uri'},
                       {'scope':'framework','id':'android.os.Bundle#putParcelable(java.lang.String,android.os.Parcelable)',
                        'receiver':{'ref':'bundle'},'arguments':[{'literal':'uri'},{'ref':'uri'}]},
                       {'scope':'framework','id':'android.os.Bundle#getParcelable(java.lang.String,java.lang.Class<T>)',
                        'typeArguments':['android.net.Uri'],'receiver':{'ref':'bundle'},
                        'arguments':[{'literal':'uri'},{'class':'android.net.Uri'}],'bind':'restored'},
                       {'scope':'framework','id':'android.net.Uri#toString()',
                        'receiver':{'ref':'restored'},'bind':'display'}]},
                   'result':'display','expected':'https://example.com/native'})
    result.extend(typed_collection_cases())
    result.extend(generic_constructor_cases())
    return result


def generic_constructor_cases():
    """Deferred camera configuration needs no camera session or live surface."""
    result = []
    for surface in ('android.graphics.SurfaceTexture', 'android.view.SurfaceHolder'):
        result.append({'name':'deferred-output-' + surface.rsplit('.', 1)[-1],
            'sequence':{'platform':'android','steps':[
                {'scope':'framework','id':'android.util.Size#<init>(int,int)',
                 'arguments':[{'literal':640},{'literal':480}],'bind':'size'},
                {'scope':'framework','id':'android.hardware.camera2.params.OutputConfiguration#<init>(android.util.Size,java.lang.Class<T>)',
                 'typeArguments':[surface],
                 'arguments':[{'ref':'size'},{'class':surface}],'bind':'configuration'},
                {'scope':'framework','id':'android.hardware.camera2.params.OutputConfiguration#getSurfaceGroupId()',
                 'receiver':{'ref':'configuration'},'bind':'group'},
                {'scope':'core-bytecode','id':'java.lang.String#valueOf(int)',
                 'arguments':[{'ref':'group'}],'bind':'display'}]},
            'result':'display','expected':'-1'})
    return result


def typed_collection_cases():
    """Reviewed device semantics, emitted exclusively through catalogued calls."""
    def step(member, **fields):
        return {'scope':'framework','id':member,**fields}
    def case(name, steps, expected):
        return {'name':name,'sequence':{'platform':'android','steps':steps},
                'result':'display','expected':expected}
    ref=lambda name:{'ref':name}
    literal=lambda value:{'literal':value}
    result=[case('typed-pair-field',[
        step('android.util.Pair#<init>(F,S)',constructedType='android.util.Pair<java.lang.String,java.lang.String>',
             arguments=[literal('first native'),literal('second native')],bind='pair'),
        step('android.util.Pair#second',receiver=ref('pair'),bind='display')], 'second native')]
    result.append(case('typed-sparse-array-clone',[
        step('android.util.SparseArray#<init>()',constructedType='android.util.SparseArray<java.lang.String>',bind='items'),
        step('android.util.SparseArray#put(int,E)',receiver=ref('items'),arguments=[literal(7),literal('retained')]),
        step('android.util.SparseArray#clone()',receiver=ref('items'),bind='copied'),
        step('android.util.SparseArray#delete(int)',receiver=ref('items'),arguments=[literal(7)]),
        step('android.util.SparseArray#get(int,E)',receiver=ref('copied'),arguments=[literal(7),literal('missing')],bind='display')], 'retained'))
    result.append(case('typed-array-map-copy',[
        step('android.util.ArrayMap#<init>()',constructedType='android.util.ArrayMap<java.lang.String,java.lang.String>',bind='items'),
        step('android.util.ArrayMap#put(K,V)',receiver=ref('items'),arguments=[literal('key'),literal('copied native')]),
        step('android.util.ArrayMap#<init>(android.util.ArrayMap<K,V>)',constructedType='android.util.ArrayMap<java.lang.String,java.lang.String>',arguments=[ref('items')],bind='copied'),
        step('android.util.ArrayMap#clear()',receiver=ref('items')),
        step('android.util.ArrayMap#get(java.lang.Object)',receiver=ref('copied'),arguments=[literal('key')],bind='display')], 'copied native'))
    for key,expected in [('old','null'),('new','fresh')]:
        result.append(case('typed-lru-cache-'+key,[
            step('android.util.LruCache#<init>(int)',constructedType='android.util.LruCache<java.lang.String,java.lang.String>',arguments=[literal(1)],bind='cache'),
            step('android.util.LruCache#put(K,V)',receiver=ref('cache'),arguments=[literal('old'),literal('stale')]),
            step('android.util.LruCache#put(K,V)',receiver=ref('cache'),arguments=[literal('new'),literal('fresh')]),
            step('android.util.LruCache#get(K)',receiver=ref('cache'),arguments=[literal(key)],bind='value'),
            {'scope':'core-bytecode','id':'java.util.Objects#toString(java.lang.Object)','arguments':[ref('value')],'bind':'display'}],expected))
    return result


def run(args, *, progress=True):
    if args.report.exists() or args.report.is_symlink():
        raise ValueError('Verification requires a new report path; preserve prior evidence separately')
    if type(args.api_level) is not int or args.api_level < 1 or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',args.build_tools):
        raise ValueError('Invalid SDK/build tools version')
    sdk = args.sdk.resolve(); java = args.java_home.resolve() / 'bin'
    adb = sdk / 'platform-tools/adb'
    jar = sdk / ('platforms/android-' + str(args.api_level)) / 'android.jar'
    d8 = sdk / 'build-tools' / args.build_tools / 'd8'
    for tool in (adb, jar, d8, java/'javac', java/'java'):
        if not tool.is_file(): raise ValueError('Missing toolchain file: ' + str(tool))
    env = os.environ.copy(); env['JAVA_HOME'] = str(args.java_home.resolve())
    def execute(command, timeout=60):
        return subprocess.run([str(x) for x in command], env=env, check=True,
                              capture_output=True, text=True, timeout=timeout).stdout.strip()
    prefix = [adb, '-s', args.serial]
    device_sdk = execute(prefix + ['shell','getprop','ro.build.version.sdk'])
    if device_sdk != str(args.api_level):
        raise ValueError('Device SDK differs from selected compilation SDK')
    fingerprint = execute(prefix + ['shell','getprop','ro.build.fingerprint'])
    token = uuid.uuid4().hex
    remote = '/data/local/tmp/dcf-array-' + token + '.jar'
    api = NativeAPI(args.catalog.resolve())
    selected = cases(); statements = []; emissions = []
    for index, case in enumerate(selected):
        statements.append('{')
        for value in case.get('inputs',[]):
            reference=JavaValue.reference(value['name'],value['type'])
            literal=JavaValue.typed_literal(value['value'],value['type'])
            statements.append(value['type']+' '+reference.source()+' = '+literal.source()+';')
        if 'sequence' in case:
            sequence={**case['sequence'],'inputs':[{'name':v['name'],'type':v['type']} for v in case.get('inputs',[])]}
            emitted=emit_sequence(api,sequence)
            result=next((b for b in emitted['bindings'] if b['name']==case['result']),None)
            if result is None or result['type']!='java.lang.String' or emitted['nativeDependencies']:
                raise ValueError('Fixture requires a native String sequence result')
            statements.append(emitted['source'])
            expression=result['nativeName']
        else:
            emitted = api.emit(case['request'])
            if emitted['resultType'] != 'java.lang.String' or emitted['runtimeDependency'] is not None:
                raise ValueError('Fixture requires a platform String-returning API')
            expression=emitted['source']
        expected = JavaValue.literal(case['expected']).source()
        statements.append('if (!' + expected + '.equals(' + expression + ')) throw new AssertionError("case ' + str(index) + '");')
        statements.append('}')
        emissions.append(emitted)
    marker = 'ARRAY_CASES_PASSED:' + token + ':' + str(len(selected))
    source = 'public class ArrayCalls { public static void main(String[] args) {\n' + '\n'.join(statements) + '\nSystem.out.println("' + marker + '");\n} }\n'
    with tempfile.TemporaryDirectory(prefix='dcflight-array-') as tmp:
        work = Path(tmp); source_path = work/'ArrayCalls.java'; source_path.write_text(source)
        captured_sdk = work/'android.jar'; shutil.copyfile(jar, captured_sdk)
        sdk_sha = hashlib.sha256(captured_sdk.read_bytes()).hexdigest()
        compiler = [java/'javac','-source','8','-target','8','-Xlint:unchecked','-Werror','-bootclasspath',captured_sdk,source_path]
        execute(compiler)
        dex = work/'dex'; dex.mkdir()
        execute([d8,'--min-api',str(args.api_level),'--lib',captured_sdk,'--output',dex,work/'ArrayCalls.class'])
        payload = work/'calls.jar'
        with zipfile.ZipFile(payload,'w') as archive:
            archive.write(dex/'classes.dex','classes.dex')
        dex_sha = hashlib.sha256((dex/'classes.dex').read_bytes()).hexdigest()
        try:
            execute(prefix + ['push',payload,remote])
            output = execute(prefix + ['shell','dalvikvm','-cp',remote,'ArrayCalls'])
            if output.splitlines().count(marker) != 1:
                raise ValueError('Android execution did not return the current run completion marker')
        finally:
            execute(prefix + ['shell','rm','-f',remote])
    compiler_files = ('android_verification.py','native_api.py','native_sequence.py','platforms/android_api.py')
    compiler_sources = {name:hashlib.sha256((Path(__file__).parent/name).read_bytes()).hexdigest()
                        for name in compiler_files}
    report = {'passed':True,'executedCases':len(selected),'cases':selected,'emissions':emissions,
              'compilerSourcesSHA256':compiler_sources,
              'serial':args.serial,'deviceSDK':int(device_sdk),'buildFingerprint':fingerprint,
              'sdkSha256':sdk_sha,'sourceSha256':hashlib.sha256(source.encode()).hexdigest(),
              'dexSha256':dex_sha,'javacVersion':execute([java/'javac','-version']),
              'compilerCommand':[str(x) for x in compiler], 'deviceOutput':output,
              'source':source,'scope':'Actual Android ART SDK-call execution. No UI, app lifecycle, physical-device or production certification.'}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    result={'passed':True,'executedCases':len(selected),'report':str(args.report),'scope':report['scope']}
    if progress: print(json.dumps(result))
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog',type=Path,required=True)
    parser.add_argument('--sdk',type=Path,required=True)
    parser.add_argument('--java-home',type=Path,required=True)
    parser.add_argument('--serial',required=True)
    parser.add_argument('--api-level',type=int,default=35)
    parser.add_argument('--build-tools',default='35.0.0')
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    if args.api_level < 1 or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',args.build_tools):
        parser.error('Invalid SDK/build tools version')
    run(args)
