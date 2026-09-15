#!/usr/bin/env python3
"""Verify wheel-only Dart authoring, with no checkout API fallback."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('wheel')
    parser.add_argument('--dart', default='dart')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / 'authoring/lib/dcflight.dart'
    with tempfile.TemporaryDirectory(prefix='authoring-wheel-') as temporary:
        root = Path(temporary)
        with zipfile.ZipFile(args.wheel) as archive:
            compiler = Path(__file__).resolve().parents[1] / 'dcflight'
            for module in compiler.rglob('*.py'):
                relative = 'dcflight/' + module.relative_to(compiler).as_posix()
                if archive.read(relative) != module.read_bytes():
                    raise RuntimeError('Packaged compiler differs: ' + relative)
            templates = Path(__file__).resolve().parents[1] / 'dcflight/backends/templates'
            for template in templates.rglob('*'):
                if template.is_file():
                    relative = 'dcflight/backends/templates/' + template.relative_to(templates).as_posix()
                    if archive.read(relative) != template.read_bytes():
                        raise RuntimeError('Packaged native template differs: ' + relative)
            if archive.read('dcflight/data/authoring/lib/dcflight.dart') != source.read_bytes():
                raise RuntimeError('Packaged Dart authoring differs from canonical source')
            if archive.read('dcflight/data/authoring/pubspec.yaml') != (source.parent.parent / 'pubspec.yaml').read_bytes():
                raise RuntimeError('Packaged Dart authoring version/manifest differs')
            for relative in ('reload/native/loader.c', 'reload/native/loader.h'):
                expected = Path(__file__).resolve().parents[1] / 'dcflight' / relative
                if archive.read('dcflight/' + relative) != expected.read_bytes():
                    raise RuntimeError('Packaged development loader differs: ' + relative)
            archive.extractall(root)
        app = root / 'example.dart'
        app.write_text("import 'package:dcflight_authoring/dcflight.dart';\nApp buildApp() => App(id: 'com.example.wheel', name: 'Wheel', root: Column(id: 'root', children: [for (var i = 0; i < 2; i++) Text('Item $i', id: 'item$i')]));\n")
        code = '''import json,sys
from dcflight.evaluated_frontend import load_evaluated
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.backends.ios import IOS
from dcflight.backends.android import Android
from dcflight.sync import synchronize
from dcflight.audit import audit
app = lower(load_evaluated(sys.argv[1], sys.argv[2]), Registry())
artifacts = IOS().generate(app, Registry())
artifacts.update(Android().generate(app, Registry()))
synchronize(sys.argv[3], artifacts, app.id)
result = audit(sys.argv[3])
assert result['passed'], result
assert len(app.nodes()) == 3
print(json.dumps({'wheelOnlyAuthoring': True, 'nativeSourceAudit': result}))
'''
        env = os.environ.copy()
        env['PYTHONPATH'] = str(root)
        process = subprocess.run([sys.executable, '-c', code, str(app), args.dart, str(root / 'native')],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())

        text_app = root / 'utf8.dart'
        text_app.write_text("""import 'package:dcflight_authoring/dcflight.dart';
App buildApp() => App(id:'com.example.utf8wheel',name:'UTF8 wheel',state:{'text':'Hello 🌍','result':0},
 logic:const Logic(source:'logic.dart',prelude:'prelude.dart',functions:[LogicFunction(name:'readText',parameters:['utf8'],returns:'int32')]),
 actions:const [Action.call(id:'read',function:'readText',args:[Ref<String>(name:'text')],target:'result',failure:'failed'),Action.set(id:'failed',target:'result',value:-1)],
 root:Text('UTF8',id:'root'));
