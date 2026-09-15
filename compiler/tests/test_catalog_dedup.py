import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from dcflight.catalog import Catalog

# Schema v1 fixture remains independent of the version currently under test.
V1='''CREATE TABLE sources(platform TEXT NOT NULL,scope TEXT NOT NULL,sdk TEXT NOT NULL,provenance TEXT NOT NULL,PRIMARY KEY(platform,scope));
CREATE TABLE apis(platform TEXT NOT NULL,scope TEXT NOT NULL,id TEXT NOT NULL,name TEXT NOT NULL,owner TEXT NOT NULL,kind TEXT NOT NULL,emittable INTEGER NOT NULL CHECK(emittable IN(0,1)),searchable TEXT NOT NULL,descriptor TEXT NOT NULL,PRIMARY KEY(platform,scope,id),FOREIGN KEY(platform,scope) REFERENCES sources(platform,scope) ON DELETE CASCADE);
CREATE INDEX api_names ON apis(platform,name);
CREATE TABLE evidence(platform TEXT NOT NULL,scope TEXT NOT NULL,id TEXT NOT NULL,level TEXT NOT NULL CHECK(level IN('compiled','executed')),evidence TEXT NOT NULL,PRIMARY KEY(platform,scope,id,level),FOREIGN KEY(platform,scope,id) REFERENCES apis(platform,scope,id) ON DELETE CASCADE);
PRAGMA user_version=1;'''
PAYLOAD={'command':['swiftc','-typecheck','Verify.swift'],'toolchain':{'sdk':'26.2'},'scope':'Compile only'}
def legacy(path, count=3, payload=PAYLOAD):
 c=sqlite3.connect(path);c.executescript(V1)
 c.execute('INSERT INTO sources VALUES (?,?,?,?)',('ios','Fixture','26.2','{}'))
 for index in range(count):
  name='api'+str(index);record={'id':name,'name':name,'emittable':True}
  c.execute('INSERT INTO apis VALUES (?,?,?,?,?,?,?,?,?)',('ios','Fixture',name,name,'Owner','method',1,name,json.dumps(record)))
  c.execute('INSERT INTO evidence VALUES (?,?,?,?,?)',('ios','Fixture',name,'compiled',json.dumps(payload,sort_keys=True)))
 c.commit();c.close()

