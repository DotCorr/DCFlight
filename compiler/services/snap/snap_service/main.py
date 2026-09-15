import io
import os
import secrets
import sqlite3
import time
import uuid
import warnings

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from PIL import Image, ImageOps, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool
from .database import Database
from .models import DeleteAccount, Location, Login, Message, Profile, Register, Story, UserID
from .security import password_hash, password_matches, token_hash

SESSION_SECONDS = 7 * 24 * 3600
STORY_SECONDS = 24 * 3600
LOCATION_SECONDS = 3600
MEDIA_LIMIT = 8 * 1024 * 1024
USER_MEDIA_QUOTA = 100 * 1024 * 1024
Image.MAX_IMAGE_PIXELS = 20_000_000


def identity():
    return uuid.uuid4().hex


def public_user(row):
    return {key: row[key] for key in ('id', 'username', 'display_name')}


def clean_image(data):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as probe:
                if probe.format not in ('JPEG', 'PNG', 'WEBP') or getattr(probe, 'n_frames', 1) != 1:
                    raise ValueError('Only still JPEG, PNG and WebP photos are accepted')
                probe.verify()
            with Image.open(io.BytesIO(data)) as loaded:
                loaded.load()
                image = ImageOps.exif_transpose(loaded).convert('RGB')
                image.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
                # A new pixel-only image drops EXIF, GPS, XMP, ICC and text metadata.
                pixels = Image.new('RGB', image.size)
                pixels.paste(image)
                output = io.BytesIO()
                pixels.save(output, format='JPEG', quality=88, optimize=True, exif=b'', icc_profile=None)
                return output.getvalue(), pixels.width, pixels.height
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning) as error:
        raise HTTPException(415, 'Invalid, unsupported or oversized photo') from error


