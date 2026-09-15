"""Native predicates use target language operators, including scoped row values."""
import os
import shutil
import subprocess
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from dcflight.ir import (Application, Node, Literal, State, Reference, ScalarType,
                         StringIsEmpty, BooleanNot, BooleanAll, BooleanAny)
from dcflight.backends.common import expression
from dcflight.backends.android_routed import AndroidRouted
from dcflight.backends.android import Android
from dcflight.backends.ios import IOS
from dcflight.backends.ios_routed import generate
from dcflight.registry import Registry
from test_ios_routed import fixture
from test_ios_device import device_fixture


def string(value):
    return Literal(value, ScalarType.STRING)


def predicate():
    return BooleanAll((BooleanAny((BooleanNot(StringIsEmpty(Reference('text', ScalarType.STRING))),
                                   Reference('override', ScalarType.BOOL))),
                       BooleanNot(Reference('blocked', ScalarType.BOOL))))


def states():
    return (State('text', string('')), State('override', Literal(False, ScalarType.BOOL)),
            State('blocked', Literal(False, ScalarType.BOOL)))


class PredicateEmitterTests(unittest.TestCase):
    def test_primitive_and_routed_sources_lower_same_predicate(self):
        body = Node('message', 'text', (('text', string('Authored status')),), (), visible_when=predicate())
        app = Application('com.example.predicates', 'Predicates', states(), (), body)
        expected_swift = '(((!(model.s_text).isEmpty) || model.s_override) && (!model.s_blocked))'
        expected_jvm = '(((!(model.s_text).isEmpty()) || model.s_override) && (!model.s_blocked))'
        self.assertEqual(expression(predicate(), 'ios'), expected_swift)
        self.assertEqual(expression(predicate(), 'android'), expected_jvm)
        self.assertEqual(AndroidRouted().expr(predicate()), expected_jvm)
        self.assertIn(expected_swift, '\n'.join(a.content for a in IOS().generate(app, Registry()).values()))
        self.assertIn(expected_jvm, '\n'.join(a.content for a in Android().generate(app, Registry()).values()))
        routed = replace(fixture(), states=states(), routes=(replace(fixture().routes[0], body=body), *fixture().routes[1:]))
        self.assertIn(expected_swift, generate(routed, Registry())['ios/App/Generated/Nodes/n_message.swift'].content)
        self.assertIn(expected_jvm, '\n'.join(a.content for a in AndroidRouted().generate(routed, Registry()).values()))
        # Native model actions use the same predicate with an explicit owner.
        self.assertIn('this.s_text', AndroidRouted().expr(predicate(), owner='this.'))
        self.assertNotIn('model.', AndroidRouted().expr(predicate(), owner='this.'))

    def test_nested_annotation_fields_and_state_dependencies(self):
        from dcflight.collection_ir import FieldReference
        app = device_fixture()
        camera, map_node = app.routes[0].body.children
        visible = BooleanAll((BooleanNot(StringIsEmpty(FieldReference('places', 'name', ScalarType.STRING))),
                              BooleanAny((Reference('override', ScalarType.BOOL), BooleanNot(Reference('blocked', ScalarType.BOOL))))))
        marker = replace(map_node.children[0], visible_when=visible)
        body = replace(app.routes[0].body, children=(camera, replace(map_node, children=(marker, *map_node.children[1:]))))
        app = replace(app, states=(*app.states, *states()), routes=(replace(app.routes[0], body=body), *app.routes[1:]))
        swift = generate(app, Registry())['ios/App/Generated/Nodes/n_marker.swift'].content
        self.assertIn('(!(item.f_name).isEmpty)', swift)
        android = '\n'.join(a.content for a in AndroidRouted().generate(app, Registry()).values())
        self.assertIn('(!(row_places.v_name).isEmpty())', android)
        self.assertIn('annotationKeys=listOf<Any>(model.s_blocked,model.s_override)', android)
        # Scope validation must also reach fields nested inside predicates.
        bad_marker = replace(marker, visible_when=BooleanNot(StringIsEmpty(FieldReference('other', 'name', ScalarType.STRING))))
        bad_body = replace(body, children=(camera, replace(map_node, children=(bad_marker, *map_node.children[1:]))))
        bad_app = replace(app, routes=(replace(app.routes[0], body=bad_body), *app.routes[1:]))
        with self.assertRaisesRegex(ValueError, 'outside its repeated row'):
            generate(bad_app, Registry())

    def native_cases(self, target):
        render = (lambda value: AndroidRouted().expr(value)) if target == 'kotlin' else (lambda value: expression(value, target))
        lines = []
        for text in ('', ' ', '\t\n', 'hello', 'é', 'e\u0301', '\u0301', '👩🏽\u200d💻', '$value'):
            for override in (False, True):
                for blocked in (False, True):
                    lines.append('model.s_text = '+render(string(text))+'; model.s_override = '+str(override).lower()+'; model.s_blocked = '+str(blocked).lower()+';')
                    expected = str((bool(text) or override) and not blocked).lower()
                    check = '('+render(predicate())+' == '+expected+')'
                    empty_check = '('+render(StringIsEmpty(Reference('text', ScalarType.STRING)))+' == '+str(not text).lower()+')'
                    for assertion in (check, empty_check):
                        if target == 'ios': lines.append('precondition'+assertion)
                        elif target == 'kotlin': lines.append('check'+assertion)
                        else: lines.append('if (!'+assertion+') throw new AssertionError("predicate mismatch");')
        return '\n'.join(lines)

    @unittest.skipUnless(shutil.which('swiftc'), 'Swift toolchain required')
    def test_swift_native_truth_table(self):
        source = 'struct Model { var s_text = ""; var s_override = false; var s_blocked = false }; var model = Model()\n'+self.native_cases('ios')
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'check.swift'; path.write_text(source)
            build = subprocess.run(['swiftc', str(path), '-o', str(Path(tmp)/'check')], capture_output=True, text=True, timeout=90)
            self.assertEqual(build.returncode, 0, build.stderr)
            subprocess.run([str(Path(tmp)/'check')], check=True, capture_output=True, timeout=20)

    @unittest.skipUnless(shutil.which('javac') and shutil.which('java'), 'JDK required')
    def test_java_native_truth_table(self):
        source = 'class Check { static class Model { String s_text=""; boolean s_override=false,s_blocked=false; } public static void main(String[] args) { Model model=new Model();\n'+self.native_cases('android')+'\n} }'
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'Check.java'; path.write_text(source)
            build = subprocess.run(['javac', str(path)], capture_output=True, text=True, timeout=90)
            self.assertEqual(build.returncode, 0, build.stderr)
            subprocess.run(['java', '-cp', tmp, 'Check'], check=True, capture_output=True, timeout=20)

    def test_kotlin_native_truth_table(self):
        compiler = os.environ.get('DCFLIGHT_KOTLIN_COMPILER_CP')
        if not compiler: self.skipTest('Set DCFLIGHT_KOTLIN_COMPILER_CP and JAVA_HOME')
        java = str(Path(os.environ['JAVA_HOME'])/'bin/java')
        source = 'class Model { var s_text=""; var s_override=false; var s_blocked=false }; fun main() { val model=Model();\n'+self.native_cases('kotlin')+'\n}'
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'Check.kt'; path.write_text(source)
            build = subprocess.run([java, '-cp', compiler, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', '-no-stdlib', '-no-reflect', '-classpath', compiler, '-d', tmp, str(path)], capture_output=True, text=True, timeout=90)
            self.assertEqual(build.returncode, 0, build.stderr)
            subprocess.run([java, '-cp', tmp+os.pathsep+compiler, 'CheckKt'], check=True, capture_output=True, timeout=20)
