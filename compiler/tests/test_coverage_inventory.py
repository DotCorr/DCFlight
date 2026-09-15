import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from tools.inventory_coverage_evidence import inventory


class CoverageInventoryTests(unittest.TestCase):
    def test_overlapping_snapshots_remain_separate_and_bad_files_are_reported(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            for name in ('old.sqlite','new.db'):
                with sqlite3.connect(root/name) as db:
                    db.executescript('''
                    create table sources(platform,scope,sdk,provenance);
                    create table apis(platform,scope,id,emittable);
                    create table evidence(platform,scope,id,level);
                    insert into sources values('ios','UIKit','26.2','{}');
                    insert into apis values('ios','UIKit','same',1);
                    insert into evidence values('ios','UIKit','same','compiled');
                    ''')
            (root/'invalid.sqlite').write_bytes(b'not a database')
            with sqlite3.connect(root/'unrelated.sqlite') as db:
                db.execute('create table accounts(id)')
            result=inventory([root,root])
            self.assertEqual(len(result['catalogs']),2)
            self.assertEqual(len(result['errors']),1)
            self.assertFalse(result['completePlatformCoverage'])
            self.assertNotIn('totalAPIs',result)
            self.assertTrue(all(c['sources'][0]['indexed']==1 for c in result['catalogs']))
