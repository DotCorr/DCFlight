import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from dcflight.cli import main
from dcflight.native_api import NativeAPI, index_android

SDK = '''package android.test {
  public class Widget {
    ctor public Widget();
    method public void setLabel(@NonNull CharSequence);
    method public static String label();
    field public static final int FLAG = 1;
  }
}
'''


class NativeAndroidIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'api.txt'; self.source.write_text(SDK)
        self.database = self.root / 'sdk.sqlite'
        index_android(self.database, self.source)

    def cli(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = main(['sdk', *args, '--catalog', str(self.database)])
        self.assertEqual(0, result)
        return json.loads(output.getvalue())

    def test_cli_index_search_get_emit(self):
        self.assertEqual(4, self.cli('index-android', str(self.source))['indexed'])
        self.assertEqual(4, self.cli('search', 'Widget', '--platform', 'android')['total'])
        member = self.cli('get', 'android.test.Widget#setLabel(java.lang.CharSequence)', '--platform', 'android')
        self.assertEqual('nonnull', member['api']['parameters'][0]['nullability'])
        invocation = self.root / 'invoke.json'
        invocation.write_text(json.dumps({'platform': 'android', 'id': member['api']['id'], 'receiver': {'ref': 'widget', 'type': 'android.test.Widget'}, 'arguments': [{'literal': 'Hello'}]}))
        emitted = self.cli('emit', str(invocation))
        self.assertEqual('java', emitted['language'])
        self.assertEqual('((android.test.Widget) widget).setLabel((java.lang.CharSequence) ("Hello"))', emitted['source'])
        self.assertIsNone(emitted['runtimeDependency'])

    def test_changed_sdk_rejected(self):
        from dcflight.catalog import Catalog
        with Catalog(self.database) as catalog:
            snapshot = self.root/catalog.source('android','framework')['provenance']['sourceRelativePath']
        snapshot.write_text(SDK + '// edited\n')
        with self.assertRaisesRegex(ValueError, 'changed'):
            NativeAPI(self.database).emit({'platform': 'android', 'id': 'android.test.Widget#label()'})

    def test_catalog_is_portable_without_original_sdk(self):
        import shutil
        destination = self.root/'moved'
        destination.mkdir()
        shutil.move(str(self.database), destination/self.database.name)
        shutil.move(str(self.root/(self.database.name+'.sources')), destination/(self.database.name+'.sources'))
        self.source.unlink()
        result = NativeAPI(destination/self.database.name).emit({'platform':'android','id':'android.test.Widget#label()'})
        self.assertEqual('android.test.Widget.label()',result['source'])

    def test_crlf_sdk_can_be_indexed_and_used(self):
        self.source.write_bytes(SDK.replace('\n', '\r\n').encode())
        index_android(self.database, self.source)
        result = NativeAPI(self.database).emit({'platform': 'android', 'id': 'android.test.Widget#label()'})
        self.assertEqual('android.test.Widget.label()', result['source'])

    def test_rejects_raw_source_and_wrong_platform_options(self):
        api = NativeAPI(self.database)
        base = {'platform': 'android', 'id': 'android.test.Widget#label()'}
        for extra in [{'set': {'literal': 'value'}}, {'allowAsync': True}, {'arguments': [{'source': 'evil()'}]}, {'receiver': {'ref': 'x);evil()', 'type': 'android.test.Widget'}}]:
            with self.assertRaises(ValueError): api.emit({**base, **extra})


if __name__ == '__main__': unittest.main()
