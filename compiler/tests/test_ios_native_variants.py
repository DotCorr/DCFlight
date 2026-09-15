import copy
from dataclasses import replace
import unittest
from dcflight.platforms.ios_api import API, Parameter, SDKCatalog, Reference
from dcflight.ios_native_variants import identity


def forms():
    base=API('same', 'Example', ('Thing','read(completion:)'), 'method',
             (Parameter('completion','completion','(Int) -> Void',escaping=True),), 'Void', (), (), owner_kind='class')
    return base, replace(base,path=('Thing','read()'),parameters=(),result='Int',async_=True)

class VariantTests(unittest.TestCase):
    def test_order_and_explicit_selection(self):
        callback,async_=forms();a=SDKCatalog([callback,async_]);b=SDKCatalog([async_,callback])
        self.assertEqual(list(a.records()),list(b.records()))
        self.assertEqual(2,len(a.variant_records('same')))
        with self.assertRaisesRegex(ValueError,'selection required'):a.get('same')
        self.assertTrue(a.apis['same'].unsupported)
        receiver=Reference('value','Thing')
        emitted=a.select('same',identity(callback)).emit_call('same',[Reference('done','(Int) -> Void')],receiver=receiver)
        self.assertIn('completion',emitted.expression)
        emitted=a.select('same',identity(async_)).emit_call('same',receiver=receiver,allow_async=True)
        self.assertIn('await',emitted.expression)
    def test_roundtrip_tamper(self):
        a=SDKCatalog(forms());record=list(a.records())[0]
        self.assertEqual(list(a.records()),list(SDKCatalog.from_records([record]).records()))
        wrong=copy.deepcopy(record);wrong['nativeVariants'][0]['resultType']='String'
        with self.assertRaisesRegex(ValueError,'variant differs'):SDKCatalog.from_records([wrong])
        wrong=copy.deepcopy(record);wrong['nativeVariants'][0]['id']='other'
        with self.assertRaisesRegex(ValueError,'identity mismatch'):SDKCatalog.from_records([wrong])
    def test_singleton_compatibility(self):
        callback,_=forms();a=SDKCatalog([callback]);self.assertEqual([callback.to_dict()],list(a.records()))
        self.assertEqual(callback,a.get('same'))
    def test_unknown_variant_and_parent_evidence(self):
        a=SDKCatalog(forms())
        with self.assertRaisesRegex(ValueError,'Unknown native variant'):a.get('same','swift-v1:'+'0'*64)
        record=list(a.records())[0];record['nativeTested']=True
        with self.assertRaisesRegex(ValueError,'parent'):SDKCatalog.from_records([record])
    def test_duplicates_and_semantic_effects(self):
        a,b=forms();self.assertEqual(1,len(SDKCatalog([a,a]).variants['same']))
        self.assertNotEqual(identity(a),identity(replace(a,throws=True)))
        self.assertNotEqual(identity(a),identity(replace(a,actor_isolation='main')))
        self.assertEqual(identity(a),identity(replace(a,parameters=(replace(a.parameters[0],name='local'),))))
    def test_native_api_explicit_selection_and_echo(self):
        from unittest.mock import patch, MagicMock
        from dcflight.native_api import NativeAPI
        callback, async_ = forms()
        record = list(SDKCatalog([callback, async_]).records())[0]
        catalog = MagicMock()
        catalog.__enter__.return_value.get.return_value = {'api': record, 'scope': 'Example'}
        request = {'platform':'ios','id':'same','variant':identity(async_),
                   'receiver':{'ref':'object','type':'Thing'},'allowAsync':True}
        with patch('dcflight.native_api.Catalog',return_value=catalog):
            emitted = NativeAPI('/unused').emit(request)
            self.assertEqual(identity(async_), emitted['variant'])
            self.assertIn('await',emitted['source'])
            del request['variant']
            with self.assertRaisesRegex(ValueError,'selection required'):NativeAPI('/unused').emit(request)

    def test_sequence_selected_callback_retains_escaping_contract(self):
        from unittest.mock import patch, MagicMock
        from dcflight.native_api import NativeAPI
        from dcflight.native_sequence import emit_sequence, validate_sequence_structure
        callback, async_ = forms();record=list(SDKCatalog([callback,async_]).records())[0]
        catalog=MagicMock();catalog.__enter__.return_value.get.return_value={'api':record,'scope':'Example'}
        steps=[{'id':'same','variant':identity(callback),'receiver':{'ref':'object'},'arguments':[{'ref':'done'}]}]
        inputs=[{'name':'object','type':'Thing'},{'name':'done','type':'(Int) -> Void'}]
        with patch('dcflight.native_api.Catalog',return_value=catalog),patch('dcflight.catalog.Catalog',return_value=catalog):
            out=emit_sequence(NativeAPI('/unused'),{'platform':'ios','inputs':inputs,'steps':steps})
        self.assertEqual(identity(callback),out['apiCalls'][0]['variant'])
        self.assertTrue(next(c for c in out['inputContracts'] if c['name']=='done')['escaping'])
        with self.assertRaises(ValueError):validate_sequence_structure('android',[],[{'id':'same','variant':None}])

    def test_present_malformed_selector_rejected_before_lookup(self):
        from unittest.mock import patch
        from dcflight.native_api import NativeAPI
        for value in (None, '', 0, False, [], {}, 'swift-v1:'+'z'*64):
            for platform in ('ios','android'):
                with self.subTest(value=value,platform=platform):
                    with patch('dcflight.native_api.Catalog') as catalog:
                        with self.assertRaises(ValueError):
                            NativeAPI('/unused').emit({'platform':platform,'id':'same','variant':value})
                        catalog.assert_not_called()

    def test_merged_provenance_remains_bounded(self):
        a,_=forms()
        rows=[]
        for i in range(257):
            fact={'id':'type','module':'Other','spelling':'Thing','sourceSHA256':format(i,'064x')}
            rows.append(replace(a,required_imports=('Other',),type_resolutions=(fact,)))
        with self.assertRaisesRegex(ValueError,'provenance exceeds'):SDKCatalog(rows)

    def test_all_type_source_provenance_retained(self):
        a,_=forms();fact={'id':'type','module':'Other','spelling':'Thing','sourceSHA256':'a'*64}
        a=replace(a,required_imports=('Other',),type_resolutions=(fact,));b=replace(a,type_resolutions=({**fact,'sourceSHA256':'b'*64},))
        self.assertEqual(identity(a),identity(b))
        self.assertEqual(2,len(SDKCatalog([a,b]).get('same').type_resolutions))
        self.assertEqual(list(SDKCatalog([a,b]).records()),list(SDKCatalog([b,a]).records()))

if __name__=='__main__':unittest.main()
