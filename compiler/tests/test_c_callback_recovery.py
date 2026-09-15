import json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from dcflight.c_callback_recovery import declaration,recover_types,patch_parameter


def api(types,result='Void'):
    return SimpleNamespace(parameters=[SimpleNamespace(type=t) for t in types],result=result)

class CallbackRecoveryTests(unittest.TestCase):
    def test_optional_and_nonoptional_callback_are_exact(self):
        self.assertEqual(recover_types(api(['((Int32) -> Void)?']),'((@convention(c) (Int32) -> Void)?) -> Void'),{0:'(@convention(c) (Int32) -> Void)?'})
        self.assertEqual(recover_types(api(['Int32','(Int32) -> Int32'],'Int32'),'(Int32, @convention(c) (Int32) -> Int32) -> Int32'),{1:'@convention(c) (Int32) -> Int32'})
    def test_only_convention_difference_allowed(self):
        original=api(['((Int32) -> Void)?'])
        for native in ['((@convention(c) (Int64) -> Void)?) -> Void','(@convention(c) (Int32) -> Void) -> Void','((@Sendable @convention(c) (Int32) -> Void)?) -> Void','((@convention(c) (Int32) -> Void)?) -> Int32','@Sendable (((Int32) -> Void)?) -> Void','(((Int32) -> Void)?) -> Void']:
            with self.subTest(native=native),self.assertRaises(ValueError):recover_types(original,native)
    def test_nested_only_convention_not_recovered(self):
        with self.assertRaises(ValueError):recover_types(api(['((Int32) -> Void) -> Void']),'((@convention(c) (Int32) -> Void) -> Void) -> Void')
    def test_fragments_preserve_identity_tokens(self):
        fragments=[{'kind':'identifier','spelling':'callback'},{'kind':'text','spelling':': (('},{'kind':'typeIdentifier','spelling':'Int32','preciseIdentifier':'s:s5Int32V'},{'kind':'text','spelling':') -> Void)?'}]
        patched=patch_parameter(fragments,'((Int32) -> Void)?','(@convention(c) (Int32) -> Void)?')
        self.assertEqual(patched[2],fragments[2]);self.assertEqual(fragments[1]['spelling'],': ((')
        self.assertEqual(''.join(f['spelling'] for f in patched),'callback: (@convention(c) (Int32) -> Void)?')
        with self.assertRaises(ValueError):patch_parameter(fragments,'Int32','@convention(c) Int32')
    def test_exact_declref_and_sdk_header_identity(self):
        with tempfile.TemporaryDirectory() as temp:
            sdk=Path(temp).resolve();header=sdk/'err.h';header.write_text('void err_set_exit(void (*callback)(int));\n')
            ast='(declref_expr type="((@convention(c) (Int32) -> Void)?) -> Void" decl='+json.dumps('Darwin.(file).err_set_exit@'+str(header)+':1:6')+' function_ref=unapplied)'
            native,evidence=declaration(ast,'Darwin','err_set_exit',sdk)
            self.assertIn('@convention(c)',native);self.assertEqual(evidence['line'],1)
            for altered in [ast+'\n'+ast,ast.replace('Darwin.(file)','Other.(file)'),ast.replace(':1:6',':2:6'),ast.replace('function_ref=unapplied','function_ref=single'),ast.replace('declref_expr','function_conversion_expr')]:
                with self.subTest(ast=altered),self.assertRaises(ValueError):declaration(altered,'Darwin','err_set_exit',sdk)
            with self.assertRaises(ValueError):declaration(ast,'Darwin','err_set_exit',sdk/'different')
            header.write_text('void different(void);\n')
            with self.assertRaises(ValueError):declaration(ast,'Darwin','err_set_exit',sdk)

class RecoveryHardeningTests(unittest.TestCase):
    def test_header_column_is_exact_utf8_token(self):
        with tempfile.TemporaryDirectory() as temp:
            sdk=Path(temp).resolve();header=sdk/'api.h';line='/*é*/ void other(void); void selected(void);';header.write_text(line+'\n')
            column=line.encode().index(b'selected')+1
            def ast(col):return '(declref_expr type="() -> Void" decl='+json.dumps('SDK.(file).selected@'+str(header)+':1:'+str(col))+' function_ref=unapplied)'
            self.assertEqual(declaration(ast(column),'SDK','selected',sdk)[1]['column'],column)
            for wrong in [0,1,column-1,column+1,999]:
                with self.subTest(column=wrong),self.assertRaises(ValueError):declaration(ast(wrong),'SDK','selected',sdk)
    def test_output_parent_symlink_rejects_before_any_write(self):
        from dcflight.c_callback_recovery import recover,reject_symlinks
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp).resolve();other=root/'other';other.mkdir();link=root/'link';link.symlink_to(other,target_is_directory=True)
            with self.assertRaisesRegex(ValueError,'symlink'):recover(root,'SDK',['c:@F@api'],link/'output',swiftc=root/'swiftc',sdk=root,target='arm64-apple-ios18.0-simulator')
            self.assertEqual(list(other.iterdir()),[])
            reject_symlinks(Path(temp)/'normal')
    def test_snapshot_change_rejects_before_output(self):
        from unittest.mock import patch
        from dcflight.c_callback_recovery import recover
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp).resolve();graph=root/'SDK.symbols.json';graph.write_text('{"module":{"name":"SDK"},"symbols":[]}');original=Path.read_bytes
            def changed(path):return b'{"module":{"name":"Other"},"symbols":[]}' if path==graph else original(path)
            with patch.object(Path,'read_bytes',changed),self.assertRaisesRegex(ValueError,'snapshot retention'):
                recover(root,'SDK',['c:@F@api'],root/'output',swiftc=root/'swiftc',sdk=root,target='arm64-apple-ios18.0-simulator')
            self.assertFalse((root/'output').exists())
    def test_timeout_stops_spawned_writer_process(self):
        import sys,time
        from dcflight.c_callback_recovery import capture
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp).resolve();marker=root/'marker'
            child="import pathlib,time; p=pathlib.Path("+repr(str(marker))+"); i=0\nwhile True:\n p.write_text(str(i)); i+=1; time.sleep(.01)"
            parent="import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',"+repr(child)+"]); time.sleep(30)"
            with self.assertRaisesRegex(ValueError,'timed out'):capture([sys.executable,'-c',parent],timeout=.5)
            self.assertTrue(marker.exists());before=marker.read_bytes();time.sleep(.15);self.assertEqual(marker.read_bytes(),before)
    def test_aggregate_decompressed_graphs_are_bounded(self):
        import gzip
        from unittest.mock import patch
        import dcflight.c_callback_recovery as recovery
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp).resolve()
            for i in range(2):
                (root/(str(i)+'.symbols.json.gz')).write_bytes(gzip.compress(json.dumps({'module':{'name':'SDK'},'symbols':[],'padding':'x'*300}).encode()))
            with patch.object(recovery,'MAX_TOTAL',512),self.assertRaisesRegex(ValueError,'Expanded graph snapshots exceed'):
                recovery.recover(root,'SDK',['c:@F@api'],root/'output',swiftc=root/'swiftc',sdk=root,target='arm64-apple-ios18.0-simulator')
            self.assertFalse((root/'output').exists())