class RequestLimits:
    def __init__(self, app, database, clock, enabled):
        self.app, self.database, self.clock, self.enabled = app, database, clock, enabled

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        path = scope['path']
        if self.enabled:
            client = (scope.get('client') or ('unknown', 0))[0]
            category, limit, window = ('auth', 20, 60) if path.startswith('/v1/auth/') else ('all', 240, 60)
            now = int(self.clock())
            key = token_hash(category + ':' + client)
            def increment_limit():
                with self.database.connect() as db:
                    db.execute('BEGIN IMMEDIATE')
                    db.execute('DELETE FROM rate_limits WHERE bucket < ?', (now - 86400,))
                    db.execute('INSERT INTO rate_limits VALUES(?,?,1) ON CONFLICT(key,bucket) DO UPDATE SET count=count+1', (key, now // window * window))
                    return db.execute('SELECT count FROM rate_limits WHERE key=? AND bucket=?', (key, now // window * window)).fetchone()[0]
            try:
                count = await run_in_threadpool(increment_limit)
            except sqlite3.OperationalError:
                return await JSONResponse({'detail': 'Service temporarily unavailable'}, 503)(scope, receive, send)
            if count > limit:
                return await JSONResponse({'detail': 'Rate limit exceeded'}, 429, headers={'Retry-After': str(window)})(scope, receive, send)
        maximum = MEDIA_LIMIT if path == '/v1/media' and scope['method'] == 'POST' else 16384
        body = bytearray()
        while True:
            message = await receive()
            if message['type'] == 'http.disconnect':
                return
            body.extend(message.get('body', b''))
            if len(body) > maximum:
                return await JSONResponse({'detail': 'Request body too large'}, 413)(scope, receive, send)
            if not message.get('more_body', False):
                break
        consumed = False
        async def limited_receive():
            nonlocal consumed
            if consumed:
                return await receive()
            consumed = True
            return {'type': 'http.request', 'body': bytes(body), 'more_body': False}
        async def private_send(message):
            if message['type'] == 'http.response.start':
                message['headers'] = list(message.get('headers', [])) + [(b'cache-control', b'no-store'), (b'x-content-type-options', b'nosniff')]
            await send(message)
        await self.app(scope, limited_receive, private_send)


def create_app(database_path=None, *, clock=time.time, rate_limit=True):
    database = Database(database_path or os.environ.get('SNAP_DATABASE', './data/snap.sqlite3'))
    app = FastAPI(title='Snap private social API', version='0.1.0', description='Bearer-authenticated private photo sharing. Self-hosted single-node service.')
    app.state.database = database
    app.add_middleware(RequestLimits, database=database, clock=clock, enabled=rate_limit)
    bearer = HTTPBearer(auto_error=False)

    def db_connection(request: Request):
        with database.connect() as db:
            db.execute('BEGIN IMMEDIATE' if request.method in ('POST', 'PUT', 'PATCH', 'DELETE') else 'BEGIN')
            yield db

    def authenticated(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), db=Depends(db_connection, scope='function')):
        if credentials is None or credentials.scheme.lower() != 'bearer' or len(credentials.credentials) > 256:
            raise HTTPException(401, 'Authentication required', headers={'WWW-Authenticate': 'Bearer'})
        row = db.execute('SELECT u.*,s.hash AS session_hash FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.hash=? AND s.expires_at>?', (token_hash(credentials.credentials), int(clock()))).fetchone()
        if row is None:
            raise HTTPException(401, 'Invalid or expired session', headers={'WWW-Authenticate': 'Bearer'})
        return row

    def friend(db, a, b):
        low, high = sorted((a, b))
        return db.execute('SELECT 1 FROM friends WHERE a=? AND b=?', (low, high)).fetchone() is not None

    def conversation(db, cid, user):
        row = db.execute('SELECT * FROM conversations WHERE id=? AND (a=? OR b=?)', (cid, user, user)).fetchone()
        if row is None:
            raise HTTPException(404, 'Conversation not found')
        return row

    def owned_media(db, media_id, user):
        if db.execute('SELECT 1 FROM media WHERE id=? AND owner=?', (media_id, user)).fetchone() is None:
            raise HTTPException(404, 'Owned media not found')

    def new_session(db, user):
        token = secrets.token_urlsafe(32)
        expires = int(clock()) + SESSION_SECONDS
        db.execute('DELETE FROM sessions WHERE expires_at<=?', (int(clock()),))
        db.execute('INSERT INTO sessions VALUES(?,?,?)', (token_hash(token), user['id'], expires))
        return {'token': token, 'expires_at': expires, 'user': public_user(user)}

    @app.exception_handler(RequestValidationError)
    async def invalid_request(request, error):
        # Pydantic's default includes rejected input (including passwords). Never
        # echo request content into native error banners or response diagnostics.
        details = [{'loc': list(item['loc']), 'msg': item['msg'], 'type': item['type']} for item in error.errors()]
        return JSONResponse({'detail': details}, 422)

    @app.exception_handler(sqlite3.OperationalError)
    async def database_unavailable(request, error):
        return JSONResponse({'detail': 'Service temporarily unavailable'}, 503, headers={'Retry-After': '1'})

    @app.get('/health')
    def health():
        return {'status': 'ok'}

    @app.post('/v1/auth/register', status_code=201)
    def register(data: Register, db=Depends(db_connection, scope='function')):
        if not data.display_name.strip(): raise HTTPException(422, 'Display name must not be blank')
        user_id = identity()
        hashed = password_hash(data.password)
        try:
            db.execute('INSERT INTO users VALUES(?,?,?,?,?)', (user_id, data.username, data.display_name.strip(), hashed, int(clock())))
        except sqlite3.IntegrityError:
            raise HTTPException(409, 'Username unavailable')
        return new_session(db, db.execute('SELECT * FROM users WHERE id=?', (user_id,)).fetchone())

    @app.post('/v1/auth/login')
    def login(data: Login, db=Depends(db_connection, scope='function')):
        row = db.execute('SELECT * FROM users WHERE username=?', (data.username,)).fetchone()
        if not password_matches(data.password, row['password'] if row else None):
            raise HTTPException(401, 'Invalid username or password')
        return new_session(db, row)

    @app.post('/v1/auth/logout', status_code=204)
    def logout(user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        db.execute('DELETE FROM sessions WHERE hash=?', (user['session_hash'],))
        return Response(status_code=204)

    @app.get('/v1/me')
    def me(user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        result = public_user(user)
        result['location_sharing'] = db.execute('SELECT 1 FROM locations WHERE user_id=? AND updated_at>?', (user['id'], int(clock()) - LOCATION_SECONDS)).fetchone() is not None
        return result

    @app.patch('/v1/me')
    def update_profile(data: Profile, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        if not data.display_name.strip(): raise HTTPException(422, 'Display name must not be blank')
        db.execute('UPDATE users SET display_name=? WHERE id=?', (data.display_name.strip(), user['id']))
        return public_user(db.execute('SELECT * FROM users WHERE id=?', (user['id'],)).fetchone())

    @app.delete('/v1/me', status_code=204)
    def delete_account(data: DeleteAccount, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        if not password_matches(data.password, user['password']): raise HTTPException(401, 'Password confirmation failed')
        db.execute('DELETE FROM users WHERE id=?', (user['id'],))
        return Response(status_code=204)

    @app.get('/v1/users')
    def search(q: str = Query(min_length=2, max_length=24, pattern=r'^[a-zA-Z0-9_]+$'), user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        return {'users': [public_user(row) for row in db.execute('SELECT * FROM users WHERE username LIKE ? ESCAPE "!" AND id<>? ORDER BY username LIMIT 30', (q.lower().replace('_', '!_') + '%', user['id']))]}

    @app.get('/v1/friends')
    def friends(user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        rows = db.execute('SELECT u.* FROM users u JOIN friends f ON (f.a=u.id AND f.b=?) OR (f.b=u.id AND f.a=?) ORDER BY u.username LIMIT 500', (user['id'], user['id']))
        return {'friends': [public_user(row) for row in rows]}

    @app.post('/v1/friend-requests', status_code=201)
    def request_friend(data: UserID, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        if data.user_id == user['id']: raise HTTPException(422, 'Cannot friend yourself')
        if db.execute('SELECT 1 FROM users WHERE id=?', (data.user_id,)).fetchone() is None: raise HTTPException(404, 'User not found')
        if friend(db, user['id'], data.user_id): raise HTTPException(409, 'Already friends')
        if db.execute('SELECT 1 FROM friend_requests WHERE status="pending" AND ((sender=? AND recipient=?) OR (sender=? AND recipient=?))', (user['id'], data.user_id, data.user_id, user['id'])).fetchone(): raise HTTPException(409, 'Request already pending')
        request_id = identity()
        db.execute('INSERT INTO friend_requests VALUES(?,?,?,?,?) ON CONFLICT(sender,recipient) DO UPDATE SET id=excluded.id,status="pending",created_at=excluded.created_at', (request_id, user['id'], data.user_id, 'pending', int(clock())))
        return {'id': request_id, 'status': 'pending'}

    @app.get('/v1/friend-requests')
    def requests(direction: str = Query(default='all', pattern='^(all|incoming)$'), user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        return {'requests': [dict(row) for row in db.execute('SELECT r.id,r.sender,r.recipient,r.status,r.created_at,u.username,u.display_name FROM friend_requests r JOIN users u ON u.id=r.sender WHERE (r.sender=? OR r.recipient=?) AND r.status="pending" AND (?="all" OR r.recipient=?) ORDER BY r.created_at DESC LIMIT 100', (user['id'], user['id'], direction, user['id']))]}

    @app.post('/v1/friend-requests/{request_id}/accept')
    def accept(request_id: str, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        row = db.execute('SELECT * FROM friend_requests WHERE id=? AND recipient=? AND status="pending"', (request_id, user['id'])).fetchone()
        if not row: raise HTTPException(404, 'Pending request not found')
        db.execute('INSERT OR IGNORE INTO friends VALUES(?,?)', tuple(sorted((row['sender'], row['recipient']))))
        db.execute('UPDATE friend_requests SET status="accepted" WHERE id=?', (request_id,))
        return {'status': 'accepted'}

    @app.delete('/v1/friends/{user_id}', status_code=204)
    def remove_friend(user_id: str, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        db.execute('DELETE FROM friends WHERE a=? AND b=?', tuple(sorted((user_id, user['id']))))
        db.execute('DELETE FROM friend_requests WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)', (user_id, user['id'], user['id'], user_id))
        return Response(status_code=204)

    @app.post('/v1/conversations', status_code=201)
    def create_conversation(data: UserID, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        if not friend(db, user['id'], data.user_id): raise HTTPException(403, 'An accepted friendship is required')
        a,b = sorted((user['id'], data.user_id))
        db.execute('INSERT OR IGNORE INTO conversations VALUES(?,?,?,?)', (identity(), a, b, int(clock())))
        return dict(db.execute('SELECT * FROM conversations WHERE a=? AND b=?', (a,b)).fetchone())

    @app.get('/v1/conversations')
    def conversations(user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        return {'conversations': [dict(row) for row in db.execute('SELECT c.*,u.username,u.display_name FROM conversations c JOIN users u ON u.id=CASE WHEN c.a=? THEN c.b ELSE c.a END WHERE c.a=? OR c.b=? ORDER BY c.created_at DESC LIMIT 100', (user['id'],user['id'],user['id']))]}

    @app.get('/v1/conversations/{cid}/messages')
    def messages(cid: str, after: int = Query(default=0, ge=0), user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        conversation(db, cid, user['id'])
        rows = [dict(row) for row in db.execute('SELECT m.*,u.display_name AS sender_display_name FROM messages m JOIN users u ON u.id=m.sender WHERE m.conversation_id=? AND m.id>? ORDER BY m.id LIMIT 101', (cid,after))]
        page = rows[:100]
        for row in page: row['has_media'] = row['media_id'] is not None
        return {'messages': page, 'next_after': page[-1]['id'] if page else after, 'has_more': len(rows)>100}

    @app.post('/v1/conversations/{cid}/messages', status_code=201)
    def send_message(cid: str, data: Message, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        convo = conversation(db, cid, user['id'])
        if not friend(db, convo['a'], convo['b']): raise HTTPException(403, 'Friendship required to send')
        if not data.text.strip() and not data.media_id: raise HTTPException(422, 'Message must contain text or media')
        if data.media_id: owned_media(db, data.media_id, user['id'])
        cursor = db.execute('INSERT INTO messages(conversation_id,sender,text,media_id,created_at) VALUES(?,?,?,?,?)', (cid,user['id'],data.text,data.media_id,int(clock())))
        return dict(db.execute('SELECT * FROM messages WHERE id=?', (cursor.lastrowid,)).fetchone())

    @app.post('/v1/media', status_code=201)
    async def upload(request: Request, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        content, width, height = await run_in_threadpool(clean_image, await request.body())
        usage = db.execute('SELECT COALESCE(SUM(bytes),0) FROM media WHERE owner=?', (user['id'],)).fetchone()[0]
        if usage + len(content) > USER_MEDIA_QUOTA: raise HTTPException(413, 'Account media quota exceeded')
        media_id = identity()
        db.execute('INSERT INTO media VALUES(?,?,?,?,?,?,?)', (media_id,user['id'],int(clock()),width,height,len(content),content))
        return {'id': media_id, 'width': width, 'height': height, 'content_type': 'image/jpeg'}

    @app.get('/v1/media/{media_id}')
    def download(media_id: str, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        row = db.execute('SELECT * FROM media WHERE id=?', (media_id,)).fetchone()
        if row is None: raise HTTPException(404, 'Media not found')
        allowed = row['owner'] == user['id']
        if not allowed:
            allowed = db.execute('SELECT 1 FROM messages m JOIN conversations c ON c.id=m.conversation_id WHERE m.media_id=? AND (c.a=? OR c.b=?) LIMIT 1', (media_id,user['id'],user['id'])).fetchone() is not None
        if not allowed and friend(db, row['owner'], user['id']):
            allowed = db.execute('SELECT 1 FROM stories WHERE media_id=? AND expires_at>?', (media_id,int(clock()))).fetchone() is not None
        if not allowed: raise HTTPException(404, 'Media not found')
        return Response(bytes(row['content']), media_type='image/jpeg', headers={'Content-Disposition': 'inline; filename="photo.jpg"'})

    @app.post('/v1/stories', status_code=201)
    def create_story(data: Story, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        owned_media(db, data.media_id, user['id'])
        story_id, now = identity(), int(clock())
        db.execute('INSERT INTO stories VALUES(?,?,?,?,?,?)', (story_id,user['id'],data.media_id,data.caption,now,now+STORY_SECONDS))
        return dict(db.execute('SELECT * FROM stories WHERE id=?', (story_id,)).fetchone())

    @app.get('/v1/stories')
    def stories(user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        rows = db.execute('SELECT s.*,u.username,u.display_name FROM stories s JOIN users u ON u.id=s.owner WHERE s.expires_at>? AND (s.owner=? OR EXISTS(SELECT 1 FROM friends f WHERE (f.a=s.owner AND f.b=?) OR (f.b=s.owner AND f.a=?))) ORDER BY s.created_at DESC LIMIT 100', (int(clock()),user['id'],user['id'],user['id']))
        return {'stories': [{**dict(row),'is_owner':row['owner']==user['id']} for row in rows]}

    @app.delete('/v1/stories/{story_id}', status_code=204)
    def delete_story(story_id: str, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        cursor = db.execute('DELETE FROM stories WHERE id=? AND owner=?', (story_id,user['id']))
        if not cursor.rowcount: raise HTTPException(404, 'Story not found')
        return Response(status_code=204)

    @app.put('/v1/location')
    def location(data: Location, user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        if not data.enabled:
            db.execute('DELETE FROM locations WHERE user_id=?', (user['id'],))
            return {'enabled': False}
        if data.latitude_e6 is None or data.longitude_e6 is None: raise HTTPException(422, 'Coordinates required when sharing is enabled')
        now = int(clock())
        db.execute('INSERT INTO locations VALUES(?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET latitude_e6=excluded.latitude_e6,longitude_e6=excluded.longitude_e6,updated_at=excluded.updated_at', (user['id'],data.latitude_e6,data.longitude_e6,now))
        return {'enabled': True, 'expires_at': now + LOCATION_SECONDS}

    @app.get('/v1/map')
    def map_friends(user=Depends(authenticated), db=Depends(db_connection, scope='function')):
        rows = db.execute('SELECT u.id,u.username,u.display_name,l.latitude_e6,l.longitude_e6,l.updated_at FROM locations l JOIN users u ON u.id=l.user_id JOIN friends f ON (f.a=l.user_id AND f.b=?) OR (f.b=l.user_id AND f.a=?) WHERE l.updated_at>? ORDER BY u.username LIMIT 500', (user['id'],user['id'],int(clock())-LOCATION_SECONDS))
        locations=[dict(row) for row in rows]
        return {'locations':locations,'expires_at':min((row['updated_at']+LOCATION_SECONDS for row in locations),default=0)}

    return app