""")
        code = '''import json,sys
from dcflight.evaluated_frontend import load_evaluated
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.ir import ABIType
from dcflight.backends.ios import IOS
from dcflight.backends.android import Android
from dcflight.shared_logic import abi_declaration
registry=Registry();app=lower(load_evaluated(sys.argv[1],sys.argv[2]),registry)
assert app.logic.functions[0].parameters==(ABIType.UTF8,)
assert next(action for action in app.actions if action.id=='read').failure=='failed'
assert abi_declaration(app.logic.functions[0])=='int32_t readText(uint64_t a0, uint32_t a1);'
swift=IOS().generate(app,registry)['ios/App/Generated/AppModel.swift'].content
java=Android().generate(app,registry)['android/app/src/main/java/com/example/utf8wheel/AppModel.java'].content
assert 'try AppLogicUTF8.f_readText' in swift and 'self.a_failed()' in swift
assert 'catch (SharedLogic.InputFailure error)' in java
print(json.dumps({'wheelOnlyUTF8Authoring':True,'failureDispatchBothTargets':True,'flattenedBorrowedABI':True}))
'''
        process=subprocess.run([sys.executable,'-c',code,str(text_app),args.dart],cwd=root,env=env,capture_output=True,text=True,check=True)
        print(process.stdout.strip())

        result_app = root / 'utf8-result.dart'
        result_app.write_text("""import 'package:dcflight_authoring/dcflight.dart';
App buildApp() => App(version:2,id:'com.example.resultwheel',name:'UTF8 result wheel',
 state:{'input':'QA_Name','output':'unchanged','status':'ready'},
 logic:const Logic(source:'logic.dart',prelude:'prelude.dart',functions:[
  LogicFunction(name:'canonicalHandle',parameters:['utf8'],returns:'utf8',maxOutputBytes:24)]),
 root:NavigationStack(id:'root',initialRoute:'home'),routes:[Screen(id:'home',title:'Result',body:Text.bind(const Ref<String>(name:'output'),id:'output'))],
 flowActions:[FlowAction(id:'normalize',cases:[FlowCase(code:0,effects:[
  LogicCallEffect(function:'canonicalHandle',arguments:[Ref<String>(name:'input')],target:'output',success:'done',failure:'failed')])]),
  FlowAction(id:'done',cases:[FlowCase(code:0,effects:[SetEffect(target:'status',value:'success')])]),
  FlowAction(id:'failed',cases:[FlowCase(code:0,effects:[SetEffect(target:'status',value:'failure')])])]);
""")
        code = r'''import copy,json,sys
from pathlib import Path
import dcflight
from dcflight.evaluated_frontend import load_evaluated
from dcflight.validate import lower,Diagnostic
from dcflight.registry import Registry
from dcflight.ir import ABIType,Reference,ScalarType
from dcflight.flow_ir import LogicCallEffect
from dcflight.backends.ios_routed import IOS
from dcflight.backends.android_routed import AndroidRouted
from dcflight.backends.ios_flow import logic_call_effect
from dcflight.backends.android_flow import AndroidFlow
from dcflight.backends.android_routed import quoted
from dcflight.shared_logic import abi_declaration,swift_utf8_wrapper,android_utf8_wrapper
assert Path(sys.argv[1]).parent.resolve() in Path(dcflight.__file__).resolve().parents
registry=Registry();document=load_evaluated(sys.argv[1],sys.argv[2]);app=lower(document,registry)
function=app.logic.functions[0]
assert function.parameters==(ABIType.UTF8,) and function.returns==ABIType.UTF8
assert function.max_output_bytes==24
assert abi_declaration(function)=='uint32_t canonicalHandle(uint64_t a0, uint32_t a1, uint64_t a2, uint32_t a3);'
effect=app.flow_actions[0].cases[0].effects[0]
assert isinstance(effect,LogicCallEffect)
assert (effect.function,effect.target,effect.success,effect.failure)==('canonicalHandle','output','done','failed')
assert effect.arguments==(Reference('input',ScalarType.STRING),)
swift_body=logic_call_effect(effect,app)
kotlin_body=AndroidFlow(app,quoted).effect(effect)
swift='\n'.join(a.content for a in IOS().generate(app,registry).values() if isinstance(a.content,str))
kotlin='\n'.join(a.content for a in AndroidRouted().generate(app,registry).values() if isinstance(a.content,str))
assert swift_body in swift and kotlin_body in kotlin
assert swift_body.index('catch { self.f_failed(navigate); return }') < swift_body.index('self.s_output = logicResult') < swift_body.index('self.f_done(navigate)')
assert kotlin_body.index('catch(error: Exception) { f_failed(navigate); return }') < kotlin_body.index('s_output = logicResult') < kotlin_body.index('f_done(navigate)')
assert 'try AppLogicUTF8.f_canonicalHandle' in swift_body
assert 'SharedLogic.f_canonicalHandle' in kotlin_body
wrapper=swift_utf8_wrapper(function,'native_handle');java,jni=android_utf8_wrapper(function,app.id)
assert 'written <= UInt32(destination.count)' in wrapper and 'String(bytes:' in wrapper
assert jni.index('result > 24') < jni.index('valid_utf8(result_bytes, result)') < jni.index('NewByteArray')
assert 'Arrays.fill(resultBytes' in java and 'free(result_bytes)' in jni
for change in ('capacity','failure'):
 bad=copy.deepcopy(document)
 if change=='capacity':bad['logic']['functions'][0]['maxOutputBytes']=0
 else:del bad['flowActions'][0]['cases'][0]['effects'][0]['failure']
 try:lower(bad,registry)
 except Diagnostic:pass
 else:raise AssertionError('Packaged UTF8 result validation missing: '+change)
print(json.dumps({'wheelOnlyUTF8ResultAuthoring':True,'typedTerminalEffect':True,'boundedOutputABI':True,'failureBeforeAssignmentBothTargets':True,'scope':'Packaged Dart evaluation and native source generation; DC Dart/native execution verified separately.'}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(result_app), args.dart],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())

        presentation = root / 'presentation.dart'
        presentation.write_text("""import 'package:dcflight_authoring/dcflight.dart';
