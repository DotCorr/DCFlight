import sqlite3
import tempfile
import unittest
from pathlib import Path

from tools.report_sdk_coverage import report


class SDKCoverageReportTests(unittest.TestCase):
    def test_missing_database_is_not_created(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'missing.sqlite'
            with self.assertRaises(FileNotFoundError):
                report(path)
            self.assertFalse(path.exists())

    def test_report_keeps_indexed_emittable_and_compiled_distinct(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / 'sdk.sqlite'
            connection = sqlite3.connect(database)
            connection.executescript('''
                create table apis(platform text, scope text, id text, name text,
                    owner text, kind text, emittable integer, searchable text, descriptor text);
                create table evidence(platform text, scope text, id text, level text, evidence text);
                insert into apis values ('ios','UIKit','a','A','','method',1,'a','{}');
                insert into apis values ('ios','UIKit','b','B','','method',0,'b','{}');
                insert into evidence values ('ios','UIKit','a','compiled','{}');
            ''')
            connection.commit(); connection.close()
            result = report(database)['totals']['ios']
            self.assertEqual(result['indexed'], 2)
            self.assertEqual(result['emittable'], 1)
            self.assertEqual(result['compiled'], 1)
            self.assertEqual(result['compiledPercentOfIndexed'], 50.0)
            self.assertEqual(result['compiledPercentOfEmittable'], 100.0)
            connection = sqlite3.connect(database)
            connection.executescript('''
                insert into evidence values ('ios','UIKit','a','compiled','{}');
                insert into evidence values ('ios','UIKit','b','compiled','{}');
                insert into evidence values ('ios','UIKit','missing','compiled','{}');
                insert into evidence values ('ios','UIKit','a','executed','{}');
            ''')
            connection.commit(); connection.close()
            result = report(database)
            self.assertFalse(result['completePlatformCoverage'])
            self.assertEqual(result['totals']['ios']['compiled'], 2)
            self.assertEqual(result['totals']['ios']['compiledAndEmittable'], 1)
            self.assertEqual(result['totals']['ios']['compiledPercentOfEmittable'], 100.0)
            self.assertEqual(result['totals']['ios']['recordedExecuted'], 1)
