import hashlib
import io
import pytest
from fastapi.testclient import TestClient
from PIL import Image
from snap_service.main import create_app

PASSWORD = 'correct horse battery'

@pytest.fixture
def service(tmp_path):
    now = [1800000000]
    app = create_app(tmp_path / 'test.sqlite3', clock=lambda: now[0], rate_limit=False)
    with TestClient(app) as client:
        yield client, app, now

def account(c, name):
    r = c.post('/v1/auth/register', json={'username':name, 'display_name':name.title(), 'password':PASSWORD})
    assert r.status_code == 201, r.text
    return r.json()

def h(a): return {'Authorization':'Bearer ' + a['token']}

def connect(c, a, b):
    r = c.post('/v1/friend-requests', headers=h(a), json={'user_id':b['user']['id']})
    assert r.status_code == 201, r.text
    assert c.post('/v1/friend-requests/'+r.json()['id']+'/accept', headers=h(b)).status_code == 200
    r = c.post('/v1/conversations', headers=h(a), json={'user_id':b['user']['id']})
    assert r.status_code == 201, r.text
    return r.json()['id']

def upload(c, a):
    output = io.BytesIO(); exif = Image.Exif(); exif[270] = 'PRIVATE_METADATA_DO_NOT_PRESERVE'
    Image.new('RGB', (40,30), 'purple').save(output, format='JPEG', exif=exif)
    r = c.post('/v1/media', headers={**h(a),'Content-Type':'image/jpeg'}, content=output.getvalue())
    assert r.status_code == 201, r.text
    return r.json()['id']

def test_sessions(service):
    c, app, now = service; a = account(c, 'alice')
    with app.state.database.connect() as db:
        assert db.execute('SELECT password FROM users').fetchone()[0].startswith('scrypt$')
        assert db.execute('SELECT hash FROM sessions').fetchone()[0] == hashlib.sha256(a['token'].encode()).hexdigest()
    assert c.get('/v1/me').status_code == 401
    for name in ['alice', 'nobody']:
        assert c.post('/v1/auth/login',json={'username':name,'password':'wrong password here'}).status_code == 401
    assert c.post('/v1/auth/logout',headers=h(a)).status_code == 204
    assert c.get('/v1/me',headers=h(a)).status_code == 401
    a = c.post('/v1/auth/login',json={'username':'alice','password':PASSWORD}).json()
    now[0] = a['expires_at']
    assert c.get('/v1/me',headers=h(a)).status_code == 401

def test_messages_private_media(service):
    c, app, now = service; a,b,e = [account(c,n) for n in ['alice','bobby','eve']]
    assert c.post('/v1/conversations',headers=h(a),json={'user_id':b['user']['id']}).status_code == 403
    cid = connect(c,a,b); mid = upload(c,a); path='/v1/conversations/'+cid+'/messages'
    assert c.get('/v1/media/'+mid,headers=h(b)).status_code == 404
    r = c.post(path,headers=h(a),json={'text':'  Hello Bob  ','media_id':mid})
    assert r.status_code == 201, r.text
    assert r.json()['text'] == 'Hello Bob'
    delivered=c.get(path,headers=h(b)).json()['messages']
    assert len(delivered)==1 and delivered[0]['has_media'] is True
    assert c.get(path,headers=h(e)).status_code == 404
    assert c.post(path,headers=h(e),json={'text':'intrude'}).status_code == 404
    assert c.get('/v1/media/'+mid,headers=h(e)).status_code == 404
    assert c.get('/v1/media/'+mid).status_code == 401
    image = c.get('/v1/media/'+mid,headers=h(b))
    assert image.status_code == 200 and image.headers['cache-control'] == 'no-store'
    assert b'PRIVATE_METADATA' not in image.content
    assert not Image.open(io.BytesIO(image.content)).getexif()
    assert c.post(path,headers=h(b),json={'media_id':mid}).status_code == 404
    assert c.get(path,headers=h(b),params={'after':r.json()['id']}).json()['messages'] == []
    assert c.delete('/v1/friends/'+b['user']['id'],headers=h(a)).status_code == 204
    assert c.post(path,headers=h(a),json={'text':'blocked'}).status_code == 403

