import contextlib,io,json,tempfile,unittest
from pathlib import Path
from dcflight.cli import main
from test_ios_type_dependencies import capture,member,nominal

class BatchPlannerCLITests(unittest.TestCase):
    def invoke(self,capture_path,output,*extra):
        out,err=io.StringIO(),io.StringIO()
        with contextlib.redirect_stdout(out),contextlib.redirect_stderr(err):
            code=main(['sdk','plan-ios-type-dependencies','--capture',str(capture_path),'--output',str(output),'--min-free-mb','0',*extra])
        return code,out.getvalue(),err.getvalue()

    def test_real_capture_selected_plan_and_streams_without_catalog(self):
        with tempfile.TemporaryDirectory() as t:
            r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);capture(c,'Other',[nominal('type:wanted','Name')])
            code,out,err=self.invoke(c,r/'out','--module','Primary');self.assertEqual(0,code)
            result=json.loads(out);self.assertEqual(1,result['planned']);self.assertEqual(0,result['rejected']);self.assertEqual(0,result['nativeTested']);self.assertFalse(result['catalogMutation'])
            plan=json.loads((r/'out/plans/Primary/type-dependencies.json').read_text());self.assertEqual(['type:wanted'],[x['id'] for x in plan['selectedNominals']])
            for line in err.splitlines():self.assertIsInstance(json.loads(line),dict)
            self.assertFalse(list(r.rglob('*.sqlite')))

    def test_ambiguous_capture_is_explicit_rejection(self):
        with tempfile.TemporaryDirectory() as t:
            r=Path(t);c=r/'capture';capture(c,'Primary',[member()]);capture(c,'Other',[nominal('type:wanted','Name')]);capture(c,'Third',[nominal('type:wanted','Name')])
            code,out,err=self.invoke(c,r/'out','--module','Primary');self.assertEqual(0,code);result=json.loads(out);self.assertEqual(1,result['rejected']);self.assertEqual(0,result['planned']);self.assertEqual(0,result['nativeTested']);self.assertFalse((r/'out/plans/Primary').exists())

    def test_corrupt_capture_and_existing_output_fail_without_overwrite(self):
        with tempfile.TemporaryDirectory() as t:
            r=Path(t);c=r/'capture';g=capture(c,'Primary',[member()]);out=r/'out';out.mkdir();sentinel=out/'user.txt';sentinel.write_text('preserve')
            code,stdout,stderr=self.invoke(c,out);self.assertEqual(1,code);self.assertEqual('',stdout);self.assertIn('error',json.loads(stderr));self.assertEqual('preserve',sentinel.read_text())
            g.write_bytes(b'corrupt');code,stdout,stderr=self.invoke(c,r/'fresh');self.assertEqual(1,code);self.assertFalse((r/'fresh').exists())

if __name__=='__main__':unittest.main()
