import copy
import dataclasses
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from dcflight.backends.ios_routed import generate
from dcflight.backends.ios_flow import HELPERS, collection_source
from dcflight.navigation_ir import NavigationAction
from dcflight.registry import Registry
from dcflight.validate import lower
from test_collections import fixture

class IOSCollectionTests(unittest.TestCase):
    def test_shared_row_and_request_are_static_native_source(self):
        data=fixture()
        # Styling is native container semantics; canonical admission tested separately.

        app=lower(data,Registry());files=generate(app,Registry())
        row=files['ios/App/Generated/Nodes/n_label.swift'].content
        self.assertIn('let item: Collection_people',row)
        self.assertIn('Text(item.f_name)',row)
        self.assertIn('if item.f_online',row)
        listing=files['ios/App/Generated/Nodes/n_list.swift'].content
        self.assertIn('VStack(alignment: .leading, spacing: 0)',listing)
        self.assertIn('id: \\.f_id',listing)
        self.assertIn('model.s_selected = item.f_id; model.f_load(router.flowNavigation)',listing)
        model=files['ios/App/Generated/AppModel.swift'].content
        self.assertIn('@Published var c_people: [Collection_people] = []',model)
        self.assertLess(model.index('let requestPath1 = String(self.s_selected)'),model.index('requestTask=Task'))
        self.assertIn('NativeURLComponent.encode(requestPath1)',model)
        self.assertIn('Collection_people.decode(json, path: ["users"])',model)
        self.assertIn('self.c_people = output0',model)
        changed=copy.deepcopy(data);changed['routes'][0]['body']['children'][0]['props']['text']='Shared changed copy'
        updated=generate(lower(changed,Registry()),Registry())['ios/App/Generated/Nodes/n_label.swift'].content
        self.assertIn('Text("Shared changed copy")',updated)

    def test_append_is_validated_before_scalar_and_collection_assignments(self):
        data=fixture();data['state']['result']=''
        request=data['flowActions'][0]['cases'][0]['effects'][0]
        request['outputs']={'result':['result'],'people':{'path':['users'],'mode':'append'}}
        source=generate(lower(data,Registry()),Registry())['ios/App/Generated/AppModel.swift'].content
        self.assertLess(source.index('let merged1 = try Collection_people.appending(self.c_people, output1)'),source.index('self.s_result = output0'))
        self.assertIn('self.c_people = merged1',source)
        data['flowActions'][1]['cases'][0]['effects']=[{'op':'clearCollection','target':'people'}]
        source=generate(lower(data,Registry()),Registry())['ios/App/Generated/AppModel.swift'].content
        self.assertIn('self.c_people = []',source)

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('swift'),'Native Foundation required')
    def test_native_record_defaults_types_keys_and_component_encoding(self):
        app=lower(fixture(),Registry())
        source=HELPERS.split('final class NativeHTTPTransport')[0]+collection_source(app.collections)+r'''
func decode(_ raw: String) throws -> [Collection_people] { try Collection_people.decode(JSONSerialization.jsonObject(with: Data(raw.utf8)),path:["users"]) }
func reject(_ raw: String) { do { _ = try decode(raw); fatalError("accepted invalid collection") } catch {} }
let rows=try decode("{\"users\":[{\"id\":\"a\"},{\"id\":\"b\",\"name\":null,\"online\":true}]}")
precondition(rows.count==2 && rows[0].f_name=="" && rows[1].f_online)
let merged=try Collection_people.appending([rows[0]],[rows[1]])
precondition(merged==rows)
do { _ = try Collection_people.appending(rows,[rows[0]]);fatalError("accepted duplicate append") } catch {}
reject("{\"users\":[{\"id\":\"a\"},{\"id\":\"a\"}]}")
reject("{\"users\":[{\"id\":1}]}")
reject("{\"users\":[{\"id\":\"a\",\"online\":1}]}")
reject("{\"users\":[{\"id\":\"a\",\"name\":false}]}")
reject("{\"users\":null}")
precondition(NativeURLComponent.encode("/?&%+ café") == "%2F%3F%26%25%2B%20caf%C3%A9")
precondition(NativeURLComponent.encode("AZaz09-._~") == "AZaz09-._~")
'''
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'records.swift';path.write_text(source)
            result=subprocess.run(['swift',str(path)],capture_output=True,text=True,timeout=60)
            self.assertEqual(result.returncode,0,result.stderr)

    def test_root_reset_is_inherited_and_clears_native_history(self):
        app=lower(fixture(),Registry())
        app=dataclasses.replace(app,navigation_actions=(NavigationAction('reset','resetRoot','people'),))
        source=generate(app,Registry())['ios/App/Generated/NavigationRouter.swift'].content
        self.assertIn('func a_reset() { resetRoot?(.r_people) }',source)
        self.assertIn('sheet = nil; fullScreen = nil; path = []; root = route',source)
        self.assertIn('inheritedRootReset ?? { [weak router]',source)
        self.assertIn('.environment(\\.authoredRootReset, rootReset)',source)

    @unittest.skipUnless(sys.platform=='darwin' and shutil.which('xcrun'),'iOS SDK required')
    def test_all_generated_collection_sources_typecheck_for_ios(self):
        app=lower(fixture(),Registry())
        files=generate(app,Registry())
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        with tempfile.TemporaryDirectory() as directory:
            paths=[]
            for key,artifact in files.items():
                if key.endswith('.swift') and '/User/' not in key:
                    path=Path(directory)/Path(key).name;path.write_text(artifact.content);paths.append(str(path))
            result=subprocess.run(['xcrun','swiftc','-typecheck','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths],capture_output=True,text=True,timeout=120)
            self.assertEqual(result.returncode,0,result.stderr)