class CatalogDedupTests(unittest.TestCase):
 def setUp(self):self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.path=self.root/'catalog.sqlite'
 def tearDown(self):self.temp.cleanup()
 def test_v1_read_only_unchanged_then_atomic_upgrade_with_same_read_shape(self):
  legacy(self.path);before=hashlib.sha256(self.path.read_bytes()).hexdigest()
  with Catalog(self.path) as c:
   prior=c.get('ios','api0');coverage=c.coverage();self.assertEqual(1,c.connection.execute('PRAGMA user_version').fetchone()[0])
  self.assertEqual(before,hashlib.sha256(self.path.read_bytes()).hexdigest())
  with Catalog(self.path,write=True) as c:
   self.assertEqual(2,c.connection.execute('PRAGMA user_version').fetchone()[0]);self.assertEqual(prior,c.get('ios','api0'));self.assertEqual(coverage,c.coverage())
   self.assertEqual(1,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0]);self.assertEqual(3,c.connection.execute('SELECT count(*) FROM evidence').fetchone()[0])
   self.assertEqual(['platform','scope','id','level','evidence'],[x[1] for x in c.connection.execute('PRAGMA table_info(evidence)')])
  with Catalog(self.path) as c:self.assertEqual(prior,c.get('ios','api0'))
 def test_bad_legacy_evidence_rolls_back_schema_and_rows(self):
  legacy(self.path)
  with sqlite3.connect(self.path) as c:c.execute("UPDATE evidence SET evidence='{}' WHERE id='api2'")
  with self.assertRaisesRegex(ValueError,'legacy evidence'):Catalog(self.path,write=True)
  with sqlite3.connect(self.path) as c:
   self.assertEqual(1,c.execute('PRAGMA user_version').fetchone()[0]);self.assertEqual(3,c.execute('SELECT count(*) FROM evidence').fetchone()[0]);self.assertIsNone(c.execute("SELECT name FROM sqlite_master WHERE name='evidence_links'").fetchone());self.assertEqual('table',c.execute("SELECT type FROM sqlite_master WHERE name='evidence'").fetchone()[0])
 def test_evidence_validation_replacement_and_scope_cascade(self):
  with Catalog(self.path,write=True) as c:
   for scope in ('One','Two'):c.import_records('ios',scope,'26.2',[{'id':'x','emittable':True}],{},compiled={'ids':['x'],'evidence':PAYLOAD})
   self.assertEqual(1,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])
   c.record_evidence('ios','One',['x'],'compiled',{**PAYLOAD,'detail':'new'})
   self.assertEqual(2,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])
   c.record_evidence('ios','One',['x'],'executed',PAYLOAD)
   with self.assertRaises(ValueError):c.record_evidence('ios','One',['x','missing'],'compiled',{'command':'bad','toolchain':'bad'})
   self.assertEqual('new',c.get('ios','x','One')['evidence'][0]['detail'])
   self.assertEqual(2,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])
   c.import_records('ios','One','27',[{'id':'x','emittable':True}],{})
   self.assertEqual(1,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0]);self.assertEqual(1,len(c.get('ios','x','Two')['evidence']))
   with c.connection:c.connection.execute("DELETE FROM sources WHERE scope='Two'")
   self.assertEqual(0,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])
 def test_import_entries_atomicity_and_read_only_v2(self):
  with Catalog(self.path,write=True) as c:
   c.import_records('ios','Fixture','26.2',[{'id':'a','emittable':True}],{},compiled={'ids':['a'],'evidence':PAYLOAD})
   with self.assertRaises(ValueError):c.import_records('ios','Fixture','27',[{'id':'b','emittable':True}],{},compiled={'ids':['b'],'evidence':PAYLOAD},evidence_entries=[{'ids':['missing'],'level':'executed','evidence':PAYLOAD}])
   self.assertEqual('26.2',c.source('ios','Fixture')['sdk']);self.assertEqual(1,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])
  before=self.path.read_bytes()
  with Catalog(self.path) as c:
   with self.assertRaises(sqlite3.OperationalError):c.record_evidence('ios','Fixture',['a'],'compiled',PAYLOAD)
  self.assertEqual(before,self.path.read_bytes())
 def test_unversioned_nonempty_database_rejected_without_changes(self):
  with sqlite3.connect(self.path) as c:c.execute('CREATE TABLE unrelated(x)')
  with self.assertRaisesRegex(ValueError,'Unversioned'):Catalog(self.path,write=True)
  with sqlite3.connect(self.path) as c:self.assertEqual(0,c.execute('PRAGMA user_version').fetchone()[0]);self.assertIsNone(c.execute("SELECT name FROM sqlite_master WHERE name='sources'").fetchone())
 def test_repeated_payload_size_reduction(self):
  payload={**PAYLOAD,'compilerSources':{'compiler/module_'+str(i)+'.py':hashlib.sha256(str(i).encode()).hexdigest() for i in range(100)}}
  legacy(self.path,1000,payload);before=self.path.stat().st_size
  with Catalog(self.path,write=True) as c:
   self.assertEqual(1,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0]);page=c.connection.execute('PRAGMA page_size').fetchone()[0];freed=c.connection.execute('PRAGMA freelist_count').fetchone()[0]*page
   self.assertGreater(freed,before*.7)
   # Only this disposable test fixture is compacted, never user catalogs.
   c.connection.execute('VACUUM')
  after=self.path.stat().st_size;self.assertLess(after,before*.15)
  print('CATALOG_SIZE_EVIDENCE '+json.dumps({'symbols':1000,'payloadBytes':len(json.dumps(payload,sort_keys=True).encode()),'v1Bytes':before,'v2CompactedBytes':after,'freedReusableBytesBeforeVacuum':freed,'reductionPercent':round((1-after/before)*100,2)}))

class EvidenceGroupingTests(unittest.TestCase):
 def test_grouping_preserves_ids_levels_and_payloads_for_v1_and_v2(self):
  with tempfile.TemporaryDirectory() as folder:
   path=Path(folder)/'fixture.sqlite';legacy(path,50)
   for writable in (False,True):
    with Catalog(path,write=writable) as c:
     groups=c.evidence_groups('ios','Fixture');self.assertEqual(1,len(groups));self.assertEqual(50,len(groups[0]['ids']));self.assertEqual(PAYLOAD,groups[0]['evidence']);self.assertEqual('compiled',groups[0]['level'])
     self.assertEqual([],c.evidence_groups('android','missing'))
     if writable:
      c.record_evidence('ios','Fixture',['api0'],'executed',PAYLOAD)
      groups=c.evidence_groups('ios','Fixture');self.assertEqual({'compiled','executed'},{g['level'] for g in groups})
      self.assertEqual(1,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])

