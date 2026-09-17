"""Real TCP smoke with isolated accounts; prints no credentials or messages."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import httpx
from network_flow import verify

with tempfile.TemporaryDirectory() as folder:
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
    env = {**os.environ, 'SNAP_DATABASE':str(Path(folder)/'smoke.sqlite3')}
    process = subprocess.Popen([sys.executable,'-m','uvicorn','snap_service.main:create_app','--factory','--host','127.0.0.1','--port',str(port),'--no-access-log','--no-proxy-headers','--log-level','error'], env=env)
    try:
        with httpx.Client(base_url=f'http://127.0.0.1:{port}', timeout=10) as c:
            for _ in range(100):
                try:
                    if c.get('/health').status_code == 200: break
                except httpx.ConnectError: pass
                time.sleep(.05)
            else: raise RuntimeError('Service did not start')
            accounts=[]
            for name in ['smokealice','smokebobby','smokeeve']:
                r=c.post('/v1/auth/register',json={'username':name,'password':'temporary smoke password','display_name':name});r.raise_for_status();accounts.append(r.json())
            a,b,e=accounts
            def headers(u): return {'Authorization':'Bearer '+u['token']}
            r=c.post('/v1/friend-requests',headers=headers(a),json={'user_id':b['user']['id']});r.raise_for_status()
            c.post('/v1/friend-requests/'+r.json()['id']+'/accept',headers=headers(b)).raise_for_status()
            r=c.post('/v1/conversations',headers=headers(a),json={'user_id':b['user']['id']});r.raise_for_status()
            path='/v1/conversations/'+r.json()['id']+'/messages'
            c.post(path,headers=headers(a),json={'text':'network smoke message'}).raise_for_status()
            assert len(c.get(path,headers=headers(b)).json()['messages']) == 1
            assert c.get(path,headers=headers(e)).status_code == 404
            flow=verify(c,a,b,e,path)
            print(json.dumps({**flow,'transport':'TCP HTTP loopback development','accounts':3,'unauthorized_read_status':404,'passed':True}))
    finally:
        process.terminate();process.wait(timeout=10)
