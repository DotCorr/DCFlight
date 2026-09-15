import dataclasses
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI,index_android
from dcflight.platforms.ios_api import API,Parameter
from dcflight.native_operation import emit_operation,lower_contract
from dcflight.flow_ir import NativeOperationEffect
from dcflight.ir import Reference,ScalarType
from dcflight.backends.ios_flow import native_operation_effect
from dcflight.backends.android_flow import AndroidFlow
from dcflight.backends.android_routed import quoted
from test_android_flow import flow_fixture


class NativeUnwrapFlowIntegrationTests(unittest.TestCase):
    def test_generated_operations_and_effects_preserve_state_on_missing_result(self):
        compiler=os.environ.get('DCFLIGHT_KOTLIN_COMPILER_CP')
        if not compiler or not shutil.which('xcrun'):
            self.skipTest('Swift and configured Kotlin toolchains required')
        java=Path(os.environ['JAVA_HOME'])/'bin'
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);db=root/'sdk.db';sdk=root/'sdk.txt'
            sdk.write_text('package java.lang {\n public class Integer {\n method public static java.lang.Integer valueOf(java.lang.String);\n method public int intValue();\n }\n}\n')
            index_android(db,sdk)
            member=API('parse','Swift',('Int32','init(_:)'),'constructor',(Parameter('_','description','String'),),'Int32?',(),())
            with Catalog(db,write=True) as catalog:
                catalog.import_records('ios','Swift','6',[member.to_dict()],{'fixture':'reviewed native initializer'})
            operation={'name':'parseCount','execution':'main','throws':True,'result':'int','parameters':[{'name':'text','type':'string'}],
                'implementations':{'ios':{'steps':[{'id':'parse','arguments':[{'ref':'text'}],'bind':'candidate'},
                    {'unwrap':{'ref':'candidate'},'bind':'number','message':'Invalid count'}],'return':{'ref':'number'}},
                'android':{'steps':[{'id':'java.lang.Integer#valueOf(java.lang.String)','arguments':[{'ref':'text'}],'bind':'candidate'},
                    {'unwrap':{'ref':'candidate'},'bind':'number','message':'Invalid count'},
                    {'id':'java.lang.Integer#intValue()','receiver':{'ref':'number'},'bind':'result'}],'return':{'ref':'result'}}}}
            api=NativeAPI(db);emitted=emit_operation(api,operation);contract=lower_contract(operation)
            effect=NativeOperationEffect('parseCount',(Reference('value',ScalarType.STRING),),'count','success','failure')
            swift_effect=native_operation_effect(effect,contract)
            app=dataclasses.replace(flow_fixture(),native_operations=(contract,))
            kotlin_effect=AndroidFlow(app,quoted).effect(effect)
            swift=root/'Operation.swift';swift.write_text(emitted['targets']['ios']['source'])
            main=root/'Main.swift';main.write_text('''@MainActor final class Model {
              var s_value="",s_count:Int32=99; var success=0,failure=0
              func f_success(_ n:(String)->Void){success += 1}
              func f_failure(_ n:(String)->Void){failure += 1}
              func execute(_ navigate:(String)->Void) {
            '''+swift_effect+''' } }
            @main struct Main { @MainActor static func main() {
              let m=Model();m.s_value="42";m.execute({_ in});precondition(m.s_count==42 && m.success==1)
              for text in ["bad","2147483648"] {m.s_value=text;m.s_count=99;let failures=m.failure;m.execute({_ in});precondition(m.s_count==99 && m.failure==failures+1 && m.success==1)}
            } }
            ''')
            subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library',str(swift),str(main),'-o',str(root/'verify')],check=True,capture_output=True)
            subprocess.run([str(root/'verify')],check=True,capture_output=True,timeout=15)
            operation_java=root/'NativeOperation_parseCount.java';operation_java.write_text(emitted['targets']['android']['source'])
            kotlin=root/'Check.kt';kotlin.write_text('''class Model {
              var s_value="";var s_count=99;var success=0;var failure=0
              fun f_success(n:(String)->Unit){success++}
              fun f_failure(n:(String)->Unit){failure++}
              fun execute(navigate:(String)->Unit){
            '''+kotlin_effect+''' } }
            fun main(){val m=Model();m.s_value="42";m.execute{};check(m.s_count==42&&m.success==1)
              for(text in listOf("bad","2147483648")){m.s_value=text;m.s_count=99;val failures=m.failure;m.execute{};check(m.s_count==99&&m.failure==failures+1&&m.success==1)}}
            ''')
            subprocess.run([str(java/'javac'),str(operation_java)],check=True,capture_output=True)
            subprocess.run([str(java/'java'),'-cp',compiler,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17','-classpath',compiler+os.pathsep+tmp,'-d',tmp,str(kotlin)],check=True,capture_output=True)
            subprocess.run([str(java/'java'),'-cp',tmp+os.pathsep+compiler,'CheckKt'],check=True,capture_output=True,timeout=15)
            operation['throws']=False
            with self.assertRaisesRegex(ValueError,'throws context'):emit_operation(api,operation)
