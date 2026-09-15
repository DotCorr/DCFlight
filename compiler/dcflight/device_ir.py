"""Typed native device mechanics; application permissions/policy remain authored."""
from dataclasses import dataclass
from .media_ir import PhotoOptions

@dataclass(frozen=True)
class CameraResource:
    id: str
@dataclass(frozen=True)
class PermissionEffect:
    capability: str
    status_target: str
    success: str
    failure: str
@dataclass(frozen=True)
class CameraFacingEffect:
    resource: str
    facing: str
    success: str
    failure: str
@dataclass(frozen=True)
class CapturePhotoEffect:
    resource: str
    target: str
    options: PhotoOptions
    success: str
    cancel: str
    failure: str
@dataclass(frozen=True)
class LocationEffect:
    latitude_target: str
    longitude_target: str
    accuracy_target: str
    success: str
    cancel: str
    failure: str
    timeout_ms: int = 15000
@dataclass(frozen=True)
class MapRegion:
    latitude_e6: int
    longitude_e6: int
    latitude_span_e6: int
    longitude_span_e6: int
@dataclass(frozen=True)
class MapConfig:
    android_module: str
    style_url: str
    attribution: str


def lower_device(data):
    from .validate import check,keys,identifier,literal
    from urllib.parse import urlsplit
    resources=data.get('cameraResources',[]);check(isinstance(resources,list) and len(resources)<=8,'cameraResources requires at most8 resources')
    result=[];seen=set()
    for item in resources:
        keys(item,('id',),('id',),'camera resource');name=identifier(item['id'],'camera resource.id');check(name not in seen,'Duplicate camera resource');seen.add(name);result.append(CameraResource(name))
    descriptions=data.get('permissionDescriptions',{});keys(descriptions,('camera','location'),(),'permission descriptions')
    for key,text in descriptions.items():
        literal(text,'permission description');check(isinstance(text,str) and 1<=len(text)<=512,'Permission purpose requires1..512 authored characters')
    config=None
    if 'mapConfig' in data:
        raw=data['mapConfig'];keys(raw,('androidModule','styleUrl','attribution'),('androidModule','styleUrl','attribution'),'map config')
        identifier(raw['androidModule'],'map androidModule');check(isinstance(raw['styleUrl'],str),'Map style URL requires string');u=urlsplit(raw['styleUrl'])
        check(u.scheme=='https' and u.hostname and not u.username and not u.password and not u.fragment,'Map style requires explicit HTTPS URL')
        literal(raw['attribution'],'map attribution');check(isinstance(raw['attribution'],str) and 1<=len(raw['attribution'])<=2048,'Map attribution requires explicit authored text')
        config=MapConfig(raw['androidModule'],raw['styleUrl'],raw['attribution'])
    return tuple(result),tuple(descriptions.items()),config


def map_region(raw):
    from .validate import keys,check
    keys(raw,('latitudeE6','longitudeE6','latitudeSpanE6','longitudeSpanE6'),('latitudeE6','longitudeE6','latitudeSpanE6','longitudeSpanE6'),'map region')
    for name,lo,hi in [('latitudeE6',-85051128,85051128),('longitudeE6',-180000000,180000000),('latitudeSpanE6',1,180000000),('longitudeSpanE6',1,360000000)]:
        check(type(raw[name]) is int and lo<=raw[name]<=hi,'Invalid map region '+name)
    check(abs(raw['latitudeE6'])*2+raw['latitudeSpanE6']<=170102256,'Map region crosses the shared Mercator latitude limit')
    check(abs(raw['longitudeE6'])*2+raw['longitudeSpanE6']<=360000000,'Map region crosses the antimeridian')
    return MapRegion(raw['latitudeE6'],raw['longitudeE6'],raw['latitudeSpanE6'],raw['longitudeSpanE6'])