def test_stories_location_expiry(service):
    c, app, now = service; a,b,e = [account(c,n) for n in ['alice','bobby','eve']]; connect(c,a,b)
    mid=upload(c,a); story=c.post('/v1/stories',headers=h(a),json={'media_id':mid}).json()
    assert story['expires_at'] - story['created_at'] == 86400
    assert c.get('/v1/stories',headers=h(a)).json()['stories'][0]['is_owner'] is True
    friend_stories=c.get('/v1/stories',headers=h(b)).json()['stories']
    assert len(friend_stories)==1 and friend_stories[0]['is_owner'] is False
    assert c.get('/v1/stories',headers=h(e)).json()['stories'] == []
    assert c.get('/v1/media/'+mid,headers=h(b)).status_code == 200
    assert c.get('/v1/map',headers=h(b)).json()['locations'] == []
    assert c.put('/v1/location',headers=h(a),json={'enabled':True}).status_code == 422
    location={'enabled':True,'latitude_e6':52370000,'longitude_e6':4890000}
    assert c.put('/v1/location',headers=h(a),json=location).status_code == 200
    shared_map=c.get('/v1/map',headers=h(b)).json()
    assert shared_map['locations'][0]['latitude_e6']==52370000
    assert shared_map['expires_at']==now[0]+3600
    assert c.get('/v1/map',headers=h(e)).json()['locations'] == []
    now[0] += 3600
    assert c.get('/v1/map',headers=h(b)).json()=={'locations':[],'expires_at':0}
    c.put('/v1/location',headers=h(a),json=location)
    c.put('/v1/location',headers=h(a),json={'enabled':False})
    with app.state.database.connect() as db: assert db.execute('SELECT count(*) FROM locations').fetchone()[0] == 0
    now[0]=story['expires_at']
    assert c.get('/v1/stories',headers=h(b)).json()['stories'] == []
    assert c.get('/v1/media/'+mid,headers=h(b)).status_code == 404

def test_account_deletion(service):
    c, app, now = service; a,b=[account(c,n) for n in ['alice','bobby']]; cid=connect(c,a,b); mid=upload(c,a)
    c.post('/v1/conversations/'+cid+'/messages',headers=h(a),json={'media_id':mid})
    c.post('/v1/stories',headers=h(a),json={'media_id':mid})
    c.put('/v1/location',headers=h(a),json={'enabled':True,'latitude_e6':1,'longitude_e6':2})
    assert c.request('DELETE','/v1/me',headers=h(a),json={'password':'wrong'}).status_code == 401
    assert c.request('DELETE','/v1/me',headers=h(a),json={'password':PASSWORD}).status_code == 204
    assert c.get('/v1/me',headers=h(a)).status_code == 401
    assert c.get('/v1/media/'+mid,headers=h(b)).status_code == 404
    with app.state.database.connect() as db:
        for table in ['friends','friend_requests','conversations','messages','stories','media','locations']:
            assert db.execute('SELECT count(*) FROM '+table).fetchone()[0] == 0
        assert db.execute('SELECT count(*) FROM users').fetchone()[0] == 1

def test_validation(service):
    c, app, now=service; a,b,e=[account(c,n) for n in ['alice','bobby','eve']]
    req=c.post('/v1/friend-requests',headers=h(a),json={'user_id':b['user']['id']}).json()['id']
    for u in [a,e]: assert c.post('/v1/friend-requests/'+req+'/accept',headers=h(u)).status_code == 404
    c.post('/v1/friend-requests/'+req+'/accept',headers=h(b))
    cid=c.post('/v1/conversations',headers=h(a),json={'user_id':b['user']['id']}).json()['id']
    for text in ['   ','x'*2001]: assert c.post('/v1/conversations/'+cid+'/messages',headers=h(a),json={'text':text}).status_code == 422
    assert c.post('/v1/media',headers=h(a),content=b'not image').status_code == 415
    assert c.post('/v1/media',headers=h(a),content=b'x'*(8*1024*1024+1)).status_code == 413
    assert c.post('/v1/auth/login',content=b'x'*17000).status_code == 413
    assert c.put('/v1/location',headers=h(a),json={'enabled':True,'latitude_e6':90000001,'longitude_e6':0}).status_code == 422

def test_rate_limit(tmp_path):
    c=TestClient(create_app(tmp_path/'rate.sqlite3',clock=lambda:1800000000))
    statuses=[c.post('/v1/auth/login',json={}).status_code for _ in range(21)]
    assert statuses == [422]*20+[429]

