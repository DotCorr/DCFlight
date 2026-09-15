"""Full private-photo user journey against a real running HTTP service."""
import io
from PIL import Image


def verify(c, a, b, e, path):
    def h(u): return {'Authorization':'Bearer '+u['token']}
    def get(path,u): return c.get(path,headers=h(u))
    image=io.BytesIO();exif=Image.Exif();exif[270]='private metadata'
    Image.new('RGB',(32,24),'blue').save(image,format='JPEG',exif=exif)
    r=c.post('/v1/media',headers=h(a),content=image.getvalue());r.raise_for_status();mid=r.json()['id']
    assert get('/v1/media/'+mid,b).status_code==404
    c.post(path,headers=h(a),json={'text':'photo caption','media_id':mid}).raise_for_status()
    photo=get('/v1/media/'+mid,b);photo.raise_for_status()
    assert not Image.open(io.BytesIO(photo.content)).getexif()
    assert get('/v1/media/'+mid,e).status_code==404
    story=c.post('/v1/stories',headers=h(a),json={'media_id':mid,'caption':'story caption'});story.raise_for_status()
    assert story.json()['expires_at']-story.json()['created_at']==86400
    assert len(get('/v1/stories',b).json()['stories'])==1
    assert get('/v1/stories',e).json()['stories']==[]
    assert get('/v1/map',b).json()['locations']==[]
    assert c.put('/v1/location',headers=h(a),json={'enabled':True}).status_code==422
    point={'enabled':True,'latitude_e6':52370000,'longitude_e6':4890000}
    c.put('/v1/location',headers=h(a),json=point).raise_for_status()
    assert len(get('/v1/map',b).json()['locations'])==1
    assert get('/v1/map',e).json()['locations']==[]
    c.put('/v1/location',headers=h(a),json={'enabled':False}).raise_for_status()
    assert get('/v1/map',b).json()['locations']==[]
    c.put('/v1/location',headers=h(a),json=point).raise_for_status()
    c.delete('/v1/friends/'+b['user']['id'],headers=h(a)).raise_for_status()
    assert get('/v1/map',b).json()['locations']==[]
    assert get('/v1/stories',b).json()['stories']==[]
    assert c.post(path,headers=h(a),json={'text':'no longer friends'}).status_code==403
    assert get('/v1/media/'+mid,b).status_code==200  # Prior delivered attachment retention is explicit.
    c.request('DELETE','/v1/me',headers=h(a),json={'password':'temporary smoke password'}).raise_for_status()
    assert get('/v1/me',a).status_code==401
    assert get(path,b).status_code==404
    assert get('/v1/media/'+mid,b).status_code==404
    c.post('/v1/auth/logout',headers=h(b)).raise_for_status()
    assert get('/v1/me',b).status_code==401
    return {'messages_received':2,'photo_metadata_stripped':True,'story_ttl_seconds':86400,'opt_in_location':True,'unfriend_revocation':True,'account_deletion':True,'third_party_denials':True}
