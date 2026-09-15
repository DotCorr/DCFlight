import subprocess
import tempfile
from pathlib import Path
import shutil
import unittest
from dcflight.state_layout import Field,FieldType,RecordLayout

class StateLayoutTests(unittest.TestCase):
    def test_validation(self):
        with self.assertRaises(ValueError):Field('password',FieldType.UTF8,0)
        with self.assertRaises(ValueError):Field('text',FieldType.UTF8,10,'borrowed')
        with self.assertRaises(ValueError):RecordLayout('State',(Field('text',FieldType.UTF8,10),Field('textLength',FieldType.UINT32)))

    @unittest.skipUnless(shutil.which('clang'),'clang required')
    def test_native_bounds_encoding_layout_and_wipe(self):
        layout=RecordLayout('State',(Field('mode',FieldType.UINT32),Field('ready',FieldType.BOOL),Field('name',FieldType.UTF8,8)))
        self.assertEqual(layout.size,21)
        self.assertIn('nameLength',layout.dart())
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'state.h').write_text(layout.c_header())
            (root/'test.c').write_text('''#include "state.h"
#include <assert.h>
int main(){StateOwner s;State_init(&s);assert(s.state.nameCapacity==8);assert(State_set_name(&s,(uint8_t*)"hello",5));assert(!State_set_name(&s,(uint8_t*)"123456789",9));assert(s.state.nameLength==5);uint8_t invalid[]={0xc0,0x80};assert(!State_set_name(&s,invalid,2));uint8_t surrogate[]={0xed,0xa0,0x80};assert(!State_set_name(&s,surrogate,3));uint8_t valid[]={0xf0,0x9f,0x98,0x80};assert(State_set_name(&s,valid,4));assert(State_set_name(&s,(uint8_t*)"a",1));for(int i=1;i<8;i++)assert(s.nameBytes[i]==0);State_set_ready(&s,true);assert(s.state.readyFlag==1);State_wipe(&s);for(size_t i=0;i<sizeof(s);i++)assert(((uint8_t*)&s)[i]==0);}
''')
            subprocess.run(['clang','-std=c11','-Wall','-Werror',root/'test.c','-o',root/'test'],check=True)
            subprocess.run([root/'test'],check=True)