App buildApp() => App(version:2,id:'com.example.presentation',name:'Presentation',
 state:{'message':'','ready':true},
 root:NavigationStack(id:'root',initialRoute:'home'), routes:[
 Screen(id:'home',title:'Compact',titleDisplay:TitleDisplay.compact,
  body:Text.bind(const Ref<String>(name:'message'),id:'status',
   visibleWhen:const BooleanAll([Ref<bool>(name:'ready'),BooleanNot(StringIsEmpty(Ref<String>(name:'message')))]))),
 Screen(id:'large',title:'Large',titleDisplay:TitleDisplay.large,
  body:Text('Details',id:'details'))]);
""")
        code = '''import json,sys
from pathlib import Path
from dcflight.compiler import compile_app
from dcflight.evaluated_frontend import load_evaluated
from dcflight.audit import audit
from dcflight.validate import lower
from dcflight.registry import Registry
from dcflight.ir import BooleanAll,BooleanNot,StringIsEmpty
from dcflight.navigation_ir import TitleDisplay
document=load_evaluated(sys.argv[1],sys.argv[2])
app=lower(document,Registry())
condition=app.routes[0].body.visible_when
assert isinstance(condition,BooleanAll)
assert isinstance(condition.values[1],BooleanNot)
assert isinstance(condition.values[1].value,StringIsEmpty)
assert app.routes[1].title_display == TitleDisplay.LARGE
out=Path(sys.argv[3]);compile_app(sys.argv[1],out,document=document)
swift=(out/'ios/App/Generated/RouteContent.swift').read_text()
kotlin=next(out.rglob('AuthoredApplication.kt')).read_text()
assert 'navigationBarTitleDisplayMode(.inline)' in swift
assert 'navigationBarTitleDisplayMode(.large)' in swift
assert 'LargeTopAppBar(title={Text("Large")}' in kotlin
assert 'model.s_message).isEmpty()' in kotlin
status=(out/'ios/App/Generated/Nodes/n_status.swift').read_text()
assert 'model.s_message).isEmpty' in status
document['routes'][1]['titleDisplay']='compact'
document['routes'][0]['body']['visibleWhen']={'isEmpty':{'ref':'message'}}
compile_app(sys.argv[1],out,document=document)
assert 'navigationBarTitleDisplayMode(.large)' not in (out/'ios/App/Generated/RouteContent.swift').read_text()
assert 'LargeTopAppBar' not in next(out.rglob('AuthoredApplication.kt')).read_text()
assert status != (out/'ios/App/Generated/Nodes/n_status.swift').read_text()
result=audit(out);assert result['passed'],result
print(json.dumps({'wheelOnlyPredicates':True,'wheelOnlyTitleDisplay':True,
 'sharedMutationChangesBothTargets':True,'nativeSourceAudit':result,
 'scope':'Detached wheel authoring, validation and native source generation; native builds are verified separately.'}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(presentation), args.dart, str(root / 'presentation-native')],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())

        code = '''import json,sys
from dcflight import __version__
from importlib.metadata import version
from dcflight.platforms.swift_types import parse_type
from dcflight.platforms.ios_api import API,SDKCatalog,Literal
from dcflight.platforms.android_api import JavaValue
assert version('dcflight-compiler') == __version__
assert parse_type('[String: [Int32?]]') == parse_type('Dictionary<String, Array<Int32?>>')
assert JavaValue.typed_literal(9223372036854775807,'long').source() == '9223372036854775807L'
assert JavaValue.array([1,2],'int[]').source() == 'new int[] {1, 2}'
member=API('actor','Fixture',('Store','name()'),'static_method',(),'String',(),(),actor_isolation='global:Fixture.StoreActor')
api=SDKCatalog([member])
try: api.emit_call('actor')
except ValueError: pass
else: raise AssertionError('Packaged compiler lost actor context checks')
api.emit_call('actor',actor_context='global:Fixture.StoreActor')
print(json.dumps({'wheelOnlySDKTypes':True,'version':__version__,'actorValidation':True}))
'''
        process = subprocess.run([sys.executable, '-c', code], cwd=root, env=env,
                                 capture_output=True, text=True, check=True)
        print(process.stdout.strip())
        routed = Path(__file__).resolve().parents[1] / 'examples/routed/app.dart'
        app.write_text(routed.read_text())
        code = '''import json,sys
from dcflight.compiler import compile_app
from dcflight.audit import audit
compile_app(sys.argv[1],sys.argv[3],evaluate_dart=True,dart=sys.argv[2])
result=audit(sys.argv[3])
assert result['passed'], result
print(json.dumps({'wheelOnlyRoutedAuthoring':True,'nativeSourceAudit':result}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(app), args.dart, str(root / 'routed-native')],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())


        operation = root / 'operation.dart'
        operation.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeImplementation implementation(String create,String read) => NativeImplementation(
  steps:[NativeCall(create,bind:'uuid'),NativeCall(read,receiver:const NativeRef('uuid'),bind:'text')],
  result:const NativeRef('text'));
NativeOperation buildOperation() => NativeOperation(name:'newIdentifier',result:NativeScalar.string,
  ios:implementation('s:10Foundation4UUIDVACycfc','s:10Foundation4UUIDV10uuidStringSSvp'),
  android:implementation('java.util.UUID#randomUUID()','java.util.UUID#toString()'));
""")
        code = r'''import json,sys
from pathlib import Path
from dcflight.evaluated_frontend import load_evaluated_operation
from dcflight.native_operation import emit_operation
from dcflight.native_api import NativeAPI,index_android
from dcflight.catalog import Catalog
from dcflight.platforms.ios_api import API
root=Path(sys.argv[1]).parent
sdk=root/'core.txt'
sdk.write_text("package java.util {\n public final class UUID {\n method public static java.util.UUID randomUUID();\n method public String toString();\n }\n}\n")
index_android(root/'operation.db',sdk)
records=[API('s:10Foundation4UUIDVACycfc','Foundation',('UUID','init()'),'constructor',(),'UUID',(),()).to_dict(),API('s:10Foundation4UUIDV10uuidStringSSvp','Foundation',('UUID','uuidString'),'property',(),'String',(),()).to_dict()]
with Catalog(root/'operation.db',write=True) as catalog:
 catalog.import_records('ios','Foundation','26.2',records,{'fixture':True})
result=emit_operation(NativeAPI(root/'operation.db'),load_evaluated_operation(sys.argv[1],sys.argv[2]))
assert result['contract']['result']=='string'
assert set(result['targets'])=={'ios','android'}
assert result['compilerRuntimeDependency'] is None
print(json.dumps({'wheelOnlyOperationAuthoring':True,'nativeTargets':sorted(result['targets']),'scope':'Packaged authoring/emission; native execution is verified separately.'}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(operation), args.dart],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())


        operation_app = root / 'operation-app.dart'
        generic = root / 'generic.dart'
        generic.write_text("""import 'package:dcflight_authoring/dcflight.dart';
NativeOperation buildOperation() => NativeOperation(name:'typeName',result:NativeScalar.string,
 ios:NativeImplementation(steps:[],result:NativeRef('text')),
 android:NativeImplementation(steps:[NativeCall('fixture',typeArguments:['java.lang.String'],
 arguments:[NativeClass('java.lang.String')],bind:'text')],result:NativeRef('text')));
""")
        code = '''import json,sys
