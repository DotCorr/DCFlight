import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from dcflight.evaluated_frontend import load_evaluated
from dcflight.frontends import load
from dcflight.validate import Diagnostic, lower
from dcflight.registry import Registry


class EvaluatedDartTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dart = shutil.which('dart')
        if not cls.dart:
            raise unittest.SkipTest('Dart SDK required for authoring evaluation')

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / 'app.dart'

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, body):
        self.source.write_text("import 'package:dcflight_authoring/dcflight.dart';\n" + body)

    def test_helpers_loops_and_stdout_produce_same_canonical_ir(self):
        self.write('''Node label(int n) => Text('Friend $n', id: 'friend$n');
App buildApp() {
  print('developer diagnostic outside the JSON channel');
  return App(id: 'com.example.composed', name: 'Composed',
    root: Column(id: 'list', children: [for (var i = 0; i < 3; i++) label(i)]));
}
''')
        actual = load_evaluated(self.source, self.dart)
        expected = {'version': 1, 'id': 'com.example.composed', 'name': 'Composed', 'state': {}, 'actions': [],
                    'root': {'id': 'list', 'type': 'column', 'props': {}, 'children': [
                        {'id': 'friend' + str(i), 'type': 'text', 'props': {'text': 'Friend ' + str(i)}} for i in range(3)]}}
        self.assertEqual(actual, expected)
        self.assertEqual(lower(actual, Registry()), lower(expected, Registry()))

    def test_legacy_named_ref_and_raw_node_are_compatible(self):
        self.write("App buildApp() => const App(version: 1, id: 'com.example.old', name: 'Old', state: {'name': 'Ada'}, root: Node(id: 'label', type: 'text', props: {'text': Ref(name: 'name')}));")
        self.assertEqual(load_evaluated(self.source, self.dart)['root']['props'], {'text': {'ref': 'name'}})

    def test_style_motion_and_bindings_serialize_without_execution_runtime(self):
        self.write("App buildApp() => App(id: 'com.example.style', name: 'Style', root: Text.bind(const Ref<String>(name: 'title'), id: 'title', visibleWhen: const Ref<bool>(name: 'visible'), style: const Style(padding: 12, opacity: 0.5, fill: true), motion: const Motion(durationMs: 300, kind: MotionKind.slide)));")
        root = load_evaluated(self.source, self.dart)['root']
        self.assertEqual(root['style'], {'padding': 12, 'fill': True, 'opacity': 50})
        self.assertEqual(root['motion'], {'durationMs': 300, 'kind': 'slide'})
        self.assertEqual(root['visibleWhen'], {'ref': 'visible'})
        document=load_evaluated(self.source,self.dart)
        document['state']={'title':'Title','visible':True}
        self.assertEqual(lower(document,Registry()).root.style.opacity,50)

    def test_invalid_dart_opacity_is_rejected(self):
        self.write("App buildApp() => App(id: 'com.example.bad', name: 'Bad', root: Text('Bad', id: 'bad', style: const Style(opacity: 1.1)));")
        with self.assertRaisesRegex(Diagnostic,'opacity'):load_evaluated(self.source,self.dart)

    def test_restricted_loader_does_not_execute_build_app(self):
        marker = self.root / 'executed'
        self.source.write_text("import 'dart:io';\nvoid main() { File(" + json.dumps(str(marker)) + ").writeAsStringSync('bad'); }\n")
        with self.assertRaises(Diagnostic): load(self.source)
        self.assertFalse(marker.exists())

    def test_typed_widget_argument_is_rejected_by_dart(self):
        self.write("App buildApp() => App(id: 'com.example.bad', name: 'Bad', root: Text(true, id: 'bad'));")
        with self.assertRaisesRegex(Diagnostic, 'Dart authoring failed'): load_evaluated(self.source, self.dart)

    def test_runtime_error_is_actionable(self):
        self.write("App buildApp() { throw StateError('author helper failed'); }")
        with self.assertRaisesRegex(Diagnostic, 'author helper failed'): load_evaluated(self.source, self.dart)
