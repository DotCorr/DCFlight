import json
import os
from unittest.mock import patch
from pathlib import Path
import shutil
import tempfile
import unittest

from dcflight import ios_verification as verifier
from dcflight.catalog import Catalog
from dcflight.native_api import NativeAPI


def fixture_graph():
    parameters=['SectionIdentifierType','ItemIdentifierType']
    owner={'identifier':{'precise':'fixture:snapshot'},'kind':{'identifier':'swift.struct'},
           'pathComponents':['NSDiffableDataSourceSnapshot'],'declarationFragments':[{'spelling':'struct NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>'}],
           'swiftGenerics':{'parameters':[{'name':name,'index':i,'depth':0} for i,name in enumerate(parameters)],
                            'constraints':[{'kind':'conformance','lhs':name,'rhs':protocol} for name in parameters for protocol in ['Hashable','Sendable']]}}
    generic={'identifier':{'precise':'fixture:count'},'kind':{'identifier':'swift.property'},'pathComponents':['NSDiffableDataSourceSnapshot','numberOfItems'],
             'declarationFragments':[{'spelling':'var numberOfItems: Int { get }'}]}
    ordinary={'identifier':{'precise':'fixture:red'},'kind':{'identifier':'swift.type.property'},'pathComponents':['UIColor','red'],
              'declarationFragments':[{'spelling':'static var red: UIColor { get }'}]}
    return {'symbols':[owner,generic,ordinary]}


@unittest.skipUnless(shutil.which('xcrun'),'iOS Swift toolchain required')
class GenericIndexingTests(unittest.TestCase):
    def test_public_verification_indexes_specialization_without_unbound_compiled_claim(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);graphs=root/'graphs';graphs.mkdir();(graphs/'UIKit.symbols.json').write_text(json.dumps(fixture_graph()))
            database=root/'catalog.sqlite';report=root/'native.json'
            with patch.dict(os.environ,{'CLANG_MODULE_CACHE_PATH':str(root/'cache'),'SWIFT_MODULECACHE_PATH':str(root/'cache')}):
                result=verifier.verify_and_index(database,graphs,'UIKit',report,swift_version='6')
            self.assertEqual(1,result['native_tested']);self.assertEqual(1,result['native_specializations'])
            native=json.loads(report.read_text());self.assertEqual(2,native['nativeTested'])
            self.assertEqual(0,native['failedCount'])
            with Catalog(database) as catalog:
                record=catalog.get('ios','fixture:count','UIKit')
                self.assertFalse(record['api']['emittable']);self.assertEqual([],record['evidence'])
                self.assertEqual({'receiverType':'NSDiffableDataSourceSnapshot<Int, Int>'},record['api']['nativeConformance']['specialization'])
                self.assertEqual(['generic owner requires explicit specialization'],record['api']['unsupportedReasons'])
                self.assertEqual('compiled',catalog.get('ios','fixture:red','UIKit')['evidence'][0]['level'])
                coverage=catalog.coverage();self.assertEqual(1,coverage['sources'][0]['compiled']);self.assertFalse(coverage['completePlatformCoverage'])
            api=NativeAPI(database)
            with self.assertRaises(ValueError):api.emit({'platform':'ios','scope':'UIKit','id':'fixture:count','actorContext':'main'})
            emitted=api.emit({'platform':'ios','scope':'UIKit','id':'fixture:count','actorContext':'main','receiver':{'ref':'snapshot','type':'NSDiffableDataSourceSnapshot<Int, String>'}})
            self.assertEqual('Int',emitted['resultType']);self.assertIn('`snapshot`.`numberOfItems`',emitted['source'])
            with Catalog(database,write=True) as catalog:
                with self.assertRaisesRegex(ValueError,'unsupported API'):catalog.record_evidence('ios','UIKit',['fixture:count'],'compiled',{'command':['swiftc'],'toolchain':{'sdk':'fixture'}})
            for specialization in (None,{'receiverType':'NSDiffableDataSourceSnapshot<NSObject, Int>'}):
                invalid=json.loads(report.read_text())
                row=next(item for item in invalid['passed'] if item['id']=='fixture:count')
                if specialization is None:row.pop('specialization')
                else:row['specialization']=specialization
                bad=root/('bad-'+str(specialization is None)+'.json');bad.write_text(json.dumps(invalid));output=bad.with_suffix('.descriptors')
                with self.assertRaises(ValueError):verifier.export_records({'UIKit':graphs},bad,output)
                self.assertFalse(output.exists())


if __name__=='__main__':unittest.main()