from dcflight.evaluated_frontend import load_evaluated_operation
from dcflight.platforms.android_api import JavaValue
document=load_evaluated_operation(sys.argv[1],sys.argv[2])
step=document['implementations']['android']['steps'][0]
assert step['typeArguments']==['java.lang.String']
assert step['arguments']==[{'class':'java.lang.String'}]
assert JavaValue.class_literal(step['arguments'][0]['class']).source()=='java.lang.String.class'
print(json.dumps({'wheelOnlyGenericDartValues':True,'scope':'Dart serialization and native class value; fixture is not a complete operation.'}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(generic), args.dart],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())
        operation_app.write_text((Path(__file__).resolve().parents[1]/'examples/native-operation/app.dart').read_text())
        code = '''import json,sys
from pathlib import Path
from dcflight.evaluated_frontend import load_evaluated
from dcflight.compiler import compile_app
from dcflight.audit import audit
source=Path(sys.argv[1]);document=load_evaluated(source,sys.argv[2])
document['sdkCatalog']=str(source.parent/'operation.db')
compile_app(source,source.parent/'operation-native',document=document)
result=audit(source.parent/'operation-native')
assert result['passed'],result
assert (source.parent/'operation-native/ios/App/Generated/Operations/NativeOperation_newIdentifier.swift').is_file()
assert (source.parent/'operation-native/android/app/src/main/java/com/dotcorr/nativeoperation/NativeOperation_newIdentifier.java').is_file()
print(json.dumps({'wheelOnlyOperationApp':True,'nativeSourceAudit':result}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(operation_app), args.dart],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())


        worker_app = root / 'worker-app.dart'
        worker_app.write_text((Path(__file__).resolve().parents[1]/'examples/native-worker/app.dart').read_text())
        code = '''import json,sys