def test_concurrent_conversation_creation(service):
    from concurrent.futures import ThreadPoolExecutor
    c, app, now = service; a,b=[account(c,n) for n in ['alice','bobby']]; expected=connect(c,a,b)
    def create(_):
        r=c.post('/v1/conversations',headers=h(a),json={'user_id':b['user']['id']})
        assert r.status_code == 201
        return r.json()['id']
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert set(pool.map(create,range(12))) == {expected}
    with app.state.database.connect() as db:
        assert db.execute('SELECT count(*) FROM conversations').fetchone()[0] == 1

def test_retention_cleanup(service):
    from snap_service.maintenance import clean
    c,app,now=service; a=account(c,'alice'); mid=upload(c,a)
    c.post('/v1/stories',headers=h(a),json={'media_id':mid})
    c.put('/v1/location',headers=h(a),json={'enabled':True,'latitude_e6':0,'longitude_e6':0})
    counts=clean(app.state.database, now[0]+8*86400)
    assert counts['sessions'] == counts['stories'] == counts['locations'] == counts['orphan_media'] == 1

def test_write_failure_does_not_acknowledge_success(service, monkeypatch):
    from contextlib import contextmanager
    import sqlite3
    c,app,now=service; a=account(c,'alice'); original=app.state.database.connect
    @contextmanager
    def fail_commit():
        with original() as db:
            yield db
            if db.total_changes:
                raise sqlite3.OperationalError('simulated commit failure')
    monkeypatch.setattr(app.state.database,'connect',fail_commit)
    r=c.patch('/v1/me',headers=h(a),json={'display_name':'Changed'})
    assert r.status_code == 503
    monkeypatch.setattr(app.state.database,'connect',original)
    assert c.get('/v1/me',headers=h(a)).json()['display_name'] == 'Alice'

def test_validation_never_echoes_credentials(service):
    c,app,now=service
    password='secret'
    r=c.post('/v1/auth/register',json={'username':'alice','display_name':'Alice','password':password})
    assert r.status_code==422
    assert password not in r.text
    assert all('input' not in item and 'ctx' not in item for item in r.json()['detail'])

def test_message_pagination_cursor_and_display_name(service):
    c, app, now = service
    a,b,e = [account(c,n) for n in ['alice','bobby','eve']]
    cid=connect(c,a,b);path='/v1/conversations/'+cid+'/messages'
    for index in range(101):
        assert c.post(path,headers=h(a),json={'text':str(index)}).status_code==201
    page=c.get(path,headers=h(b)).json()
    assert len(page['messages'])==100 and page['has_more'] is True
    assert page['next_after']==page['messages'][-1]['id']
    assert page['messages'][0]['sender_display_name']=='Alice'
    assert page['messages'][0]['has_media'] is False
    last=c.get(path,headers=h(b),params={'after':page['next_after']}).json()
    assert len(last['messages'])==1 and last['has_more'] is False
    assert last['messages'][0]['text']=='100'
    empty=c.get(path,headers=h(b),params={'after':last['next_after']}).json()
    assert empty['messages']==[] and empty['next_after']==last['next_after']
    assert c.get(path,headers=h(e)).status_code==404


def test_incoming_requests_exclude_outgoing_and_require_recipient(service):
    c, _, _ = service
    alice, bob, eve = [account(c, name) for name in ['alice', 'bobby', 'eve']]
    response = c.post('/v1/friend-requests', headers=h(alice), json={'user_id': bob['user']['id']})
    assert response.status_code == 201
    request_id = response.json()['id']
    for user in [alice, bob]:
        assert [r['id'] for r in c.get('/v1/friend-requests', headers=h(user)).json()['requests']] == [request_id]
    assert c.get('/v1/friend-requests?direction=incoming', headers=h(alice)).json()['requests'] == []
    incoming = c.get('/v1/friend-requests?direction=incoming', headers=h(bob)).json()['requests']
    assert len(incoming) == 1 and incoming[0]['id'] == request_id
    assert incoming[0]['sender'] == alice['user']['id'] and incoming[0]['username'] == 'alice'
    assert c.get('/v1/friend-requests?direction=incoming', headers=h(eve)).json()['requests'] == []
    assert c.get('/v1/friend-requests?direction=invalid', headers=h(bob)).status_code == 422
    assert c.get('/v1/friend-requests?direction=incoming').status_code == 401
    for user in [alice, eve]:
        assert c.post(f'/v1/friend-requests/{request_id}/accept', headers=h(user)).status_code == 404
    assert c.post(f'/v1/friend-requests/{request_id}/accept', headers=h(bob)).status_code == 200
    for user in [alice, bob]:
        assert c.get('/v1/friend-requests?direction=incoming', headers=h(user)).json()['requests'] == []
