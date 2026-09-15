"""Transient typed media and OS acquisition; never persistent paths or runtime IR."""
from dataclasses import dataclass
from .ir import MediaRef, ScalarType

@dataclass(frozen=True)
class MediaState:
    name: str

@dataclass(frozen=True)
class PhotoOptions:
    max_edge: int = 2048
    jpeg_quality: int = 85
    max_input_bytes: int = 33554432
    max_output_bytes: int = 8388608
    max_decoded_pixels: int = 20000000

@dataclass(frozen=True)
class PickPhotoEffect:
    target: str
    options: PhotoOptions
    success: str
    cancel: str
    failure: str
    source: str = 'library'

@dataclass(frozen=True)
class ClearMediaEffect:
    target: str

@dataclass(frozen=True)
class MediaBody:
    source: MediaRef

@dataclass(frozen=True)
class MediaProjection:
    operation: str
    value: MediaRef
    @property
    def type(self):return ScalarType.BOOL if self.operation=='hasMedia' else ScalarType.INT


def lower_media(raw, reserved):
    from .validate import check,keys,identifier
    check(isinstance(raw,list) and len(raw)<=32,'media requires at most32 transient states')
    names={n.casefold() for n in reserved};result=[]
    for item in raw:
        keys(item,('name',),('name',),'media state');name=identifier(item['name'],'media.name')
        check(name.casefold() not in names,'Duplicate media/state/collection name');names.add(name.casefold());result.append(MediaState(name))
    return tuple(result)


def media_ref(raw, media_states):
    from .validate import keys,check
    keys(raw,('media',),('media',),'media reference')
    check(isinstance(raw['media'],str) and raw['media'] in {m.name for m in media_states},'Unknown transient media state')
    return MediaRef(raw['media'])


def photo_options(raw):
    from .validate import keys,check
    limits={'maxEdge':(32,4096,2048),'jpegQuality':(1,100,85),'maxInputBytes':(1,33554432,33554432),
            'maxOutputBytes':(1,8388608,8388608),'maxDecodedPixels':(1,40000000,20000000)}
    keys(raw,limits,(),'photo options');values=[]
    for key,(lo,hi,default) in limits.items():
        value=raw.get(key,default);check(type(value) is int and lo<=value<=hi,'Invalid bounded photo option: '+key);values.append(value)
    return PhotoOptions(*values)
