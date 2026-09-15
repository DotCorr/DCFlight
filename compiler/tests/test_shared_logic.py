import copy
import json
from pathlib import Path
import tempfile
import unittest
from dcflight.ir import ABIType, ActionOperation
from dcflight.registry import Registry
from dcflight.validate import lower, Diagnostic
from dcflight.frontends import DartParser
from dcflight.backends.ios import IOS
from dcflight.backends.android import Android
from dcflight.sync import synchronize, Conflict
from dcflight.backends import Artifact
from dcflight.audit import audit_apk

EXAMPLE = Path(__file__).resolve().parents[1] / 'examples/shared_logic/app.json'


class SharedLogicTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(EXAMPLE.read_text())
        self.registry = Registry()

    def test_canonical_call_and_platform_checked_conversions(self):
        app = lower(self.data, self.registry)
        action = next(a for a in app.actions if a.id == 'add')
        self.assertEqual(action.operation, ActionOperation.CALL)
        self.assertEqual(app.logic.functions[0].parameters, (ABIType.UINT32,))
        swift = IOS().generate(app, self.registry)['ios/App/Generated/AppModel.swift'].content
        from dcflight.shared_logic import c_alias
        self.assertIn('AppLogicConversions.signed(' + c_alias(app, 'increment') + '(AppLogicConversions.unsigned(self.s_count)))', swift)
        java = Android().generate(app, self.registry)['android/app/src/main/java/com/dotcorr/sharedlogic/AppModel.java'].content
        self.assertIn('SharedLogic.f_increment(this.s_count)', java)

    def test_invalid_call_contracts_fail_before_compilation(self):
        for change in ('arity', 'type', 'negative', 'function', 'result'):
            data = copy.deepcopy(self.data)
            action = data['actions'][0]
            if change == 'arity': action['args'] = []
            if change == 'type': action['args'] = [True]
            if change == 'negative': action['args'] = [-1]
            if change == 'function': action['function'] = 'notDeclared'
            if change == 'result': action['target'] = 'enabled'
            with self.subTest(change=change), self.assertRaises(Diagnostic): lower(data, self.registry)

    def test_logic_dart_authoring_is_declarative(self):
        parsed = DartParser("const app = App(version: 1, id: 'com.example.app', name: 'Logic', state: {'count': 0}, logic: Logic(source: 'logic.dart', prelude: 'prelude.dart', functions: [LogicFunction(name: 'increment', parameters: ['uint32'], returns: 'uint32')]), actions: [Action(id: 'add', op: 'call', target: 'count', function: 'increment', args: [Ref(name: 'count')])], root: Node(id: 'root', type: 'button', props: {'text': 'Add'}, action: 'add'));" ).parse()
        self.assertEqual(lower(parsed, self.registry).logic.functions[0].name, 'increment')

    def test_binary_synchronization_is_noop_and_conflict_safe(self):
        with tempfile.TemporaryDirectory() as folder:
            artifacts = {'native/logic.o': Artifact(b'\x00\xffnative')}
            synchronize(folder, artifacts, 'com.test.app')
            self.assertEqual(synchronize(folder, artifacts, 'com.test.app')['write'], [])
            Path(folder, 'native/logic.o').write_bytes(b'changed')
            with self.assertRaises(Conflict): synchronize(folder, artifacts, 'com.test.app')

    def test_import_rewrite_preserves_strings_and_nested_comments(self):
        from dcflight.shared_logic import rewrite_imports
        text = "import 'prelude.dart';\n" + 'const value = "import \'prelude.dart\'";\n' + "/* outer /* import 'x.dart'; */ import 'y.dart'; */\n// import 'z.dart';\n"
        changed = rewrite_imports(text, Path('/app/logic.dart'), Path('/sdk/prelude.dart'))
        self.assertTrue(changed.startswith("import 'file:///sdk/prelude.dart';"))
        self.assertEqual(changed.split('\n')[1:], text.split('\n')[1:])

    def test_apk_library_requires_exact_hash(self):
        import hashlib, zipfile
        with tempfile.TemporaryDirectory() as folder:
            apk = Path(folder, 'app.apk')
            with zipfile.ZipFile(apk, 'w') as archive: archive.writestr('lib/arm64-v8a/libapplogic.so', b'native')
            with self.assertRaises(ValueError): audit_apk(apk)
            expected = {'lib/arm64-v8a/libapplogic.so': hashlib.sha256(b'native').hexdigest()}
            self.assertTrue(audit_apk(apk, expected)['passed'])
            expected['lib/arm64-v8a/libapplogic.so'] = 'bad'
            with self.assertRaises(ValueError): audit_apk(apk, expected)

    def test_uint64_is_native_adapter_abi_not_int32_state(self):
        data=copy.deepcopy(self.data)
        data['logic']['functions'].append({'name':'echoBits','parameters':['uint64'],'returns':'uint64'})
        app=lower(data,self.registry)
        self.assertEqual(app.logic.functions[-1].parameters,(ABIType.UINT64,))
        data['actions'][0].update(function='echoBits')
        with self.assertRaisesRegex(Diagnostic,'record/buffer adapters'):lower(data,self.registry)

    def test_uint64_header_type_and_schema(self):
        from dcflight.shared_logic import C_TYPES
        self.assertEqual(C_TYPES[ABIType.UINT64],'uint64_t')
        self.assertIn('uint64',json.dumps(self.registry.schema()))