class AvailabilityMigrationTests(unittest.TestCase):
 def test_native_availability_import_migrates_v1_and_preserves_other_scope(self):
  # Reuse the native SDK/JDK fixture rather than replacing javac with a mock.
  from test_android_availability import AndroidAvailabilityTests,JDK,SDK
  if not (JDK/'bin/javac').is_file() or not SDK.is_file():self.skipTest('Native JDK/Android SDK unavailable')
  from dcflight.android_availability import import_availability
  from dcflight.native_api import NativeAPI
  fixture=AndroidAvailabilityTests('test_only_generator_verified_members_are_enabled_for_exact_sdk')
  fixture.setUpClass()
  try:
   db=fixture.catalog('migrate_v1');old=db.with_suffix('.v1.sqlite')
   with Catalog(db,write=True) as c:
    c.import_records('ios','Fixture','26.2',[{'id':'retained','emittable':True}],{},compiled={'ids':['retained'],'evidence':PAYLOAD})
    with sqlite3.connect(old) as legacy_db:
     legacy_db.executescript(V1)
     for table in ('sources','apis','evidence'):
      for row in c.connection.execute('SELECT * FROM '+table):legacy_db.execute('INSERT INTO '+table+' VALUES ('+','.join('?' for _ in row)+')',tuple(row))
   old.replace(db)
   with Catalog(db) as c:self.assertEqual(1,c.connection.execute('PRAGMA user_version').fetchone()[0])
   result=import_availability(db,fixture.report_path,fixture.sdk,javac=JDK/'bin/javac')
   self.assertEqual(1,result['conditionalCompiled'])
   with Catalog(db) as c:
    self.assertEqual(2,c.connection.execute('PRAGMA user_version').fetchone()[0]);self.assertEqual(PAYLOAD['command'],c.get('ios','retained')['evidence'][0]['command'])
    self.assertEqual(2,c.connection.execute('SELECT count(*) FROM evidence_payloads').fetchone()[0])
   emitted=NativeAPI(db,android_sdk=fixture.sdk,javac=JDK/'bin/javac').emit({'platform':'android','id':'sample.Candidate#enabled(int)','arguments':[{'literal':1}],'androidSdkSha256':fixture.report['sdkSha256']})
   self.assertIn('sample.Candidate.enabled',emitted['source'])
  finally:fixture.tearDownClass()

class SchemaV2ValidationTests(unittest.TestCase):
 def assert_corruption_rejected(self,path):
  before=hashlib.sha256(path.read_bytes()).hexdigest()
  for writable in (False,True):
   with self.subTest(write=writable),self.assertRaises(ValueError):Catalog(path,write=writable)
   self.assertEqual(before,hashlib.sha256(path.read_bytes()).hexdigest())
 def test_empty_v2_marker_rejected_without_mutation(self):
  with tempfile.TemporaryDirectory() as folder:
   path=Path(folder)/'empty.sqlite'
   with sqlite3.connect(path) as c:c.execute('PRAGMA user_version=2')
   self.assert_corruption_rejected(path)
 def test_missing_or_forged_critical_objects_rejected_without_mutation(self):
  mutations=[
   'DROP TRIGGER evidence_payload_delete',
   'DROP TRIGGER evidence_payload_replace',
   'DROP VIEW evidence',
   'DROP TABLE evidence_payloads',
   'DROP INDEX evidence_payload_links',
   'ALTER TABLE evidence_links RENAME COLUMN payload_id TO broken_payload',
   'DROP TRIGGER evidence_payload_delete; CREATE TRIGGER evidence_payload_delete AFTER DELETE ON evidence_links BEGIN SELECT 1; END',
   'DROP VIEW evidence; CREATE VIEW evidence AS SELECT l.platform,l.scope,l.id,l.level,p.evidence FROM evidence_links l JOIN evidence_payloads p USING(payload_id) WHERE 0',
  ]
  with tempfile.TemporaryDirectory() as folder:
   for index,sql in enumerate(mutations):
    with self.subTest(sql=sql):
     path=Path(folder)/(str(index)+'.sqlite')
     with Catalog(path,write=True):pass
     with sqlite3.connect(path) as c:c.executescript(sql)
     self.assert_corruption_rejected(path)
 def test_payload_foreign_key_definition_required(self):
  from dcflight.catalog import SCHEMA,TRIGGERS
  with tempfile.TemporaryDirectory() as folder:
   path=Path(folder)/'foreign.sqlite'
   broken=SCHEMA.replace(',\n    FOREIGN KEY(payload_id) REFERENCES evidence_payloads(payload_id)','')
   self.assertNotEqual(SCHEMA,broken)
   with sqlite3.connect(path) as c:
    c.executescript(broken)
    for trigger in TRIGGERS:c.execute(trigger)
   self.assert_corruption_rejected(path)