from pathlib import Path
from dcflight.evaluated_frontend import load_evaluated
from dcflight.compiler import compile_app
from dcflight.audit import audit
from dcflight.platforms.android_api import AndroidAPI
source=Path(sys.argv[1]);document=load_evaluated(source,sys.argv[2])
document['sdkCatalog']=str(source.parent/'operation.db')
destination=source.parent/'worker-native'
compile_app(source,destination,document=document)
result=audit(destination)
assert result['passed'],result
ios=(destination/'ios/App/Generated/AppModel.swift').read_text()
android='\\n'.join(p.read_text() for p in (destination/'android/app/src/main/java').rglob('*.kt'))
assert 'Task.detached' in ios
assert 'NativeOperationWorker' in android and 'ThreadPoolExecutor' in android
api=AndroidAPI('package sample {\\n public class Calls {\\n method @WorkerThread public static int background();\\n }\\n}')
api.emit('sample.Calls#background()',execution_context='worker')
try: api.emit('sample.Calls#background()',execution_context='main')
except ValueError: pass
else: raise AssertionError('Packaged compiler lost thread requirement validation')
print(json.dumps({'wheelOnlyWorkerApp':True,'threadValidation':True,'nativeSourceAudit':result,'scope':'Packaged Dart evaluation, native emission and rejection checks; native execution verified separately.'}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(worker_app), args.dart],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())

        suspending_app = root / 'suspending-app.dart'
        suspending_app.write_text(worker_app.read_text().replace(
            'execution: NativeExecution.worker,', 'execution: NativeExecution.main, suspends: true,').replace(
            "id:'identifier')", "id:'identifier',style:const Style(fontSize:40))"))
        code = '''import json,sys
from pathlib import Path
from dcflight.evaluated_frontend import load_evaluated
from dcflight.compiler import compile_app
from dcflight.audit import audit
source=Path(sys.argv[1]);document=load_evaluated(source,sys.argv[2])
assert document['nativeOperations'][0]['suspends'] is True
document['sdkCatalog']=str(source.parent/'operation.db')
destination=source.parent/'suspending-native'
compile_app(source,destination,document=document)
result=audit(destination);assert result['passed'],result
swift=(destination/'ios/App/Generated/Operations/NativeOperation_newIdentifier.swift').read_text()
ios=(destination/'ios/App/Generated/AppModel.swift').read_text()
text=(destination/'ios/App/Generated/Nodes/n_identifier.swift').read_text()
android='\\n'.join(p.read_text() for p in (destination/'android/app/src/main/java').rglob('*.kt'))
assert 'async -> String' in swift and '@MainActor' in swift
assert 'await NativeOperation_newIdentifier.invoke' in ios
assert '@ScaledMetric' in text and 'authoredFontSize: Double = 40' in text
assert 'nativeOperationMain' in android
assert 'LocalTextStyle.current.copy(lineHeight=TextUnit.Unspecified)' in android
print(json.dumps({'wheelOnlySuspendingApp':True,'nativeFontScaling':True,'nativeSourceAudit':result}))
'''
        process = subprocess.run([sys.executable, '-c', code, str(suspending_app), args.dart],
                                 cwd=root, env=env, capture_output=True, text=True, check=True)
        print(process.stdout.strip())

        code = '''import json, subprocess, sys
from dcflight import __version__
from dcflight.ios_verification import verify_and_index, compiler_sources
from dcflight.platforms.swift_types import parse_type, spelling
from dcflight.platforms.ios_api import Parameter
callback = parse_type("((Int) async throws -> String)?")
assert parse_type(spelling(callback)) == callback
assert Parameter("_", "callback", "() -> Void", True).escaping
from dcflight.platforms.ios_api import API, SDKCatalog, Reference
for typ in ("(@convention(c) (Int32) -> Int32)?", "[String: (any Error)?]"):
    assert parse_type(spelling(parse_type(typ))) == parse_type(typ)
member = API("actor", "Fixture", ("Counter", "value"), "property", (), "Int32", (), (), owner_kind="actor", actor_isolation="instance")
assert "await" in SDKCatalog([member]).emit_call("actor", receiver=Reference("counter", "Counter"), allow_async=True).expression
lazy = API("lazy", "Fixture", ("lazy(_:)",), "function", (Parameter("_", "value", "() -> Int32", autoclosure=True),), "Int32", (), ())
assert "`value`()" in SDKCatalog.from_records([lazy.to_dict()]).emit_call("lazy", [Reference("value", "() -> Int32")]).expression

assert callable(verify_and_index) and "ios_verification.py" in compiler_sources()
help = subprocess.check_output([sys.executable, "-m", "dcflight.cli", "sdk", "verify-ios", "--help"], text=True)
assert "--report" in help and "--module" in help
print(json.dumps({"version":__version__,"wheelOnlySDKCommand":True,"structuredCallbacks":True}))
'''
        process = subprocess.run([sys.executable, '-c', code], cwd=root, env=env,
                                 capture_output=True, text=True, check=True)
        print(process.stdout.strip())


        code = r'''import json, plistlib, tempfile
from pathlib import Path
from dcflight.compiler import compile_app
from dcflight.native_api import NativeAPI, index_android
from dcflight.native_sequence import emit_sequence
root=Path('metadata-owner-check');root.mkdir()
source=root/'sdk.txt'
source.write_text('package java.util {\n public interface List<E> {\n method public E get(int);\n method public boolean add(E);\n }\n}\n')
index_android(root/'sdk.sqlite',source)
api=NativeAPI(root/'sdk.sqlite')
sequence=emit_sequence(api,{'platform':'android','inputs':[{'name':'items','type':'java.util.List<java.lang.String>'}],'steps':[{'id':'java.util.List#get(int)','receiver':{'ref':'items'},'arguments':[{'literal':0}],'bind':'item'}]})
assert 'java.lang.String' in sequence['source']
try:
 api.emit({'platform':'android','id':'java.util.List#add(E)','receiver':{'ref':'items','type':'java.util.List<java.lang.String>'},'arguments':[{'literal':7}]})
except ValueError: pass
else: raise AssertionError('Packaged owner argument validation missing')
doc={'version':2,'id':'com.example.metadata','name':'First name','root':{'id':'root','type':'navigationStack','props':{'initialRoute':'home'}},'routes':[{'id':'home','title':'','body':{'id':'text','type':'text','props':{'text':'Metadata'}}}]}
out=root/'native';compile_app(root/'app.json',out,document=doc)
user=[out/'ios/App.xcodeproj/project.pbxproj',out/'android/app/src/main/AndroidManifest.xml']
before=[p.read_bytes() for p in user]
doc['name']='Changed name';compile_app(root/'app.json',out,document=doc)
assert before==[p.read_bytes() for p in user]
assert plistlib.loads((out/'ios/Native/AppInfo.plist').read_bytes())['CFBundleDisplayName']=='Changed name'
assert 'Changed name' in (out/'android/app/src/main/res/values/native_app.xml').read_text()
doc['nativeConfiguration']={'ios':{'infoPlist':{'NSMicrophoneUsageDescription':{'type':'string','value':'Native audio'}},'entitlements':{'sample.enabled':{'type':'boolean','value':True}}},'android':{'manifest':{'tag':'manifest','children':[{'tag':'uses-permission','attributes':{'android:name':'android.permission.RECORD_AUDIO'}}]}}}
configured=root/'configured';compile_app(root/'configured.json',configured,document=doc)
assert plistlib.loads((configured/'ios/Native/AppInfo.plist').read_bytes())['NSMicrophoneUsageDescription']=='Native audio'
assert plistlib.loads((configured/'ios/Native/App.entitlements').read_bytes())['sample.enabled'] is True
assert 'android.permission.RECORD_AUDIO' in (configured/'android/app/src/debug/AndroidManifest.xml').read_text()
print(json.dumps({'wheelOnlyNativeConfiguration':True}))
print(json.dumps({'wheelOnlyOwnerGenerics':True,'wheelOnlyMetadataRename':True,'userOwnedFilesPreserved':True}))
'''
        process = subprocess.run([sys.executable, '-c', code], cwd=root, env=env,
                                 capture_output=True, text=True, check=True)
        print(process.stdout.strip())


        code = r'''import json
from pathlib import Path
from dcflight.native_api import NativeAPI, index_android
root=Path('constructor-check');root.mkdir()
source=root/'sdk.txt'
source.write_text('package sample {\n public class Box<C> {\n ctor public <T extends C> Box(T);\n }\n}\n')
index_android(root/'sdk.sqlite',source)
api=NativeAPI(root/'sdk.sqlite')
request={'platform':'android','id':'sample.Box#<init>(T)','constructedType':'sample.Box<java.lang.CharSequence>','typeArguments':['java.lang.String'],'arguments':[{'literal':'native'}]}
result=api.emit(request)
assert 'new <java.lang.String> sample.Box<java.lang.CharSequence>' in result['source']
assert result['compilerRuntimeDependency'] is None
try:
 api.emit({**request,'typeArguments':['java.lang.Integer']})
except ValueError: pass
else: raise AssertionError('Packaged generic constructor bound validation missing')
print(json.dumps({'wheelOnlyGenericConstructors':True,'boundValidation':True,'compilerRuntimeDependency':None}))
'''
        process = subprocess.run([sys.executable, '-c', code], cwd=root, env=env,
                                 capture_output=True, text=True, check=True)
        print(process.stdout.strip())


if __name__ == '__main__':
    main()
