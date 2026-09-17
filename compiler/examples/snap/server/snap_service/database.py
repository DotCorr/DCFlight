from contextlib import contextmanager
from pathlib import Path
import sqlite3

SCHEMA = '''
CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,username TEXT NOT NULL UNIQUE,display_name TEXT NOT NULL,password TEXT NOT NULL,created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,expires_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS session_users ON sessions(user_id);
CREATE TABLE IF NOT EXISTS friend_requests(id TEXT PRIMARY KEY,sender TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,recipient TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,status TEXT NOT NULL CHECK(status IN ('pending','accepted')),created_at INTEGER NOT NULL,UNIQUE(sender,recipient));
CREATE TABLE IF NOT EXISTS friends(a TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,b TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,PRIMARY KEY(a,b),CHECK(a<b));
CREATE TABLE IF NOT EXISTS conversations(id TEXT PRIMARY KEY,a TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,b TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,created_at INTEGER NOT NULL,UNIQUE(a,b),CHECK(a<b));
CREATE TABLE IF NOT EXISTS media(id TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,created_at INTEGER NOT NULL,width INTEGER NOT NULL,height INTEGER NOT NULL,bytes INTEGER NOT NULL,content BLOB NOT NULL);
CREATE INDEX IF NOT EXISTS media_owner ON media(owner);
CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT,conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,sender TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,text TEXT NOT NULL,media_id TEXT REFERENCES media(id) ON DELETE CASCADE,created_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS conversation_messages ON messages(conversation_id,id);
CREATE TABLE IF NOT EXISTS stories(id TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,caption TEXT NOT NULL,created_at INTEGER NOT NULL,expires_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS active_stories ON stories(expires_at,owner);
CREATE TABLE IF NOT EXISTS locations(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,latitude_e6 INTEGER NOT NULL,longitude_e6 INTEGER NOT NULL,updated_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS rate_limits(key TEXT NOT NULL,bucket INTEGER NOT NULL,count INTEGER NOT NULL,PRIMARY KEY(key,bucket));
'''


class Database:
    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.execute('PRAGMA journal_mode=WAL')
            db.executescript(SCHEMA)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=15, check_same_thread=False)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        db.execute('PRAGMA busy_timeout=15000')
        try:
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()
